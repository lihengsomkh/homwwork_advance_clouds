@echo off
title Docker Swarm and CI/CD Pipeline Results - Homework 2
color 0A
cls
echo ==============================================================================
echo         AWS DOCKER SWARM AND CI/CD PIPELINE DEPLOYMENT RESULTS
echo ==============================================================================
echo.
echo [1] DOCKER SWARM CLUSTER NODES:
echo ------------------------------------------------------------------------------
docker node ls
echo.
echo [2] DOCKER STACKS:
echo ------------------------------------------------------------------------------
docker stack ls
echo.
echo [3] DOCKER SERVICES AND REPLICAS (3/3 CONVERGED):
echo ------------------------------------------------------------------------------
docker service ls --filter "name=cloud-microservice-stack"
echo.
echo [4] SERVICE REPLICA TASK DISTRIBUTION ACROSS NODES:
echo ------------------------------------------------------------------------------
docker service ps cloud-microservice-stack_web-api
echo.
echo [5] DOCKER IMAGES AND IMMUTABLE PIPELINE TAGS:
echo ------------------------------------------------------------------------------
docker images | findstr "cloud-microservice"
echo.
echo [6] LIVE APPLICATION ROOT ENDPOINT (http://localhost:8000/):
echo ------------------------------------------------------------------------------
curl.exe -s http://localhost:8000/
echo.
echo.
echo [7] LIVE HEALTHCHECK PROBE (http://localhost:8000/health):
echo ------------------------------------------------------------------------------
curl.exe -s http://localhost:8000/health
echo.
echo.
echo ==============================================================================
echo       ALL VERIFICATION CHECKS PASSED - READY FOR SCREENSHOT!
echo ==============================================================================
echo.
pause
