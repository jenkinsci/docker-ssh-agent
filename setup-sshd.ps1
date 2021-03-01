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

# Usage:
#  docker run jenkins/ssh-agent <public key>
# or
#  docker run -e "JENKINS_AGENT_SSH_PUBKEY=<public key>" jenkins/ssh-agent
# or
#  docker run -e "JENKINS_AGENT_SSH_PUBKEY=<public key>" -e "JENKINS_AGENT_SSH_KNOWNHOST_0=<known host entry>" -e "JENKINS_AGENT_SSH_KNOWNHOST_n=<known host entry>" jenkins/ssh-agent

[CmdletBinding()]
Param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string] $Cmd
)

function Get-SSHDir {
    return Join-Path "C:/Users/$env:JENKINS_AGENT_USER" '.ssh'
}

function Check-SSHDir {
    $sshDir = Get-SSHDir
    if(-not (Test-Path $sshDir)) {
        New-Item -Type Directory -Path $sshDir | Out-Null
        icacls.exe $sshDir /setowner $env:JENKINS_AGENT_USER | Out-Null
        icacls.exe $sshDir /grant $('{0}:(CI)(OI)(F)' -f $env:JENKINS_AGENT_USER) /grant "administrators:(CI)(OI)(F)" | Out-Null
        icacls.exe $sshDir /inheritance:r | Out-Null
    }
}

function Write-Key($Key) {
    # this writes the key and sets the permissions correctly for pubkey auth
    $authorizedKeys = Join-Path (Get-SSHDir) 'authorized_keys'
    Set-Content -Path $authorizedKeys -Value "$Key" -Encoding UTF8

    icacls.exe $authorizedKeys /setowner $env:JENKINS_AGENT_USER | Out-Null
}

function Write-HostKey($Key) {
    # this writes the key and sets the permissions
    $knownHosts = Join-Path (Get-SSHDir) 'known_hosts'
    Set-Content -Path $knownHosts -Value "$Key" -Encoding UTF8

    icacls.exe $knownHosts /setowner $env:JENKINS_AGENT_USER | Out-Null
}

# Give the user Full Access to the home directory
icacls.exe "C:/Users/$env:JENKINS_AGENT_USER" /grant "${env:JENKINS_AGENT_USER}:(CI)(OI)(F)" | Out-Null

# check the .ssh dir permissions
Check-SSHDir

if($env:JENKINS_AGENT_SSH_PUBKEY -match "^ssh-.*") {
    Write-Key $env:JENKINS_AGENT_SSH_PUBKEY
}

$index = 0
$knownHostKeyVar = Get-ChildItem -Path "env:JENKINS_AGENT_SSH_KNOWNHOST_$index" -ErrorAction 'SilentlyContinue'
while($null -ne $knownHostKeyVar) {
    Write-HostKey $knownHostKeyVar.Value
    $index++
    $knownHostKeyVar = Get-ChildItem env: -Name "JENKINS_AGENT_SSH_KNOWNHOST_$index"
}

# ensure variables passed to docker container are also exposed to ssh sessions
Get-ChildItem env: | ForEach-Object { setx /m $_.Name $_.Value | Out-Null }

if(![System.String]::IsNullOrWhiteSpace($Cmd)) {
    Write-Host "$($MyInvocation.MyCommand.Name) param: '$Cmd'"
    if($Cmd -match "^ssh-.*") {
        Write-Host "Authorizing ssh pubkey found in params."
        Write-Key $Cmd
    } elseif($Cmd -match "^/usr/sbin/sshd") {
        # neutralize default jenkins docker-plugin command
        # we will run sshd at the end anyway
        Write-Host "Ignoring provided (linux) sshd command."
    } else {
        Write-Host "Executing param: $Cmd"
        & $Cmd
        exit
    }
}

Start-Service sshd

# dump network information
ipconfig
netstat -a

# aside from forwarding ssh logs, this keeps the container open
Get-Content -Path "C:\ProgramData\ssh\logs\sshd.log" -Wait
