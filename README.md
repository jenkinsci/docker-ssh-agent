# Jenkins SSH Build Agent Docker image

[![Docker Stars](https://img.shields.io/docker/stars/jenkins/ssh-slave.svg)](https://hub.docker.com/r/jenkins/ssh-slave/)
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/ssh-slave.svg)](https://hub.docker.com/r/jenkins/ssh-slave/)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-ssh-slave.svg?label=changelog)

A [Jenkins](https://jenkins.io) agent using SSH to establish connection.

See [Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

## Running

To run a Docker container

```bash
docker run jenkins/ssh-slave "<public key>"
```

You'll then be able to connect this agent using the [SSH Build Agents plugin](https://plugins.jenkins.io/ssh-slaves) as "jenkins" with the matching private key.

### How to use this image with Docker Plugin

To use this image with [Docker Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Docker+Plugin), you need to
pass the public SSH key using environment variable `JENKINS_AGENT_SSH_PUBKEY` and not as a startup argument.

In _Environment_ field of the Docker Template (advanced section), just add:

    JENKINS_AGENT_SSH_PUBKEY=<YOUR PUBLIC SSH KEY HERE>

Don't put quotes around the public key. You should be all set.

## Changelog

See [GitHub Releases](https://github.com/jenkinsci/docker-ssh-slave/releases/latest).
Note that the changelogs and release tags were introduced in Dec 2019, and there is no entries for previous patches.
Please consult with the commit history if needed.
