# MIT License
#
# Copyright (c) 2019-2022 Fabio Kruger and other contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

FROM eclipse-temurin:11.0.19_7-jdk-alpine

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG JENKINS_AGENT_HOME=/home/${user}

ENV JENKINS_AGENT_HOME=${JENKINS_AGENT_HOME}

ARG AGENT_WORKDIR="${JENKINS_AGENT_HOME}"/agent
# Persist agent workdir path through an environment variable for people extending the image
ENV AGENT_WORKDIR=${AGENT_WORKDIR}

RUN addgroup -g "${gid}" "${group}" \
    # Set the home directory (h), set user and group id (u, G), set the shell, don't ask for password (D)
    && adduser -h "${JENKINS_AGENT_HOME}" -u "${uid}" -G "${group}" -s /bin/bash -D "${user}" \
    # Unblock user
    && passwd -u "${user}" \
    # Prepare subdirectories
    && mkdir -p "${JENKINS_AGENT_HOME}/.ssh/" "${JENKINS_AGENT_HOME}/.jenkins/" "${AGENT_WORKDIR}" \
    && chown -R "${uid}":"${gid}" "${JENKINS_AGENT_HOME}" "${AGENT_WORKDIR}"


RUN apk add --no-cache \
    bash \
    git-lfs \
    less \
    netcat-openbsd \
    openssh \
    patch

# setup SSH server
RUN sed -i /etc/ssh/sshd_config \
        -e 's/#PermitRootLogin.*/PermitRootLogin no/' \
        -e 's/#PasswordAuthentication.*/PasswordAuthentication no/' \
        -e 's/#SyslogFacility.*/SyslogFacility AUTH/' \
        -e 's/#LogLevel.*/LogLevel INFO/' \
        -e 's/#PermitUserEnvironment.*/PermitUserEnvironment yes/' \
    && mkdir /var/run/sshd

# VOLUME directive must happen after setting up permissions and content
VOLUME "${AGENT_WORKDIR}" "${JENKINS_AGENT_HOME}"/.jenkins "/tmp" "/run" "/var/run"
WORKDIR "${JENKINS_AGENT_HOME}"

# Alpine's ssh doesn't use $PATH defined in /etc/environment, so we define `$PATH` in `~/.ssh/environment`
# The file path has been created earlier in the file by `mkdir -p` and we also have configured sshd so that it will
# allow environment variables to be sourced (see `sed` command related to `PermitUserEnvironment`)
RUN echo "PATH=${PATH}" >> ${JENKINS_AGENT_HOME}/.ssh/environment
COPY setup-sshd /usr/local/bin/setup-sshd

EXPOSE 22

ENTRYPOINT ["setup-sshd"]

LABEL \
    org.opencontainers.image.vendor="Jenkins project" \
    org.opencontainers.image.title="Official Jenkins SSH Agent Docker image" \
    org.opencontainers.image.description="A Jenkins agent image which allows using SSH to establish the connection" \
    org.opencontainers.image.url="https://www.jenkins.io/" \
    org.opencontainers.image.source="https://github.com/jenkinsci/docker-ssh-agent" \
    org.opencontainers.image.licenses="MIT"
