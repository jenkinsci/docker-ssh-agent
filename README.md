# Docker image for Jenkins agents connected over SSH

[![Docker Stars](https://img.shields.io/docker/stars/jenkins/ssh-agent.svg)](https://hub.docker.com/r/jenkins/ssh-agent/)
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

To use this image with [Docker Plugin](https://plugins.jenkins.io/docker), you need to
pass the public SSH key using environment variable `JENKINS_AGENT_SSH_PUBKEY` and not as a startup argument.

In _Environment_ field of the Docker Template (advanced section), just add:

    JENKINS_AGENT_SSH_PUBKEY=<YOUR PUBLIC SSH KEY HERE>

Don't put quotes around the public key. You should be all set.

## Configurations

The image has several supported configurations, which can be accessed via the following tags:

* `latest`: Latest version with the newest remoting (based on `openjdk:8-jdk`)
* `jdk11`: Latest version with the newest remoting and Java 11 (based on `openjdk:11-jdk`)
* `alpine`: Small image based on Alpine Linux (based on `openjdk:8-jdk-alpine`)
* `jdk8-windowsservercore-1809`: Latest version with the newest remoting (based on `adoptopenjdk:8-jdk-hotspot-windowsservercore-1809`)
* `jdk11-windowsservercore-1809`: Latest version with the newest remoting and Java 11 (based on `adoptopenjdk:11-jdk-hotspot-windowsservercore-1809`)
* `jdk8-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server
* `jdk11-nanoserver-1809`: Latest version with the newest remoting with Windows Nano Server and Java 11

## Changelog

See [GitHub Releases](https://github.com/jenkinsci/docker-ssh-agent/releases/latest).
Note that the changelogs and release tags were introduced in Dec 2019, and there is no entries for previous patches.
Please consult with the commit history if needed.
