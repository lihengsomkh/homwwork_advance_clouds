#!/usr/bin/env bash
# ==============================================================================
# Script: verify-security-groups.sh
# Purpose: Audit and verify AWS Security Group ingress rules for Docker Swarm
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SECURITY_GROUP_ID="${1:-}"

echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}        AWS Security Group & Port Verification for Docker Swarm      ${NC}"
echo -e "${BLUE}====================================================================${NC}"

cat << 'EOF'
REQUIRED PORTS SPECIFICATION:
--------------------------------------------------------------------------------
Port / Protocol  | Scope               | Purpose
--------------------------------------------------------------------------------
22 / TCP         | Admin / Jenkins     | Secure SSH remote pipeline management
80 / TCP         | Internet / Ingress  | Public HTTP traffic to web application
2377 / TCP       | Swarm Cluster Nodes | Swarm cluster management communication
7946 / TCP + UDP | Swarm Cluster Nodes | Node communication / gossip discovery
4789 / UDP       | Swarm Cluster Nodes | Overlay network VXLAN data plane
--------------------------------------------------------------------------------
EOF

# If AWS CLI is configured and Security Group ID is supplied, audit directly
if command -v aws &> /dev/null && [ -n "$SECURITY_GROUP_ID" ]; then
    echo -e "\n${CYAN}Auditing AWS Security Group: ${SECURITY_GROUP_ID} using AWS CLI...${NC}"
    
    RULES=$(aws ec2 describe-security-groups \
        --group-ids "$SECURITY_GROUP_ID" \
        --query "SecurityGroups[0].IpPermissions" \
        --output json 2>/dev/null || echo "ERROR")
    
    if [ "$RULES" != "ERROR" ]; then
        echo -e "${GREEN}[PASS] Successfully retrieved Security Group rules from AWS.${NC}"
        
        # Check ports
        for PORT in 22 80 2377 7946 4789; do
            MATCH=$(echo "$RULES" | grep -w "\"FromPort\": $PORT" || true)
            if [ -n "$MATCH" ]; then
                echo -e "Port ${PORT}: ${GREEN}[PASS] Ingress rule detected.${NC}"
            else
                echo -e "Port ${PORT}: ${YELLOW}[WARN] Ingress rule NOT found or uses range.${NC}"
            fi
        done
    else
        echo -e "${YELLOW}[WARN] Could not fetch AWS Security Group with ID '${SECURITY_GROUP_ID}'. Check AWS credentials or region.${NC}"
    fi
else
    echo -e "\n${YELLOW}[INFO] AWS CLI not configured or Security Group ID not provided as argument.${NC}"
    echo -e "Usage: ./scripts/verify-security-groups.sh <sg-xxxxxxxxx>"
    echo -e "Performing local network listener audit for Docker Swarm ports..."
fi

# Local listening ports check if run on the Linux node
if command -v ss &> /dev/null; then
    echo -e "\n${CYAN}Active Listening Sockets on Current Host:${NC}"
    ss -tlpn | grep -E ":(22|80|2377|7946)\b" || echo "No standard Swarm TCP listeners found on this specific interface."
    ss -ulpn | grep -E ":(7946|4789)\b" || echo "No standard Swarm UDP listeners found on this specific interface."
elif command -v netstat &> /dev/null; then
    echo -e "\n${CYAN}Active Listening Sockets (netstat):${NC}"
    netstat -tuln | grep -E ":(22|80|2377|7946|4789)\b" || echo "No matching listeners."
fi

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}                Security Group Audit Finished                       ${NC}"
echo -e "${GREEN}====================================================================${NC}"
