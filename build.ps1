[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = 'build',
    [String] $VersionTag = '1.0-1',
    [switch] $DryRun = $false,
    # Output debug info for tests. Accepted values:
    # - empty (no additional test output)
    # - 'debug' (test cmd & stderr outputed)
    # - 'verbose' (test cmd, stderr, stdout outputed)
    [String] $TestsDebug = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Disable Progress bar for faster downloads

$Repository = 'ssh-agent'
$Organisation = 'jenkins'
$ImageType = 'windows-ltsc2019'

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

if(![String]::IsNullOrWhiteSpace($env:IMAGE_TYPE)) {
    $ImageType = $env:IMAGE_TYPE
}

# Ensure constant env vars used in the docker compose file are defined
$env:DOCKERHUB_ORGANISATION = "$Organisation"
$env:DOCKERHUB_REPO = "$Repository"
$env:VERSION = "$VersionTag"

$items = $ImageType.Split('-')
$env:WINDOWS_FLAVOR = $items[0]
$env:WINDOWS_VERSION_TAG = $items[1]
$env:TOOLS_WINDOWS_VERSION = $items[1]
if ($items[1] -eq 'ltsc2019') {
    # There are no eclipse-temurin:*-ltsc2019 or mcr.microsoft.com/powershell:*-ltsc2019 docker images unfortunately, only "1809" ones
    $env:TOOLS_WINDOWS_VERSION = '1809'
}

# Check for required commands
Function Test-CommandExists {
    # From https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
    Param (
        [String] $command
    )

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if(Get-Command $command){
            Write-Debug "$command exists"
        }
    }
    Catch {
        "$command does not exist"
    }
    Finally {
        $ErrorActionPreference=$oldPreference
    }
}

Test-CommandExists 'docker'
Test-CommandExists 'docker-compose'
Test-CommandExists 'yq'

function Test-Image {
    param (
        $ImageNameAndJavaVersion
    )

    $items = $ImageNameAndJavaVersion.Split('|')
    $imageName = $items[0]
    $javaVersion = $items[1]
    $imageNameItems = $imageName.Split(':')
    $imageTag = $imageNameItems[1]

    Write-Host "= TEST: Testing ${ImageName} image"

    $env:IMAGE_NAME = $ImageName
    $env:JAVA_VERSION = "$javaVersion"

    $targetPath = '.\target\{0}' -f $imageTag
    if(Test-Path $targetPath) {
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

$baseDockerCmd = 'docker-compose --file=build-windows.yaml'
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

Write-Host "= PREPARE: List of images and tags to be processed:"
Invoke-Expression "$baseDockerCmd config"

Write-Host '= BUILD: Building all images...'
switch ($DryRun) {
    $true { Write-Host "(dry-run) $baseDockerBuildCmd" }
    $false { Invoke-Expression $baseDockerBuildCmd }
}
Write-Host '= BUILD: Finished building all images.'

if($lastExitCode -ne 0) {
    exit $lastExitCode
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
        $jdks = Invoke-Expression "$baseDockerCmd config" | yq --unwrapScalar --output-format json '.services' | ConvertFrom-Json
        foreach ($jdk in $jdks.PSObject.Properties) {
            $testFailed = $testFailed -or (Test-Image ('{0}|{1}' -f $jdk.Value.image, $jdk.Value.build.args.JAVA_VERSION))
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
