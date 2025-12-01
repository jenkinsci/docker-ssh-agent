[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    # Default build.ps1 target
    [String] $Target = 'build',
    # Image version
    [String] $VersionTag = '0.0.1',
    # Windows flavor and windows version to build
    [String] $ImageType = 'nanoserver-ltsc2019',
    # Generate a docker compose file even if it already exists
    [switch] $OverwriteDockerComposeFile = $false,
    # Print the build and publish command instead of executing them if set
    [switch] $DryRun = $false,
    # Output debug info for tests: 'empty' (no additional test output), 'debug' (test cmd & stderr outputed), 'verbose' (test cmd, stderr, stdout outputed)
    [String] $TestsDebug = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Disable Progress bar for faster downloads

$dockerComposeFile = 'build-windows.yaml'
$baseDockerCmd = 'docker-compose --file={0}' -f $dockerComposeFile
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

$Repository = 'ssh-agent'
$Organisation = 'jenkins'

if(![String]::IsNullOrWhiteSpace($env:TESTS_DEBUG)) {
    $TestsDebug = $env:TESTS_DEBUG
}
$env:TESTS_DEBUG = $TestsDebug

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organisation = $env:DOCKERHUB_ORGANISATION
}

if(![String]::IsNullOrWhiteSpace($env:VERSION)) {
    $VersionTag = $env:VERSION
}

if(![String]::IsNullOrWhiteSpace($env:IMAGE_TYPE)) {
    $ImageType = $env:IMAGE_TYPE
}

# Ensure constant env vars used in the docker compose file are defined
$env:DOCKERHUB_ORGANISATION = "$Organisation"
$env:DOCKERHUB_REPO = "$Repository"
$env:VERSION = "$VersionTag"

# Check for required commands
Function Test-CommandExists {
    # From https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
    Param (
        [String] $command
    )

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        # Special case to test "docker buildx"
        if ($command.Contains(" ")) {
            Invoke-Expression $command | Out-Null
            Write-Debug "$command exists"
        } else {
            if(Get-Command $command){
                Write-Debug "$command exists"
            }
        }
    }
    Catch {
        "$command does not exist"
    }
    Finally {
        $ErrorActionPreference=$oldPreference
    }
}

function Test-Image {
    param (
        $ImageNameAndJavaVersion
    )

    # Ex: docker.io/jenkins/ssh-agent:windowsservercore-ltsc2019-jdk21|21.0.3_9
    $items = $ImageNameAndJavaVersion.Split('|')
    $imageName = $items[0] -replace 'docker.io/', ''
    $javaVersion = $items[1]
    $imageNameItems = $imageName.Split(':')
    $imageTag = $imageNameItems[1]

    Write-Host "= TEST: Testing ${ImageName} image"

    $env:IMAGE_NAME = $ImageName
    $env:JAVA_VERSION = "$javaVersion"

    $targetPath = '.\target\{0}' -f $imageTag
    if (Test-Path $targetPath) {
        Remove-Item -Recurse -Force $targetPath
    }
    New-Item -Path $targetPath -Type Directory | Out-Null
    $configuration.TestResult.OutputPath = '{0}\junit-results.xml' -f $targetPath
    $TestResults = Invoke-Pester -Configuration $configuration
    $failed = $false
    if ($TestResults.FailedCount -gt 0) {
        Write-Host "There were $($TestResults.FailedCount) failed tests out of $($TestResults.TotalCount) in ${ImageName}"
        $failed = $true
    } else {
        Write-Host "There were $($TestResults.PassedCount) passed tests in ${ImageName}"
    }
    Remove-Item env:\IMAGE_NAME
    Remove-Item env:\JAVA_VERSION

    return $failed
}

function Initialize-Docker() {
    Get-ChildItem env: | Select-Object Name, Value
    # Cf https://github.com/jenkins-infra/jenkins-infra/blob/production/modules/profile/templates/jenkinscontroller/casc/clouds-ec2.yaml.erb
    $dockerDaemonConfigPath = 'C:\ProgramData\Docker\config\daemon.json'
    if (Test-Path $dockerDaemonConfigPath) {
        $dockerDaemonConfig = Get-Content -Path $dockerDaemonConfigPath -Raw | ConvertFrom-Json
        Write-Host "${dockerDaemonConfigPath} file content:"
        $dockerDaemonConfig | ConvertTo-Json
        # Remove docker daemon config setting "data-root" to Z:\docker (NVMe mount) to avoid hitting moby/moby#48093
        Remove-Item -Path $dockerDaemonConfigPath

        # Push-Location -Path 'C:\Windows'
        # Rename-Item SystemTemp SystemTemp.old
        # cmd.exe /c 'mklink /D SystemTemp {0}' -f $dockerDaemonConfig.PSObject.Properties['data-root'].Value
        # Pop-Location
    }
    Get-ComputerInfo | Select-Object OsName, OsBuildNumber, WindowsVersion
    Get-WindowsFeature Containers | Out-String
    Invoke-Expression 'docker info'
}

function Initialize-DockerComposeFile {
    $baseDockerBakeCmd = 'docker buildx bake --progress=plain --file=docker-bake.hcl'

    $items = $ImageType.Split('-')
    $windowsFlavor = $items[0]
    $windowsVersion = $items[1]

    # Override the list of Windows versions taken defined in docker-bake.hcl by the version from image type
    $env:WINDOWS_VERSION_OVERRIDE = $windowsVersion

    # Retrieve the targets from docker buildx bake --print output
    # Remove the 'output' section (unsupported by docker compose)
    # For each target name as service key, return a map consisting of:
    # - 'image' set to the first tag value
    # - 'build' set to the content of the bake target
    $yqMainQuery = '''.target[]' + `
        ' | del(.output)' + `
        ' | {(. | key): {\"image\": .tags[0], \"build\": .}}'''
    # Encapsulate under a top level 'services' map
    $yqServicesQuery = '''{\"services\": .}'''

    # - Use docker buildx bake to output image definitions from the "<windowsFlavor>" bake target
    # - Convert with yq to the format expected by docker compose
    # - Store the result in the docker compose file
    $generateDockerComposeFileCmd = ' {0} {1} --print' -f $baseDockerBakeCmd, $windowsFlavor + `
        ' | yq --prettyPrint {0} | yq {1}' -f $yqMainQuery, $yqServicesQuery + `
        ' | Out-File -FilePath {0}' -f $dockerComposeFile

    Write-Host "= PREPARE: Docker compose file generation command`n$generateDockerComposeFileCmd"

    Invoke-Expression $generateDockerComposeFileCmd

    # Remove override
    Remove-Item env:\WINDOWS_VERSION_OVERRIDE
}

Test-CommandExists 'docker'
Test-CommandExists 'docker-compose'
Test-CommandExists 'docker buildx'
Test-CommandExists 'yq'

if($target -eq 'docker-init') {
    Initialize-Docker
}

# Generate the docker compose file if it doesn't exists or if the parameter OverwriteDockerComposeFile is set
if ((Test-Path $dockerComposeFile) -and -not $OverwriteDockerComposeFile) {
    Write-Host "= PREPARE: The docker compose file '$dockerComposeFile' containing the image definitions already exists."
} else {
    Write-Host "= PREPARE: Initialize the docker compose file '$dockerComposeFile' containing the image definitions."
    Initialize-DockerComposeFile
}

Write-Host '= PREPARE: List of images and tags to be processed:'
Invoke-Expression "$baseDockerCmd config"

if ($target -eq 'build') {
    Write-Host '= BUILD: Building all images...'
    switch ($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerBuildCmd" }
        $false { Invoke-Expression $baseDockerBuildCmd }
    }
    Write-Host '= BUILD: Finished building all images.'

    if($lastExitCode -ne 0) {
        exit $lastExitCode
    }
}

if($target -eq 'test') {
    if ($DryRun) {
        Write-Host '= TEST: (dry-run) test harness'
    } else {
        Write-Host '= TEST: Starting test harness'

        $mod = Get-InstalledModule -Name Pester -MinimumVersion 5.3.0 -MaximumVersion 5.3.3 -ErrorAction SilentlyContinue
        if($null -eq $mod) {
            Write-Host '= TEST: Pester 5.3.x not found: installing...'
            $module = 'C:\Program Files\WindowsPowerShell\Modules\Pester'
            if(Test-Path $module) {
                takeown /F $module /A /R
                icacls $module /reset
                icacls $module /grant Administrators:'F' /inheritance:d /T
                Remove-Item -Path $module -Recurse -Force -Confirm:$false
            }
            Install-Module -Force -Name Pester -MaximumVersion 5.3.3
        }

        Import-Module Pester
        Write-Host '= TEST: Setting up Pester environment...'
        $configuration = [PesterConfiguration]::Default
        $configuration.Run.PassThru = $true
        $configuration.Run.Path = '.\tests'
        $configuration.Run.Exit = $true
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputFormat = 'JUnitXml'
        $configuration.Output.Verbosity = 'Diagnostic'
        $configuration.CodeCoverage.Enabled = $false

        Write-Host '= TEST: Testing all images...'
        # Only fail the run afterwards in case of any test failures
        $testFailed = $false
        $imageDefinitions = Invoke-Expression "$baseDockerCmd config" | yq --unwrapScalar --output-format json '.services' | ConvertFrom-Json
        foreach ($imageDefinition in $imageDefinitions.PSObject.Properties) {
            $testFailed = $testFailed -or (Test-Image ('{0}|{1}' -f $imageDefinition.Value.image, $imageDefinition.Value.build.args.JAVA_VERSION))
        }

        # Fail if any test failures
        if($testFailed -ne $false) {
            Write-Error '= TEST: stage failed!'
            exit 1
        } else {
            Write-Host '= TEST: stage passed!'
        }
    }
}

if($target -eq 'publish') {
    Write-Host '= PUBLISH: push all images and tags'
    switch($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerCmd push" }
        $false { Invoke-Expression "$baseDockerCmd push" }
    }

    # Fail if any issues when publising the docker images
    if($lastExitCode -ne 0) {
        Write-Error '= PUBLISH: failed!'
        exit 1
    }
}

if($lastExitCode -ne 0) {
    Write-Error 'Build failed!'
} else {
    Write-Host 'Build finished successfully'
}
exit $lastExitCode
