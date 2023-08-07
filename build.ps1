[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = 'build',
    [String] $Build = '',
    [String] $VersionTag = '1.0-1',
    [switch] $PushVersions = $false
)

$ErrorActionPreference = 'Stop'
$Repository = 'ssh-agent'
<<<<<<< HEAD
$Organisation = 'jenkins'
=======
$Organization = 'jenkins'
>>>>>>> 3bbee4c (refactor Jenkinsfile, adapt build.ps1 and docker compose file)
$ImageType = 'windows-ltsc2019'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
<<<<<<< HEAD
    $Organisation = $env:DOCKERHUB_ORGANISATION
=======
    $Organization = $env:DOCKERHUB_ORGANISATION
>>>>>>> 3bbee4c (refactor Jenkinsfile, adapt build.ps1 and docker compose file)
}

if(![String]::IsNullOrWhiteSpace($env:IMAGE_TYPE)) {
    $ImageType = $env:IMAGE_TYPE
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

<<<<<<< HEAD
# Ensure constant env vars used in the docker compose file are defined
$env:DOCKERHUB_ORGANISATION = "$Organisation"
$env:DOCKERHUB_REPO = "$Repository"
$env:VERSION = "$VersionTag"
=======
# this is the jdk version that will be used for the 'bare tag' images, e.g., windowsservercore-1809-jdk11 -> windowsserver-1809
$defaultJdk = '11'
$builds = @{}
>>>>>>> 3bbee4c (refactor Jenkinsfile, adapt build.ps1 and docker compose file)

$items = $ImageType.Split("-")
$env:WINDOWS_FLAVOR = $items[0]
$env:WINDOWS_VERSION_TAG = $items[1]
$env:TOOLS_WINDOWS_VERSION = $items[1]
if ($items[1] -eq 'ltsc2019') {
    # There are no eclipse-temurin:*-ltsc2019 or mcr.microsoft.com/powershell:*-ltsc2019 docker images unfortunately, only "1809" ones
    $env:TOOLS_WINDOWS_VERSION = '1809'
}

$ProgressPreference = 'SilentlyContinue' # Disable Progress bar for faster downloads

Test-CommandExists "docker"
Test-CommandExists "docker-compose"
Test-CommandExists "yq"

<<<<<<< HEAD
=======
$baseDockerCmd = 'docker-compose --file=build-windows.yaml'
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

Invoke-Expression "$baseDockerCmd config --services" 2>$null | ForEach-Object {
    $image = '{1}-{2}-{0}' -f $_, $env:WINDOWS_FLAVOR, $env:WINDOWS_VERSION_TAG # Ex: "nanoserver-ltsc2019-jdk11"

    # Remove the 'jdk' prefix
    $jdkMajorVersion = $_.Remove(0,3)

    $baseImage = "${env:WINDOWS_FLAVOR}-${env:WINDOWS_VERSION_TAG}"
    $tags = @( $image )
    # Additional image tag without any 'jdk' prefix for the default JDK
    if($jdkMajorVersion -eq "$defaultJdk") {
        $tags += $baseImage
    }

    $builds[$image] = @{
        'Tags' = $tags;
    }
}

Write-Host '= PREPARE: List of images and tags to be processed:'
ConvertTo-Json $builds

if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    Write-Host "= BUILD: Building image ${Build}..."
    $dockerBuildCmd = '{0} {1}' -f $baseDockerBuildCmd, $Build
    Invoke-Expression $dockerBuildCmd
    Write-Host "= BUILD: Finished building image ${Build}"
} else {
    Write-Host "= BUILD: Building all images..."
    Invoke-Expression $baseDockerBuildCmd
    Write-Host "= BUILD: Finished building all image"
}

if($lastExitCode -ne 0) {
    exit $lastExitCode
}

>>>>>>> 3bbee4c (refactor Jenkinsfile, adapt build.ps1 and docker compose file)
function Test-Image {
    param (
        $ImageName
    )

    Write-Host "= TEST: Testing image ${ImageName}:"

    $env:AGENT_IMAGE = $ImageName
<<<<<<< HEAD
    $serviceName = $ImageName.SubString($ImageName.LastIndexOf('-') + 1)
=======
    $serviceName = $ImageName.SubString(0, $ImageName.LastIndexOf('-'))
>>>>>>> 3bbee4c (refactor Jenkinsfile, adapt build.ps1 and docker compose file)
    $env:BUILD_CONTEXT = Invoke-Expression "$baseDockerCmd config" 2>$null |  yq -r ".services.${serviceName}.build.context"

    if(Test-Path ".\target\$ImageName") {
        Remove-Item -Recurse -Force ".\target\$ImageName"
    }
    New-Item -Path ".\target\$ImageName" -Type Directory | Out-Null
    $configuration.TestResult.OutputPath = ".\target\$ImageName\junit-results.xml"
    $TestResults = Invoke-Pester -Configuration $configuration
    $failed = $false
    if ($TestResults.FailedCount -gt 0) {
        Write-Host "There were $($TestResults.FailedCount) failed tests out of $($TestResults.TotalCount) in $ImageName"
        $failed = $true
    } else {
        Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $ImageName"
    }
    Remove-Item env:\AGENT_IMAGE
    Remove-Item env:\BUILD_CONTEXT
<<<<<<< HEAD

    return $failed
}

$baseDockerCmd = 'docker-compose --file=build-windows.yaml'
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

$builds = @()

$compose = Invoke-Expression "$baseDockerCmd config --format=json" 2>$null | ConvertFrom-Json
foreach ($service in $compose.services.PSObject.Properties) {
    $builds += $service.Value.image
}

Write-Host "= PREPARE: List of $Organisation/$env:DOCKERHUB_REPO images and tags to be processed:"
Invoke-Expression "$baseDockerCmd config"

Write-Host "= BUILD: Building all images..."
    switch ($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerBuildCmd" }
        $false { Invoke-Expression $baseDockerBuildCmd }
    }
    Write-Host "= BUILD: Finished building all images."

if($lastExitCode -ne 0) {
    exit $lastExitCode
=======
>>>>>>> 3bbee4c (refactor Jenkinsfile, adapt build.ps1 and docker compose file)
}

if($target -eq "test") {
    if ($DryRun) {
        Write-Host "= TEST: (dry-run) test harness"
    } else {
        Write-Host "= TEST: Starting test harness"

        $mod = Get-InstalledModule -Name Pester -MinimumVersion 5.3.0 -MaximumVersion 5.3.3 -ErrorAction SilentlyContinue
        if($null -eq $mod) {
            Write-Host "= TEST: Pester 5.3.x not found: installing..."
            $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
            if(Test-Path $module) {
                takeown /F $module /A /R
                icacls $module /reset
                icacls $module /grant Administrators:'F' /inheritance:d /T
                Remove-Item -Path $module -Recurse -Force -Confirm:$false
            }
            Install-Module -Force -Name Pester -MaximumVersion 5.3.3
        }

        Import-Module Pester
        Write-Host "= TEST: Setting up Pester environment..."
        $configuration = [PesterConfiguration]::Default
        $configuration.Run.PassThru = $true
        $configuration.Run.Path = '.\tests'
        $configuration.Run.Exit = $true
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputFormat = 'JUnitXml'
        $configuration.Output.Verbosity = 'Diagnostic'
        $configuration.CodeCoverage.Enabled = $false

        Write-Host "= TEST: Testing all ${agentType} images..."
        # Only fail the run afterwards in case of any test failures
        $testFailed = $false
        foreach($image in $builds) {
            $testFailed = $testFailed -or (Test-Image $image)
        }

        # Fail if any test failures
        if($testFailed -ne $false) {
            Write-Error "= TEST: stage failed!"
            exit 1
        } else {
            Write-Host "= TEST: stage passed!"
        }
    }
}

if($target -eq "publish") {
<<<<<<< HEAD
    Write-Host "= PUBLISH: push all images and tags"
    switch($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerCmd push" }
        $false { Invoke-Expression "$baseDockerCmd push" }
=======
    # Only fail the run afterwards in case of any issues when publishing the docker images
    $publishFailed = 0
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Publish-Image  "$Build" "${Organization}/${Repository}:${tag}"
            if($lastExitCode -ne 0) {
                $publishFailed = 1
            }

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Publish-Image "$Build" "${Organization}/${Repository}:${buildTag}"
                if($lastExitCode -ne 0) {
                    $publishFailed = 1
                }
            }
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Publish-Image "$b" "${Organization}/${Repository}:${tag}"
                if($lastExitCode -ne 0) {
                    $publishFailed = 1
                }

                if($PushVersions) {
                    $buildTag = "$VersionTag-$tag"
                    if($tag -eq 'latest') {
                        $buildTag = "$VersionTag"
                    }
                    Publish-Image "$b" "${Organization}/${Repository}:${buildTag}"
                    if($lastExitCode -ne 0) {
                        $publishFailed = 1
                    }
                }
            }
        }
>>>>>>> 3bbee4c (refactor Jenkinsfile, adapt build.ps1 and docker compose file)
    }

    # Fail if any issues when publising the docker images
    if($lastExitCode -ne 0) {
        Write-Error "= PUBLISH: failed!"
        exit 1
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
