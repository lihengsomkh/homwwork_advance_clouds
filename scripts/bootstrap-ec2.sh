#!/usr/bin/env bash
# ==============================================================================
# Script: bootstrap-ec2.sh
# Purpose: Configure remote AWS EC2 instance as Docker Swarm Manager
# ==============================================================================

set -euo pipefail

echo "===> [1/6] Retrieving AWS EC2 Instance Metadata..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300" || echo "")
if [ -n "$TOKEN" ]; then
    AWS_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region || echo "ap-southeast-2")
    PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 || echo "127.0.0.1")
else
    AWS_REGION="ap-southeast-2"
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
fi

echo "Detected AWS Region:    ${AWS_REGION}"
echo "Detected Private IP:    ${PRIVATE_IP}"

echo "===> [2/6] Installing Docker on Ubuntu..."
if ! command -v docker &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y docker.io awscli curl git
    sudo usermod -aG docker ubuntu
    sudo systemctl enable --now docker
    echo "Docker installed successfully."
else
    echo "Docker is already installed."
fi

# Ensure current script can use docker without restart
sudo chmod 666 /var/run/docker.sock || true

echo "===> [3/6] Initializing Docker Swarm Cluster..."
SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")
if [ "$SWARM_STATE" != "active" ]; then
    echo "Initializing new Docker Swarm Leader node on ${PRIVATE_IP}..."
    docker swarm init --advertise-addr "${PRIVATE_IP}"
    echo "Docker Swarm cluster initialized."
else
    echo "Docker Swarm is already active."
fi

echo "===> [4/6] Docker Swarm Node Status:"
docker node ls

echo "===> [5/6] Checking IAM / AWS Credentials:"
if aws sts get-caller-identity 2>/dev/null; then
    echo "AWS CLI is authenticated via IAM Role or local credentials."
else
    echo "NOTICE: EC2 instance does not have an IAM role attached. Jenkins or local machine can push directly."
fi

echo "===> [6/6] EC2 Docker Swarm Bootstrap Completed Successfully!"
