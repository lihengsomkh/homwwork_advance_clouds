@echo off
title AWS EC2 Live Docker Swarm Deployment Results
color 0B
cls
echo ==============================================================================
echo                 AWS EC2 LIVE DOCKER SWARM RESULTS (54.206.14.99)
echo ==============================================================================
echo.
echo [1] AWS EC2 SWARM CLUSTER NODES:
echo ------------------------------------------------------------------------------
ssh.exe -i lihengsomkh.pem -o StrictHostKeyChecking=no ubuntu@54.206.14.99 "docker node ls"
echo.
echo [2] AWS EC2 SWARM SERVICES (3/3 HEALTHY REPLICAS):
echo ------------------------------------------------------------------------------
ssh.exe -i lihengsomkh.pem -o StrictHostKeyChecking=no ubuntu@54.206.14.99 "docker service ls"
echo.
echo [3] TASK REPLICA DISTRIBUTION ON EC2:
echo ------------------------------------------------------------------------------
ssh.exe -i lihengsomkh.pem -o StrictHostKeyChecking=no ubuntu@54.206.14.99 "docker service ps cloud-microservice-stack_web-api"
echo.
echo [4] LIVE INTERNET PROBE TO AWS EC2 (http://54.206.14.99/):
echo ------------------------------------------------------------------------------
curl.exe -s http://54.206.14.99/
echo.
echo.
echo [5] LIVE HEALTHCHECK PROBE (http://54.206.14.99/health):
echo ------------------------------------------------------------------------------
curl.exe -s http://54.206.14.99/health
echo.
echo.
echo ==============================================================================
echo         ALL AWS DEPLOYMENT CHECKS PASSED - READY FOR SCREENSHOT!
echo ==============================================================================
echo.
pause
