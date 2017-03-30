#!/bin/bash

set -ex

# The MIT License
#
#  Copyright (c) 2015, CloudBees, Inc.
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
#  docker run jenkinsci/ssh-slave <public key>
# or
#  docker run -e "JENKINS_SLAVE_SSH_PUBKEY=<public key>" jenkinsci/ssh-slave

write_key() {
	mkdir -p "${JENKINS_AGENT_HOME}/.ssh"
	echo "$1" > "${JENKINS_AGENT_HOME}/.ssh/authorized_keys"
	chown -Rf jenkins:jenkins "${JENKINS_AGENT_HOME}/.ssh"
	chmod 0700 -R "${JENKINS_AGENT_HOME}/.ssh"
}

if [[ $JENKINS_SLAVE_SSH_PUBKEY == ssh-* ]]; then
  write_key "${JENKINS_SLAVE_SSH_PUBKEY}"
fi
if [[ $# -gt 0 ]]; then
  if [[ $1 == ssh-* ]]; then
    write_key "$1"
    shift 1
  else
    exec "$@"
  fi
fi


# ensure variables passed to docker container are also exposed to ssh sessions
env | grep _ >> /etc/environment

ssh-keygen -A
exec /usr/sbin/sshd -D -e "${@}"
