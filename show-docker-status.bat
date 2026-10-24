@echo off
title Docker Image and Swarm Service Status
color 0A
cls
echo ==============================================================================
echo                           DOCKER IMAGE STATUS
echo ==============================================================================
echo.
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | findstr /i "REPOSITORY cloud-microservice"
echo.
echo ==============================================================================
echo                     DOCKER SWARM SERVICE STATUS
echo ==============================================================================
echo.
docker service ls --filter "name=cloud-microservice-stack"
echo.
docker service ps cloud-microservice-stack_web-api
echo.
echo ==============================================================================
echo.
pause
