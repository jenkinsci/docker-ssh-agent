# Jenkins SSH slave Docker image

[![Build Status](https://jenkins.ci.cloudbees.com/buildStatus/icon?job=docker/ssh-slave)](https://jenkins.ci.cloudbees.com/job/docker/job/ssh-slave/)

[`jenkinsci/ssh-slave`](https://hub.docker.com/r/jenkinsci/ssh-slave/)

A [Jenkins](https://jenkins-ci.org) slave using SSH to establish connection.

See [Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

## Running

To run a Docker container

    docker run jenkinsci/ssh-slave "<public key>"

You'll then be able to connect this slave using ssh-slaves-plugin as "jenkins" with the matching private key.

