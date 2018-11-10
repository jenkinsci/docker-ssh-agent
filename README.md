# Jenkins SSH agent Docker image

[`papazogler/jenkins-ssh-agent`](https://hub.docker.com/r/papazogler/jenkins-ssh-agent/)

A [Jenkins](https://jenkins-ci.org) agent using SSH to establish connection.

See [Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

This image supports executing jobs that use docker (e.g. build images, run containers, etc).

This is possible by mounting `/var/run/docker.sock` of the host to the container created by this image, 
however, since the agent is executing as `jenkins` user, in order to be allowed to execute docker commands, 
it needs to be a member of the `docker` group of the host. To achieve that, pass the `GID` of 
the host's `docker` group using the environment variable `JENKINS_AGENT_DOCKER_GID`.  

## Running

To run a Docker container

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock -e JENKINS_AGENT_DOCKER_GID=<docker GID in host> papazogler/jenkins-ssh-agent "<public key>"
```

You'll then be able to connect this slave using ssh-slaves-plugin as "jenkins" with the matching private key.

### How to use this image with Docker Plugin

To use this image with [Docker Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Docker+Plugin), you need to
pass the public SSH key using environment variable `JENKINS_AGENT_SSH_PUBKEY` and not as a startup argument.

In _Environment_ field of the Docker Template (advanced section), just add:

    JENKINS_AGENT_SSH_PUBKEY=<YOUR PUBLIC SSH KEY HERE>
    JENKINS_AGENT_DOCKER_GID=<docker GID in host>

Don't put quotes around the public key or the gid. You should be all set.
