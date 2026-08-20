final String cronExpr = env.BRANCH_IS_PRIMARY ? '@daily' : ''

properties([
    buildDiscarder(logRotator(numToKeepStr: '10')),
    disableConcurrentBuilds(abortPrevious: true),
    pipelineTriggers([cron(cronExpr)]),
])

def agentSelector(String imageType, retryCounter) {
    def platform
    switch (imageType) {
        // nanoserver-ltsc2019 and windowservercore-ltsc2019
        case ~/.*2019/:
            platform = 'windows-2019'
            break

        // nanoserver-ltsc2022 and windowservercore-ltsc2022
        case ~/.*2022/:
            platform = 'windows-2022'
            break

        // All other Windows images
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

// Specify parallel stages
def parallelStages = [failFast: false]
[
    'alpine_jdk21',
    'alpine_jdk25',
    'debian_jdk21',
    'debian_jdk25',
    'nanoserver-ltsc2019',
    'nanoserver-ltsc2022',
    'windowsservercore-ltsc2019',
    'windowsservercore-ltsc2022'
].each { imageType ->
    parallelStages[imageType] = {
        withEnv([
            "IMAGE_TYPE=${imageType}",
            "REGISTRY_ORG=${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}",
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
                        if (infra.isTrusted()) {
                            // trusted.ci.jenkins.io builds (e.g. publication to DockerHub)
                            stage('Deploy to DockerHub') {
                                withEnv([
                                    "ON_TAG=true",
                                    "VERSION=${env.TAG_NAME}",
                                ]) {
                                    // This function is defined in the jenkins-infra/pipeline-library
                                    infra.withDockerCredentials {
                                        if (isUnix()) {
                                            sh 'make publish'
                                        } else {
                                            // JDK21 only
                                            powershell '''
                                            (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                            & ./build.ps1 build
                                            & ./build.ps1 publish
                                            '''
                                            // JDK25 only
                                            powershell '''
                                            (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                            & ./build.ps1 build
                                            & ./build.ps1 publish
                                            '''
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
                                    // JDK21 only
                                    powershell '''
                                    (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                    & ./build.ps1 build
                                    '''
                                    // JDK25 only
                                    powershell '''
                                    (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                    & ./build.ps1 build
                                    '''
                                    archiveArtifacts artifacts: 'build-windows*.yaml', allowEmptyArchive: true
                                }
                            }
                            stage('Test') {
                                if (isUnix()) {
                                    sh 'make test'
                                } else {
                                    powershell '''
                                    (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[21]' | Set-Content docker-bake.hcl
                                    & ./build.ps1 test
                                    '''
                                    // JDK25 only
                                    powershell '''
                                    (Get-Content docker-bake.hcl -Raw) -replace '(variable\\s+"jdks_to_build"\\s*{\\s*default\\s*=\\s*)\\[[^\\]]*\\]', '$1[25]' | Set-Content docker-bake.hcl
                                    & ./build.ps1 test
                                    '''
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
