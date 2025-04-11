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

variable "jdks_to_build" {
  default = [17, 21]
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
  default = "3.21.3"
}

variable "ALPINE_SHORT_TAG" {
  default = regex_replace(ALPINE_FULL_TAG, "\\.\\d+$", "")
}

variable "JAVA17_VERSION" {
  default = "17.0.14_7"
}

variable "JAVA21_VERSION" {
  default = "21.0.6_7"
}

variable "DEBIAN_RELEASE" {
  default = "bookworm-20250407"
}

# Set this value to a specific Windows version to override Windows versions to build returned by windowsversions function
variable "WINDOWS_VERSION_OVERRIDE" {
  default = ""
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
  result = (equal(17, jdk)
    ? "${JAVA17_VERSION}"
  : "${JAVA21_VERSION}")
}

## Specific functions
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

# Return array of Windows version(s) to build
# There is no mcr.microsoft.com/windows/servercore:1809 image
# Can be overriden by setting WINDOWS_VERSION_OVERRIDE to a specific Windows version
# Ex: WINDOWS_VERSION_OVERRIDE=1809 docker buildx bake windows
function "windowsversions" {
  params = [flavor]
  result = (notequal(WINDOWS_VERSION_OVERRIDE, "")
    ? [WINDOWS_VERSION_OVERRIDE]
    : (equal(flavor, "windowsservercore")
      ? ["ltsc2019", "ltsc2022"]
  : ["1809", "ltsc2019", "ltsc2022"]))
}

# Return the Windows version to use as base image for the Windows version passed as parameter
# There is no mcr.microsoft.com/powershell ltsc2019 base image, using a "1809" instead
function "toolsversion" {
  params = [version]
  result = (equal("ltsc2019", version)
    ? "1809"
  : version)
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

target "nanoserver" {
  matrix = {
    jdk             = jdks_to_build
    windows_version = windowsversions("nanoserver")
  }
  name       = "nanoserver-${windows_version}_jdk${jdk}"
  dockerfile = "windows/nanoserver/Dockerfile"
  context    = "."
  args = {
    JAVA_HOME             = "C:/openjdk-${jdk}"
    JAVA_VERSION          = "${replace(javaversion(jdk), "_", "+")}"
    TOOLS_WINDOWS_VERSION = "${toolsversion(windows_version)}"
    WINDOWS_VERSION_TAG   = windows_version
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-nanoserver-${windows_version}-jdk${jdk}" : "",
    # If there is a tag and if the jdk is the default one, add versioned and short tags
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-nanoserver-${windows_version}" : "") : "",
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:nanoserver-${windows_version}" : "") : "",
    "${REGISTRY}/${JENKINS_REPO}:nanoserver-${windows_version}-jdk${jdk}",
  ]
  platforms = ["windows/amd64"]
}

target "windowsservercore" {
  matrix = {
    jdk             = jdks_to_build
    windows_version = windowsversions("windowsservercore")
  }
  name       = "windowsservercore-${windows_version}_jdk${jdk}"
  dockerfile = "windows/windowsservercore/Dockerfile"
  context    = "."
  args = {
    JAVA_HOME             = "C:/openjdk-${jdk}"
    JAVA_VERSION          = "${replace(javaversion(jdk), "_", "+")}"
    TOOLS_WINDOWS_VERSION = "${toolsversion(windows_version)}"
    WINDOWS_VERSION_TAG   = windows_version
  }
  tags = [
    # If there is a tag, add versioned tag suffixed by the jdk
    equal(ON_TAG, "true") ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-windowsservercore-${windows_version}-jdk${jdk}" : "",
    # If there is a tag and if the jdk is the default one, add versioned and short tags
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:${VERSION}-windowsservercore-${windows_version}" : "") : "",
    equal(ON_TAG, "true") ? (is_default_jdk(jdk) ? "${REGISTRY}/${JENKINS_REPO}:windowsservercore-${windows_version}" : "") : "",
    "${REGISTRY}/${JENKINS_REPO}:windowsservercore-${windows_version}-jdk${jdk}",
  ]
  platforms = ["windows/amd64"]
}
