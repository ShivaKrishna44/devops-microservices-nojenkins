pipeline {
    agent { label 'devops-agent' }

    stages {
        stage('Test') {
            steps {
                sh 'hostname'
                sh 'whoami'
                sh 'pwd'
            }
        }
    }
}