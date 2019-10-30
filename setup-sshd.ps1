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

# Usage:
#  docker run jenkins/ssh-agent:windows <public key>
# or
#  docker run -e "JENKINS_SLAVE_SSH_PUBKEY=<public key>" jenkins/ssh-agent:windows

function Write-Key($Key) {
  # this writes the key and sets the permissions correctly for pubkey auth
  $sshDir = '{0}\.ssh' -f $env:JENKINS_AGENT_HOME
  $authorizedKeys = Join-Path $sshDir 'authorized_keys'
  New-Item -Type Directory -Path $sshDir | Out-Null
  icacls.exe $sshDir /setowner ${env:JENKINS_AGENT_USER} | Out-Null
  icacls.exe $sshDir /grant "${env:JENKINS_AGENT_USER}:(CI)(OI)(F)" /grant "administrators:(CI)(OI)(F)" | Out-Null
  icacls.exe $sshDir /inheritance:r | Out-Null

  Set-Content -Path $authorizedKeys -Value "$Key" -Encoding UTF8
  icacls.exe $authorizedKeys /setowner ${env:JENKINS_AGENT_USER} | Out-Null
}

# Even though we created a profile, the NTUSER.DAT file is missing
# this needs to be in the directory or Windows will not load
# the profile
if(!(Test-Path (Join-Path $env:JENKINS_AGENT_HOME 'NTUSER.DAT'))) {
  Copy-Item -Path 'C:\Users\Default\NTUSER.DAT' -Destination (Join-Path $env:JENKINS_AGENT_HOME 'NTUSER.DAT')
}

# Give the user Full Access to the home directory
icacls.exe $env:JENKINS_AGENT_HOME /grant "${env:JENKINS_AGENT_USER}:(CI)(OI)(F)" | Out-Null

if($env:JENKINS_SLAVE_SSH_PUBKEY -match "^ssh-.*") {
  Write-Key $env:JENKINS_SLAVE_SSH_PUBKEY
} 

if($args.Length -gt 0) {
  if($args[0] -match "^ssh-.*") {
    Write-Key "$($args[0]) $($args[1]) $($args[2])"
    $null, $null, $null, $args = $args
  } else {
    & "$args"
  }
}



# ensure variables passed to docker container are also exposed to ssh sessions
Get-ChildItem env: | ForEach-Object { setx /m $_.Name $_.Value | Out-Null }

Start-Service sshd
while($true) {
    # if we don't do this endless loop, the container exits
    Start-Sleep -Seconds 60
}
