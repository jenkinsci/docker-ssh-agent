# escape=`

# The MIT License
#
#  Copyright (c) 2019-2020, Alex Earl and other Jenkins Contributors
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

ARG WINDOWS_VERSION_TAG
FROM mcr.microsoft.com/windows/servercore:"${WINDOWS_VERSION_TAG}" AS jdk-pwsh

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG JAVA_HOME
ARG JAVA_ZIP_URL
ARG jdkTemp="C:\jdktemp"
ARG localArchive="${jdkTemp}\jdk.zip"
RUN New-Item -ItemType Directory -Path $env:jdkTemp | Out-Null ; `
    Invoke-WebRequest $env:JAVA_ZIP_URL -OutFile $env:localArchive ; `
    Expand-Archive -Path $env:localArchive -DestinationPath $env:jdkTemp ; `
    $expandedDir = Get-ChildItem -Path $env:jdkTemp -Directory | Where-Object { $_.Name -like 'jdk*' } ; `
    Move-Item -Path $expandedDir.FullName -Destination $env:JAVA_HOME -Force ; `
    Remove-Item -Path $env:jdkTemp -Recurse | Out-Null

ARG POWERSHELL_VERSION=7.5.4
ENV PSTMP="C:\pwsh"
RUN Invoke-WebRequest `
      -Uri "https://github.com/PowerShell/PowerShell/releases/download/v$env:POWERSHELL_VERSION/PowerShell-$env:POWERSHELL_VERSION-win-x64.zip" `
      -OutFile "$env:TEMP\pwsh.zip" ; `
    New-Item -ItemType Directory -Path "$env:PSTMP" -Force | Out-Null ; `
    Expand-Archive "$env:TEMP\pwsh.zip" "$env:PSTMP" ; `
    Remove-Item "$env:TEMP\pwsh.zip"

FROM mcr.microsoft.com/windows/nanoserver:"${WINDOWS_VERSION_TAG}"

SHELL ["cmd.exe", "/c"]

# Ensure PowerShell 7 is available
ENV PSHOME="C:\Program Files\PowerShell\7"
ENV PATH="C:\Windows\system32;C:\Windows;${PSHOME};${PATH}"
COPY --from=jdk-pwsh pwsh $PSHOME
RUN pwsh.exe -NoLogo -NoProfile -Command "$PSVersionTable"

SHELL ["pwsh.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
USER ContainerAdministrator

ARG JAVA_HOME

# The nanoserver image is nice and small, but we need a couple of things to get SSH working
COPY --from=jdk-pwsh /windows/system32/whoami.exe /windows/system32/whoami.exe
COPY --from=jdk-pwsh $JAVA_HOME $JAVA_HOME

# While nanoserver-ltsc2025 includes netapi32.dll, older versions don't
COPY --from=jdk-pwsh /windows/system32/netapi32.dll C:/netapi32.dll
RUN if (!(Test-Path 'C:\Windows\System32\netapi32.dll')) { `
        Move-Item 'C:\netapi32.dll' 'C:\Windows\System32\netapi32.dll' `
    } else { `
        Remove-Item 'C:\netapi32.dll' `
    }

# Backward compatibility with version <= 5.x: create a symlink to the "new" JAVA_HOME
# hadolint ignore=DL3059
RUN $javaMajorVersion = $env:JAVA_HOME.Substring($env:JAVA_HOME.Length - 2); `
    New-Item -Path "C:\jdk-${javaMajorVersion}" -ItemType SymbolicLink -Value "${env:JAVA_HOME}"

# Install git
ARG GIT_VERSION=2.55.0
ARG GIT_PATCH_VERSION=3
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    # The patch "windows.1" always have a different URL than the subsequent patch (ZIP filename is different)
    if($env:GIT_PATCH_VERSION -eq 1) { $url = $('https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}-64-bit.zip' -f $env:GIT_VERSION, $env:GIT_PATCH_VERSION); } `
    else {$url = $('https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}.{1}-64-bit.zip' -f $env:GIT_VERSION, $env:GIT_PATCH_VERSION)} ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'mingit.zip' -UseBasicParsing ; `
    Expand-Archive mingit.zip -DestinationPath c:\mingit ; `
    Remove-Item mingit.zip -Force

# Add java & git to PATH
ENV PATH="C:\Windows\system32;C:\Windows;${PSHOME};${JAVA_HOME}\bin;C:\mingit\cmd;${PATH}"

# Install git-lfs
ARG GIT_LFS_VERSION=3.7.1
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = $('https://github.com/git-lfs/git-lfs/releases/download/v{0}/git-lfs-windows-amd64-v{0}.zip' -f $env:GIT_LFS_VERSION) ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'GitLfs.zip' -UseBasicParsing ; `
    Expand-Archive GitLfs.zip -DestinationPath c:\mingit\mingw64\bin ; `
    $gitLfsFolder = 'c:\mingit\mingw64\bin\git-lfs-{0}' -f $env:GIT_LFS_VERSION ; `
    Move-Item -Path "${gitLfsFolder}\git-lfs.exe" -Destination c:\mingit\mingw64\bin\ ; `
    Remove-Item -Path $gitLfsFolder -Recurse -Force ; `
    Remove-Item GitLfs.zip -Force ; `
    & C:\mingit\cmd\git.exe lfs install

ARG user=jenkins
ARG JENKINS_AGENT_WORK="C:/Users/${user}/Work"
ENV JENKINS_AGENT_USER=${user}
ENV JENKINS_AGENT_WORK=${JENKINS_AGENT_WORK}

# Setup SSH server
ARG OPENSSH_VERSION=10.0.0.0p2-Preview
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/{0}/OpenSSH-Win64.zip' -f $env:OPENSSH_VERSION ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest -Uri $url -OutFile C:/openssh.zip -UseBasicParsing ; `
    Expand-Archive c:/openssh.zip 'C:/Program Files' ; `
    Remove-Item C:/openssh.zip ; `
    $env:PATH = '{0};{1}' -f $env:PATH,'C:\Program Files\OpenSSH-Win64' ; `
    if(!(Test-Path 'C:\ProgramData\ssh')) { New-Item -Type Directory -Path 'C:\ProgramData\ssh' | Out-Null } ; `
    icacls 'C:\ProgramData\ssh' /inheritance:d ; `
    icacls 'C:\ProgramData\ssh' /remove 'CREATOR OWNER' ; `
    & 'C:/Program Files/OpenSSH-Win64/Install-SSHd.ps1' ; `
    Copy-Item 'C:\Program Files\OpenSSH-Win64\sshd_config_default' 'C:\ProgramData\ssh\sshd_config' ; `
    $configPath = 'C:\ProgramData\ssh\sshd_config' ; `
    $content = Get-Content -Path $configPath ; `
    $content | ForEach-Object { $_ -replace '#PermitRootLogin.*','PermitRootLogin no' `
                        -replace '#PasswordAuthentication.*','PasswordAuthentication no' `
                        -replace '#PermitEmptyPasswords.*','PermitEmptyPasswords no' `
                        -replace '#PubkeyAuthentication.*','PubkeyAuthentication yes' `
                        -replace '#SyslogFacility.*','SyslogFacility LOCAL0' `
                        -replace '#LogLevel.*','LogLevel INFO' `
                        -replace 'Match Group administrators','' `
                        -replace '(\s*)AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys','' `
                } | `
    Set-Content -Path $configPath ; `
    Add-Content -Path $configPath -Value 'ChallengeResponseAuthentication no' ; `
    Add-Content -Path $configPath -Value 'HostKeyAgent \\.\pipe\openssh-ssh-agent' ; `
    Add-Content -Path $configPath -Value ('Match User {0}' -f $env:JENKINS_AGENT_USER) ; `
    Add-Content -Path $configPath -Value ('       AuthorizedKeysFile C:/Users/{0}/.ssh/authorized_keys' -f $env:JENKINS_AGENT_USER) ; `

    # Force PowerShell 7 for all SSH sessions
    Add-Content -Path $configPath -Value '' ; `
    Add-Content -Path $configPath -Value '# Force PowerShell 7 as default shell' ; `
    Add-Content -Path $configPath -Value ('ForceCommand {0}\pwsh.exe -NoLogo -NoProfile' -f $env:PSHOME) ; `

    New-Item -Path HKLM:\SOFTWARE -Name OpenSSH -Force | Out-Null ; `
    Remove-Item -Path "C:\ProgramData\ssh\ssh_host*_key*"

COPY CreateProfile.psm1 C:/

# Create user and user directory
RUN Import-Module -Force C:/CreateProfile.psm1 ; `
    New-UserWithProfile -UserName $env:JENKINS_AGENT_USER -Description 'Jenkins Agent User' ; `
    Remove-Item -Force C:/CreateProfile.psm1

RUN pwsh -Command `
    "Write-Host 'PSHOME:' $PSHOME; `
     Write-Host 'pwsh:' (Get-Command pwsh).Source; `
     Get-Service sshd"

VOLUME "${JENKINS_AGENT_WORK}" "C:/Users/${user}/AppData/Local/Temp"
WORKDIR "${JENKINS_AGENT_WORK}"

COPY setup-sshd.ps1 C:/ProgramData/Jenkins/setup-sshd.ps1

# Debug
RUN Get-ChildItem env: | Sort-Object Name | ConvertTo-Json -Compress

EXPOSE 22

LABEL `
    org.opencontainers.image.vendor="Jenkins project" `
    org.opencontainers.image.title="Official Jenkins SSH Agent Docker image" `
    org.opencontainers.image.description="A Jenkins agent image which allows using SSH to establish the connection" `
    org.opencontainers.image.url="https://www.jenkins.io/" `
    org.opencontainers.image.source="https://github.com/jenkinsci/docker-ssh-agent" `
    org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["pwsh.exe", "-NoExit", "-Command", "& C:/ProgramData/Jenkins/setup-sshd.ps1"]
