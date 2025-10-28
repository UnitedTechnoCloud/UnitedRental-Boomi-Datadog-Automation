# UnitedRental-Boomi-Datadog-Automation-
Production-safe PowerShell scripts to automate Boomi Atom/Molecule + Datadog Agent configuration
**Configuration Details**
JMX (Boomi)

**Enables remote JMX monitoring on port 9999 for local collection:**
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=9999
-Dcom.sun.management.jmxremote.local.only=false
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false

 Datadog YAML (datadog.yaml)

**Configures:**
API key
Site (datadoghq.com)
Process and logs collection
Host tags for Boomi Production Atom

**Datadog Integrations Written**
Integration	File Path	Purpose
JMX	conf.d\jmx.d\conf.yaml	-> Connects to Boomi JMX (port 9999)
Process	conf.d\process.d\conf.yaml	-> Tracks Atom-related Java processes
Disk	conf.d\disk.d\conf.yaml	-> Collects logical disk metrics
Windows Performance Counters	conf.d\windows_performance_counters.d\conf.yaml ->	Monitors system-level performance counters
NTP	conf.d\ntp.d\conf.yaml	-> Ensures NTP time synchronization check

**How to Run**
Open PowerShell as Administrator
Start-Process PowerShell -Verb RunAs

**Allow Script Execution (if restricted)**
Set-ExecutionPolicy Bypass -Scope Process -Force

**Navigate to the Script Directory**
cd "C:\Datadog\Scripts"


**Run the Script**
.\Datadog_Boomi_ConfigWriter.ps1

**What Happens During Execution**
Step	Action
1	Verifies Boomi and Datadog installation paths
2	Creates a timestamped backup of all target files
3	Detects Boomi instance matching UnitedRental-Production-Final
4	Writes JMX and Boomi config files
5	Writes Datadog configuration and integration YAMLs
6	Restarts datadogagent service only
7	Runs a local netstat to verify JMX port (9999) is active
8	Displays Datadog Agent status summary

**Verification Commands**
Check Datadog Agent status:
& "C:\Program Files\Datadog\Datadog Agent\bin\agent.exe" status

**Verify JMX port is open:**
netstat -ano | findstr 9999

**List running Datadog services:**
Get-Service | Where-Object { $_.Name -like "*datadog*" }

Safety Notes
Do NOT run this script without reviewing the $DatadogApiKeyValue — update it with your actual key.
Do NOT restart Boomi services manually during execution.
All modified files are backed up automatically before changes.
The script is idempotent — it can be safely re-run if needed.
