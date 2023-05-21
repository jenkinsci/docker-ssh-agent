# escape=`

# The MIT License
#
#  Copyright (c) 2019-2020, Alex Earl
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

ARG JAVA_VERSION=11.0.19_7
FROM eclipse-temurin:"${JAVA_VERSION}"-jdk-windowsservercore-1809

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

USER ContainerAdministrator

# install git
ARG GIT_VERSION=2.40.1
ARG GIT_PATCH_VERSION=1
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = $('https://github.com/git-for-windows/git/releases/download/v{0}.windows.{1}/MinGit-{0}-64-bit.zip' -f $env:GIT_VERSION, $env:GIT_PATCH_VERSION) ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'mingit.zip' -UseBasicParsing ; `
    Expand-Archive mingit.zip -DestinationPath c:\mingit ; `
    Remove-Item mingit.zip -Force

ARG GIT_LFS_VERSION=3.1.4
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    $url = $('https://github.com/git-lfs/git-lfs/releases/download/v{0}/git-lfs-windows-amd64-v{0}.zip' -f $env:GIT_LFS_VERSION) ; `
    Write-Host "Retrieving $url..." ; `
    Invoke-WebRequest $url -OutFile 'GitLfs.zip' -UseBasicParsing ; `
    Expand-Archive GitLfs.zip -DestinationPath c:\mingit\mingw64\bin ; `
    Remove-Item GitLfs.zip -Force ; `
    & C:\mingit\cmd\git.exe lfs install ; `
    $CurrentPath = (Get-Itemproperty -path 'hklm:\system\currentcontrolset\control\session manager\environment' -Name Path).Path ; `
    $NewPath = $CurrentPath + ';C:\mingit\cmd' ; `
    Set-ItemProperty -path 'hklm:\system\currentcontrolset\control\session manager\environment' -Name Path -Value $NewPath

ENV ProgramFiles="C:\Program Files"
ENV WindowsPATH="C:\Windows\system32;C:\Windows"
ENV PATH="${WindowsPATH};${ProgramFiles}\PowerShell;${JAVA_HOME}\bin;C:\mingit\cmd"

ARG user=jenkins
ENV JENKINS_AGENT_USER ${user}
COPY CreateProfile.psm1 C:/
# create user and user directory
RUN Import-Module -Force C:/CreateProfile.psm1 ; `
    New-UserWithProfile -UserName $env:JENKINS_AGENT_USER -Description 'Jenkins Agent User' ; `
    Remove-Item -Force C:/CreateProfile.psm1

# setup SSH server - https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell
RUN Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 ; `
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; `
    $content = Get-Content -Path "C:\ProgramData\ssh\sshd_config" ; `
    $content | ForEach-Object { $_ -replace '#PermitRootLogin.*','PermitRootLogin no' `
        -replace '#PasswordAuthentication.*','PasswordAuthentication no' `
        -replace '#PermitEmptyPasswords.*','PermitEmptyPasswords no' `
        -replace '#PubkeyAuthentication.*','PubkeyAuthentication yes' `
        -replace '#SyslogFacility.*','SyslogFacility LOCAL0' `
        -replace '#LogLevel.*','LogLevel INFO' `
        -replace 'Match Group administrators','' `
        -replace '(\s*)AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys','' `
    } | `
    Set-Content -Path "C:\ProgramData\ssh\sshd_config" ; `
    Add-Content -Path "C:\ProgramData\ssh\sshd_config" -Value 'ChallengeResponseAuthentication no' ; `
    Add-Content -Path "C:\ProgramData\ssh\sshd_config" -Value 'HostKeyAgent \\.\pipe\openssh-ssh-agent' ; `
    Add-Content -Path "C:\ProgramData\ssh\sshd_config" -Value ('Match User {0}' -f $env:JENKINS_AGENT_USER) ; `
    Add-Content -Path "C:\ProgramData\ssh\sshd_config" -Value ('       AuthorizedKeysFile C:/Users/{0}/.ssh/authorized_keys' -f $env:JENKINS_AGENT_USER) ;

ARG JENKINS_AGENT_WORK="C:/Users/${JENKINS_AGENT_USER}/Work"
ENV JENKINS_AGENT_WORK ${JENKINS_AGENT_WORK}
VOLUME "${JENKINS_AGENT_WORK}" "C:/Users/${JENKINS_AGENT_USER}/AppData/Local/Temp"
WORKDIR "${JENKINS_AGENT_WORK}"

COPY setup-sshd.ps1 C:/ProgramData/Jenkins/setup-sshd.ps1

EXPOSE 22

ENTRYPOINT ["powershell.exe", "-NoExit", "-Command", "& C:/ProgramData/Jenkins/setup-sshd.ps1"]

LABEL `
    org.opencontainers.image.vendor="Jenkins project" `
    org.opencontainers.image.title="Official Jenkins SSH Agent Docker image" `
    org.opencontainers.image.description="A Jenkins agent image which allows using SSH to establish the connection" `
    org.opencontainers.image.url="https://www.jenkins.io/" `
    org.opencontainers.image.source="https://github.com/jenkinsci/docker-ssh-agent" `
    org.opencontainers.image.licenses="MIT"
