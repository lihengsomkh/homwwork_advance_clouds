param (
    [Parameter(Mandatory=$true)]
    [string]$Action,
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$PushToEcr = "false",
    [string]$DeployToSwarm = "true"
)

$crumbJson = curl.exe -s -c cookies.txt -u admin:password123 "http://localhost:8080/crumbIssuer/api/json" | ConvertFrom-Json
$crumb = $crumbJson.crumb
$field = $crumbJson.crumbRequestField
$headerArg = "$($field): $($crumb)"

$url = "http://localhost:8080/job/cloud-microservice-pipeline/buildWithParameters?ACTION=$Action&VERSION=$Version&PUSH_TO_ECR=$PushToEcr&DEPLOY_TO_SWARM=$DeployToSwarm"

Write-Host "Triggering Jenkins build: ACTION=$Action, VERSION=$Version..."
$httpCode = curl.exe -s -w "%{http_code}" -b cookies.txt -u admin:password123 -X POST $url -H $headerArg
Write-Host "Jenkins Response: HTTP $httpCode"

if ($httpCode -eq "201" -or $httpCode -eq "200") {
    Write-Host "Build queued successfully!"
} else {
    Write-Host "Failed to trigger build. Check Jenkins logs or parameters."
}
