## Variables
variable "java_releases_to_build" {
  default = [21, 25]
}

variable "default_java_release" {
  default = 21
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
  default = "3.24.1"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "DEBIAN_RELEASE" {
  default = "trixie-20260824"
}

# Set this value to a specific Windows version to override Windows versions to build returned by windowsversions function
variable "WINDOWS_VERSION_OVERRIDE" {
  default = ""
}

# Set this value to a specific version to override java release to build
variable "JAVA_RELEASE_OVERRIDE" {
  default = ""
}

## Targets
target "alpine" {
  matrix = {
    java_release = java_releases(JAVA_RELEASE_OVERRIDE)
  }
  name       = "alpine_jdk${java_release}"
  dockerfile = "alpine/Dockerfile"
  context    = "."
  args = {
    ALPINE_TAG   = ALPINE_FULL_TAG
    JAVA_RELEASE = java_release
  }
  tags = [
    # If there is a tag, add versioned tags suffixed by the java_release
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine-jdk${java_release}" : "",
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-alpine${ALPINE_SHORT_TAG}-jdk${java_release}" : "",
    # If the java_release is the default one, add Alpine short tags
    is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:alpine" : "",
    is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}" : "",
    is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}" : "",
    "${REGISTRY}/${JENKINS_REPO}:alpine-jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine-jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:alpine${ALPINE_SHORT_TAG}-jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:latest-alpine${ALPINE_SHORT_TAG}-jdk${java_release}",
  ]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "debian" {
  matrix = {
    java_release = java_releases(JAVA_RELEASE_OVERRIDE)
  }
  name       = "debian_jdk${java_release}"
  dockerfile = "debian/Dockerfile"
  context    = "."
  args = {
    DEBIAN_RELEASE = DEBIAN_RELEASE
    JAVA_RELEASE   = java_release
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the java_release
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-jdk${java_release}" : "",
    # If there is a tag and if the java_release is the default one, add versioned short tag
    equal(ON_TAG, "true") ? (is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}" : "") : "",
    # If the java_release is the default one, add latest short tag
    is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:latest" : "",
    "${REGISTRY}/${JENKINS_REPO}:trixie-jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:debian-jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:latest-trixie-jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:latest-debian-jdk${java_release}",
    "${REGISTRY}/${JENKINS_REPO}:latest-jdk${java_release}",
  ]
  platforms = ["linux/amd64", "linux/arm64", "linux/ppc64le", "linux/s390x", "linux/riscv64"]
}

target "nanoserver" {
  matrix = {
    java_release    = java_releases(JAVA_RELEASE_OVERRIDE)
    windows_version = windowsversions("nanoserver")
  }
  name       = "nanoserver-${windows_version}_jdk${java_release}"
  dockerfile = "windows/nanoserver/Dockerfile"
  context    = "."
  args = {
    JAVA_RELEASE        = java_release
    WINDOWS_VERSION_TAG = windows_version
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the java_release
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-nanoserver-${windows_version}-jdk${java_release}" : "",
    # If there is a tag and if the java_release is the default one, add versioned and short tags
    equal(ON_TAG, "true") ? (is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-nanoserver-${windows_version}" : "") : "",
    equal(ON_TAG, "true") ? (is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:nanoserver-${windows_version}" : "") : "",
    "${REGISTRY}/${JENKINS_REPO}:nanoserver-${windows_version}-jdk${java_release}",
  ]
  platforms = ["windows/amd64"]
}

target "windowsservercore" {
  matrix = {
    java_release    = java_releases(JAVA_RELEASE_OVERRIDE)
    windows_version = windowsversions("windowsservercore")
  }
  name       = "windowsservercore-${windows_version}_jdk${java_release}"
  dockerfile = "windows/windowsservercore/Dockerfile"
  context    = "."
  args = {
    JAVA_RELEASE        = java_release
    WINDOWS_VERSION_TAG = windows_version
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the java_release
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-windowsservercore-${windows_version}-jdk${java_release}" : "",
    # If there is a tag and if the java_release is the default one, add versioned and short tags
    equal(ON_TAG, "true") ? (is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-windowsservercore-${windows_version}" : "") : "",
    equal(ON_TAG, "true") ? (is_default_java_release(java_release) ? "${REGISTRY}/${JENKINS_REPO}:windowsservercore-${windows_version}" : "") : "",
    "${REGISTRY}/${JENKINS_REPO}:windowsservercore-${windows_version}-jdk${java_release}",
  ]
  platforms = ["windows/amd64"]
}

## Groups
group "linux" {
  targets = [
    "alpine",
    "debian",
  ]
}

group "windows" {
  targets = [
    "nanoserver",
    "windowsservercore"
  ]
}

group "linux-arm64" {
  targets = [
    "debian",
    "alpine_jdk21",
  ]
}

group "linux-s390x" {
  targets = [
    "debian_jdk21"
  ]
}

group "linux-ppc64le" {
  targets = [
    "debian"
  ]
}

## Common functions
# Return "true" if the java_release passed as parameter is the same as the default java_release, "false" otherwise
function "is_default_java_release" {
  params = [java_release]
  result = equal(default_java_release, java_release)
}

# Return array of java releases to build
# Can be overriden to a specific version
function "java_releases" {
  params = [override]
  result = (notequal(override, "")
    ? [parseint(override, 10)]
  : java_releases_to_build)
}

## Specific functions
# Return array of Windows version(s) to build
# Can be overriden by setting WINDOWS_VERSION_OVERRIDE to a specific Windows version
# Ex: WINDOWS_VERSION_OVERRIDE=ltsc2025 docker buildx bake windows
function "windowsversions" {
  params = [flavor]
  result = (notequal(WINDOWS_VERSION_OVERRIDE, "")
    ? [WINDOWS_VERSION_OVERRIDE]
  : ["ltsc2022"])
}
