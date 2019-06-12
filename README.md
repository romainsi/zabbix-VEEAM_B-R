# VEEAM-Backup-Recovery-jobs

This template use the VEEAM Backup & Replication PowerShell Cmdlets to discover and manage VEEAM Backup jobs, Veeam BackupSync, Veeam Tape Job, Veeam Endpoint Backup Jobs, All Repositories and Veeam Services.

- Work with Veeam backup & replication V7 to V9.5
- Work with Zabbix 3.X (english template only for V3.X) & 4.X
- French & English translation for the Template

### Explanation of how it works:
The "Result Export Xml Veeam" item sends a powershell command (with `nowait` option) to the host to create an xml file of the result of the `Get-VBRBbackupSession`, `Get-VBRJob`, `Get-VRBBackup` and `Get-VBREPJob` commands that is stored under `C:\Program Files\Zabbix Agent\scripts\TempXmlVeeam\*.xml` (variable `$pathxml`).
Then, each request imports the xml to retrieve the information.

Why? Because the execution of this command can take between 30 seconds and more than 3 minutes (depending on the history and the number of tasks) and I end up with several scripts running for a certain time and the execution is in timeout.


## Items

  - Number of tasks jobs
  - Number of running jobs
  - Result Export Xml Veeam

## Discovery Jobs

### 1. Veeam Jobs:
  - Result of each jobs
  - Execution status for each jobs
  - Number of VMs Failed in each jobs
  - Number of VMs Warning in each jobs
  - Type for each jobs
  - Number of VMs in each jobs
  - Size included in each jobs (disabled by default)
  - Size excluded in each jobs (disabled by default)
  - Next run time of each jobs

### 2. Veeam Tape Jobs:
  - Result of each jobs
  - Execution status for each jobs

### 3. Veeam BackupSync Jobs:
  - Result of each jobs
  - Execution status for each jobs
  - Number of VMs Failed in each jobs
  - Number of VMs Warning in each jobs
  - Type for each jobs
  - Number of VMs in each jobs
  - Size included in each jobs (disabled by default)
  - Size excluded in each jobs (disabled by default)

### 4. Veeam Jobs Endpoint Backup:
  - Result of each jobs
  - Execution status for each jobs
  - Next run time of each jobs
  
### 5. Veeam Jobs Replication Backup:
  - Result of each jobs
  - Execution status for each jobs
  - Type for each jobs

### 6. Veeam Repository:
  - Remaining space in repository for each repo
  - Total space in repository for each repo

## Discovery Jobs By VMs

### 1. VEEAM Backup By VMs:
  - Result of each VMs in each Jobs

### 2. VEEAM BackupSync By VMs:
  - Result of each VMs in each Jobs


## Triggers

- [WARNING] => Export XML Veeam Error

### Discovery Veeam Jobs
- [HIGH] => Job has FAILED
- [AVERAGE] => Job has completed with warning
- [HIGH] => Job is still running (8 hours)
- [WARNING] => Backup Veeam data recovery problem

### Discovery Veeam Tape Jobs
- [HIGH] => Job has FAILED
- [AVERAGE] => Job has completed with warning
- [HIGH] => Job is still running (8 hours)
- [INFORMATION] => No data recovery for 24 hours

### Discovery Veeam BackupSync Jobs
- [HIGH] => Job has FAILED
- [AVERAGE] => Job has completed with warning
- [INFORMATION] => No data recovery for 24 hours

### Discovery Veeam Jobs Endpoint Agent
- [HIGH] => Job has FAILED
- [AVERAGE] => Job has completed with warning
- [HIGH] => Job is still running (8 hours)
- [INFORMATION] => No data recovery for 24 hours

### Discovery Veeam Replication Jobs
- [HIGH] => Job has FAILED
- [AVERAGE] => Job has completed with warning
- [INFORMATION] => No data recovery for 24 hours

### Discovery Veeam Repository
- [HIGH] => Less than 2Gb remaining on the repository

### Discovery Veeam Services
- [AVERAGE] => Veeam Service is down for each services


## Setup

1. Install the Zabbix agent on your host
2. Copy `zabbix_vbr_job.ps1` in the directory : `C:\Program Files\Zabbix Agent\scripts\` (create folder if not exist)
3. Add the following line to your Zabbix agent configuration file:
    ```
    EnableRemoteCommands=1
    UnsafeUserParameters=1
    ServerActive="IP or DNS Zabbix Server"
    Alias=service.discovery.veeam:service.discovery
    Timeout=(to adjust if items arrive in timeout)
    UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" "$1" "$2" "$3"
    ```
4. In Zabbix : Administration, General, Regular Expression:

    1. Add a new regular expression:
        + Name: `Veeam`
        + Expression Type: `Result is TRUE`
        + Expression: `Veeam.*`
    2.  Modify the "Windows Service Startup States for Discovery regex by adding a new expression:
        + Expression Type: `Result is FALSE`
        + Expression: `Veeam.*`

5. Import TemplateVEEAM-BACKUPtrapper.xml file into Zabbix.
6. Purge and clean Template OS Windows if is linked to the host (you can relink it after).
7. Associate "Template VEEAM - Backup and Replication" to the host.
8. Wait about 1h for discovery, XML file to be generated and first informations retrieves.

! If you use old version of this script (< v3) please Purge and clean "Template VEEAM-BACKUP trapper".

With a large or very large backup tasks history, the XML size can be more than 500 MB (so script finish in timeout) you can reduce this with this link :
https://www.veeam.com/kb1995
Use first : "Changing Session history retention" and if this is not enough, "Clear old job sessions".
