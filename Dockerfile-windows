# escape=`

# The MIT License
#
#  Copyright (c) 2019, Alex Earl
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

ARG WINDOWS_DOCKER_TAG=1809

FROM openjdk:8-jdk-windowsservercore-$WINDOWS_DOCKER_TAG
LABEL MAINTAINER="Alex Earl <slide.o.mix@gmail.com>"

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG user=jenkins

ARG JENKINS_AGENT_HOME=C:/Users/${user}

ARG OPENSSH_VERSION=v8.0.0.0p1-Beta

ENV JENKINS_AGENT_USER ${user}

ENV JENKINS_AGENT_HOME ${JENKINS_AGENT_HOME}

COPY CreateProfile.psm1 C:/

#create jenkins user
RUN Import-Module -Force C:/CreateProfile.psm1 ; `
    New-UserWithProfile -UserName $env:user -Description 'Jenkins Agent User' ; `
    Remove-Item -Force C:/CreateProfile.psm1 ; `
    Set-LocalUser -Name $env:user -PasswordNeverExpires $true ; `
    New-Item -Type Directory -Path "C:\ProgramData\Jenkins" | Out-Null

# setup SSH server
RUN [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 ; `
    Invoke-WebRequest -Uri "https://github.com/PowerShell/Win32-OpenSSH/releases/download/${env:OPENSSH_VERSION}/OpenSSH-Win64.zip -OutFile C:/openssh.zip -UseBasicParsing ; `
    Expand-Archive c:/openssh.zip 'C:/Program Files' ; `
    Remove-Item C:/openssh.zip ; `
    $env:PATH = '{0};{1}' -f $env:PATH,'C:\Program Files\OpenSSH-Win64' ; `
    & 'C:/Program Files/OpenSSH-Win64/Install-SSHd.ps1' ; `
    New-Item -Type Directory -Path 'C:\ProgramData\ssh' | Out-Null ; `
    Copy-Item 'C:\Program Files\OpenSSH-Win64\sshd_config_default' 'C:\ProgramData\ssh\sshd_config' ; `
    $content = Get-Content -Path "C:\ProgramData\ssh\sshd_config" ; `
    $content | ForEach-Object { $_ -replace '#PermitRootLogin.*','PermitRootLogin no' `
                        -replace '#PasswordAuthentication.*','PasswordAuthentication no' `
                        -replace '#PermitEmptyPasswords.*','PermitEmptyPasswords no' `
                        -replace '#PubkeyAuthentication.*','PubkeyAuthentication yes' `
                        -replace '#SyslogFacility.*','SyslogFacility LOCAL0' `
                        -replace '#LogLevel.*','LogLevel DEBUG3' `
                        -replace 'Match Group administrators','' `
                        -replace '(\s*)AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys','' `
                } | `
    Set-Content -Path "C:\ProgramData\ssh\sshd_config" ; `
    Add-Content -Path "C:\ProgramData\ssh\sshd_config" -Value 'ChallengeResponseAuthentication no' ; `
    Add-Content -Path "C:\ProgramData\ssh\sshd_config" -Value 'HostKeyAgent \\.\pipe\openssh-ssh-agent' ; `
    New-Item -Path HKLM:\SOFTWARE -Name OpenSSH -Force | Out-Null ; `
    New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType string -Force | Out-Null

VOLUME "${JENKINS_AGENT_HOME}" "C:\Users\${user}\AppData\Local\Temp"
WORKDIR "${JENKINS_AGENT_HOME}"

COPY setup-sshd.ps1 C:/ProgramData/Jenkins/setup-sshd.ps1

EXPOSE 22

ENTRYPOINT ["powershell.exe", "-NoExit", "-Command", "& C:/ProgramData/Jenkins/setup-sshd.ps1"]
