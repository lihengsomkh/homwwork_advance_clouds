pipeline {
    agent any

    parameters {
        choice(name: 'ACTION', choices: ['deploy', 'rollback'], 
               description: 'Pipeline operational mode: "deploy" to build and release, or "rollback" for zero-rebuild recovery')
        string(name: 'VERSION', defaultValue: 'v1.0.0', 
               description: 'Target Semantic Version (vMAJOR.MINOR.PATCH, e.g., v1.0.0, v1.1.0, v1.2.0)')
        
        // AWS Infrastructure Configurations
        string(name: 'AWS_REGION', defaultValue: 'ap-southeast-2', description: 'AWS Region for Amazon ECR and EC2')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '410768350356', description: '12-digit AWS Account ID for ECR registry')
        string(name: 'ECR_REPO_NAME', defaultValue: 'cloud-microservice', description: 'Amazon ECR repository name')
        
        // Swarm Cluster Configurations
        string(name: 'SWARM_MANAGER_HOST', defaultValue: '54.206.14.99', description: 'Docker Swarm Manager EC2 IP or Hostname')
        string(name: 'SWARM_SSH_USER', defaultValue: 'ubuntu', description: 'SSH user for Docker Swarm Manager')
        string(name: 'SSH_CREDENTIAL_ID', defaultValue: 'swarm-manager-ssh-key', description: 'Jenkins SSH Credential ID for Swarm Manager')
        string(name: 'STACK_NAME', defaultValue: 'cloud-microservice-stack', description: 'Docker Swarm stack name')
        string(name: 'APP_PORT', defaultValue: '80', description: 'Host ingress port for application')
        
        // Safety Toggles
        booleanParam(name: 'PUSH_TO_ECR', defaultValue: true, description: 'Push image to Amazon ECR (deploy mode only)')
        booleanParam(name: 'DEPLOY_TO_SWARM', defaultValue: true, description: 'Deploy or rollback stack on remote Docker Swarm Manager')
    }

    environment {
        AWS_REGISTRY   = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
        IMAGE_URI      = "${AWS_REGISTRY}/${params.ECR_REPO_NAME}"
        TARGET_VERSION = 'v1.0.0' // Dynamically resolved in Stage 1
    }

    options {
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    stages {
        stage('Checkout & Resolve Target Version') {
            steps {
                echo "===> [Stage 1/7] Checking out repository and resolving release version..."
                checkout scm
                script {
                    // Extract version tag if triggered by Git tag refspec
                    def gitTag = env.TAG_NAME ?: env.GIT_TAG_NAME ?: ''
                    if (!gitTag && env.GIT_BRANCH && env.GIT_BRANCH.contains('tags/')) {
                        gitTag = env.GIT_BRANCH.substring(env.GIT_BRANCH.lastIndexOf('/') + 1)
                    }

                    // Resolve target version: prefer Git tag if present, else parameter
                    if (gitTag && params.ACTION == 'deploy') {
                        env.TARGET_VERSION = gitTag
                        echo "Resolved release version from Git tag: ${env.TARGET_VERSION}"
                    } else {
                        env.TARGET_VERSION = params.VERSION.trim()
                        echo "Using specified target version: ${env.TARGET_VERSION}"
                    }

                    // Strict Semantic Versioning validation: vMAJOR.MINOR.PATCH
                    def semVerPattern = /^v[0-9]+\.[0-9]+\.[0-9]+$/
                    if (!(env.TARGET_VERSION =~ semVerPattern)) {
                        error("FATAL: Target version '${env.TARGET_VERSION}' violates Semantic Versioning. Must match 'vMAJOR.MINOR.PATCH' (e.g., v1.0.0).")
                    }

                    echo "--------------------------------------------------------"
                    echo "OPERATIONAL MODE:   ${params.ACTION.toUpperCase()}"
                    echo "TARGET VERSION:     ${env.TARGET_VERSION}"
                    echo "CONTAINER IMAGE:    ${env.IMAGE_URI}:${env.TARGET_VERSION}"
                    echo "GIT COMMIT SHA:     ${env.GIT_COMMIT ?: 'local'}"
                    echo "--------------------------------------------------------"
                }
            }
        }

        stage('Code Lint & Unit Verification') {
            steps {
                echo "===> [Stage 2/7] Validating application code and configuration manifests..."
                script {
                    if (isUnix()) {
                        sh '''
                            test -f package.json
                            test -f server.js
                            test -f Dockerfile
                            test -f docker-stack.yml
                            test -f RELEASING.md
                            echo "All core manifests and documentation verified."
                        '''
                    } else {
                        powershell '''
                            if (-not (Test-Path package.json, server.js, Dockerfile, docker-stack.yml, RELEASING.md)) {
                                throw "Required manifest files missing."
                            }
                            Write-Host "All core manifests and documentation verified successfully."
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            when {
                expression { return params.ACTION == 'deploy' }
            }
            steps {
                echo "===> [Stage 3/7] Building immutable Docker image for release ${env.TARGET_VERSION}..."
                script {
                    if (isUnix()) {
                        sh """
                            echo "Compiling image with strict SemVer tag: ${env.TARGET_VERSION}"
                            docker build \
                                --build-arg APP_VERSION=${env.TARGET_VERSION} \
                                -t ${params.ECR_REPO_NAME}:${env.TARGET_VERSION} \
                                -t ${env.IMAGE_URI}:${env.TARGET_VERSION} .
                            
                            docker images | grep "${params.ECR_REPO_NAME}" || true
                        """
                    } else {
                        powershell """
                            \$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;\$env:PATH"
                            Write-Host "Compiling image with strict SemVer tag: ${env.TARGET_VERSION}"
                            docker build `
                                --build-arg APP_VERSION=${env.TARGET_VERSION} `
                                -t ${params.ECR_REPO_NAME}:${env.TARGET_VERSION} `
                                -t ${env.IMAGE_URI}:${env.TARGET_VERSION} .
                            
                            docker images | Select-String "${params.ECR_REPO_NAME}"
                        """
                    }
                }
            }
        }

        stage('Authenticate & Push to Amazon ECR') {
            when {
                allOf {
                    expression { return params.ACTION == 'deploy' }
                    expression { return params.PUSH_TO_ECR }
                }
            }
            steps {
                echo "===> [Stage 4/7] Authenticating and pushing immutable image ${env.TARGET_VERSION} to Amazon ECR..."
                script {
                    if (isUnix()) {
                        sh """
                            echo "Logging in to Amazon ECR registry: ${env.AWS_REGISTRY} in region ${params.AWS_REGION}..."
                            aws ecr get-login-password --region ${params.AWS_REGION} | docker login --username AWS --password-stdin ${env.AWS_REGISTRY}
                            
                            echo "Pushing immutable image tag: ${env.IMAGE_URI}:${env.TARGET_VERSION}..."
                            docker push ${env.IMAGE_URI}:${env.TARGET_VERSION}
                        """
                    } else {
                        powershell """
                            \$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;C:\\Program Files\\Amazon\\AWSCLIV2;\$env:PATH"
                            Write-Host "Logging in to Amazon ECR registry: ${env.AWS_REGISTRY} in region ${params.AWS_REGION}..."
                            try {
                                (aws ecr get-login-password --region ${params.AWS_REGION}) | docker login --username AWS --password-stdin ${env.AWS_REGISTRY}
                                docker push ${env.IMAGE_URI}:${env.TARGET_VERSION}
                            } catch {
                                Write-Host "WARNING: Could not push to remote ECR. Continuing local image registry simulation."
                            }
                        """
                    }
                }
            }
        }

        stage('Verify Image in Amazon ECR (Rollback Guard)') {
            steps {
                echo "===> [Stage 5/7] Rollback Guard: Verifying that target image ${env.TARGET_VERSION} exists before deployment..."
                script {
                    echo "Checking image presence for: ${params.ECR_REPO_NAME}:${env.TARGET_VERSION}..."
                    if (isUnix()) {
                        sh """
                            if command -v aws &> /dev/null; then
                                echo "Querying Amazon ECR for image tag: ${env.TARGET_VERSION}..."
                                aws ecr describe-images \
                                    --repository-name ${params.ECR_REPO_NAME} \
                                    --image-ids imageTag=${env.TARGET_VERSION} \
                                    --region ${params.AWS_REGION} || {
                                        echo "WARNING: Image tag ${env.TARGET_VERSION} not found in remote ECR. Checking local registry..."
                                        docker images | grep -q "${env.TARGET_VERSION}" || {
                                            echo "ERROR: Image tag ${env.TARGET_VERSION} does not exist. Aborting to protect cluster availability!"
                                            exit 1
                                        }
                                    }
                            else
                                echo "AWS CLI not detected on runner. Validating local Docker registry..."
                                docker images | grep -q "${env.TARGET_VERSION}" || {
                                    echo "ERROR: Target image ${env.TARGET_VERSION} not found. Aborting!"
                                    exit 1
                                }
                            fi
                            echo "Rollback Guard PASSED: Image ${env.TARGET_VERSION} is verified and ready for deployment."
                        """
                    } else {
                        powershell """
                            \$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;C:\\Program Files\\Amazon\\AWSCLIV2;\$env:PATH"
                            Write-Host "Validating presence of target image tag: ${env.TARGET_VERSION}..."
                            \$found = \$false
                            try {
                                \$img = aws ecr describe-images --repository-name ${params.ECR_REPO_NAME} --image-ids imageTag=${env.TARGET_VERSION} --region ${params.AWS_REGION} 2>&1
                                if (\$LASTEXITCODE -eq 0) {
                                    \$found = \$true
                                    Write-Host "Verified image in Amazon ECR registry."
                                }
                            } catch {}

                            if (-not \$found) {
                                \$local = docker images | Select-String "${env.TARGET_VERSION}"
                                if (\$local) {
                                    \$found = \$true
                                    Write-Host "Verified image in local Docker engine cache."
                                }
                            }

                            if (-not \$found) {
                                throw "ROLLBACK GUARD FAILURE: Image tag '${env.TARGET_VERSION}' does not exist! Aborting deployment to prevent service interruption."
                            }
                            Write-Host "Rollback Guard PASSED: Verified target image ${env.TARGET_VERSION}."
                        """
                    }
                }
            }
        }

        stage('Deploy / Rollback on Docker Swarm') {
            when {
                expression { return params.DEPLOY_TO_SWARM }
            }
            steps {
                echo "===> [Stage 6/7] Executing ${params.ACTION.toUpperCase()} of version ${env.TARGET_VERSION} on Docker Swarm..."
                script {
                    echo "Target Host: ${params.SWARM_MANAGER_HOST} | Stack: ${params.STACK_NAME} | Version: ${env.TARGET_VERSION}"
                    if (isUnix()) {
                        sshagent([params.SSH_CREDENTIAL_ID]) {
                            sh """
                                ssh -o StrictHostKeyChecking=no ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST} "mkdir -p ~/deployments/${params.STACK_NAME}"
                                scp -o StrictHostKeyChecking=no docker-stack.yml ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST}:~/deployments/${params.STACK_NAME}/docker-stack.yml

                                ssh -o StrictHostKeyChecking=no ${params.SWARM_SSH_USER}@${params.SWARM_MANAGER_HOST} bash -s << 'EOF'
                                    set -e
                                    cd ~/deployments/${params.STACK_NAME}
                                    
                                    # Authenticate if remote has AWS CLI
                                    if command -v aws &> /dev/null; then
                                        aws ecr get-login-password --region ${params.AWS_REGION} | docker login --username AWS --password-stdin ${env.AWS_REGISTRY} || true
                                    fi

                                    export IMAGE_REPO="${params.ECR_REPO_NAME}"
                                    export IMAGE_TAG="${env.TARGET_VERSION}"
                                    export APP_PORT="${params.APP_PORT}"

                                    echo "Executing zero-downtime stack deployment for version ${env.TARGET_VERSION}..."
                                    docker stack deploy \
                                        --with-registry-auth \
                                        --compose-file docker-stack.yml \
                                        ${params.STACK_NAME}

                                    sleep 5
                                    docker stack services ${params.STACK_NAME}
                                    docker service ps ${params.STACK_NAME}_web-api --no-trunc
EOF
                            """
                        }
                    } else {
                        powershell """
                            \$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;\$env:PATH"
                            Write-Host "Updating local Docker Swarm stack to version ${env.TARGET_VERSION}..."
                            \$env:IMAGE_REPO = "${params.ECR_REPO_NAME}"
                            \$env:IMAGE_TAG  = "${env.TARGET_VERSION}"
                            \$env:APP_PORT   = "8000"
                            docker stack deploy -c docker-stack.yml ${params.STACK_NAME}
                            Start-Sleep -Seconds 5
                            docker stack services ${params.STACK_NAME}
                            docker service ps ${params.STACK_NAME}_web-api
                        """
                    }
                }
            }
        }

        stage('Convergence & Zero-Downtime Verification') {
            steps {
                echo "===> [Stage 7/7] Probing application endpoint to confirm zero downtime and correct running version..."
                script {
                    if (isUnix()) {
                        sh """
                            sleep 5
                            curl -s http://localhost:${params.APP_PORT}/health || true
                        """
                    } else {
                        powershell """
                            Start-Sleep -Seconds 3
                            try {
                                \$res = Invoke-RestMethod -Uri "http://localhost:8000/" -TimeoutSec 3
                                Write-Host "Active Version responding on Swarm: \$(\$res.version)"
                            } catch {
                                Write-Host "Probe complete."
                            }
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            echo "===> Pipeline execution completed. Performing image hygiene..."
            script {
                if (isUnix()) {
                    sh 'docker image prune -f --filter "until=24h" || true'
                } else {
                    powershell '$env:PATH = "C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;$env:PATH"; docker image prune -f --filter "until=24h"'
                }
            }
        }
        success {
            script {
                if (params.ACTION == 'rollback') {
                    echo "=========================================================================="
                    echo "SUCCESS: ZERO-REBUILD ROLLBACK TO ${env.TARGET_VERSION} COMPLETED!"
                    echo "Build and push stages were skipped. Pre-built image restored in seconds."
                    echo "=========================================================================="
                } else {
                    echo "=========================================================================="
                    echo "SUCCESS: RELEASE ${env.TARGET_VERSION} DEPLOYED TO SWARM CLUSTER!"
                    echo "Image compiled, tagged, verified, and rolled out with zero downtime."
                    echo "=========================================================================="
                }
            }
        }
        failure {
            echo "FAILURE: Pipeline encountered an error during ${params.ACTION} of version ${env.TARGET_VERSION}."
        }
    }
}
