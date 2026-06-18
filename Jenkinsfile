pipeline {
    agent any

    tools {
        maven 'M3'
    }

    stages {

        stage('Checkout') {
            steps {
                git 'https://github.com/Abhi-viraj/Calculator_App_Maven_jenkins_CICD.git'
            }
        }

        stage('Compile') {
            steps {
                sh 'mvn clean compile'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }

        stage('Verify') {
            steps {
                sh 'mvn verify'
            }
        }

        stage('Package') {
            steps {
                sh 'mvn package'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('Sonar') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('Upload To Artifactory') {
            steps {
                sh '''
                curl -u admin:adminadmin \
                -T target/Calculator_web_app.war \
                http://localhost:8081/artifactory/libs-release-local/Calculator_web_app.war
                '''
            }
        }

        stage('Deploy To Tomcat') {
            steps {
                sh '''
                cp target/Calculator_web_app.war \
                /var/lib/tomcat10/webapps/
                '''
            }
        }
    }
}
