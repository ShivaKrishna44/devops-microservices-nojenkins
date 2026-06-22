pipeline {
    agent {
        label 'devops-agent'
    }

    stages {
        stage('Initialize') {
            steps {
                echo 'Checking out code and verifying environment...'
                sh 'git --version'
                sh 'docker --version'
                sh 'aws --version'
            }
        }
        
        stage('Build Image') {
            steps {
                echo 'Building your service docker image...'
                // Add your build steps here
            }
        }
    }
}
