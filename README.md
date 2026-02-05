# Docker image for Jenkins agents connected over SSH

[![Join the chat at https://gitter.im/jenkinsci/docker](https://badges.gitter.im/jenkinsci/docker.svg)](https://gitter.im/jenkinsci/docker?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![GitHub stars](https://img.shields.io/github/stars/jenkinsci/docker-ssh-agent?label=GitHub%20stars)](https://github.com/jenkinsci/docker-ssh-agent)
[![Docker Pulls](https://img.shields.io/docker/pulls/jenkins/ssh-agent.svg)](https://hub.docker.com/r/jenkins/ssh-agent/)
[![GitHub release](https://img.shields.io/github/release/jenkinsci/docker-ssh-agent.svg?label=changelog)](https://github.com/jenkinsci/docker-ssh-agent/releases)

A [Jenkins](https://jenkins.io) agent image which allows using SSH to establish the connection.
It can be used together with the [SSH Build Agents plugin](https://plugins.jenkins.io/ssh-slaves) or other similar plugins.

See [Jenkins Distributed builds](https://wiki.jenkins-ci.org/display/JENKINS/Distributed+builds) for more info.

## Running

### Running with the SSH Build Agents plugin

To run a Docker container

```bash
docker run -d --rm --name=agent --publish 2200:22 -e "JENKINS_AGENT_SSH_PUBKEY=<public_key>" jenkins/ssh-agent
```

 - `-d`: To start a container in detached mode, use the `-d` option. Containers started in detached mode exit when the root process used to run the container exits, unless you also specify the --rm option.
 - `--rm`: If you use -d with --rm, the container is removed when it exits or when the daemon exits, whichever happens first.
 - `--name`: Assigns a name to the container. If you do not specify a name, Docker generates a random name.
 - `--publish 2200:22`: Publishes the host port 2200 to the agent container port 22 (SSH) to allow connection from the host with `ssh jenkins@localhost -p 2200`

Please note none of these options are mandatory, they are just examples.

You will then be able to connect this agent using the [SSH Build Agents plugin](https://plugins.jenkins.io/ssh-slaves) as "jenkins" with the matching private key.

When using the Linux image, you have to set the value of the `Remote root directory` to `/home/jenkins/agent` in the agent configuration UI.

![Remote root directory with a Linux agent](docs/ssh-plugin-remote-root-directory-linux.png "Remote root directory with a Linux agent")

When using the Windows image, you have to set the value of the `Remote root directory` to `C:/Users/jenkins/Work` in the agent configuration UI.

![Remote root directory with a Windows agent](docs/ssh-plugin-remote-root-directory-windows.png "Remote root directory with a Windows agent")

If you intend to use another directory than `/home/jenkins/agent` under Linux or `C:/Users/jenkins/Work` under Windows, don't forget to add it as a data volume.

```bash
docker run -v docker-volume-for-jenkins-ssh-agent:/home/jenkins/agent:rw jenkins/ssh-agent "<public key>"
```

### How to use this image with Docker Plugin

To use this image with [Docker Plugin](https://plugins.jenkins.io/docker-plugin), you need to pass the public SSH key using environment variable `JENKINS_AGENT_SSH_PUBKEY` and not as a startup argument.

In _Environment_ field of the Docker Template (advanced section), just add:

    JENKINS_AGENT_SSH_PUBKEY=<YOUR PUBLIC SSH KEY HERE>

Don't put quotes around the public key.

Please note that you have to set the value of the `Remote File System Root` to `/home/jenkins/agent` in the Docker Agent Template configuration UI.

![Remote File System Root](docs/docker-plugin-remote-filesystem-root.png "Remote File System Root directory")

If you intend to use another directory than `/home/jenkins/agent`, don't forget to add it as a data volume.

![Docker Volumes mounts](docs/docker-plugin-volumes.png "Docker Volumes mounts")

You should be all set.

## Extending the image
Should you need to extend the image, you could use something along those lines:

```Dockerfile
FROM jenkins/ssh-agent:debian-jdk17 as ssh-agent
# [...]
COPY --chown=jenkins mykey "${JENKINS_AGENT_HOME}"/.ssh/mykey
# [...]
```

## Configurations

The image has several supported configurations, which can be accessed via the following tags:

`${IMAGE_VERSION}` can be found on the [releases](https://github.com/jenkinsci/docker-ssh-agent/releases) page.

List of tags can be consulted at https://github.com/jenkinsci/docker-ssh-agent/tree/master/tests/golden

## Host keys

Host keys are generated with `ssh-keygen -A` in `setup-httpd`. Host keys reside inside the container. When the container is recreated, different host keys are also generated. Jenkins master may need to re-trust new host keys.

We can preserve host keys in mounted volume.

Steps:
1. Copy host keys from the mounted volume to /etc/ssh/
2. Run ssh-keygen -A to generate host keys
3. Copy host keys from /etc/ssh/ to the mounted volume
4. Run setup-sshd

Entry point example:

```
#!/bin/bash

# /mnt/agent is the mounted volume
mkdir -p /mnt/agent/host_keys/

cp -u /mnt/agent/host_keys/ssh_host*_key* /etc/ssh/

ssh-keygen -A

cp -u /etc/ssh/ssh_host*_key* /mnt/agent/host_keys/

setup-ssd "$@"
```

## Building instructions

### Pre-requisites

Should you want to build this image on your machine (before submitting a pull request for example), please have a look at the pre-requisites:

* A GNU/Linux machine with [Docker](https://docs.docker.com/engine/install/), a macOS machine with [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/), or a Windows machine with [Docker for Windows](https://docs.docker.com/docker-for-windows/) installed
* Docker BuildX plugin [installed](https://github.com/docker/buildx#installing) on older versions of Docker (from `19.03`). Docker Buildx is included in recent versions of Docker Desktop for Windows, macOS, and Linux. Docker Linux packages also include Docker Buildx when installed using the DEB or RPM packages.
* [GNU Make](https://www.gnu.org/software/make/) [installed](https://command-not-found.com/make)
* jq [installed](https://command-not-found.com/jq)
* yq [installed](https://github.com/mikefarah/yq) (for Windows)
* [GNU Bash](https://www.gnu.org/software/bash/) [installed](https://command-not-found.com/bash)
* git [installed](https://command-not-found.com/git)
* curl [installed](https://command-not-found.com/curl)

### Building

#### Target images

If you want to see the target images that will be built, you can issue the following command:

```bash
make list
alpine_jdk11
alpine_jdk17
debian_jdk11
debian_jdk17
```

#### Building a specific image

If you want to build a specific image, you can issue the following command:

```bash
make build-<OS>_<JDK_VERSION>
```

That would give for JDK 17 on Alpine Linux:

```bash
make build-alpine_jdk17
```

#### Building images supported by your current architecture

Then, you can build the images supported by your current architecture by running:

```bash
make build
```

#### Testing all images

If you want to test these images, you can run:

```bash
make test
```
#### Testing a specific image

If you want to test a specific image, you can run:

```bash
make test-<OS>_<JDK_VERSION>
```

That would give for JDK 17 on Alpine Linux:

```bash
make test-alpine_jdk17
```

#### Building all images

You can build all images (even those unsupported by your current architecture) by running:

```bash
make every-build
```

#### Other `make` targets

`show` gives us a detailed view of the images that will be built, with the tags, platforms, and Dockerfiles.

```bash
make show
{
  "group": {
    "default": {
      "targets": [
        "alpine_jdk17",
        "alpine_jdk11",
        "debian_jdk11",
        "debian_jdk17",
      ]
    }
  },
  "target": {
    "alpine_jdk11": {
      "context": ".",
      "dockerfile": "alpine/Dockerfile",
      "tags": [
        "docker.io/jenkins/ssh-agent:alpine-jdk11",
        "docker.io/jenkins/ssh-agent:latest-alpine-jdk11"
      ],
      "platforms": [
        "linux/amd64"
      ],
      "output": [
        "type=docker"
      ]
    },
    [...]
```

`bats` is a dependency target. It will update the [`bats` submodule](https://github.com/bats-core/bats-core) and run the tests.

```bash
make bats
make: 'bats' is up to date.
```

`publish` allows the publication of all images targeted by 'linux' to a registry.

`docker-init` is dedicated to Jenkins infrastructure for initializing docker and isn't required in other contexts.

### Building and testing on Windows

#### Building all images

Run `.\build.ps1` to launch the build of the images corresponding to the "windows" target of docker-bake.hcl.

Internally, the first time you'll run this script and if there is no build-windows.yaml file in your repository, it will use a combination of `docker buildx bake` and `yq` to generate a  build-windows.yaml docker compose file containing all Windows image definitions from docker-bake.hcl. Then it will run `docker compose` on this file to build these images.

You can modify this docker compose file as you want, then rerun `.\build.ps1`.
It won't regenerate the docker compose file from docker-bake.hcl unless you add the `-OverwriteDockerComposeFile` build.ps1 parameter:  `.\build.ps1 -OverwriteDockerComposeFile`.

Note: you can generate this docker compose file from docker-bake.hcl yourself with the following command (require `docker buildx` and `yq`):

```console
# - Use docker buildx bake to output image definitions from the "windows" bake target
# - Convert with yq to the format expected by docker compose
# - Store the result in the docker compose file

$ docker buildx bake --progress=plain --file=docker-bake.hcl windows --print `
    | yq --prettyPrint '.target[] | del(.output) | {(. | key): {\"image\": .tags[0], \"build\": .}}' | yq '{\"services\": .}' `
    | Out-File -FilePath build-windows.yaml
```

Note that you don't need build.ps1 to build (or to publish) your images from this docker compose file, you can use `docker compose --file=build-windows.yaml build`.

#### Testing all images

Run `.\build.ps1 test` if you also want to run the tests harness suit.

Run `.\build.ps1 test -TestsDebug 'debug'` to also get commands & stderr of tests, displayed on top of them.
You can set it to `'verbose'` to also get stdout of every test command.

Note that instead of passing `-TestsDebug` parameter to build.ps1, you can set the  $env:TESTS_DEBUG environment variable to the desired value.

Also note that contrary to the Linux part, you have to build the images before testing them.

#### Dry run

Add the `-DryRun` parameter to print out any build, publish or tests commands instead of executing them: `.\build.ps1 test -DryRun`

#### Building and testing a specific image

You can build (and test) only one image type by setting `-ImageType` to a combination of Windows flavors ("nanoserver" & "windowsservercore") and Windows versions ("ltsc2019", "ltsc2022").

Ex: `.\build.ps1 -ImageType 'nanoserver-ltsc2019'`

## Changelog

See [GitHub Releases](https://github.com/jenkinsci/docker-ssh-agent/releases/latest).
Note that the changelogs and release tags were introduced in Dec 2019, and there are no entries for previous releases.
Please consult with the commit history if needed.
