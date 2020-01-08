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
# Return the value of result (see the VeeamStatusReplace function for correspondence)
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

$ITEM = [string]$args[0]
$ID = [string]$args[1]
$ID0 = [string]$args[2]

# Load Veeam Module
Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue

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
		[string]$type,
		[Parameter(Mandatory = $false)]
		[string]$options
	)
	
	PROCESS
	{
		$path = "$pathxml\$name" + "temp.xml"
		$newpath = "$pathxml\$name" + ".xml"
		
		if ($switch -like "normal")
		{
			[System.DateTime]$Date = (Get-Date).adddays($days) #.ToString('dd/MM/yyyy HH:mm:ss')
			if ($options -like "true")
			{
				$commandnew = "$command " + "| Where-Object { `$_.CreationTime -ge `"$Date`" }"
				$command = $commandnew
			}
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
			$commandnew = "$command " + "| Where-Object { `$_.JobType -eq `"$type`" }"
			Start-Job -Name $name -ScriptBlock {
				Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
				$connectVeeam = Connect-VBRServer
				$BackupVmByJob = Invoke-Expression $args[0] | ForEach-Object {
					$JobName = $_.Name
					$_ | Get-VBRJobObject | Where-Object { $_.Object.Type -eq "VM" } | Select-Object @{ L = "Job"; E = { $JobName } }, Name | Sort-Object -Property Job, Name
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
				$BackupSessions = [Veeam.Backup.Core.CBackupSession]::GetAll() | Where-Object { $_.CreationTime -ge $StartDate } | Sort-Object JobName, CreationTime
				$Result = & {
					ForEach ($BackupSession in ($BackupSessions | Where-Object { $_.IsRetryMode -eq $false }))
					{
						[System.Collections.ArrayList]$TaskSessions = @($BackupSession | Get-VBRTaskSession)
						If ($BackupSession.Result -eq "Failed")
						{
							$RetrySessions = $BackupSessions | Where-Object { ($_.IsRetryMode -eq $true) -and ($_.OriginalSessionId -eq $BackupSession.Id) }
							ForEach ($RetrySession in $RetrySessions)
							{
								[System.Collections.ArrayList]$RetryTaskSessions = @($RetrySession | Get-VBRTaskSession)
								ForEach ($RetryTaskSession in $RetryTaskSessions)
								{
									$PriorTaskSession = $TaskSessions | Where-Object { $_.Name -eq $RetryTaskSession.Name }
									If ($PriorTaskSession) { $TaskSessions.Remove($PriorTaskSession) }
									$TaskSessions.Add($RetryTaskSession) | Out-Null
								}
							}
						}
						$TaskSessions | Select-Object @{ N = "JobName"; E = { $BackupSession.JobName } }, @{ N = "JobId"; E = { $BackupSession.JobId } }, @{ N = "SessionName"; E = { $_.JobSess.Name } }, @{ N = "JobResult"; E = { $_.JobSess.Result } }, @{ N = "JobStart"; E = { $_.JobSess.CreationTime } }, @{ N = "JobEnd"; E = { $_.JobSess.EndTime } }, @{ N = "Date"; E = { $_.JobSess.CreationTime.ToString("yyyy-MM-dd") } }, name, status
					}
				}
				$Result | Export-Clixml $args[1]
				$disconnectVeeam = Disconnect-VBRServer
				Copy-Item -Path $args[1] -Destination $args[3]
				Remove-Item $args[1]
			} -ArgumentList "$commandnew", "$path", "$name", "$newpath", "$days"
		}
		
		# Purge completed Job 
		$purge = get-job | Where-Object { $_.State -eq 'Completed' } | Remove-Job
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
		start-sleep -Milliseconds 10
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
		start-sleep -Milliseconds 50
		$xmlquery = Import-Clixml "$path"
	}
	$xmlquery
}

# Replace Function for Veeam Correlation
function VeeamStatusReplace
{
	[CmdletBinding()]
	Param ([Parameter(ValueFromPipeline = $true)]
		$item)
	$item.replace('Failed', '0').
	replace('Warning', '1').
	replace('Success', '2').
	replace('None', '2').
	replace('idle', '3').
	replace('InProgress', '5').
	replace('Pending', '6').
	replace('Pausing', '7').
	replace('Postprocessing', '8').
	replace('Resuming', '9').
	replace('Starting', '10').
	replace('Stopped', '11').
	replace('Stopping', '12').
	replace('WaitingRepository', '13').
	replace('WaitingTape', '13').
	replace('Working', '13')
}

# Function Sort-Object VMs by jobs on last backup (with unique name if retry)
function veeam-backuptask-unique
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		$jobtype,
		[Parameter(Mandatory = $true)]
		$ID
	)
	$xml1 = ImportXml -item backuptaskswithretry | Where-Object { $_.$jobtype -like "$ID" }
	$unique = $xml1.Name | Sort-Object -Unique
	
	$output = & {
		foreach ($object in $unique)
		{
			$query = $xml1 | Where-Object { $_.Name -like $object } | Sort-Object JobStart -Descending | Select-Object -First 1
			foreach ($object1 in $query)
			{
				$query | Select-Object @{ N = "JobName"; E = { $object1.JobName } }, @{ N = "JobId"; E = { $object1.JobId } }, @{ N = "SessionName"; E = { $object1.SessionName } }, @{ N = "JobResult"; E = { $object1.JobResult } }, @{ N = "JobStart"; E = { $object1.JobStart } }, @{ N = "JobEnd"; E = { $object1.JobEnd } }, @{ N = "Date"; E = { $object1.Date.ToString("yyyy-MM-dd") } }, @{ N = "Name"; E = { $object1.Name } }, @{ N = "Status"; E = { $object1.Status } }
			}
		}
	}
	$output
}

function ConvertTo-ZabbixDiscoveryJson
{
	[CmdletBinding()]
	param
	(
		[Parameter(ValueFromPipeline = $true)]
		$InputObject,
		[Parameter(Position = 0)]
		[String[]]$Property = @("ID", "NAME", "JOBTYPE")
	)
	
	begin
	{
		$out = @()
	}
	
	process
	{
		if ($InputObject)
		{
			$InputObject | ForEach-Object {
				if ($_)
				{
					$Element = @{ }
					foreach ($P in $Property)
					{
						$Element.Add("{#$($P.ToUpper())}", [String]$_.$P)
					}
					$out += $Element
				}
			}
		}
	}
	end
	{
		@{ 'data' = $out } | ConvertTo-Json -Compress
	}
}

switch ($ITEM)
{
	"DiscoveryBackupJobs" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and ($_.JobType -like "Backup" -or $_.JobType -like "EpAgentBackup") } | Select-Object @{ N = "JOBID"; E = { $_.ID } }, @{ N = "JOBNAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBNAME, JOBID
	}
	
	"DiscoveryBackupSyncJobs" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and $_.JobType -like "BackupSync" } | Select-Object @{ N = "JOBBSID"; E = { $_.ID } }, @{ N = "JOBBSNAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBBSNAME, JOBBSID
	}
	
	"DiscoveryTapeJobs" {
		$xml1 = ImportXml -item backuptape
		$query = $xml1 | Select-Object @{ N = "JOBTAPEID"; E = { $_.ID } }, @{ N = "JOBTAPENAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBTAPENAME, JOBTAPEID
	}
	
	"DiscoveryEndpointJobs" {
		$xml1 = ImportXml -item backupendpoint
		$query = $xml1 | Select-Object Id, Name | Select-Object @{ N = "JOBENDPOINTID"; E = { $_.ID } }, @{ N = "JOBENDPOINTNAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBENDPOINTNAME, JOBENDPOINTID
	}
	
	"DiscoveryReplicaJobs" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and $_.JobType -like "Replica" } | Select-Object @{ N = "JOBREPLICAID"; E = { $_.ID } }, @{ N = "JOBREPLICANAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBREPLICANAME, JOBREPLICAID
	}
	
	"DiscoveryRepo" {
		$query = Get-CimInstance -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Select-Object @{ N = "REPONAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson REPONAME
	}
	
	"DiscoveryBackupVmsByJobs" {
		if ($ID -like "BackupSync")
		{
			ImportXml -item backupsyncvmbyjob | Select-Object @{ N = "JOBNAME"; E = { $_.Job } }, @{ N = "JOBVMNAME"; E = { $_.NAME } } | ConvertTo-ZabbixDiscoveryJson JOBVMNAME, JOBNAME
		}
		else
		{
			ImportXml -item backupvmbyjob | Select-Object @{ N = "JOBNAME"; E = { $_.Job } }, @{ N = "JOBVMNAME"; E = { $_.NAME } } | ConvertTo-ZabbixDiscoveryJson JOBVMNAME, JOBNAME
		}
	}
	
	"ExportXml" {
		
		$test = Test-Path -Path "$pathxml"
		if ($test -like "False")
		{
			$query = New-Item -ItemType Directory -Force -Path "$pathxml"
		}
		if ((Get-CimInstance -Class Win32_Process -Filter "Name='PowerShell.EXE'" | Where-Object { $_.CommandLine -Like "*exportxml*" } | Measure-Object).count -eq 1)
		{
			$job = ExportXml -command "[Veeam.Backup.Core.CBackupSession]::GetAll()" -name backupsession -switch normal -options true
			$job0 = ExportXml -command "[Veeam.Backup.Core.CBackupJob]::GetAll()" -name backupjob -switch normal
			$job1 = ExportXml -command Get-VBRTapeJob -name backuptape -switch normal
			$job2 = ExportXml -command Get-VBREPJob -name backupendpoint -switch normal
			$job3 = ExportXml -command "[Veeam.Backup.Core.CBackupJob]::GetAll()" -name backupvmbyjob -switch byvm -type Backup
			$job4 = ExportXml -command "[Veeam.Backup.Core.CBackupJob]::GetAll()" -name backupsyncvmbyjob -switch byvm -type BackupSync
			$job5 = ExportXml -name backuptaskswithretry -switch bytaskswithretry
			Get-Job | Wait-Job
		}
	}
	
	"ResultBackup"  {
		$xml = ImportXml -item backuptaskswithretry
		$query1 = $xml | Where-Object { $_.jobId -like "$ID" } | Sort-Object JobStart -Descending | Select-Object -First 1
		$query2 = $query1.JobResult
		if (!$query2.value)
		{
			write-output "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $query2.value
			$query4 = "$query3" | VeeamStatusReplace
			write-output "$query4"
		}
	}
	
	"ResultBackupSync"  {
		[System.DateTime]$ExcludeDate = (Get-Date).adddays(-7)
		$xml = ImportXml -item backupjob | Where-Object { $_.Id -like $ID }
		$result = veeam-backuptask-unique -ID $xml.name -jobtype jobname | Where-Object { $_.JobEnd -ge $ExcludeDate }
		$result1 = $result | Where-Object { $_.JobEnd -ge $ExcludeDate } # If the Vm have not a backup for 7 days, exclusion
		$query = $result1 | Measure-Object
		$count = $query.count
		$success = ($Result.Status | Where-Object { $_.Value -like "*Success*" }).count
		$warning = ($Result.Status | Where-Object { $_.Value -like "*Warning*" }).count
		$failed = ($Result.Status | Where-Object { $_.Value -like "*Failed*" }).count
		$pending = ($Result.Status | Where-Object { $_.Value -like "*Pending*" }).count
		$InProgress = ($Result.Status | Where-Object { $_.Value -like "*InProgress*" }).count
		if ($count -eq $success) { write-output "2" }
		else
		{
			if ($failed -gt 0) { write-output "0" }
			else
			{
				if ($warning -gt 0) { write-output "1" }
				else
				{
					
					if ($InProgress -gt 0) { write-output "5" }
					else
					{
						if ($pending -gt 0)
						{
							$xml2 = ImportXml -item backupsession
							$query1 = $xml2 | Where-Object { $_.jobId -like "*$ID*" } | Sort-Object creationtime -Descending | Select-Object -First 2 | Select-Object -Index 1
							if (!$query1.Result.Value) { write-output "4" }
							else
							{
								$query2 = $query1.Result.Value | VeeamStatusReplace
								write-output "$query2"
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
			write-output "-- ERROR --   Switch 'ResultTape' need ID of the Veeam task"
			write-output ""
			write-output "Example : ./zabbix_vbr_job.ps1 ResultTape 'c333cedf-db4a-44ed-8623-17633300d7fe'"
		}
		else
		{
			$xml1 = ImportXml -item backuptape
			$query = $xml1 | Where-Object { $_.Id -like "*$ID*" } | Sort-Object creationtime -Descending | Select-Object -First 1
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
					$query2 = "$query1" | VeeamStatusReplace
					write-output "$query2"
				}
				else
				{
					write-output "4"
				}
			}
			else
			{
				if (($query.LastState.Value -like "WaitingTape") -and ($query2 -like "None"))
				{
					write-output "1"
				}
				else
				{
					$query3 = $query2 | VeeamStatusReplace
					write-output "$query3"
				}
			}
		}
	}
	
	"ResultEndpoint"  {
		if (!$ID)
		{
			write-output "-- ERROR --   Switch 'ResultEndpoint' need ID of the Veeam Endpoint Task"
			write-output ""
			write-output "Example : ./zabbix_vbr_job.ps1 ResultEndpoint 'c333cedf-db4a-44ed-8623-17633300d7fe'"
		}
		else
		{
			$xml3 = ImportXml -item backupendpoint
			$query = $xml3 | Where-Object { $_.Id -like "*$ID*" }
			$query1 = $query | Where-Object { $_.Id -eq $query.Id } | Sort-Object creationtime -Descending | Select-Object -First 1
			$query2 = $query1.LastResult
			# If empty Send 4 : First Backup (or no history)
			if (!$query2)
			{
				write-output "4"
			}
			else
			{
				$query4 = $query2.value
				$query3 = $query4 | VeeamStatusReplace
				write-output "$query3"
			}
		}
	}
	
	"ResultReplica"  {
		$xml = ImportXml -item backupsession
		$query1 = $xml | Where-Object { $_.jobId -like "$ID" } | Sort-Object creationtime -Descending | Select-Object -First 1
		$query2 = $query1.Result
		if (!$query2.value)
		{
			write-output "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $query2.value
			$query4 = "$query3" | VeeamStatusReplace
			write-output "$query4"
		}
	}
	
	"VmResultBackup" {
		$query = veeam-backuptask-unique -ID $ID0 -jobtype jobname
		$result = $query | Where-Object { $_.Name -like "$ID" }
		if (!$result)
		{
			write-output "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $Result.Status.Value
			$query4 = $query3 | VeeamStatusReplace
			[string]$query4
		}
	}
	
	"VmResultBackupSync" {
		$query = veeam-backuptask-unique -ID $ID0 -jobtype jobname
		$result = $query | Where-Object { $_.Name -like "$ID" }
		if (!$result)
		{
			write-output "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			$query3 = $Result.Status.Value
			$query4 = $query3 | VeeamStatusReplace
			[string]$query4
		}
	}
	"RepoCapacity" {
		$query = Get-CimInstance -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object { $_.Name -eq "$ID" }
		$query | Select-Object -ExpandProperty Capacity
	}
	
	"RepoFree" {
		$query = Get-CimInstance -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object { $_.Name -eq "$ID" }
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
		$result = $query | Where-Object { $_.Status -like $ID0 } | Measure-Object
		[string]$result.count
	}
	
	"VmCountResultBackupSync" {
		$query = veeam-backuptask-unique -ID $ID -jobtype jobname
		$result = $query | Where-Object { $_.Status -like $ID0 } | Measure-Object
		[string]$result.count
	}
	
	"Type" {
		$xml1 = ImportXml -item backupsession
		$query = $xml1 | Where-Object { $_.JobId -like "$ID" } | Select-Object -First 1
		[string]$query.JobType
	}
	
	"LastRunTime" {
		$xml1 = ImportXml -item backupsession
		$query = $xml1 | Where-Object { $_.JobId -like "*$ID*" } | Sort-Object creationtime -Descending | Select-Object -First 1
		[string]$query1 = $query.CreationTimeUTC.ToString('dd/MM/yyyy HH:mm:ss')
		$result1 = $nextdate, $nexttime = $query1.Split(" ")
		$newdate = ("$($nextdate -replace "(\d{2})-(\d{2})", "`$2-`$1") $nexttime")
		$date = get-date -date "01/01/1970"
		$result2 = (New-TimeSpan -Start $date -end $newdate).TotalSeconds
		[string]$result2
	}
	
	"LastEndTime" {
		$xml1 = ImportXml -item backupsession
		$query = $xml1 | Where-Object { $_.JobId -like "*$ID*" } | Sort-Object creationtime -Descending | Select-Object -First 1
		[string]$query1 = $query.EndTime
		$result1 = $nextdate, $nexttime = $query1.Split(" ")
		$newdate = [datetime]("$($nextdate -replace "(\d{2})-(\d{2})", "`$2-`$1") $nexttime")
		$date = get-date -date "01/01/1970"
		$result2 = (New-TimeSpan -Start $date -end $newdate).TotalSeconds
		[string]$result2
	}
	
	"NextRunTime" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		$query1 = $query.ScheduleOptions
		$result = $query1.NextRun
		if (!$result)
		{
			$result = $query | Select-Object name, @{ N = 'RunAfter'; E = { ($xml1 | Where-Object { $_.id -eq $query.info.ParentScheduleId }).Name } }
			$result1 = 'After Job' + " : " + $result.RunAfter
			[string]$result1
		}
		else
		{
			[string]$result
		}
	}
	
	"RunningJob" {
		$xml1 = ImportXml -item backupjob
		$query = $xml1 | Where-Object { $_.isCompleted -eq $false } | Measure-Object
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
		write-output "-- ERROR -- : Need an option !"
	}
}
