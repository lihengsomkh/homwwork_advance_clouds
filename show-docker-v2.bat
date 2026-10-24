@echo off
title Docker v2 Images and Verification - Homework 2
color 0E
cls
echo ==============================================================================
echo                      DOCKER V2 IMAGES AND SERVICE STATUS
echo ==============================================================================
echo.
echo [1] DOCKER V2 IMAGE ARTIFACTS AND TAGS:
echo ------------------------------------------------------------------------------
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | findstr /i "REPOSITORY v2.0.0"
echo.
echo [2] ALL CLOUD-MICROSERVICE IMAGE TAGS (BUILDS, V2, AND ECR):
echo ------------------------------------------------------------------------------
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | findstr /i "REPOSITORY cloud-microservice"
echo.
echo [3] DOCKER SWARM SERVICE STATUS (RUNNING V2):
echo ------------------------------------------------------------------------------
docker service ls --filter "name=cloud-microservice-stack"
echo.
echo [4] SERVICE REPLICAS CONVERGENCE:
echo ------------------------------------------------------------------------------
docker service ps cloud-microservice-stack_web-api
echo.
echo [5] LIVE APPLICATION RESPONSE (http://localhost:8000/):
echo ------------------------------------------------------------------------------
curl.exe -s http://localhost:8000/
echo.
echo.
echo ==============================================================================
echo                      DOCKER V2 VERIFICATION COMPLETE!
echo ==============================================================================
echo.
pause
