**================ VEEAM-Backup-Recovery-jobs ================**

This template use the VEEAM Backup & Replication PowerShell Cmdlets to discover and manage VEEAM Backup jobs, Veeam BackupSync, Veeam Tape Job, Veeam Endpoint Backup Jobs, All Repositories and Veeam Services.

Work with Veeam backup & replication V7 to V9.5<br />
Work with Zabbix 3.X & 4.0<br /> 
French & English translation for the Template

Explanation of how it works :<br />
The "Result Export Xml Veeam" item sends a powerhell command (with nowait option) to the host to create an xml file of the result of the Get-VBRBbackupSession,Get-VBRJob, Get-VRBBackup and Get-VBREPJob commands that is stored under C:\Program Files\Zabbix Agent\scripts\TempXmlVeeam\\*.xml (variable $pathxml)<br />
Then, each request imports the xml to retrieve the information.<br />
Why? Because the execution of this command can take between 30 seconds and more than 3 minutes (depending on the history and the number of tasks) and I end up with several scripts running for a certain time and the execution is in timeout.
<br /><br />

**-------- Items --------**

  - Number of tasks jobs<br />
  - Number of running jobs<br />
  - Result Export Xml Veeam<br />

**-------- Discovery Jobs --------**

**1. Veeam Jobs :** <br />
  - Result of each jobs (ZabbixTrapper)<br />
  - Result task ZabbixSender of each jobs<br />
  - Execution status for each jobs<br />
  - Number of VMs Failed in each jobs<br />
  - Number of VMs Warning in each jobs<br />
  - Type for each jobs<br />
  - Number of VMs in each jobs<br />
  - Size included in each jobs (disabled by default)<br />
  - Size excluded in each jobs (disabled by default)<br />
  - Next run time of each jobs<br />

**2. Veeam Tape Jobs :**<br />
  - Result of each jobs (ZabbixTrapper)<br />
  - Result task ZabbixSender of each jobs<br />
  - Execution status for each jobs<br />

**3. Veeam BackupSync Jobs :**<br />
  - Result of each jobs (ZabbixTrapper)<br />
  - Result task ZabbixSender of each jobs<br />
  - Execution status for each jobs<br />
  - Number of VMs Failed in each jobs<br />
  - Number of VMs Warning in each jobs<br />
  - Type for each jobs<br />
  - Number of VMs in each jobs<br />
  - Size included in each jobs (disabled by default)<br />
  - Size excluded in each jobs (disabled by default)<br />

**4. Veeam Jobs Endpoint Backup:**<br />
  - Result of each jobs (ZabbixTrapper)<br />
  - Result task ZabbixSender of each jobs<br />
  - Execution status for each jobs<br />
  - Next run time of each jobs<br />

**5. Veeam Repository :**<br />
  - Remaining space in repository for each repo<br />
  - Total space in repository for each repo<br /><br />

**-------- Discovery Jobs By VMs --------**

**1. VEEAM Backup By VMs :**
  - Result of each VMs in each Jobs (ZabbixTrapper)
  
**2. VEEAM BackupSync By VMs :**
  - Result of each VMs in each Jobs (ZabbixTrapper)
<br />

**-------- Triggers --------**
<br><br />
[WARNING] => Export XML Veeam Error<br />

-------- Discovery Veeam Jobs --------<br />
[HIGH] => Job has FAILED <br />
[AVERAGE] => Job has completed with warning  
[HIGH] => Job is still running (8 hours)<br />
[WARNING] => Backup Veeam data recovery problem

-------- Discovery Veeam Tape Jobs --------<br />
[HIGH] => Job has FAILED <br />
[AVERAGE] => Job has completed with warning<br />
[HIGH] => Job is still running (8 hours)<br />
[INFORMATION] => No data recovery for 24 hours<br />

-------- Discovery Veeam BackupSync Jobs --------<br />
[HIGH] => Job has FAILED <br />
[AVERAGE] => Job has completed with warning<br />
[INFORMATION] => No data recovery for 24 hours<br />

-------- Discovery Veeam Jobs Endpoint Agent --------<br />
[HIGH] => Job has FAILED <br />
[AVERAGE] => Job has completed with warning<br />
[HIGH] => Job is still running (8 hours)<br />
[INFORMATION] => No data recovery for 24 hours<br />

-------- Discovery Veeam Repository --------<br />
[HIGH] => Less than 2Gb remaining on the repository

-------- Discovery Veeam Services --------<br />
[AVERAGE] => Veeam Service is down for each services<br />
<br />

**-------- Setup --------**

1. Install the Zabbix agent on your host
2. Copy zabbix_vbr_job.ps1 in the directory : "C:\Program Files\Zabbix Agent\scripts\" (create folder if not exist)
3. Add the following line to your Zabbix agent configuration file.<br />
EnableRemoteCommands=1 <br />
UnsafeUserParameters=1 <br />
ServerActive="IP or DNS Zabbix Server"<br />
Alias=service.discovery.veeam:service.discovery<br />
UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" "$1" "$2" "$3"
4. In Zabbix : Administration, General, Regular Expression : Add a new regular expression :<br /> 
Name : "Veeam"    ;     Expression type : "**TRUE**"     ;     	Expression : "Veeam.\*"<br />
And modify regular expression "Windows service startup states for discovery" : Add : <br />
Name : "Veeam" ; Expression type : "**FALSE**" ; Expression : "Veeam.\*"<br />
5. Import TemplateVEEAM-BACKUPtrapper.xml file into Zabbix. 
6. Purge and clean Template OS Windows if is linked to the host (you can relink it after).
7. Associate "Template VEEAM-BACKUP trapper" to the host.
8. Wait about 1h for discovery, XML file to be generated and first informations retrieves.
<br />
With a large or very large backup tasks history, the XML size can be more than 500 MB (so script finish in timeout) you can reduce this with this link : <br /> 
https://www.veeam.com/kb1995 <br />
Use first : "Changing Session history retention" and if this is not enough, "Clear old job sessions".
