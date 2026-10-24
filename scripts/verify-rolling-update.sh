#!/usr/bin/env bash
# ==============================================================================
# Script: verify-rolling-update.sh
# Purpose: Probe application during rolling update to verify zero downtime
# ==============================================================================

set -euo pipefail

TARGET_URL="${1:-http://localhost}"
REQUEST_COUNT="${2:-60}"
DELAY="${3:-0.5}"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}      Docker Swarm Zero-Downtime Rolling Update Prober               ${NC}"
echo -e "${CYAN}====================================================================${NC}"
echo -e "Target URL:       ${TARGET_URL}"
echo -e "Total Probes:     ${REQUEST_COUNT}"
echo -e "Interval Delay:   ${DELAY}s"
echo -e "--------------------------------------------------------------------"

SUCCESS_COUNT=0
FAILURE_COUNT=0
declare -A REPLICA_HOSTS
declare -A DETECTED_VERSIONS

for ((i=1; i<=REQUEST_COUNT; i++)); do
    RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" "${TARGET_URL}/" 2>/dev/null || echo -e "FAILED\n000\n0")
    
    BODY=$(echo "$RESPONSE" | sed '$d' | sed '$d')
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 2 | head -n 1)
    TIME_TOTAL=$(echo "$RESPONSE" | tail -n 1)

    if [ "$HTTP_CODE" = "200" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Parse hostname and version from JSON body
        HOST=$(echo "$BODY" | grep -o '"hostname":"[^"]*' | cut -d'"' -f4 || echo "unknown")
        VER=$(echo "$BODY" | grep -o '"version":"[^"]*' | cut -d'"' -f4 || echo "unknown")
        
        REPLICA_HOSTS["$HOST"]=1
        DETECTED_VERSIONS["$VER"]=1

        printf "[Probe %02d/%02d] HTTP %s | %ss | Version: %-8s | Container Host: %s\n" \
            "$i" "$REQUEST_COUNT" "$HTTP_CODE" "$TIME_TOTAL" "$VER" "$HOST"
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo -e "[Probe $i/$REQUEST_COUNT] ${RED}FAILED - HTTP ${HTTP_CODE}${NC} (${TIME_TOTAL}s)"
    fi

    sleep "$DELAY"
done

echo -e "\n--------------------------------------------------------------------"
echo -e "${CYAN}ROLLING UPDATE VERIFICATION SUMMARY:${NC}"
echo -e "Total Requests:      ${REQUEST_COUNT}"
echo -e "Successful (200 OK): ${GREEN}${SUCCESS_COUNT}${NC}"
echo -e "Failed Requests:     ${RED}${FAILURE_COUNT}${NC}"

UNIQUE_HOSTS="${!REPLICA_HOSTS[@]}"
UNIQUE_VERSIONS="${!DETECTED_VERSIONS[@]}"

echo -e "Active Replicas hit: ${YELLOW}${UNIQUE_HOSTS}${NC}"
echo -e "Versions Detected:   ${YELLOW}${UNIQUE_VERSIONS}${NC}"

if [ "$FAILURE_COUNT" -eq 0 ]; then
    echo -e "${GREEN}===> SUCCESS: Zero downtime verified! 100% availability during rolling deployment.${NC}"
else
    echo -e "${RED}===> WARNING: ${FAILURE_COUNT} dropped requests detected during deployment.${NC}"
fi
echo -e "${CYAN}====================================================================${NC}"
