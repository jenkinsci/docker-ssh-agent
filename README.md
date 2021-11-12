# Docker image for Jenkins agents connected over SSH

[![Join the chat at https://gitter.im/jenkinsci/docker](https://badges.gitter.im/jenkinsci/docker.svg)](https://gitter.im/jenkinsci/docker?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![GitHub stars](https://img.shields.io/github/stars/jenkinsci/docker-ssh-agent?label=GitHub%20stars)](https://github.com/jenkinsci/docker-ssh-agent)
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/ssh-agent.svg)](https://hub.docker.com/r/jenkins/ssh-agent/)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-ssh-agent.svg?label=changelog)](https://github.com/jenkinsci/docker-ssh-agent/releases)

A [Jenkins](https://jenkins.io) agent image which allows using SSH to establish the connection.
It can be used together with the [SSH Build Agents plugin](https://plugins.jenkins.io/ssh-slaves) or other similar plugins.

See [Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

## Running

To run a Docker container

```bash
docker run jenkins/ssh-agent "<public key>"
```

You'll then be able to connect this agent using the [SSH Build Agents plugin](https://plugins.jenkins.io/ssh-slaves) as "jenkins" with the matching private key.

### How to use this image with Docker Plugin

To use this image with [Docker Plugin](https://plugins.jenkins.io/docker-plugin), you need to
pass the public SSH key using environment variable `JENKINS_AGENT_SSH_PUBKEY` and not as a startup argument.

In _Environment_ field of the Docker Template (advanced section), just add:

    JENKINS_AGENT_SSH_PUBKEY=<YOUR PUBLIC SSH KEY HERE>

Don't put quotes around the public key. You should be all set.

## Configurations

The image has several supported configurations, which can be accessed via the following tags:

`${IMAGE_VERSION}` can be found on the [releases](https://github.com/jenkinsci/docker-ssh-agent/releases) page.

* `latest`, `latest-jdk11`, `jdk11`, `latest-bullseye-jdk11`, `bullseye-jdk11`, `${IMAGE_VERSION}`, `${IMAGE_VERSION}-jdk11`, ([Dockerfile](11/bullseye/Dockerfile))
* `latest-jdk8`, `jdk8`, `latest-bullseye-jdk8`, `bullseye-jdk8`, `${IMAGE_VERSION}-jdk8`, ([Dockerfile](8/bullseye/Dockerfile))
* `latest-jdk17-preview`, `jdk17-preview`, `latest-bullseye-jdk17-preview`, `bullseye-jdk17-preview`, `${IMAGE_VERSION}-jdk17-preview`, ([Dockerfile](17/bullseye/Dockerfile))
* `latest-alpine-jdk8`, `alpine-jdk8`, `${IMAGE_VERSION}-jdk8`, ([Dockerfile](8/alpine/Dockerfile))
* `nanoserver-1809`, `nanoserver-ltsc2019`, `nanoserver-1809-jdk11`, `nanoserver-ltsc2019-jdk11`, `${IMAGE_VERSION}-nanoserver-1809`, `${IMAGE_VERSION}-nanoserver-ltsc2019`, `${IMAGE_VERSION}-nanoserver-1809-jdk11`, `${IMAGE_VERSION}-nanoserver-ltsc2019-jdk11` ([Dockerfile](11/windows/nanoserver-ltsc2019/Dockerfile))
* `nanoserver-1809-jdk8`, `nanoserver-ltsc2019-jdk8`, `${IMAGE_VERSION}-nanoserver-1809-jdk8`, `${IMAGE_VERSION}-nanoserver-ltsc2019-jdk8` ([Dockerfile](8/windows/nanoserver-ltsc2019/Dockerfile))
* `windowsservercore-1809`, `windowsservercore-ltsc2019`, `windowsservercore-1809-jdk11`, `windowsservercore-ltsc2019-jdk11`, `${IMAGE_VERSION}-windowsservercore-1809`, `${IMAGE_VERSION}-windowsservercore-ltsc2019`, `${IMAGE_VERSION}-windowsservercore-1809-jdk11`, `${IMAGE_VERSION}-windowsservercore-ltsc2019-jdk11` ([Dockerfile](11/windows/windowsservercore-ltsc2019/Dockerfile))
* `windowsservercore-1809-jdk8`, `windowsservercore-ltsc2019-jdk8`, `${IMAGE_VERSION}-windowsservercore-1809-jdk8`, `${IMAGE_VERSION}-windowsservercore-ltsc2019-jdk8` ([Dockerfile](8/windows/windowsservercore-ltsc2019/Dockerfile))

## Changelog

See [GitHub Releases](https://github.com/jenkinsci/docker-ssh-agent/releases/latest).
Note that the changelogs and release tags were introduced in Dec 2019, and there are no entries for previous releases.
Please consult with the commit history if needed.
