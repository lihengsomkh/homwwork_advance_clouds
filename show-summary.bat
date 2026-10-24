@echo off
title Docker Verification Summary - Homework 2
color 0B
cls
echo ==============================================================================
echo                      DOCKER VERIFICATION SUMMARY
echo ==============================================================================
echo.
echo [1] DOCKER IMAGES (IMMUTABLE BUILD TAGS):
echo ------------------------------------------------------------------------------
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | findstr /i "REPOSITORY cloud-microservice"
echo.
echo [2] DOCKER SWARM SERVICE STATUS:
echo ------------------------------------------------------------------------------
docker service ls --filter "name=cloud-microservice-stack"
echo.
echo [3] LIVE APPLICATION RESPONSE (http://localhost:8000/):
echo ------------------------------------------------------------------------------
curl.exe -s http://localhost:8000/
echo.
echo.
echo ==============================================================================
echo.
pause
