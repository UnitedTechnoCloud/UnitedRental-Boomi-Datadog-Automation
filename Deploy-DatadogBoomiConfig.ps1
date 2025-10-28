<#
FINAL PRODUCTION SCRIPT
-----------------------
Name:     Datadog + Boomi (Atom/Molecule) Configuration Writer
Version:  2025-10-28 (v1.0)
Author:   Mahendrakumar Viswanathan
Purpose:  Automates safe configuration of Datadog and Boomi for JMX monitoring on Windows.

Key Features:
- Backs up and writes Boomi Atom/Molecule vmoptions and container.properties.
- Configures JMX on port 9999 (localhost).
- Backs up and writes Datadog configuration files.
- Does NOT restart Boomi Atom/Molecule (production-safe).
- Restarts only the Datadog Agent service.
#>

# -------------------------
# Fail Fast
# -------------------------
$ErrorActionPreference = "Stop"

# -------------------------
# Utility Functions
# -------------------------
function Write-Log($lvl, $msg) {
    $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$t] [$lvl] $msg"
}

function Fail-Exit($msg) {
    Write-Host "[FATAL] $msg"
    exit 1
}

function Copy-Backup($src, $destRoot) {
    if (Test-Path $src) {
        $rel = $src.TrimStart("\") -replace ":", ""
        $targetDir = Join-Path $destRoot (Split-Path $rel -Parent)
        if (-not (Test-Path $targetDir)) { New-Item -Path $targetDir -ItemType Directory -Force | Out-Null }
        $fname = Split-Path $src -Leaf
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $dest = Join-Path $targetDir ($fname + ".bak.$ts")
        Copy-Item -Path $src -Destination $dest -Force
        Write-Log "INFO" "Backed up `"$src`" -> `"$dest`""
        return $dest
    } else {
        return $null
    }
}

# -------------------------
# Global Variables
# -------------------------
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupRoot = "C:\Backup_Boomi_Datadog_$timestamp"
New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null

$BoomiRoot = "C:\Program Files\Boomi AtomSphere"
$DesiredInstanceMarker = "UnitedRental-Production-Final"
$DatadogYamlPath = "C:\ProgramData\Datadog\datadog.yaml"
$DatadogConfD = "C:\ProgramData\Datadog\conf.d"
$DatadogAgentServiceName = "datadogagent"
$DatadogApiKeyValue = "2abccbc2a47020e8fd790d21f582d9b2"
$DatadogSite = "datadoghq.com"

# -------------------------
# Configuration Templates
# -------------------------
$AtomVmoptionsContent = @"
-Xmx512m
-Dsun.net.client.defaultConnectTimeout=120000
-Dsun.net.client.defaultReadTimeout=120000
-Dsun.net.http.retryPost=false
-Dcom.boomi.container.securityCompatibility=JVM_DEFINED
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=9999
-Dcom.sun.management.jmxremote.local.only=false
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.rmi.port=9999
-Djava.rmi.server.hostname=localhost
"@

$ContainerPropertiesContent = @"
com.boomi.container.jmxremote.port=9999
com.boomi.container.jmxremote.authenticate=false
com.boomi.container.jmxremote.ssl=false
"@

$DatadogYamlContent = @"
api_key: $DatadogApiKeyValue
site: $DatadogSite
hostname: UnitedRental-Production-Final

process_config:
  enabled: true
  process_collection:
    enabled: true

logs_enabled: true
use_dogstatsd: true

tags:
  - app: boomi
  - env: production
  - host: UnitedRental-Production-Final
  - role: atom

conf.d: C:\ProgramData\Datadog\conf.d
checks.d: C:\ProgramData\Datadog\checks.d
"@

$jmxConf = @"
init_config:
  is_jmx: true

instances:
  - host: localhost
    port: 9999
    name: boomi
    collect_default_metrics: true
    conf:
      - include:
          domain: com.boomi.container.services
      - exclude:
          domain: com.boomi.container.services
          bean:
            - com.boomi.container.services:type=MessageQueue,queueId=overrides
"@

$procConf = @"
init_config:

instances:
  - name: process_disk
    search_string:
      - java
      - Atom.exe
    exact_match: false
    win_perf_counters:
      - counter: '\\Process(*)\\IO Read Bytes/sec'
        type: gauge
        name: process.disk.read_bytes
      - counter: '\\Process(*)\\IO Write Bytes/sec'
        type: gauge
        name: process.disk.write_bytes
"@

$diskConf = @"
init_config:

instances:
  - name: system_disk
    tags:
      - service:boomi
      - env:prod
    win_perf_counters:
      - counter: "\\LogicalDisk(*)\\% Free Space"
        type: gauge
        name: system.disk.free_percent
      - counter: "\\LogicalDisk(*)\\Disk Reads/sec"
        type: rate
        name: system.disk.reads_per_sec
      - counter: "\\LogicalDisk(*)\\Disk Writes/sec"
        type: rate
        name: system.disk.writes_per_sec
      - counter: "\\LogicalDisk(*)\\Disk Read Bytes/sec"
        type: gauge
        name: system.disk.read_bytes
      - counter: "\\LogicalDisk(*)\\Disk Write Bytes/sec"
        type: gauge
        name: system.disk.write_bytes
      - counter: "\\LogicalDisk(*)\\Current Disk Queue Length"
        type: gauge
        name: system.disk.queue_length
      - counter: "\\LogicalDisk(*)\\Avg. Disk sec/Transfer"
        type: gauge
        name: system.disk.avg_sec_per_transfer
"@

$winPerfConf = @"
init_config:

instances:
  - metrics:
      LogicalDisk:
        name: logicaldisk
        tag_name: disk
        counters:
          - '% Disk Read Time': percent_disk_read_time
          - '% Disk Write Time': percent_disk_write_time
          - '% Disk Time': percent_disk_time
          - '% Free Space': percent_free_space
          - '% Idle Time': percent_idle_time
          - 'Avg. Disk sec/Read': avg_disk_sec_per_read
          - 'Avg. Disk sec/Write': avg_disk_sec_per_write
          - 'Avg. Disk Queue Length': avg_disk_queue_length
          - 'Disk Transfers/sec': disk_transfers_per_sec
          - 'Disk Reads/sec': disk_reads_per_sec
          - 'Disk Writes/sec': disk_writes_per_sec
          - 'Free Megabytes': free_megabytes
          - 'Avg. Disk Bytes/Read': avgerage_disk_bytes_read
          - 'Avg. Disk Bytes/Write': avgerage_disk_bytes_write
          - 'Current Disk Queue Length': current_disk_queue_length
    enable_health_service_check: true
    namespace: performance
    min_collection_interval: 15
    empty_default_hostname: false
"@

$ntpConf = @"
init_config:
  use_local_ntp: true
instances:
  - offset_threshold: 60
"@

# -------------------------
# Boomi Configuration
# -------------------------
Write-Log "INFO" "Starting backup and configuration. Boomi processes will NOT be restarted."

if (-not (Test-Path $BoomiRoot)) {
    Write-Log "WARN" "Boomi root '$BoomiRoot' not found. Proceeding with Datadog configuration only."
} else {
    Write-Log "INFO" "Scanning Boomi root for instances containing '$DesiredInstanceMarker'..."
}

$instances = @()
if (Test-Path $BoomiRoot) {
    $children = Get-ChildItem -Path $BoomiRoot -Directory -ErrorAction SilentlyContinue
    foreach ($c in $children) {
        if ($c.Name -like "*$DesiredInstanceMarker*") {
            $instances += $c.FullName
            Write-Log "INFO" "Found Boomi instance: $($c.FullName)"
        }
    }
}

if ($instances.Count -eq 0) {
    Write-Log "WARN" "No Boomi instance folders found matching '*$DesiredInstanceMarker*'."
}

# -------------------------
# Backup and Write Operations
# -------------------------
$modifiedFiles = @()
foreach ($inst in $instances) {
    $binDir = Join-Path $inst "bin"
    $confDir = Join-Path $inst "conf"

    $atomVmPath = Join-Path $binDir "atom.vmoptions"
    $moleculeVmPath = Join-Path $binDir "molecule.vmoptions"
    $containerPropsPath = Join-Path $confDir "container.properties"

    if (Test-Path $atomVmPath) { Copy-Backup $atomVmPath $BackupRoot | Out-Null }
    if (Test-Path $moleculeVmPath) { Copy-Backup $moleculeVmPath $BackupRoot | Out-Null }
    if (Test-Path $containerPropsPath) { Copy-Backup $containerPropsPath $BackupRoot | Out-Null }

    if (-not (Test-Path $binDir)) { New-Item -Path $binDir -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $confDir)) { New-Item -Path $confDir -ItemType Directory -Force | Out-Null }

    $AtomVmoptionsContent | Out-File -FilePath $atomVmPath -Encoding ascii -Force
    $AtomVmoptionsContent | Out-File -FilePath $moleculeVmPath -Encoding ascii -Force
    $ContainerPropertiesContent | Out-File -FilePath $containerPropsPath -Encoding ascii -Force

    $modifiedFiles += @($atomVmPath, $moleculeVmPath, $containerPropsPath)
}

# -------------------------
# Datadog Configuration
# -------------------------
if (Test-Path $DatadogYamlPath) { Copy-Backup $DatadogYamlPath $BackupRoot | Out-Null }
$DatadogYamlContent | Out-File -FilePath $DatadogYamlPath -Encoding ascii -Force
Write-Log "INFO" "Wrote Datadog YAML -> $DatadogYamlPath"
$modifiedFiles += $DatadogYamlPath

if (-not (Test-Path $DatadogConfD)) { New-Item -Path $DatadogConfD -ItemType Directory -Force | Out-Null }

$subdirs = @{
    "jmx.d\conf.yaml" = $jmxConf;
    "process.d\conf.yaml" = $procConf;
    "disk.d\conf.yaml" = $diskConf;
    "windows_performance_counters.d\conf.yaml" = $winPerfConf;
    "ntp.d\conf.yaml" = $ntpConf;
}

foreach ($k in $subdirs.Keys) {
    $fullPath = Join-Path $DatadogConfD $k
    $dirPath = Split-Path $fullPath -Parent
    if (-not (Test-Path $dirPath)) { New-Item -Path $dirPath -ItemType Directory -Force | Out-Null }
    if (Test-Path $fullPath) { Copy-Backup $fullPath $BackupRoot | Out-Null }
    $subdirs[$k] | Out-File -FilePath $fullPath -Encoding ascii -Force
    Write-Log "INFO" "Wrote Datadog conf -> $fullPath"
    $modifiedFiles += $fullPath
}

# -------------------------
# Restart Datadog Agent
# -------------------------
Write-Log "INFO" "Restarting Datadog Agent service..."
if (Get-Service -Name $DatadogAgentServiceName -ErrorAction SilentlyContinue) {
    & sc.exe stop $DatadogAgentServiceName | Out-Null
    Start-Sleep -Seconds 3
    & sc.exe start $DatadogAgentServiceName | Out-Null
    Start-Sleep -Seconds 5
    Write-Log "INFO" "Datadog Agent restart completed."
} else {
    Write-Log "WARN" "Datadog Agent service not found."
}

# -------------------------
# Verification
# -------------------------
$agentExe = "C:\Program Files\Datadog\Datadog Agent\bin\agent.exe"
if (Test-Path $agentExe) {
    Write-Log "INFO" "Datadog Agent status:"
    & $agentExe status
} else {
    Write-Log "WARN" "Agent binary not found."
}

Write-Log "INFO" "Netstat check for port 9999 (local JMX):"
netstat -ano | findstr 9999 | ForEach-Object { Write-Log "INFO" $_ }

# -------------------------
# Summary
# -------------------------
Write-Log "INFO" "Operation completed successfully."
Write-Log "INFO" "Backup root: $BackupRoot"
Write-Log "INFO" "No Boomi processes were restarted."