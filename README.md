# Jenkins SSH slave Docker image

[`jenkinsci/ssh-slave`](https://hub.docker.com/r/jenkinsci/ssh-slave/)

A [Jenkins](https://jenkins-ci.org) slave using SSH to establish connection.

See [GitHub docker-ssh-slave](https://github.com/jenkinsci/docker-ssh-slave) and
[Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

## Running

To run a Docker container

    docker run jenkinsci/ssh-slave "<public key>"

You'll then be able to connect this slave using ssh-slaves-plugin as "jenkins" with the matching private key.

