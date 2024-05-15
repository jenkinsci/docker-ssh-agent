function Test-CommandExists($command) {
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    $res = $false
    try {
        if(Get-Command $command) {
            $res = $true
        }
    } catch {
        $res = $false
    } finally {
        $ErrorActionPreference=$oldPreference
    }
    return $res
}

# check dependencies
if(-Not (Test-CommandExists docker)) {
    Write-Error 'docker is not available'
}

function Get-EnvOrDefault($name, $def) {
    $entry = Get-ChildItem env: | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if(($null -ne $entry) -and ![System.String]::IsNullOrWhiteSpace($entry.Value)) {
        return $entry.Value
    }
    return $def
}

function Retry-Command {
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [scriptblock] $ScriptBlock,
        [int] $RetryCount = 3,
        [int] $Delay = 30,
        [string] $SuccessMessage = 'Command executed successfuly!',
        [string] $FailureMessage = 'Failed to execute the command'
        )

    process {
        $Attempt = 1
        $Flag = $true

        do {
            try {
                $PreviousPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
                Invoke-Command -NoNewScope -ScriptBlock $ScriptBlock -OutVariable Result 4>&1
                $ErrorActionPreference = $PreviousPreference

                # flow control will execute the next line only if the command in the scriptblock executed without any errors
                # if an error is thrown, flow control will go to the 'catch' block
                Write-Verbose "$SuccessMessage `n"
                $Flag = $false
            }
            catch {
                if ($Attempt -gt $RetryCount) {
                    Write-Verbose "$FailureMessage! Total retry attempts: $RetryCount"
                    Write-Verbose "[Error Message] $($_.exception.message) `n"
                    $Flag = $false
                } else {
                    Write-Verbose "[$Attempt/$RetryCount] $FailureMessage. Retrying in $Delay seconds..."
                    Start-Sleep -Seconds $Delay
                    $Attempt = $Attempt + 1
                }
            }
        }
        While ($Flag)
    }
}

function Cleanup($name='') {
    if([System.String]::IsNullOrWhiteSpace($name)) {
        $name = Get-EnvOrDefault 'IMAGE_NAME' ''
    }

    if(![System.String]::IsNullOrWhiteSpace($name)) {
        docker kill "$name" 2>&1 | Out-Null
        docker rm -fv "$name" 2>&1 | Out-Null
    }
}

function CleanupNetwork($name) {
    docker network rm $name 2>&1 | Out-Null
}

function Is-ContainerRunning($container) {
    Start-Sleep -Seconds 5
    return Retry-Command -RetryCount 10 -Delay 2 -ScriptBlock {
        $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "inspect --format `"{{.State.Running}}`" $container"
        if(($exitCode -ne 0) -or (-not $stdout.Contains('true')) ) {
            throw('Exit code incorrect, or invalid value for running state')
        }
        return $true
    }
}

function Run-Program($cmd, $params) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = (Get-Location)
    $psi.FileName = $cmd
    $psi.Arguments = $params
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if(($env:TESTS_DEBUG -eq 'debug') -or ($env:TESTS_DEBUG -eq 'verbose')) {
        Write-Host -ForegroundColor DarkBlue "[cmd] $cmd $params"
        if ($env:TESTS_DEBUG -eq 'verbose') { Write-Host -ForegroundColor DarkGray "[stdout] $stdout" }
        if($proc.ExitCode -ne 0){
            Write-Host -ForegroundColor DarkRed "[stderr] $stderr"
        }
    }
    return $proc.ExitCode, $stdout, $stderr
}

# return the published port for given container port $1
function Get-Port($container, $port=22) {
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "port $container $port"
    return ($stdout -split ":" | Select-Object -Skip 1).Trim()
}

# run a given command through ssh on the test container.
function Run-ThruSSH($container, $privateKeyVal, $cmd) {
    $SSH_PORT = Get-Port $container 22
    if([System.String]::IsNullOrWhiteSpace($SSH_PORT)) {
        Write-Error 'Failed to get SSH port'
        return -1, $null, $null
    } else {
        if (-not $quiet) {
            Write-Host "Run-ThruSSH > Get-Port = $SSH_PORT"

            # List running and stoped containers
            $anExitCode, $aStdout, $aStderr = Run-Program 'docker.exe' 'ps --all'
            Write-Host $aStdout
        }

        $TMP_PRIV_KEY_FILE = New-TemporaryFile
        Set-Content -Path $TMP_PRIV_KEY_FILE -Value "$privateKeyVal"

        $exitCode, $stdout, $stderr = Run-Program (Join-Path $PSScriptRoot 'ssh.exe') "-v -i `"$TMP_PRIV_KEY_FILE`" -o LogLevel=$sslLogLevel -o UserKnownHostsFile=NUL -o StrictHostKeyChecking=no -l jenkins localhost -p $SSH_PORT $cmd"
        Remove-Item -Force $TMP_PRIV_KEY_FILE

        if (-not $quiet) {
            Write-Host "Run-ThruSSH > Run-Program > stdout = $stdout"
        }

        return $exitCode, $stdout, $stderr
    }
}
