#!/usr/bin/env bash
# ==============================================================================
# Script: verify-cluster.sh
# Purpose: Verify Docker Swarm cluster nodes, service convergence, and health
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

STACK_NAME="${1:-cloud-microservice-stack}"
SERVICE_NAME="${STACK_NAME}_web-api"

echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}        Docker Swarm Cluster & Service Health Verification          ${NC}"
echo -e "${BLUE}====================================================================${NC}"

# Check Docker CLI availability
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR] Docker command not found on host.${NC}"
    exit 1
fi

# 1. Swarm State Verification
echo -e "\n${YELLOW}[1/4] Checking Docker Swarm Status...${NC}"
SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")

if [ "$SWARM_STATE" != "active" ]; then
    echo -e "${RED}[FAIL] Docker Swarm is NOT active on this node (State: ${SWARM_STATE}).${NC}"
    exit 1
fi
echo -e "${GREEN}[PASS] Docker Swarm is active.${NC}"

# 2. Node Health & Topology
echo -e "\n${YELLOW}[2/4] Inspecting Swarm Nodes (Manager & Workers)...${NC}"
docker node ls

TOTAL_NODES=$(docker node ls -q | wc -l)
READY_NODES=$(docker node ls --filter "membership=accepted" --format "{{.Status}}" | grep -c "Ready" || true)

echo -e "Total Nodes: ${TOTAL_NODES} | Ready Nodes: ${READY_NODES}"
if [ "$TOTAL_NODES" -ge 1 ] && [ "$READY_NODES" -eq "$TOTAL_NODES" ]; then
    echo -e "${GREEN}[PASS] All ${TOTAL_NODES} Swarm nodes are in Ready state.${NC}"
else
    echo -e "${YELLOW}[WARN] One or more nodes may be unreachable or disconnected.${NC}"
fi

# 3. Stack and Service Verification
echo -e "\n${YELLOW}[3/4] Verifying Stack '${STACK_NAME}' and Service '${SERVICE_NAME}'...${NC}"
if docker stack ls | grep -qw "$STACK_NAME"; then
    echo -e "${GREEN}[PASS] Stack '${STACK_NAME}' is deployed.${NC}"
else
    echo -e "${RED}[WARN] Stack '${STACK_NAME}' is not currently listed in 'docker stack ls'.${NC}"
fi

if docker service ls | grep -qw "$SERVICE_NAME"; then
    REPLICAS=$(docker service ls --filter "name=${SERVICE_NAME}" --format "{{.Replicas}}")
    echo -e "Service '${SERVICE_NAME}' Replicas: ${REPLICAS}"
    
    DESIRED=$(echo "$REPLICAS" | cut -d'/' -f2)
    ACTUAL=$(echo "$REPLICAS" | cut -d'/' -f1)
    
    if [ "$DESIRED" = "$ACTUAL" ] && [ "$ACTUAL" -gt 0 ]; then
        echo -e "${GREEN}[PASS] Service '${SERVICE_NAME}' is fully converged (${ACTUAL}/${DESIRED} healthy replicas).${NC}"
    else
        echo -e "${YELLOW}[WARN] Service '${SERVICE_NAME}' is still converging (${ACTUAL}/${DESIRED}).${NC}"
    fi
else
    echo -e "${YELLOW}[INFO] Service '${SERVICE_NAME}' not found. Listing all active services:${NC}"
    docker service ls
fi

# 4. Service Task Details
echo -e "\n${YELLOW}[4/4] Listing Task Replica Distribution across Nodes...${NC}"
if docker service ls | grep -qw "$SERVICE_NAME"; then
    docker service ps "$SERVICE_NAME" --no-trunc
fi

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}             Cluster Health Audit Completed Successfully             ${NC}"
echo -e "${GREEN}====================================================================${NC}"
