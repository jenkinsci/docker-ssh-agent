final String cronExpr = env.BRANCH_IS_PRIMARY ? '@daily' : ''

properties([
    buildDiscarder(logRotator(numToKeepStr: '10')),
    disableConcurrentBuilds(abortPrevious: true),
    pipelineTriggers([cron(cronExpr)]),
])

// Specify parallel stages
def parallelStages = [failFast: false]
[
    'windowsservercore-ltsc2022',
].each { imageType ->
    parallelStages[imageType] = {
        withEnv([
          "IMAGE_TYPE=${imageType}", 
          "REGISTRY_ORG=${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}",
        ]) {
            int retryCounter = 0
            retry(count: 2, conditions: [agent(), nonresumable()]) {
                // Use local variable to manage concurrency and increment BEFORE spinning up any agent
                retryCounter++
                node('windows-2022') {
                    timeout(time: 60, unit: 'MINUTES') {
                        checkout scm
                        stage('Prepare Docker') {
                            powershell '''
                            $ErrorActionPreference = "Stop"
                            $ConfirmPreference = "None"
                            $ProgressPreference = "SilentlyContinue"

                            Get-ComputerInfo | Select WindowsVersion, OsName, OsBuildNumber
                            Get-WindowsFeature Containers, Hyper-V
                            docker info
                            Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
                            Get-WindowsFeature Containers, Hyper-V
                            docker info
                            '''
                        }
                        // ci.jenkins.io builds (e.g. no publication)
                        stage('Build') {
                            powershell '& ./build.ps1 build'
                            archiveArtifacts artifacts: 'build-windows.yaml', allowEmptyArchive: true
                        }
                        // stage('Test') {
                        //     powershell '& ./build.ps1 test'
                        //     junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                        // }
                    }
                }
                node('windows-2025') {
                    timeout(time: 60, unit: 'MINUTES') {
                        checkout scm
                        stage('Prepare Docker') {
                            powershell '''
                            $ErrorActionPreference = "Stop"
                            $ConfirmPreference = "None"
                            $ProgressPreference = "SilentlyContinue"

                            Get-ComputerInfo | Select WindowsVersion, OsName, OsBuildNumber
                            Get-WindowsFeature Containers, Hyper-V
                            docker info
                            Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
                            Get-WindowsFeature Containers, Hyper-V
                            docker info
                            '''
                        }
                        // ci.jenkins.io builds (e.g. no publication)
                        stage('Build') {
                            powershell '& ./build.ps1 build'
                            archiveArtifacts artifacts: 'build-windows.yaml', allowEmptyArchive: true
                        }
                        // stage('Test') {
                        //     powershell '& ./build.ps1 test'
                        //     junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
                        // }
                    }
                }
                node('windows-2025') {
                    timeout(time: 60, unit: 'MINUTES') {
                        checkout scm
                        stage('Prepare Docker') {
                            powershell '''
                            $ErrorActionPreference = "Stop"
                            $ConfirmPreference = "None"
                            $ProgressPreference = "SilentlyContinue"

                            Get-ComputerInfo | Select WindowsVersion, OsName, OsBuildNumber
                            Get-WindowsFeature Containers, Hyper-V
                            docker info
                            Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
                            Get-WindowsFeature Containers, Hyper-V
                            docker info
                            '''
                        }
                        // ci.jenkins.io builds (e.g. no publication)
                        stage('Build') {
                            powershell '& ./build.ps1 build'
                            archiveArtifacts artifacts: 'build-windows.yaml', allowEmptyArchive: true
                        }
                        stage('Test') {
                            powershell '& ./build.ps1 test'
                            junit(allowEmptyResults: true, keepLongStdio: true, testResults: 'target/**/junit-results.xml')
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
