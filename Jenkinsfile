pipeline {
    agent any

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region for Amazon ECR')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '123456789012', description: '12-digit AWS Account ID for ECR registry')
        string(name: 'ECR_REPO_NAME', defaultValue: 'cloud-microservice', description: 'Amazon ECR repository name')
        string(name: 'SWARM_MANAGER_HOST', defaultValue: '10.0.1.50', description: 'Docker Swarm Manager EC2 IP or Hostname')
        string(name: 'SWARM_SSH_USER', defaultValue: 'ubuntu', description: 'SSH user for Docker Swarm Manager')
        string(name: 'SSH_CREDENTIAL_ID', defaultValue: 'swarm-manager-ssh-key', description: 'Jenkins SSH Credential ID for Swarm Manager')
        string(name: 'STACK_NAME', defaultValue: 'cloud-microservice-stack', description: 'Docker Swarm stack name')
        string(name: 'APP_PORT', defaultValue: '80', description: 'Host ingress port for application')
        booleanParam(name: 'PUSH_TO_ECR', defaultValue: false, description: 'Authenticate and push image to Amazon ECR')
        booleanParam(name: 'DEPLOY_TO_SWARM', defaultValue: false, description: 'Deploy stack to remote Docker Swarm Manager via SSH')
    }

    environment {
        AWS_REGISTRY = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
        IMAGE_URI    = "${AWS_REGISTRY}/${params.ECR_REPO_NAME}"
        IMAGE_TAG    = "${BUILD_NUMBER}-${GIT_COMMIT ? GIT_COMMIT.take(8) : 'latest'}"
    }

    options {
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15'))
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    stages {
        stage('Checkout SCM') {
            steps {
                echo "===> [Stage 1/5] Checking out source repository..."
                checkout scm
                script {
                    echo "Git Commit SHA: ${env.GIT_COMMIT ?: 'workspace'}"
                    echo "Jenkins Build Number: ${env.BUILD_NUMBER}"
                    echo "Assigned Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Code Lint & Unit Verification') {
            steps {
                echo "===> [Stage 2/5] Running local unit tests and manifest checks..."
                script {
                    if (isUnix()) {
                        sh '''
                            echo "Checking application files and configuration manifests..."
                            test -f package.json
                            test -f server.js
                            test -f Dockerfile
                            test -f docker-stack.yml
                            echo "All core pipeline manifests verified."
                        '''
                    } else {
                        powershell '''
                            Write-Host "Checking application files and configuration manifests..."
                            if (-not (Test-Path package.json, server.js, Dockerfile, docker-stack.yml)) {
                                throw "Manifest validation failed."
                            }
                            Write-Host "All core pipeline manifests verified successfully."
                        '''
                    }
                }
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                echo "===> [Stage 3/5] Building lean non-root Docker image..."
                script {
                    if (isUnix()) {
                        sh """
                            echo "Building Docker image: ${IMAGE_URI}:${IMAGE_TAG}"
                            docker build \
                                -t ${params.ECR_REPO_NAME}:${IMAGE_TAG} \
                                -t ${params.ECR_REPO_NAME}:latest \
                                -t ${IMAGE_URI}:${IMAGE_TAG} \
                                -t ${IMAGE_URI}:latest .
                            
                            echo "Listing generated Docker images:"
                            docker images | grep "${params.ECR_REPO_NAME}" || true
                        """
                    } else {
                        powershell """
                            \$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;\$env:PATH"
                            Write-Host "Building Docker image: ${IMAGE_URI}:${IMAGE_TAG}"
                            docker build `
                                -t ${params.ECR_REPO_NAME}:${IMAGE_TAG} `
                                -t ${params.ECR_REPO_NAME}:latest `
                                -t ${IMAGE_URI}:${IMAGE_TAG} `
                                -t ${IMAGE_URI}:latest .
                            
                            Write-Host "Listing generated Docker images:"
                            docker images | Select-String "${params.ECR_REPO_NAME}"
                        """
                    }
                }
            }
        }

        stage('Authenticate & Push to Amazon ECR') {
            when {
                expression { return params.PUSH_TO_ECR }
            }
            steps {
                echo "===> [Stage 4/5] Authenticating to Amazon ECR via AWS CLI..."
                script {
                    if (isUnix()) {
                        sh """
                            echo "Logging in to Amazon ECR registry: ${AWS_REGISTRY} in region ${params.AWS_REGION}..."
                            aws ecr get-login-password --region ${params.AWS_REGION} | docker login --username AWS --password-stdin ${AWS_REGISTRY}
                            
                            echo "Pushing immutable image tag: ${IMAGE_URI}:${IMAGE_TAG}..."
                            docker push ${IMAGE_URI}:${IMAGE_TAG}

                            echo "Pushing latest image tag: ${IMAGE_URI}:latest..."
                            docker push ${IMAGE_URI}:latest
                        """
                    } else {
                        powershell """
                            \$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;C:\\Program Files\\Amazon\\AWSCLIV2;\$env:PATH"
                            Write-Host "Logging in to Amazon ECR registry: ${AWS_REGISTRY} in region ${params.AWS_REGION}..."
                            (aws ecr get-login-password --region ${params.AWS_REGION}) | docker login --username AWS --password-stdin ${AWS_REGISTRY}
                            
                            Write-Host "Pushing immutable image tag: ${IMAGE_URI}:${IMAGE_TAG}..."
                            docker push ${IMAGE_URI}:${IMAGE_TAG}

                            Write-Host "Pushing latest image tag: ${IMAGE_URI}:latest..."
                            docker push ${IMAGE_URI}:latest
                        """
                    }
                }
            }
        }

        stage('Deploy to Docker Swarm via SSH') {
            when {
                expression { return params.DEPLOY_TO_SWARM }
            }
            steps {
                echo "===> [Stage 5/5] Deploying stack to AWS Docker Swarm Manager (${params.SWARM_MANAGER_HOST})..."
                sshagent([params.SSH_CREDENTIAL_ID]) {
                    script {
                        if (isUnix()) {
                            sh """
                                # Ensure remote target directory exists
                                ssh -o StrictHostKeyChecking=no ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST} "mkdir -p ~/deployments/${params.STACK_NAME}"

                                # Securely transfer stack configuration to the Swarm Manager
                                scp -o StrictHostKeyChecking=no docker-stack.yml ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST}:~/deployments/${params.STACK_NAME}/docker-stack.yml

                                # Execute rolling update deployment on Swarm Manager with registry authentication
                                ssh -o StrictHostKeyChecking=no ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST} bash -s << 'EOF'
                                    set -e
                                    echo "Authenticating Swarm Manager to Amazon ECR..."
                                    aws ecr get-login-password --region ${params.AWS_REGION} | docker login --username AWS --password-stdin ${AWS_REGISTRY}

                                    cd ~/deployments/${params.STACK_NAME}

                                    echo "Executing Docker Stack Deploy with registry authentication..."
                                    export IMAGE_REPO="${IMAGE_URI}"
                                    export IMAGE_TAG="${IMAGE_TAG}"
                                    export APP_PORT="${params.APP_PORT}"

                                    docker stack deploy \
                                        --with-registry-auth \
                                        --compose-file docker-stack.yml \
                                        ${params.STACK_NAME}

                                    echo "Verifying cluster convergence and service replica health..."
                                    sleep 5
                                    docker stack services ${params.STACK_NAME}
                                    docker service ps ${params.STACK_NAME}_web-api --no-trunc
EOF
                            """
                        } else {
                            powershell """
                                Write-Host "Connecting to Swarm Manager ${params.SWARM_MANAGER_HOST} via SSH..."
                                ssh -o StrictHostKeyChecking=no ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST} "mkdir -p ~/deployments/${params.STACK_NAME}"
                                scp -o StrictHostKeyChecking=no docker-stack.yml ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST}:~/deployments/${params.STACK_NAME}/docker-stack.yml
                                ssh -o StrictHostKeyChecking=no ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST} "cd ~/deployments/${params.STACK_NAME} && IMAGE_REPO=${IMAGE_URI} IMAGE_TAG=${IMAGE_TAG} APP_PORT=${params.APP_PORT} docker stack deploy --with-registry-auth -c docker-stack.yml ${params.STACK_NAME} && sleep 5 && docker stack services ${params.STACK_NAME}"
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "===> Pipeline execution completed. Performing image cleanup on runner..."
            script {
                if (isUnix()) {
                    sh 'docker image prune -f --filter "until=24h" || true'
                } else {
                    powershell '$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;$env:PATH"; docker image prune -f --filter "until=24h"'
                }
            }
        }
        success {
            echo "SUCCESS: Pipeline successfully completed build ${BUILD_NUMBER} (${IMAGE_TAG})!"
        }
        failure {
            echo "FAILURE: Pipeline execution failed. Review console output for details."
        }
    }
}
