**================ VEEAM-Backup-Recovery-jobs ================**

This template use the VEEAM Backup & Replication PowerShell Cmdlets to discover and manage VEEAM Backup jobs, Veeam BackupSync, Veeam Tape Job and All Repositories 

Work with Veeam backup & replication V7 to V9.5<br />
Work with Zabbix 3.X

Explanation of how it works :<br />
The "Result Export Xml Veeam Xml" element sends a powerhell command to the host to create an xml of the result of the Get-VBRBackupSession command.<br />
Then, each request imports the xml to retrieve the information.<br />
Why? Because the execution of this command can take between 30 seconds and 3 minutes (depending on the history and the number of tasks) and I end up with several scripts running for a certain time and the execution is in timeout.

**-------- Items --------**

  - Number of running jobs<br />
  - Result Export Xml Veeam


**-------- Discovery --------**

**1. Veeam Jobs :** 
  - Execution status for each jobs
  - Type for each jobs
  - Number of virtual machine in each jobs
  - Size included in each jobs
  - Size excluded in each jobs
  - Result of each jobs (ZabbixTrapper)
  - Result task ZabbixSender of each jobs

**2. Veeam Tape Jobs :**
  - Execution status for each jobs
  - Result of each jobs (ZabbixTrapper)
  - Result task ZabbixSender of each jobs

**3. Veeam Repository :**
Remaining space in repository for each repo
Total space in repository for each repo
<br />
<br />

**-------- Triggers --------**

-------- Discovery Veeam Jobs --------<br />
[HIGH] => Job has FAILED <br />
[AVERAGE] => Job has completed with warning  
[HIGH] => Job is still running (8 hours)

-------- Discovery Veeam Tape Jobs --------<br />
[HIGH] => Job has FAILED <br />
[AVERAGE] => Job has completed with warning<br />
[HIGH] => Job is still running (8 hours)<br />
[INFORMATION] => No data recovery for 24 hours<br />

-------- Discovery Veeam Repository --------<br />
[HIGH] => Less than 2Gb remaining on the repository
<br />
<br />

**-------- Setup --------**

1. Install the Zabbix agent on your host
2. Copy zabbix_vbr_job.ps1 in the directory : "C:\Program Files\Zabbix Agent\scripts\" (create folder if not exist)
3. Add the following line to your Zabbix agent configuration file.<br />
EnableRemoteCommands=1 <br />
UnsafeUserParameters=1 <br />
UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" "$1" "$2"
4. Import TemplateVEEAM-BACKUPtrapper.xml file into Zabbix. 
5. Associate "Template VEEAM-BACKUP trapper" to the host.
