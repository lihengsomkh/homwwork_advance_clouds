pipeline {
    agent any

    environment {
        // AWS and ECR Configurations
        AWS_REGION          = credentials('aws-region') ?: 'us-east-1'
        AWS_ACCOUNT_ID      = credentials('aws-account-id') ?: '123456789012'
        ECR_REPO_NAME       = 'cloud-microservice'
        ECR_REGISTRY        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_URI           = "${ECR_REGISTRY}/${ECR_REPO_NAME}"
        
        // Swarm Cluster Configurations
        SWARM_MANAGER_HOST  = credentials('swarm-manager-host') ?: '10.0.1.50'
        SWARM_SSH_USER      = 'ubuntu'
        SSH_CREDENTIAL_ID   = 'swarm-manager-ssh-key'
        STACK_NAME          = 'cloud-microservice-stack'
        APP_PORT            = '80'

        // Dynamic Tagging: ${BUILD_NUMBER}-${GIT_COMMIT}
        IMAGE_TAG           = "${BUILD_NUMBER}-${GIT_COMMIT.take(8)}"
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
                    echo "Git Commit SHA: ${GIT_COMMIT}"
                    echo "Jenkins Build Number: ${BUILD_NUMBER}"
                    echo "Assigned Image Tag: ${IMAGE_TAG}"
                }
            }
        }

        stage('Code Lint & Unit Verification') {
            steps {
                echo "===> [Stage 2/5] Running local unit tests and syntax checks..."
                sh '''
                    echo "Verifying application files and package integrity..."
                    test -f package.json
                    test -f server.js
                    test -f Dockerfile
                    test -f docker-stack.yml
                    echo "Application assets verified successfully."
                '''
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                echo "===> [Stage 3/5] Building lean non-root Docker image..."
                sh """
                    echo "Building Docker image: ${IMAGE_URI}:${IMAGE_TAG}"
                    docker build \
                        --pull \
                        --build-arg BUILD_NUMBER=${BUILD_NUMBER} \
                        --build-arg COMMIT_SHA=${GIT_COMMIT} \
                        -t ${IMAGE_URI}:${IMAGE_TAG} \
                        -t ${IMAGE_URI}:latest .
                    
                    echo "Listing generated image metadata:"
                    docker images | grep "${ECR_REPO_NAME}" || true
                """
            }
        }

        stage('Authenticate & Push to Amazon ECR') {
            steps {
                echo "===> [Stage 4/5] Authenticating to Amazon ECR via AWS CLI..."
                sh """
                    echo "Logging in to Amazon ECR registry: ${ECR_REGISTRY} in region ${AWS_REGION}..."
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    
                    echo "Pushing immutable image tag: ${IMAGE_URI}:${IMAGE_TAG}..."
                    docker push ${IMAGE_URI}:${IMAGE_TAG}

                    echo "Pushing latest image tag: ${IMAGE_URI}:latest..."
                    docker push ${IMAGE_URI}:latest
                """
            }
        }

        stage('Deploy to Docker Swarm via SSH') {
            steps {
                echo "===> [Stage 5/5] Deploying stack to AWS Docker Swarm Manager (${SWARM_MANAGER_HOST})..."
                sshagent([SSH_CREDENTIAL_ID]) {
                    sh """
                        # Ensure remote target directory exists
                        ssh -o StrictHostKeyChecking=no ${SWARM_SSH_USER}@${SWARM_MANAGER_HOST} "mkdir -p ~/deployments/${STACK_NAME}"

                        # Securely transfer stack configuration to the Swarm Manager
                        scp -o StrictHostKeyChecking=no docker-stack.yml ${SWARM_SSH_USER}@${SWARM_MANAGER_HOST}:~/deployments/${STACK_NAME}/docker-stack.yml

                        # Execute rolling update deployment on Swarm Manager with registry authentication
                        ssh -o StrictHostKeyChecking=no ${SWARM_SSH_USER}@${SWARM_MANAGER_HOST} bash -s << 'EOF'
                            set -e
                            echo "Authenticating Swarm Manager to Amazon ECR..."
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                            cd ~/deployments/${STACK_NAME}

                            echo "Executing Docker Stack Deploy with registry authentication..."
                            export IMAGE_REPO="${IMAGE_URI}"
                            export IMAGE_TAG="${IMAGE_TAG}"
                            export APP_PORT="${APP_PORT}"

                            docker stack deploy \
                                --with-registry-auth \
                                --compose-file docker-stack.yml \
                                ${STACK_NAME}

                            echo "Verifying cluster convergence and service replica health..."
                            sleep 5
                            docker stack services ${STACK_NAME}
                            docker service ps ${STACK_NAME}_web-api --no-trunc
EOF
                    """
                }
            }
        }
    }

    post {
        always {
            echo "===> Pipeline execution completed. Performing image cleanup on Jenkins runner..."
            sh """
                docker rmi ${IMAGE_URI}:${IMAGE_TAG} || true
                docker image prune -f --filter "until=24h" || true
            """
        }
        success {
            echo "SUCCESS: Pipeline successfully deployed build ${BUILD_NUMBER} (${IMAGE_TAG}) to AWS Docker Swarm cluster!"
        }
        failure {
            echo "FAILURE: Pipeline execution failed during deployment. Review console output for troubleshooting."
        }
    }
}
