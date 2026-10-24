# PowerShell Rolling Update Verification Prober
param (
    [string]$TargetUrl = "http://localhost:3000",
    [int]$TotalProbes = 30,
    [double]$DelaySeconds = 0.5
)

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "      Docker Swarm Zero-Downtime Rolling Update Prober (PowerShell)  " -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "Target URL:    $TargetUrl"
Write-Host "Total Probes:  $TotalProbes"
Write-Host "Interval:      $DelaySeconds s`n"

$success = 0
$failed = 0
$replicas = @{}
$versions = @{}

for ($i = 1; $i -le $TotalProbes; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $res = Invoke-RestMethod -Uri "$TargetUrl/?format=json" -TimeoutSec 3 -ErrorAction Stop
        $sw.Stop()
        $success++
        $hostId = if ($res.instance -and $res.instance.hostname) { $res.instance.hostname } else { "node" }
        $ver = if ($res.version) { $res.version } else { "v1.0.0" }
        if ($hostId) { $replicas[$hostId] = $true }
        if ($ver) { $versions[$ver] = $true }

        Write-Host ("[Probe {0:D2}/{1:D2}] HTTP 200 | {2}ms | Version: {3} | Host: {4}" -f $i, $TotalProbes, $sw.ElapsedMilliseconds, $ver, $hostId) -ForegroundColor Green
    }
    catch {
        $sw.Stop()
        $failed++
        Write-Host ("[Probe {0:D2}/{1:D2}] FAILED | {2}ms | Error: {3}" -f $i, $TotalProbes, $sw.ElapsedMilliseconds, $_.Exception.Message) -ForegroundColor Red
    }
    Start-Sleep -Seconds $DelaySeconds
}

Write-Host "`n--------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "Total Probes: $TotalProbes"
Write-Host "Successful:   $success" -ForegroundColor Green
Write-Host "Failed:       $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "Replicas:     $($replicas.Keys -join ', ')" -ForegroundColor Yellow
Write-Host "Versions:     $($versions.Keys -join ', ')" -ForegroundColor Yellow

if ($failed -eq 0) {
    Write-Host "`n===> SUCCESS: Zero downtime verified (100% availability)!" -ForegroundColor Green
} else {
    Write-Host "`n===> WARNING: $failed requests failed during the probe." -ForegroundColor Yellow
}
