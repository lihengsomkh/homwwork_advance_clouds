param (
    [int]$BuildNumber = 6
)

Write-Host "Monitoring Jenkins Build #$BuildNumber..."
$done = $false
while (-not $done) {
    Start-Sleep -Seconds 3
    $statusJson = curl.exe -s -u admin:password123 "http://localhost:8080/job/cloud-microservice-pipeline/$BuildNumber/api/json"
    if ($statusJson) {
        $buildInfo = $statusJson | ConvertFrom-Json
        if ($buildInfo.building -eq $false) {
            $done = $true
            Write-Host "Build #$BuildNumber completed with result: $($buildInfo.result)"
        } else {
            Write-Host "Build #$BuildNumber in progress..."
        }
    } else {
        Write-Host "Waiting for build #$BuildNumber to start..."
    }
}

Write-Host "`n=== Console Log Output (Last 60 lines) ==="
$log = curl.exe -s -u admin:password123 "http://localhost:8080/job/cloud-microservice-pipeline/$BuildNumber/consoleText"
$lines = $log -split "`n"
$lastLines = $lines | Select-Object -Last 60
$lastLines | ForEach-Object { Write-Host $_ }
