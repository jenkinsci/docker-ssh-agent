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
ARG ALPINE_TAG=3.18.4
FROM alpine:"${ALPINE_TAG}" AS jre-build
ARG JAVA_VERSION=21.0.1+12

RUN apk add --no-cache curl jq \
  && ARCH=$(uname -m | sed -e 's/x86_64/x64/' -e 's/armv7l/arm/') \
  && JAVA_VERSION_ENCODED=$(printf '%s' "$JAVA_VERSION" | jq -jRr '@uri') \
  && BUILD_NUMBER=$(printf '%s' "$JAVA_VERSION" | cut -d'+' -f2) \
  && JAVA_MAJOR_VERSION=$(printf '%s' "$JAVA_VERSION" | cut -d'.' -f1) \
  && JAVA_VERSION_KEBAB=$(printf '%s' "$JAVA_VERSION" | sed 's/+/-/g;s/\./-/g') \
  && curl -sL https://github.com/adoptium/temurin"${JAVA_MAJOR_VERSION}"-binaries/releases/download/jdk-"${JAVA_VERSION_ENCODED}"-ea-beta/OpenJDK"${JAVA_MAJOR_VERSION}"U-jdk_"${ARCH}"_alpine-linux_hotspot_ea_"${JAVA_VERSION_KEBAB}".tar.gz | tar xz -C /opt/

ENV PATH=/opt/jdk-${JAVA_VERSION}/bin:$PATH

RUN if [ "$TARGETPLATFORM" != 'linux/arm/v7' ]; then \
    case "$(jlink --version 2>&1)" in \
      # jlink version 11 has less features than JDK17+
      "11."*) strip_java_debug_flags="--strip-debug" ;; \
      *) strip_java_debug_flags="--strip-java-debug-attributes" ;; \
    esac; \
    jlink \
      --add-modules ALL-MODULE-PATH \
      "$strip_java_debug_flags" \
      --no-man-pages \
      --no-header-files \
      --compress=2 \
      --output /javaruntime; \
  else \
    cp -r /opt/java/openjdk /javaruntime; \
  fi

FROM alpine:"${ALPINE_TAG}" AS build

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
    musl-locales \
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

# Install JDK

ENV JAVA_HOME=/opt/java/openjdk
COPY --from=jre-build /javaruntime "$JAVA_HOME"
ENV PATH="${JAVA_HOME}/bin:${PATH}"

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
