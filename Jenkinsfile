final String cronExpr = env.BRANCH_IS_PRIMARY ? '@daily' : ''

properties([
    buildDiscarder(logRotator(numToKeepStr: '10')),
    disableConcurrentBuilds(abortPrevious: true),
    pipelineTriggers([cron(cronExpr)]),
])

def agentSelector(String imageType, retryCounter) {
    def platform
    switch (imageType) {
        // Windows
        case ~/(nanoserver|windowsservercore).*/:
            platform = 'windows-2025'
            break

        // Linux
        default:
            // Need Docker in a VM.
            platform = 'docker && linux && amd64'
            break
    }

    // Defined in https://github.com/jenkins-infra/pipeline-library/blob/master/vars/infra.groovy
    return infra.getBuildAgentLabel([
        useContainerAgent: false,
        platform: platform,
        spotRetryCounter: retryCounter
    ])
}

def allImagesTypeAndTheirVariants = [
    'alpine_jdk21':               ['linux', 'alpine', 'jdk21'],
    'alpine_jdk25':               ['linux', 'alpine', 'jdk25'],
    'debian_jdk21':               ['linux', 'debian', 'jdk21'],
    'debian_jdk25':               ['linux', 'debian', 'jdk25'],
    'nanoserver-ltsc2022':        ['windows', 'nanoserver', 'jdk21', 'jdk25'],
    'windowsservercore-ltsc2022': ['windows', 'windowsservercore', 'jdk21', 'jdk25'],
    'windowsservercore-ltsc2025': ['windows', 'windowsservercore', 'jdk21', 'jdk25'],
]

// Specify java release(s) to build for Windows images
def allWindowsJavaReleases = [21, 25]

def imageTypesToBuild = allImagesTypeAndTheirVariants.keySet().toList()
def windowsJavaReleases = allWindowsJavaReleases.collect()
if (env.CHANGE_ID) {
    def requestedVariants = []
    pullRequest.labels.each { label -> 
        if (label.startsWith('variant-')) {
            requestedVariants << label.replace('variant-', '')
        }
    }
    if (requestedVariants) {
        echo "Building only selected variant(s): ${requestedVariants}"

        imageTypesToBuild = allImagesTypeAndTheirVariants.findAll { image, variants ->
            variants.any { it in requestedVariants }
        }.keySet().toList()

        // Special case for JDK variants and Windows Java releases
        if (requestedVariants.any { it ==~ /jdk\d+/ }) {
            windowsJavaReleases = []
            requestedVariants.findAll { it.contains('jdk') }.each {
                windowsJavaReleases += it.replace('jdk', '')
            }
            echo "Building only Windows Java release(s): ${windowsJavaReleases}"
        }
        echo "Images to build: ${imageTypesToBuild}"
    }
}

// Specify parallel stages
def parallelStages = [failFast: false]
imageTypesToBuild.each { imageType ->
    parallelStages[imageType] = {
        withEnv([
            "IMAGE_TYPE=${imageType}",
            "REGISTRY_ORG=${infra.isTrustedCiController() ? 'jenkins' : 'jenkins4eval'}",
        ]) {
            int retryCounter = 0
            retry(count: 2, conditions: [agent(), nonresumable()]) {
                // Use local variable to manage concurrency and increment BEFORE spinning up any agent
                final String resolvedAgentLabel = agentSelector(imageType, retryCounter)
                retryCounter++
                node(resolvedAgentLabel) {
                    timeout(time: 60, unit: 'MINUTES') {
                        checkout scm
                        if (isUnix()) {
                            stage("Prepare Docker on ${resolvedAgentLabel}") {
                                sh 'make docker-init'
                            }
                        }
                        // This function is defined in the jenkins-infra/pipeline-library
                        if (infra.isTrustedCiController()) {
                            // trusted.ci.jenkins.io builds (e.g. publication to DockerHub)
                            stage('Deploy to DockerHub') {
                                withEnv([
                                    "ON_TAG=true",
                                    "VERSION=${env.TAG_NAME}",
                                ]) {
                                    // This function is defined in the jenkins-infra/pipeline-library
                                    infra.withContainerRegistry {
                                        if (isUnix()) {
                                            sh 'make publish'
                                        } else {
                                            windowsJavaReleases.each { javaRelease ->
                                                withEnv(["JAVA_RELEASE_OVERRIDE=${javaRelease}"]) {
                                                    powershell './build.ps1 build'
                                                    powershell './build.ps1 publish'
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // ci.jenkins.io builds (e.g. no publication)
                            stage('Build') {
                                if (isUnix()) {
                                    sh 'make build'
                                } else {
                                    windowsJavaReleases.each { javaRelease ->
                                        withEnv(["JAVA_RELEASE_OVERRIDE=${javaRelease}"]) {
                                            powershell './build.ps1 build'
                                        }
                                        archiveArtifacts artifacts: 'build-windows*.yaml', allowEmptyArchive: true
                                    }
                                }
                            }
                            stage('Test') {
                                if (isUnix()) {
                                    sh 'make test'
                                } else {
                                    windowsJavaReleases.each { javaRelease ->
                                        withEnv(["JAVA_RELEASE_OVERRIDE=${javaRelease}"]) {
                                            powershell './build.ps1 test'
                                        }
                                    }
                                }
                                junit 'target/**/junit-results*.xml'
                            }
                            // If the tests are passing for Linux AMD64, then we can build all the CPU architectures
                            if (isUnix()) {
                                stage('Multi-Arch Build') {
                                    sh 'make "multiarchbuild-${IMAGE_TYPE}"'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// Execute parallel stages
parallel parallelStages
// // vim: ft=groovy
