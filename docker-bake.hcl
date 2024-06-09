group "linux" {
  targets = [
    "alpine",
    "debian",
    "debian_jdk21-preview",
  ]
}

group "linux-arm64" {
  targets = [
    "debian",
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
    "debian"
  ]
}

variable "jdks_to_build" {
  default = [11, 17, 21]
}

variable "default_jdk" {
  default = 17
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
  default = "3.20.0"
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
  default = "21.0.3_9"
}

variable "JAVA21_PREVIEW_VERSION" {
  default = "21.0.1+12"
}

variable "DEBIAN_RELEASE" {
  default = "bookworm-20240513"
}

## Common functions
# Return "true" if the jdk passed as parameter is the same as the default jdk, "false" otherwise
function "is_default_jdk" {
  params = [jdk]
  result = equal(default_jdk, jdk) ? "true" : "false"
}

# Return the complete Java version corresponding to the jdk passed as parameter
function "javaversion" {
  params = [jdk]
  result = (equal(11, jdk)
    ? "${JAVA11_VERSION}"
    : (equal(17, jdk)
      ? "${JAVA17_VERSION}"
  : "${JAVA21_VERSION}"))
}

# Specific functions
# Return an array of Alpine platforms to use depending on the jdk passed as parameter
function "alpine_platforms" {
  params = [jdk]
  result = (equal(21, jdk)
    ? ["linux/amd64", "linux/arm64"]
  : ["linux/amd64"])
}

# Return an array of Debian platforms to use depending on the jdk passed as parameter
function "debian_platforms" {
  params = [jdk]
  result = (equal(17, jdk)
    ? ["linux/amd64", "linux/arm64", "linux/ppc64le"]
  : ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/s390x"])
}

target "alpine" {
  matrix = {
    jdk = jdks_to_build
  }
  name       = "alpine_${jdk}"
  dockerfile = "alpine/Dockerfile"
  context    = "."
  args = {
    ALPINE_TAG   = ALPINE_FULL_TAG
    JAVA_VERSION = "${javaversion(jdk)}"
  }
  tags = [
    # If there is a tag, add versioned tags suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine-jdk${jdk}" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine${ALPINE_SHORT_TAG}-jdk${jdk}" : "",
    # If the jdk is the default one, add Alpine short tags
    is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:alpine" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}" : "",
    is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}" : "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk${jdk}",
  ]
  platforms = alpine_platforms(jdk)
}

target "debian" {
  matrix = {
    jdk = jdks_to_build
  }
  name       = "debian_${jdk}"
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    DEBIAN_RELEASE = DEBIAN_RELEASE
    JAVA_VERSION   = "${javaversion(jdk)}"
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk${jdk}" : "",
    # If there is a tag and if the jdk is the default one, add versioned short tag
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}" : "") : "",
    # If the jdk is the default one, add latest short tag
    is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:latest" : "",
    "${REGISTRY}/${JENKINS_REPO}:bookworm-jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:debian-jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:latest-bookworm-jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:latest-debian-jdk${jdk}",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk${jdk}",
  ]
  platforms = debian_platforms(jdk)
}

target "debian_jdk21-preview" {
  dockerfile = "debian/preview/Dockerfile"
  context    = "."
  args = {
    JAVA_VERSION   = JAVA21_PREVIEW_VERSION
    DEBIAN_RELEASE = DEBIAN_RELEASE
  }
  tags = [
    # If there is a tag, add the versioned tag suffixed by the jdk
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
