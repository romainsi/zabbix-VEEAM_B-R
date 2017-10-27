================ VEEAM-Backup-Recovery-jobs ================

This template use the VEEAM Backup & Replication PowerShell Cmdlets to discover and manage VEEAM Backup jobs, Veeam BackupSync, Veeam Tape Job and All Repositories 

Work with Veeam backup & replication V7 to V9.5
Work with Zabbix 3.X

Explanation of how it works :
The item "Result Export Xml Veeam" send a powershell command to the host to create an xml of the result of the Get-VBRBackupSession command.
Then each query imports the xml to retrieve the information.
Why ? Because the execution of this command can take between 30seconds and 3 minutes (depending on the history and number of tasks) and I end up with several scripts running for a certain time and this chain. 

**-------- Items --------**

Number of running jobs
Result Export Xml Veeam


**-------- Discovery --------**

1. Veeam Jobs: 
  - Execution status for each jobs
  - Type for each jobs
  - Number of virtual machine in each jobs
  - Size included in each jobs
  - Size excluded in each jobs
  -   - Result of each jobs (ZabbixTrapper)
  - Result task ZabbixSender of each jobs

2. Veeam Tape Jobs
  - Execution status for each jobs
  - Result of each jobs (ZabbixTrapper)
  - Result task ZabbixSender of each jobs

3. Veeam Repository
Remaining space in repository for each repo
Total space in repository for each repo

**-------- Triggers --------**

-------- Discovery Veeam Jobs --------
[HIGH] => Job has FAILED 
[AVERAGE] => Job has completed with warning  
[HIGH] => Job is still running (8 hours)

-------- Discovery Veeam Tape Jobs --------
[HIGH] => Job has FAILED 
[AVERAGE] => Job has completed with warning  
[HIGH] => Job is still running (8 hours)
[INFORMATION] => No data recovery for 24 hours

-------- Discovery Veeam Repository --------
[HIGH] => Less than 2Gb remaining on the repository


**-------- Setup --------**

1. Install the Zabbix agent on your host
2. Copy zabbix_vbr_job.ps1 in the directory : "C:\Program Files\Zabbix Agent\scripts\" (create folder if not exist)
3. Add the following line to your Zabbix agent configuration file.
EnableRemoteCommands=1 
UnsafeUserParameters=1 
UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" "$1" "$2"
4. Import TemplateVEEAM-BACKUPtrapper.xml file into Zabbix. 
5. Associate "Template VEEAM-BACKUP trapper" to the host.
