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
                            infra.withDockerCredentials {
                                def branchName = "${env.BRANCH_NAME}"
                                if (infra.isTrusted()) {
                                    if (branchName ==~ 'master') {
                                        sh '''
                                            docker buildx create --use
                                            docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                            docker buildx bake --push --file docker-bake.hcl linux
                                        '''
                                    } else if (env.TAG_NAME != null)  {
                                        sh """
                                            export ON_TAG=true
                                            export VERSION=$TAG_NAME
                                            docker buildx create --use
                                            docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                            docker buildx bake --push --file docker-bake.hcl linux
                                        """
                                    }
                                } else {
                                    sh 'make build'
                                    try {
                                        sh 'make test'
                                    } finally {
                                        junit('target/*.xml')
                                    }
                                    sh '''
                                        docker buildx create --use
                                        docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
                                        docker buildx bake --file docker-bake.hcl linux
                                    '''
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// vim: ft=groovy
