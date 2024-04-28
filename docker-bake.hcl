group "linux" {
  targets = [
    "alpine_jdk11",
    "alpine_jdk17",
    "alpine_jdk21",
    "debian_jdk11",
    "debian_jdk17",
    "debian_jdk21",
    "debian_jdk21-preview",
  ]
}

group "linux-arm64" {
  targets = [
    "debian_jdk11",
    "debian_jdk17",
    "debian_jdk21",
    "alpine_jdk21",
  ]
}

group "linux-arm32" {
  targets = [
    "debian_jdk21-preview",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk11",
    "debian_jdk21"
  ]
}

group "linux-ppc64le" {
  targets = [
    "debian_jdk11",
    "debian_jdk17",
    "debian_jdk21"
  ]
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

variable "ALPINE_FULL_TAG" {
  default = "3.19.1"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "JAVA11_VERSION" {
  default = "11.0.23_9"
}

variable "JAVA17_VERSION" {
  default = "17.0.11_9"
}

variable "JAVA21_VERSION" {
  default = "21.0.2_13"
}

variable "JAVA21_PREVIEW_VERSION" {
  default = "21.0.1+12"
}

variable "DEBIAN_RELEASE" {
  default = "bookworm-20240423"
}

target "alpine_jdk11" {
  dockerfile = "alpine/Dockerfile"
  context    = "."
  args = {
    ALPINE_TAG   = ALPINE_FULL_TAG
    JAVA_VERSION = JAVA11_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine-jdk11" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine${ALPINE_SHORT_TAG}-jdk11" : "",
    "${REGISTRY}/${JENKINS_REPO}:alpine",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}",
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk17" {
  dockerfile = "alpine/Dockerfile"
  context    = "."
  args = {
    ALPINE_TAG   = ALPINE_FULL_TAG
    JAVA_VERSION = JAVA17_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine-jdk17" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine${ALPINE_SHORT_TAG}-jdk17" : "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk17",
  ]
  platforms = ["linux/amd64"]
}

target "alpine_jdk21" {
  dockerfile = "alpine/Dockerfile"
  context    = "."
  args = {
    ALPINE_TAG   = ALPINE_FULL_TAG
    JAVA_VERSION = JAVA21_VERSION
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine-jdk21" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine${ALPINE_SHORT_TAG}-jdk21" : "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk21",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk21",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk21",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk21",
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "debian_jdk11" {
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    JAVA_VERSION   = JAVA11_VERSION
    DEBIAN_RELEASE = DEBIAN_RELEASE
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk11" : "",
    "${REGISTRY}/${JENKINS_REPO}:bookworm-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:debian-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest",
    "${REGISTRY}/${JENKINS_REPO}:latest-bookworm-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-debian-jdk11",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk11",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/s390x", "linux/ppc64le"]
}

target "debian_jdk17" {
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    JAVA_VERSION   = JAVA17_VERSION
    DEBIAN_RELEASE = DEBIAN_RELEASE
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk17" : "",
    "${REGISTRY}/${JENKINS_REPO}:bookworm-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:debian-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-bookworm-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-debian-jdk17",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk17",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/ppc64le"]
}

target "debian_jdk21" {
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    JAVA_VERSION   = JAVA21_VERSION
    DEBIAN_RELEASE = DEBIAN_RELEASE
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk21" : "",
    "${REGISTRY}/${JENKINS_REPO}:bookworm-jdk21",
    "${REGISTRY}/${JENKINS_REPO}:debian-jdk21",
    "${REGISTRY}/${JENKINS_REPO}:jdk21",
    "${REGISTRY}/${JENKINS_REPO}:latest-bookworm-jdk21",
    "${REGISTRY}/${JENKINS_REPO}:latest-debian-jdk21",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk21",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/s390x"]
}

target "debian_jdk21-preview" {
  dockerfile = "debian/preview/Dockerfile"
  context    = "."
  args = {
    JAVA_VERSION   = JAVA21_PREVIEW_VERSION
    DEBIAN_RELEASE = DEBIAN_RELEASE
  }
  tags = [
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk21-preview" : "",
    "${REGISTRY}/${JENKINS_REPO}:bookworm-jdk21-preview",
    "${REGISTRY}/${JENKINS_REPO}:debian-jdk21-preview",
    "${REGISTRY}/${JENKINS_REPO}:jdk21-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-bookworm-jdk21-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-debian-jdk21-preview",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk21-preview",
  ]
  platforms = ["linux/arm/v7"]
}
