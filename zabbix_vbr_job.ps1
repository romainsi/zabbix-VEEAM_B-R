# Script: zabbix_vbr_job
# Author: Romainsi
# Description: Query Veeam job information
# This script is intended for use with Zabbix > 3.X
#
# USAGE:
#
#   as a script:    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" <ITEM_TO_QUERY> <JOBID>or<JOBNAME> <TRIGGERLEVEL>
#   as an item:     vbr[<ITEM_TO_QUERY>,<JOBID>or<JOBNAME>,<TRIGGERLEVEL>]
#
#
# ITEMS availables (Switch) :
# - DiscoveryBackupJobs
# - DiscoveryBackupSyncJobs
# - DiscoveryTapeJobs
# - DiscoveryEndpointJobs
# - DiscoveryReplicaJobs
# - DiscoveryRepo
# - DiscoveryBackupVmsByJobs
# - ExportXml
# - JobsCount
# - RunningJob
#
# Examples:
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" DiscoveryBackupJobs
# Return a Json Value with all Backups Name and JobID 
# Xml must be present in 'C:\Program Files\Zabbix Agent\scripts\TempXmlVeeam\*.xml', if not, you can launch manually : powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" ExportXml
#
# ITEMS availables (Switch) with JOBID Mandatory :
# - ResultBackup
# - ResultBackupSync
# - ResultTape
# - ResultEndpoint
# - ResultReplica
# - VmResultBackup
# - VmResultBackupSync
# - RepoCapacity
# - RepoFree
# - RunStatus
# - VmCount
# - VmCountResultBackup
# - VmCountResultBackupSync
# - Type
# - NextRunTime
#
# Examples:
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" ResultBackup "2fd246be-b32a-4c65-be3e-1ca5546ef225"
# Return the value of result (see the veeam-replace function for correspondence)
# or
# powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" VmCountResultBackup "BackupJob1" "Warning"
#
# Xml must be present in 'C:\Program Files\Zabbix Agent\scripts\TempXmlVeeam\*.xml', if not, you can launch manually : powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" ExportXml
#
#
#
# Add to Zabbix Agent
#   UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" "$1" "$2" "$3"


# If you change the pathxml modify also the item Result Export XML with the new location in zabbix template
$pathxml = 'C:\Program Files\Zabbix Agent\scripts\TempXmlVeeam'

# ONLY FOR VMs RESULTS :
# Ajust the start date for retrieve backup vms history
#
# Example : If you have a backup job that runs every 30 days this value must be at least '-31' days
# but if you have only daily job ajust to '-2' days.
# ! This request can consume a lot of cpu resources, adjust carefully !
# 
$days = '-31'

# Function convert return Json String to html
function convertto-encoding
{
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline = $true)]
		[string]$item,
		[Parameter(Mandatory = $true)]
		[string]$switch
	)
	if ($switch -like "in")
	{
		$item.replace('&', '&amp;').replace('à', '&agrave;').replace('â', '&acirc;').replace('è', '&egrave;').replace('é', '&eacute;').replace('ê', '&ecirc;')
	}
	if ($switch -like "out")
	{
		$item.replace('&amp;', '&').replace('&agrave;', 'à').replace('&acirc;', 'â').replace('&egrave;', 'è').replace('&eacute;', 'é').replace('&ecirc;', 'ê')
	}
}

$ITEM = [string]$args[0]
$ID = [string]$args[1] | convertto-encoding -switch out
$ID0 = [string]$args[2] | convertto-encoding -switch out

# Function Multiprocess ExportXml
function ExportXml
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]$switch,
		[Parameter(Mandatory = $true)]
		[string]$name,
		[Parameter(Mandatory = $false)]
		[string]$command,
		[Parameter(Mandatory = $false)]
		[string]$type
	)
	
	PROCESS
	{
		$path = "$pathxml\$name" + "temp.xml"
		$newpath = "$pathxml\$name" + ".xml"
			
			if ($switch -like "normal")
			{
				Start-Job -Name $name -ScriptBlock {
					Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
					$connectVeeam = Connect-VBRServer
					Invoke-Expression $args[0] | Export-Clixml $args[1]
					$disconnectVeeam = Disconnect-VBRServer
					Copy-Item -Path $args[1] -Destination $args[3]
					Remove-Item $args[1]
				} -ArgumentList "$command", "$path", "$name", "$newpath"
			}
			
			
			if ($switch -like "byvm")
			{
				$commandnew = "$command " + "| ?{ `$_.JobType -eq `"$type`" }"
				Start-Job -Name $name -ScriptBlock {
					Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
					$connectVeeam = Connect-VBRServer
					$BackupVmByJob = Invoke-Expression $args[0] | %{
						$JobName = $_.Name
						$_ | Get-VBRJobObject | ?{ $_.Object.Type -eq "VM" } | Select @{ L = "Job"; E = { $JobName } }, Name | Sort -Property Job, Name
					}
					$BackupVmByJob | Export-Clixml $args[1]
					$disconnectVeeam = Disconnect-VBRServer
					Copy-Item -Path $args[1] -Destination $args[3]
					Remove-Item $args[1]
				} -ArgumentList "$commandnew", "$path", "$name", "$newpath"
			}
			
			if ($switch -like "bytaskswithretry")
			{
				Start-Job -Name $name -ScriptBlock {
					Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
					$connectVeeam = Connect-VBRServer
					$StartDate = (Get-Date).adddays($args[4])
					$BackupSessions = Get-VBRBackupSession | where { $_.CreationTime -ge $StartDate } | Sort JobName, CreationTime
					$Result = & {
						ForEach ($BackupSession in ($BackupSessions | ?{ $_.IsRetryMode -eq $false }))
						{
							[System.Collections.ArrayList]$TaskSessions = @($BackupSession | Get-VBRTaskSession)
							If ($BackupSession.Result -eq "Failed")
							{
								$RetrySessions = $BackupSessions | ?{ ($_.IsRetryMode -eq $true) -and ($_.OriginalSessionId -eq $BackupSession.Id) }
								ForEach ($RetrySession in $RetrySessions)
								{
									[System.Collections.ArrayList]$RetryTaskSessions = @($RetrySession | Get-VBRTaskSession)
									ForEach ($RetryTaskSession in $RetryTaskSessions)
									{
										$PriorTaskSession = $TaskSessions | ?{ $_.Name -eq $RetryTaskSession.Name }
										If ($PriorTaskSession) { $TaskSessions.Remove($PriorTaskSession) }
										$TaskSessions.Add($RetryTaskSession) | Out-Null
									}
								}
							}
							$TaskSessions | Select @{ N = "JobName"; E = { $BackupSession.JobName } }, @{ N = "JobId"; E = { $BackupSession.JobId } }, @{ N = "SessionName"; E = { $_.JobSess.Name } }, @{ N = "JobResult"; E = { $_.JobSess.Result } }, @{ N = "JobStart"; E = { $_.JobSess.CreationTime } }, @{ N = "JobEnd"; E = { $_.JobSess.EndTime } }, @{ N = "Date"; E = { $_.JobSess.CreationTime.ToString("yyyy-MM-dd") } }, name, status
						}
					}
					$Result | Export-Clixml $args[1]
					$disconnectVeeam = Disconnect-VBRServer
					Copy-Item -Path $args[1] -Destination $args[3]
					Remove-Item $args[1]
				} -ArgumentList "$commandnew", "$path", "$name", "$newpath", "$days"
			}
			
			# Purge completed Job 
			$purge = get-job | ? { $_.State -eq 'Completed' } | Remove-Job
	}
}



# Converts an object to a JSON-formatted string
$GlobalConstant = @{
	'ZabbixJsonHost' = 'host'
	'ZabbixJsonKey' = 'key'
	'ZabbixJsonValue' = 'value'
	'ZabbixJsonTimestamp' = 'clock'
	'ZabbixJsonRequest' = 'request'
	'ZabbixJsonData' = 'data'
	'ZabbixJsonSenderData' = 'sender data'
	'ZabbixJsonDiscoveryKey' = '{{#{0}}}'
}

$GlobalConstant += @{
	'ZabbixMappingProperty' = 'Property'
	'ZabbixMappingKey' = 'Key'
	'ZabbixMappingKeyProperty' = 'KeyProperty'
}

foreach ($Constant in $GlobalConstant.GetEnumerator())
{
	Set-Variable -Scope Global -Option ReadOnly -Name $Constant.Key -Value $Constant.Value -Force
}

$ExportFunction = ('ConvertTo-ZabbixDiscoveryJson')

if ($Host.Version.Major -le 2)
{
	$ExportFunction += ('ConvertTo-Json', 'ConvertFrom-Json')
}

function ConvertTo-ZabbixDiscoveryJson
{
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipeline = $true)]
		$InputObject,
		[Parameter(Position = 0)]
		[String[]]$Property = "#JOBID"
	)
	
	begin
	{
		$Result = @()
	}
	
	process
	{
		if ($InputObject)
		{
			$Result += foreach ($Obj in $InputObject)
			{
				if ($Obj)
				{
					$Element = @{ }
					foreach ($P in $Property)
					{
						$Key = $ZabbixJsonDiscoveryKey -f $P.ToUpper()
						$Element[$Key] = [String]$Obj.$P
					}
					$Element
				}
			}
		}
	}
	end
	{
		$Result = @{ $ZabbixJsonData = $Result }
		return $Result | ConvertTo-Json -Compress | % { [System.Text.RegularExpressions.Regex]::Unescape($_) }
	}
}

# Function import xml with check & delay time if copy process running
function ImportXml
{
	[CmdletBinding()]
	Param ([Parameter(ValueFromPipeline = $true)]
		$item)
	
	$path = "$pathxml\$item" + ".xml"
	$result = Test-Path -Path $path
	if ($result -like 'False')
	{
		start-sleep -Seconds 2
	}
	
	$err = $null
	try
	{
		$xmlquery = Import-Clixml "$path"
	}
	catch
	{
		$err = $_
	}
	If ($err -ne $null)
	{
		Start-Sleep -Seconds 2
		$xmlquery = Import-Clixml "$path"
	}
	$xmlquery
}

# Replace Function for Veeam Correlation
function veeam-replace
{
	[CmdletBinding()]
	Param ([Parameter(ValueFromPipeline = $true)]
		$item)
	$item.replace('Failed', '0').replace('Warning', '1').replace('Success', '2').replace('None', '2').replace('idle', '3').replace('InProgress', '5').replace('Pending', '6')
}

# Function sort VMs by jobs on last backup (with unique name if retry)
function veeam-backuptask-unique
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		$jobtype,
		[Parameter(Mandatory = $true)]
		$ID
	)
	$xml1 = ImportXml -item backuptaskswithretry | Where { $_.$jobtype -like "$ID" }
	$unique = $xml1.Name | sort-object -Unique
	
	$output = & {
		foreach ($object in $unique)
		{
			$query = $xml1 | where { $_.Name -like $object } | Sort JobStart -Descending | Select -First 1
			foreach ($object1 in $query)
			{
				$query | Select @{ N = "JobName"; E = { $object1.JobName } }, @{ N = "JobId"; E = { $object1.JobId } }, @{ N = "SessionName"; E = { $object1.SessionName } }, @{ N = "JobResult"; E = { $object1.JobResult } }, @{ N = "JobStart"; E = { $object1.JobStart } }, @{ N = "JobEnd"; E = { $object1.JobEnd } }, @{ N = "Date"; E = { $object1.Date.ToString("yyyy-MM-dd") } }, @{ N = "Name"; E = { $object1.Name } }, @{ N = "Status"; E = { $object1.Status } }
			}
		}
	}
	$output
}

# Load Veeam Module
Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue

switch ($ITEM)
{
	"DiscoveryBackupJobs" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and $_.JobType -like "Backup" } | Select @{ N = "JOBID"; E = { $_.ID | convertto-encoding -switch in } }, @{ N = "JOBNAME"; E = { $_.NAME | convertto-encoding -switch in } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBNAME, JOBID
	}
	
	"DiscoveryBackupSyncJobs" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and $_.JobType -like "BackupSync" } | Select @{ N = "JOBBSID"; E = { $_.ID | convertto-encoding -switch in } }, @{ N = "JOBBSNAME"; E = { $_.NAME | convertto-encoding -switch in } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBBSNAME, JOBBSID
	}
	
	"DiscoveryTapeJobs" {
		$xml1 = ImportXml -item backuptape
		$query = $xml1 | Select @{ N = "JOBTAPEID"; E = { $_.ID | convertto-encoding -switch in } }, @{ N = "JOBTAPENAME"; E = { $_.NAME | convertto-encoding -switch in } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBTAPENAME, JOBTAPEID
	}
	
	"DiscoveryEndpointJobs" {
		$xml1 = ImportXml -item backupendpoint
		$query = $xml1 | Select-Object Id, Name | Select @{ N = "JOBENDPOINTID"; E = { $_.ID | convertto-encoding -switch in } }, @{ N = "JOBENDPOINTNAME"; E = { $_.NAME | convertto-encoding -switch in } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBENDPOINTNAME, JOBENDPOINTID
	}
	
	"DiscoveryReplicaJobs" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and $_.JobType -like "Replica" } | Select @{ N = "JOBREPLICAID"; E = { $_.ID | convertto-encoding -switch in } }, @{ N = "JOBREPLICANAME"; E = { $_.NAME | convertto-encoding -switch in } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBREPLICANAME, JOBREPLICAID
	}
	
	"DiscoveryRepo" {
		$query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Select @{ N = "REPONAME"; E = { $_.NAME | convertto-encoding -switch in } }
		$query | ConvertTo-ZabbixDiscoveryJson REPONAME
	}
	
	"DiscoveryBackupVmsByJobs" {
		if ($ID -like "BackupSync")
		{
			ImportXml -item backupsyncvmbyjob | Select @{ N = "JOBNAME"; E = { $_.Job | convertto-encoding -switch in } }, @{ N = "JOBVMNAME"; E = { $_.NAME | convertto-encoding -switch in } } | ConvertTo-ZabbixDiscoveryJson JOBVMNAME, JOBNAME
		}
		else
		{
			ImportXml -item backupvmbyjob | Select @{ N = "JOBNAME"; E = { $_.Job | convertto-encoding -switch in } }, @{ N = "JOBVMNAME"; E = { $_.NAME | convertto-encoding -switch in } } | ConvertTo-ZabbixDiscoveryJson JOBVMNAME, JOBNAME
		}
	}
	
	"ExportXml" {
		
		$test = Test-Path -Path "$pathxml"
		if ($test -like "False")
		{
			$query = New-Item -ItemType Directory -Force -Path "$pathxml"
		}
		if ((Get-WMIObject -Class Win32_Process -Filter "Name='PowerShell.EXE'" | Where { $_.CommandLine -Like "*exportxml*" } | measure).count -eq 1)
		{
		$job = ExportXml -command Get-VBRBackupSession -name backupsession -switch normal
		$job0 = ExportXml -command Get-VBRJob -name backupjob -switch normal
		$job1 = ExportXml -command Get-VBRBackup -name backupbackup -switch normal
		$job2 = ExportXml -command Get-VBRTapeJob -name backuptape -switch normal
		$job3 = ExportXml -command Get-VBREPJob -name backupendpoint -switch normal
		$job4 = ExportXml -command Get-VBRJob -name backupvmbyjob -switch byvm -type Backup
		$job5 = ExportXml -command Get-VBRJob -name backupsyncvmbyjob -switch byvm -type BackupSync
		$job6 = ExportXml -name backuptaskswithretry -switch bytaskswithretry
		Get-Job | Wait-Job
		}
	}
	
	"ResultBackup"  {
		$xml = ImportXml -item backuptaskswithretry
		$query1 = $xml | Where { $_.jobId -like "$ID" } | Sort JobStart -Descending | Select -First 1
		$query2 = $query1.JobResult
		if (!$query2.value)
		{
			write-host "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $query2.value
			$query4 = "$query3" | veeam-replace
			write-host "$query4"
		}
	}
	
	"ResultBackupSync"  {
		$xml = ImportXml -item backupjob | Where-Object { $_.Id -like $ID }
		$result = veeam-backuptask-unique -ID $xml.name -jobtype jobname
		$query = $result | Measure-Object
		$count = $query.count
		$success = ($Result.Status | Where { $_.Value -like "*Success*" }).count
		$warning = ($Result.Status | Where { $_.Value -like "*Warning*" }).count
		$failed = ($Result.Status | Where { $_.Value -like "*Failed*" }).count
		$pending = ($Result.Status | Where { $_.Value -like "*Pending*" }).count
		$InProgress = ($Result.Status | Where { $_.Value -like "*InProgress*" }).count
		if ($count -eq $success) { write-host "2" }
		else
		{
			if ($failed -gt 0) { write-host "0" }
			else
			{
				if ($warning -gt 0) { write-host "1" }
				else
				{
					
					if ($InProgress -gt 0) { write-host "5" }
					else
					{
						if ($pending -gt 0)
						{
							$xml2 = ImportXml -item backupsession
							$query1 = $xml2 | Where { $_.jobId -like "*$ID*" } | Sort creationtime -Descending | Select -First 2 | Select -Index 1
							if (!$query1.Result.Value) { write-host "4" }
							else
							{
								$query2 = $query1.Result.Value | veeam-replace
								write-host "$query2"
							}
						}
					}
				}
			}
		}
	}
	
	"ResultTape"  {
		if (!$ID)
		{
			Write-Host "-- ERROR --   Switch 'ResultTape' need ID of the Veeam task"
			Write-Host ""
			Write-Host "Example : ./zabbix_vbr_job.ps1 ResultTape 'c333cedf-db4a-44ed-8623-17633300d7fe'"
		}
		else
		{
			$xml1 = ImportXml -item backuptape
			$query = $xml1 | Where-Object { $_.Id -like "*$ID*" } | Sort creationtime -Descending | Select -First 1
			$query2 = $query.LastResult.Value
			if (!$query2)
			{
				# Retrieve version veeam
				$corePath = Get-ItemProperty -Path "HKLM:\Software\Veeam\Veeam Backup and Replication\" -Name "CorePath"
				$depDLLPath = Join-Path -Path $corePath.CorePath -ChildPath "Packages\VeeamDeploymentDll.dll" -Resolve
				$file = Get-Item -Path $depDLLPath
				$version = $file.VersionInfo.ProductVersion
				if ($version -lt "8")
				{
					$query = Get-VBRTapeJob | Where-Object { $_.Id -like "*$ID*" }
					$query1 = $query.GetLastResult()
					$query2 = "$query1" | veeam-replace
					Write-Host "$query2"
				}
				else
				{
					write-host "4"
				}
			}
			else
			{
				if (($query.LastState.Value -like "WaitingTape") -and ($query2 -like "None"))
				{
					write-host "1"
				}
				else
				{
					$query3 = $query2 | veeam-replace
					write-host "$query3"
				}
			}
		}
	}
	
	"ResultEndpoint"  {
		if (!$ID)
		{
			Write-Host "-- ERROR --   Switch 'ResultEndpoint' need ID of the Veeam Endpoint Task"
			Write-Host ""
			Write-Host "Example : ./zabbix_vbr_job.ps1 ResultEndpoint 'c333cedf-db4a-44ed-8623-17633300d7fe'"
		}
		else
		{
			$xml3 = ImportXml -item backupendpoint
			$query = $xml3 | Where-Object { $_.Id -like "*$ID*" }
			$query1 = $query | Where { $_.Id -eq $query.Id } | Sort creationtime -Descending | Select -First 1
			$query2 = $query1.LastResult
			# If empty Send 4 : First Backup (or no history)
			if (!$query2)
			{
				write-host "4"
			}
			else
			{
				$query4 = $query2.value
				$query3 = $query4 | veeam-replace
				write-host "$query3"
			}
		}
	}
	
	"ResultReplica"  {
		$xml = ImportXml -item backupsession
		$query1 = $xml | Where { $_.jobId -like "$ID" } | Sort creationtime -Descending | Select -First 1
		$query2 = $query1.Result
		if (!$query2.value)
		{
			write-host "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $query2.value
			$query4 = "$query3" | veeam-replace
			write-host "$query4"
		}
	}
	
	"VmResultBackup" {
		$query = veeam-backuptask-unique -ID $ID0 -jobtype jobname
		$result = $query | where { $_.Name -like "$ID" }
		if (!$result)
		{
			write-host "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $Result.Status.Value
			$query4 = $query3 | veeam-replace
			[string]$query4
		}
	}
	
	"VmResultBackupSync" {
		$query = veeam-backuptask-unique -ID $ID0 -jobtype jobname
		$result = $query | where { $_.Name -like "$ID" }
		if (!$result)
		{
			write-host "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $Result.Status.Value
			$query4 = $query3 | veeam-replace
			[string]$query4
		}
	}
	"RepoCapacity" {
		$query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object { $_.Name -eq "$ID" }
		$query | Select-Object -ExpandProperty Capacity
	}
	"RepoFree" {
		$query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object { $_.Name -eq "$ID" }
		$query | Select-Object -ExpandProperty FreeSpace
	}
	"RunStatus" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		if ($query.IsRunning) { return "1" }
		else { return "0" }
	}
	"IncludedSize"{
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		[string]$query.Info.IncludedSize
	}
	"ExcludedSize"{
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		[string]$query.Info.ExcludedSize
	}
	"JobsCount" {
		$xml1 = ImportXml -item backupjob | Measure-Object
		[string]$xml1.Count
	}
	"VmCount" {
		$result = veeam-backuptask-unique -ID $ID -jobtype jobname | Measure-Object
		[string]$result.count
	}
	"VmCountResultBackup" {
		$query = veeam-backuptask-unique -ID $ID -jobtype jobname
		$result = $query | where { $_.Status -like $ID0 } | Measure-Object
		[string]$result.count
	}
	"VmCountResultBackupSync" {
		$query = veeam-backuptask-unique -ID $ID -jobtype jobname
		$result = $query | where { $_.Status -like $ID0 } | Measure-Object
		[string]$result.count
	}
	"Type" {
		$xml1 = ImportXml -item backupbackup
        if (!$xml1) { $xml1 = ImportXml -item backupsession }
		$query = $xml1 | Where-Object { $_.JobId -like "$ID" } | Select -First 1
		[string]$query.JobType
	}
	"NextRunTime" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | where { $_.Id -like "*$ID*" }
		$query1 = $query.ScheduleOptions
		$result = $query1.NextRun
        if (!$result) { Write-Host "0000000001" }
        else {
		$result1 = $nextdate, $nexttime = $result.Split(" ")
		$newdate = [datetime]("$($nextdate -replace "(\d{2})-(\d{2})", "`$2-`$1") $nexttime")
		$date = get-date -date "01/01/1970"
		$result2 = (New-TimeSpan -Start $date -end $newdate).TotalSeconds
		[string]$result2
        }
	}
	"RunningJob" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | where { $_.isCompleted -eq $false } | Measure
		if ($query)
		{
			[string]$query.Count
		}
		else
		{
			return "0"
		}
	}
	default
	{
		Write-Host "-- ERROR -- : Need an option !"
	}
}
