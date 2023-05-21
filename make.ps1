[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $Build = '',
    [String] $VersionTag = '1.0-1',
    [switch] $PushVersions = $false
)

$Repository = 'ssh-agent'
$Organization = 'jenkins'
$Java11Version = '11.0.19_7'

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

$builds = @{
    'jdk11-windowsservercore-ltsc2019' = @{
        'Folder' = 'windows\windowsservercore-ltsc2019';
        'Tags' = @( "windowsservercore-1809", "windowsservercore-1809-jdk11", "windowsservercore-ltsc2019", "windowsservercore-ltsc2019-jdk11" );
        'JavaVersion' = $Java11Version;
        'JavaHome' = 'C:\openjdk-11';
    };
    'jdk11-nanoserver-1809' = @{
        'Folder' = 'windows\nanoserver-ltsc2019';
        'Tags' = @( "nanoserver-1809", "nanoserver-ltsc2019", "nanoserver-1809-jdk11", "nanoserver-ltsc2019", "nanoserver-ltsc2019-jdk11" );
        'JavaVersion' = $Java11Version;
        'JavaHome' = 'C:\openjdk-11';
    };
}

function Build-Image {
    param (
        [String] $Build,
        [String] $ImageName,
        [String] $JavaVersion,
        [String] $JavaHome,
        [String] $Folder
    )

    Write-Host "Building $Build with name $imageName"
    docker build --build-arg "JAVA_VERSION=${JavaVersion}" --build-arg "JAVA_HOME=${JavaHome}" --tag="${ImageName}" --file="${Folder}/Dockerfile" ./
}

$exitCodes = 0
if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
    foreach($tag in $builds[$Build]['Tags']) {
        Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${tag}" -JavaVersion $builds[$Build]['JavaVersion'] -JavaHome $builds[$Build]['JavaHome'] -Folder $builds[$Build]['Folder']
        $exitCodes += $lastExitCode

        if($PushVersions) {
            $buildTag = "$VersionTag-$tag"
            if($tag -eq 'latest') {
                $buildTag = "$VersionTag"
            }
            Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${buildTag}" -JavaVersion $builds[$Build]['JavaVersion'] -JavaHome $builds[$Build]['JavaHome'] -Folder $builds[$Build]['Folder']
            $exitCodes += $lastExitCode
        }
    }
} else {
    foreach($b in $builds.Keys) {
        foreach($tag in $builds[$b]['Tags']) {
            Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${tag}" -JavaVersion $builds[$b]['JavaVersion'] -JavaHome $builds[$b]['JavaHome'] -Folder $builds[$b]['Folder']
            $exitCodes += $lastExitCode

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Build-Image -Build $Build -ImageName "${Organization}/${Repository}:${buildTag}" -JavaVersion $builds[$b]['JavaVersion'] -JavaHome $builds[$b]['JavaHome'] -Folder $builds[$b]['Folder']
                $exitCodes += $lastExitCode
            }
        }
    }
}

if($exitCodes -ne 0) {
    Write-Host "Image build stage failed!"
    exit 1
} else {
    Write-Host "Image build stage passed!"
}

function Test-Image {
    param (
        [String] $ImageName,
        [String] $ImageFolder
    )

    Write-Host "Testing $ImageName..."
    $env:AGENT_IMAGE = $ImageName
    $env:IMAGE_FOLDER = $ImageFolder
    Invoke-Pester -Path tests -EnableExit
    Remove-Item env:\AGENT_IMAGE
    Remove-Item env:\IMAGE_FOLDER
}

if($Target -eq "test") {
    $mod = Get-InstalledModule -Name Pester -MinimumVersion 4.9.0 -MaximumVersion 4.99.99 -ErrorAction SilentlyContinue
    if($null -eq $mod) {
        $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
        if(Test-Path $module) {
            takeown /F $module /A /R
            icacls $module /reset
            icacls $module /grant Administrators:'F' /inheritance:d /T
            Remove-Item -Path $module -Recurse -Force -Confirm:$false
        }
        Install-Module -Force -Name Pester -MaximumVersion 4.99.99
    }

    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        Test-Image $Build $builds[$Build]['Folder']
    } else {
        foreach($b in $builds.Keys) {
            Test-Image $b $builds[$b]['Folder']
        }
    }
}

function Publish-Image {
    param (
        [String] $Build,
        [String] $ImageName
    )
    Write-Host "= PUBLISH: Tagging $Build => full name = $ImageName"
    docker tag "$Build" "$ImageName"

    Write-Host "= PUBLISH: Publishing $ImageName..."
    docker push "$ImageName"
}

if($Target -eq "publish") {
    if(![System.String]::IsNullOrWhiteSpace($Build) -and $builds.ContainsKey($Build)) {
        foreach($tag in $Builds[$Build]['Tags']) {
            Publish-Image  "$Build" "${Organization}/${Repository}:${tag}"

            if($PushVersions) {
                $buildTag = "$VersionTag-$tag"
                if($tag -eq 'latest') {
                    $buildTag = "$VersionTag"
                }
                Publish-Image "$Build" "${Organization}/${Repository}:${buildTag}"
            }
        }
    } else {
        foreach($b in $builds.Keys) {
            foreach($tag in $Builds[$b]['Tags']) {
                Publish-Image "$b" "${Organization}/${Repository}:${tag}"

                if($PushVersions) {
                    $buildTag = "$VersionTag-$tag"
                    if($tag -eq 'latest') {
                        $buildTag = "$VersionTag"
                    }
                    Publish-Image "$b" "${Organization}/${Repository}:${tag}"
                }
            }
        }
    }
}

if($lastExitCode -ne 0) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
