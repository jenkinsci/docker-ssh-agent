/* NOTE: this Pipeline mainly aims at catching mistakes (wrongly formed Dockerfile, etc.)
 * This Pipeline is *not* used for actual image publishing.
 * This is currently handled through Automated Builds using standard Docker Hub feature
*/
pipeline {
    agent none

    options {
        buildDiscarder(logRotator(daysToKeepStr: '10'))
        timestamps()
    }

    triggers {
        pollSCM('H/24 * * * *') // once a day in case some hooks are missed
    }

    stages {
        stage('Build Docker Image') {
            parallel {
                stage('Windows') {
                    agent {
                        label "windock"
                    }
                    options {
                        timeout(time: 60, unit: 'MINUTES')
                    }
                    environment {
                        DOCKERHUB_ORGANISATION = "${infra.isTrusted() ? 'jenkins' : 'jenkins4eval'}"
                    }
                    steps {
                        powershell '& ./make.ps1 test'
                        script {
                            def branchName = "${env.BRANCH_NAME}"
                            if (branchName ==~ 'master') {
                                // we can't use dockerhub builds for windows
                                // so we publish here
                                infra.withDockerCredentials {
                                    powershell '& ./make.ps1 publish'
                                }
                            }

                            def tagName = "${env.TAG_NAME}"
                            if(tagName =~ /\d(\.\d)+(-\d+)?/) {
                                // we need to build and publish the tagged version
                                infra.withDockerCredentials {
                                    powershell "& ./make.ps1 -PushVersions -VersionTag $tagName publish"
                                }
                            }
                        }
                    }
                }
                stage('Linux') {
                    agent {
                        label "docker&&linux"
                    }
                    options {
                        timeout(time: 30, unit: 'MINUTES')
                    }
                    steps {
                        script {
                            if(!infra.isTrusted()) {
                                deleteDir()
                                checkout scm
                                sh '''
                                make build
                                make test
                                '''
                            }
                        }
                    }
                    post {
                        always {
                            junit('target/*.xml')
                        }
                    }
                }
            }
        }
    }
}

// vim: ft=groovy
