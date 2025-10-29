Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "   BOOMI + DATADOG POST-INSTALL VALIDATION (PRODUCTION SAFE)" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

function Section($msg) {
    Write-Host ""
    Write-Host ("-- " + $msg + " " + ("-" * (60 - $msg.Length))) -ForegroundColor Yellow
}

Section "Checking Boomi (Atom / Molecule) Services"
$boomi = Get-Service | Where-Object { $_.DisplayName -match "(?i)Boomi|Atom|Molecule" }
if ($boomi) {
    Write-Host "[OK] Found Boomi services:" -ForegroundColor Green
    $boomi | ForEach-Object {
        Write-Host ("   - {0} (Status: {1})" -f $_.DisplayName, $_.Status)
    }
} else {
    Write-Host "[FAIL] No Boomi services found." -ForegroundColor Red
}

Section "Checking Boomi Runtime Processes (atom.exe / molecule.exe)"
$boomiProcs = Get-Process | Where-Object { $_.ProcessName -match "(?i)atom|molecule" }
if ($boomiProcs) {
    Write-Host "[OK] Running Boomi processes found:" -ForegroundColor Green
    $boomiProcs | Select-Object Id, ProcessName, Path | Format-Table
} else {
    Write-Host "[WARN] No active Boomi JVM process found." -ForegroundColor Yellow
}

Section "Checking Datadog Agent Service"
$dd = Get-Service | Where-Object { $_.Name -eq "datadogagent" }
if ($dd -and $dd.Status -eq "Running") {
    Write-Host "[OK] Datadog Agent running" -ForegroundColor Green
} elseif ($dd) {
    Write-Host "[WARN] Datadog Agent installed but not running" -ForegroundColor Yellow
} else {
    Write-Host "[FAIL] Datadog Agent not found" -ForegroundColor Red
}

Section "Checking Datadog Agent Version"
try {
    $agentPath = "C:\Program Files\Datadog\Datadog Agent\bin\agent.exe"
    if (Test-Path $agentPath) {
        $ddVersion = & "$agentPath" version 2>$null
        if ($ddVersion) { Write-Host $ddVersion }
        else { Write-Host "[WARN] Unable to detect Datadog version" -ForegroundColor Yellow }
    } else {
        Write-Host "[WARN] agent.exe not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Error while checking Datadog Agent version: $_" -ForegroundColor Yellow
}

Section "Validating JMX Metrics from Boomi"
try {
    $agentPath = "C:\Program Files\Datadog\Datadog Agent\bin\agent.exe"
    if (Test-Path $agentPath) {
        $jmxOutput = & "$agentPath" status 2>$null | Select-String "jmx"
        if ($jmxOutput) {
            Write-Host "[OK] JMX Fetch metrics detected ??? Boomi JVM connected" -ForegroundColor Green
        } else {
            Write-Host "[WARN] No JMX metrics found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[FAIL] agent.exe not found, cannot check JMX metrics" -ForegroundColor Red
    }
} catch {
    Write-Host "[FAIL] Unable to query Datadog Agent for JMX metrics: $_" -ForegroundColor Red
}

Section "Verifying Datadog Configuration Files"
$paths = @(
    "C:\ProgramData\Datadog\datadog.yaml",
    "C:\ProgramData\Datadog\conf.d\jmx.d\conf.yaml",
    "C:\ProgramData\Datadog\conf.d\windows_performance_counters.d\conf.yaml"
)
foreach ($p in $paths) {
    if (Test-Path $p) { Write-Host "[OK] $p exists" -ForegroundColor Green }
    else { Write-Host "[WARN] $p missing" -ForegroundColor Yellow }
}

Section "Checking JMX Port (9999)"
$portCheck = netstat -ano | findstr ":9999"
if ($portCheck) {
    Write-Host "[OK] Port 9999 active (LISTENING)" -ForegroundColor Green
    $portCheck
} else {
    Write-Host "[WARN] Port 9999 not active" -ForegroundColor Yellow
}

Section "Reading Datadog Agent Logs (last 10 lines)"
$logPath = "C:\ProgramData\Datadog\logs\agent.log"
if (Test-Path $logPath) { Get-Content $logPath -Tail 10 }
else { Write-Host "[WARN] Datadog log file not found" -ForegroundColor Yellow }

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "   VALIDATION COMPLETE ??? REVIEW RESULTS ABOVE" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
