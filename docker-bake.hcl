group "linux" {
  targets = [
    "alpine_jdk8",
    "debian_jdk8",
    "debian_jdk11",
    "debian_jdk17",
  ]
}

group "linux-arm64" {
  targets = [
    "debian_jdk11",
    "debian_jdk17",
    "debian_jdk8",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk11",
  ]
}

group "linux-ppc64le" {
  targets = []
}

variable "REGISTRY" {
  default = "docker.io"
}

variable "JENKINS_REPO" {
  default = "jenkins/ssh-agent"
}

variable "ON_TAG" {
  default = "false"
}

variable "VERSION" {
  default = ""
}

target "alpine_jdk8" {
  dockerfile = "8/alpine/Dockerfile"
  context = "."
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk8",
  ]
  platforms = ["linux/amd64"]
}

target "debian_jdk8" {
  dockerfile = "8/bullseye/Dockerfile"
  context = "."
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk8": "",
    "${REGISTRY}/${JENKINS_REPO}:bullseye-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-bullseye-jdk8",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk8",
  ]
  platforms = ["linux/amd64", "linux/arm64",]
}

target "debian_jdk11" {
  dockerfile = "11/bullseye/Dockerfile"
  context = "."
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}": "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk11": "",
    "${REGISTRY}/${JENKINS_REPO}:bullseye-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest",
    "${REGISTRY}/${JENKINS_REPO}:latest-bullseye-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk11",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x"]
}

target "debian_jdk17" {
  dockerfile = "17/bullseye/Dockerfile"
  context = "."
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk17-preview": "",
    "${REGISTRY}/${JENKINS_REPO}:bullseye-jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-bullseye-jdk17-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk17-preview",
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}
