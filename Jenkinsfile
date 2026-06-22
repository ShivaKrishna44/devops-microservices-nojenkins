pipeline {
    agent { label 'ec2' }

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