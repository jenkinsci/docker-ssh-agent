#!/usr/bin/env bash

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
#  docker run jenkins/ssh-agent <public key>
# or
#  docker run -e "JENKINS_AGENT_SSH_PUBKEY=<public key>" jenkins/ssh-agent

write_key() {
  local ID_GROUP

  # As user, group, uid, gid and JENKINS_AGENT_HOME can be overridden at build,
  # we need to find the values for JENKINS_AGENT_HOME
  # ID_GROUP contains the user:group of JENKINS_AGENT_HOME directory
  ID_GROUP=$(stat -c '%U:%G' "${JENKINS_AGENT_HOME}")

  mkdir -p "${JENKINS_AGENT_HOME}/.ssh"
  echo "$1" > "${JENKINS_AGENT_HOME}/.ssh/authorized_keys"
  chown -Rf "${ID_GROUP}" "${JENKINS_AGENT_HOME}/.ssh"
  chmod 0700 -R "${JENKINS_AGENT_HOME}/.ssh"
}

if [[ ${JENKINS_AGENT_SSH_PUBKEY} == ssh-* ]]; then
  write_key "${JENKINS_AGENT_SSH_PUBKEY}"
fi
if [[ ${JENKINS_SLAVE_SSH_PUBKEY} == ssh-* ]]; then
  write_key "${JENKINS_SLAVE_SSH_PUBKEY}"
fi

# ensure variables passed to docker container are also exposed to ssh sessions
env | grep _ >> /etc/environment

if [[ $# -gt 0 ]]; then
  echo "${0##*/} params: $@"

  if [[ $1 == ssh-* ]]; then
    echo "Authorizing ssh pubkey found in params."
    write_key "$1"
    shift 1
  elif [[ "$@" == "/usr/sbin/sshd -D -p 22" ]]; then
    # neutralize default jenkins docker-plugin command
    # we will run sshd at the end anyway
    echo "Ignoring provided sshd command."

    # if unquoted (4 tokens) shift extra 3
    [[ "$2" == "-D" ]] && shift 3

    shift 1
  else
    echo "Executing params: '$@'"
    exec "$@"
  fi
fi

# generate host keys if not present
ssh-keygen -A

# do not detach (-D), log to stderr (-e), passthrough other arguments
exec /usr/sbin/sshd -D -e "${@}"
