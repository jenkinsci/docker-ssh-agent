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
                    steps {
                        checkout scm
                        powershell "& ./make.ps1"
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
                        checkout scm
                        sh 'make build'
                        sh 'make test'
                        sh 'docker system prune --force --all'
                    }
                }
            }
        }
    }
}

// vim: ft=groovy
