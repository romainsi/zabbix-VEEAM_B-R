# Script: zabbix_vbr_job
# Author: Romainsi
# Description: Query Veeam job information
# This script is intended for use with Zabbix > 3.X
#
# USAGE:
#
#   as a script:    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" <ITEM_TO_QUERY> <JOBID>"
#   as an item:     vbr[<ITEM_TO_QUERY>,<JOBID>]
#
# Add to Zabbix Agent
#   UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" "$1" "$2" "$3"
#

$pathxml = 'C:\Program Files\Zabbix Agent\scripts\TempXmlVeeam'

$ITEM = [string]$args[0]
$ID = [string]$args[1]
$ID0 = [string]$args[2]

# The function is to bring to the format understands zabbix
function convertto-encoding ([string]$from, [string]$to)
{
	begin
	{
		$encfrom = [system.text.encoding]::getencoding($from)
		$encto = [system.text.encoding]::getencoding($to)
	}
	process
	{
		$bytes = $encto.getbytes($_)
		$bytes = [system.text.encoding]::convert($encfrom, $encto, $bytes)
		$encto.getstring($bytes)
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
		
		return $Result | ConvertTo-Json -Compress
	}
}

# Replace Function for Veeam Correlation
function veeam-replace
{
	[CmdletBinding()]
	Param ([Parameter(ValueFromPipeline)]
		$item)
	$item.replace('Failed', '0').replace('Warning', '1').replace('Success', '2').replace('None', '4').replace('idle', '3').replace('InProgress', '5').replace('Pending', '6')
}

# Load Veeam Module
Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue

switch ($ITEM)
{
	"DiscoveryBackupJobs" {
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and $_.JobType -like "Backup" } | Select @{ N = "JOBID"; E = { $_.ID } }, @{ N = "JOBNAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBNAME, JOBID
	}
	
	"DiscoveryBackupSyncJobs" {
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
		$query = $xml1 | Where-Object { $_.IsScheduleEnabled -eq "true" -and $_.JobType -like "BackupSync" } | Select @{ N = "JOBBSID"; E = { $_.ID } }, @{ N = "JOBBSNAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBBSNAME, JOBBSID
	}
	
	"DiscoveryTapeJobs" {
		$xml1 = Import-Clixml "$pathxml\backuptape.xml"
		$query = $xml1 | Select @{ N = "JOBTAPEID"; E = { $_.ID } }, @{ N = "JOBTAPENAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBTAPENAME, JOBTAPEID
	}
	
	"DiscoveryEndpointJobs" {
		$xml1 = Import-Clixml "$pathxml\backupendpoint.xml"
		$query = $xml1 | Select-Object Id, Name | Select @{ N = "JOBENDPOINTID"; E = { $_.ID } }, @{ N = "JOBENDPOINTNAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson JOBENDPOINTNAME, JOBENDPOINTID
	}
	
	"DiscoveryRepo" {
		$query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Select @{ N = "REPONAME"; E = { $_.NAME } }
		$query | ConvertTo-ZabbixDiscoveryJson REPONAME
	}
	
	"DiscoveryBackupVmsByJobs" {
		if ($ID -like "BackupSync")
		{
			Import-Clixml "$pathxml\backupsyncvmbyjob.xml" | Select @{ N = "JOBNAME"; E = { $_.Job } }, @{ N = "JOBVMNAME"; E = { $_.NAME } } | ConvertTo-ZabbixDiscoveryJson JOBVMNAME, JOBNAME
		}
		else
		{
			Import-Clixml "$pathxml\backupvmbyjob.xml" | Select @{ N = "JOBNAME"; E = { $_.Job } }, @{ N = "JOBVMNAME"; E = { $_.NAME } } | ConvertTo-ZabbixDiscoveryJson JOBVMNAME, JOBNAME
		}
	}
	
	"ExportXml" {
		write-host "Command Send"
		$test = Test-Path -Path "$pathxml"
		if ($test -like "False") { $query = New-Item -ItemType Directory -Force -Path "$pathxml" }
		$connectVeeam = Connect-VBRServer
		Get-VBRBackupSession | Export-Clixml "$pathxml\backupsessiontemp.xml"
		Get-VBRJob | Export-Clixml "$pathxml\backupjobtemp.xml"
		Get-VBRBackup | Export-Clixml "$pathxml\backupbackuptemp.xml"
		Get-VBRTapeJob | Export-Clixml "$pathxml\backuptapetemp.xml"
		Get-VBREPJob | Export-Clixml "$pathxml\backupendpointtemp.xml"
		$BackupVmByJob = Get-VBRJob | ?{ $_.JobType -eq "Backup" } | %{
			$JobName = $_.Name
			$_ | Get-VBRJobObject | ?{ $_.Object.Type -eq "VM" } | Select @{ L = "Job"; E = { $JobName } }, Name | Sort -Property Job, Name
		}
		$BackupVmByJob | Export-Clixml "$pathxml\backupvmbyjobtemp.xml"
		$BackupSyncVmByJob = Get-VBRJob | ?{ $_.JobType -eq "BackupSync" } | %{
			$JobName = $_.Name
			$_ | Get-VBRJobObject | ?{ $_.Object.Type -eq "VM" } | Select @{ L = "Job"; E = { $JobName } }, Name | Sort -Property Job, Name
		}
		$BackupSyncVmByJob | Export-Clixml "$pathxml\backupsyncvmbyjobtemp.xml"
		$TasksBackupJob = $null
		$TasksBackupSyncJob = $null
		foreach ($Job in (Get-VBRJob | where-object { $_.JobType -like "Backup" }))
		{
			$Session = $Job.FindLastSession()
			if (!$Session) { continue; }
			$TasksBackupJob += $Session.GetTaskSessions()
		}
		$TasksBackupJob | Export-Clixml "$pathxml\backuptaskstemp.xml"
		foreach ($Job in (Get-VBRJob | Where-Object { $_.JobType -eq "BackupSync" }))
		{
			$Session = $Job.FindLastSession()
			if (!$Session) { continue; }
			$TasksBackupSyncJob += $Session.GetTaskSessions()
		}
		$TasksBackupSyncJob | Export-Clixml "$pathxml\backupsynctaskstemp.xml"
		$disconnectVeeam = Disconnect-VBRServer
		Copy-Item -Path $pathxml\backupsessiontemp.xml -Destination "$pathxml\backupsession.xml"
		Copy-Item -Path $pathxml\backupjobtemp.xml -Destination "$pathxml\backupjob.xml"
		Copy-Item -Path $pathxml\backupbackuptemp.xml -Destination "$pathxml\backupbackup.xml"
		Copy-Item -Path $pathxml\backuptapetemp.xml -Destination "$pathxml\backuptape.xml"
		Copy-Item -Path $pathxml\backupendpointtemp.xml -Destination "$pathxml\backupendpoint.xml"
		Copy-Item -Path $pathxml\backuptaskstemp.xml -Destination "$pathxml\backuptasks.xml"
		Copy-Item -Path $pathxml\backupsynctaskstemp.xml -Destination "$pathxml\backupsynctasks.xml"
		Copy-Item -Path $pathxml\backupvmbyjobtemp.xml -Destination "$pathxml\backupvmbyjob.xml"
		Copy-Item -Path $pathxml\backupsyncvmbyjobtemp.xml -Destination "$pathxml\backupsyncvmbyjob.xml"
		Remove-Item "$pathxml\backupsessiontemp.xml"
		Remove-Item "$pathxml\backupjobtemp.xml"
		Remove-Item "$pathxml\backupbackuptemp.xml"
		Remove-Item "$pathxml\backuptapetemp.xml"
		Remove-Item "$pathxml\backupendpointtemp.xml"
		Remove-Item "$pathxml\backuptaskstemp.xml"
		Remove-Item "$pathxml\backupsynctaskstemp.xml"
		Remove-Item "$pathxml\backupvmbyjobtemp.xml"
		Remove-Item "$pathxml\backupsyncvmbyjobtemp.xml"
	}
	
	"ResultBackup"  {
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		$xml = Import-Clixml "$pathxml\backupsession.xml"
		$query1 = $xml | Where { $_.jobId -eq $query.Id.Guid } | Sort creationtime -Descending | Select -First 1
		$query2 = $query1.Result
		if (!$query2.value)
		{
			write-host "4" # If empty Send 4 : First Backup (or no history)
		}
		else
		{
			if ($query2.value -like "none" -and $query1.State.Value -like "Working")
			{
				write-host "5"
			}
			else
			{
				$query3 = $query2.value
				$query4 = "$query3" | veeam-replace
				write-host "$query4"
			}
		}
	}
	
	"ResultBackupSync"  {
		$xml = Import-Clixml "$pathxml\backupjob.xml" | Where-Object { $_.Id -like "*$ID*" }
		$xml1 = Import-Clixml "$pathxml\backupsynctasks.xml" | Where { $_.JobName -like $xml.Name } | select name, jobname, status
		$count = $xml1 | measure-object
		$success = ($xml1.Status | Where { $_.Value -like "*Success*" }).count
		$warning = ($xml1.Status | Where { $_.Value -like "*Warning*" }).count
		$failed = ($xml1.Status | Where { $_.Value -like "*Failed*" }).count
		$pending = ($xml1.Status | Where { $_.Value -like "*Pending*" }).count
		if ($count.count -eq $success) { write-host "2" }
		else
		{
			if ($failed -gt 0) { write-host "0" }
			else
			{
				if ($warning -gt 0) { write-host "1" }
				else
				{
					if ($pending -gt 0)
					{
						$xml2 = Import-Clixml "$pathxml\backupsession.xml"
						$query1 = $xml2 | Where { $_.jobId -like "*$ID*" } | Sort creationtime -Descending | Select -First 2 | Select -Index 1
						$query2 = $query1.Result.Value | veeam-replace
						write-host "$query2"
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
			$xml1 = Import-Clixml "$pathxml\backuptape.xml"
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
			$xml3 = Import-Clixml "$pathxml\backupendpoint.xml"
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
	
	"VmResultBackup" {
		$xml1 = Import-Clixml "$pathxml\backuptasks.xml"
		$query = $xml1 | Where-Object { $_.Name -like "$ID" -and $_.JobName -like "$ID0" }
		$query1 = $query.Status.Value
		$query2 = "$query1" | veeam-replace
		[string]$query2
	}
	"VmResultBackupSync" {
		$xml1 = Import-Clixml "$pathxml\backupsynctasks.xml"
		$query = $xml1 | Where-Object { $_.Name -like "$ID" -and $_.JobName -like "$ID0" }
		$query1 = $query.Status.Value
		$query2 = "$query1" | veeam-replace
		[string]$query2
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
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		if ($query.IsRunning) { return "1" }
		else { return "0" }
	}
	"IncludedSize"{
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		[string]$query.Info.IncludedSize
	}
	"ExcludedSize"{
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
		$query = $xml1 | Where-Object { $_.Id -like "*$ID*" }
		[string]$query.Info.ExcludedSize
	}
	"JobsCount" {
		$xml1 = Import-Clixml "$pathxml\backupjob.xml" | Measure-Object
		[string]$xml1.Count
	}
	"VmCount" {
		$xml1 = Import-Clixml "$pathxml\backuptasks.xml"
		$query = $xml1 | Where-Object { $_.JobName -like "$ID" } | Select Name | Measure-Object
		if ($query.count -eq "0")
		{
			$xml1 = Import-Clixml "$pathxml\backupsynctasks.xml"
			$query = $xml1 | Where-Object { $_.JobName -like "$ID" } | Select Name | Measure-Object
			[string]$query.Count
		}
		else
		{
			[string]$query.Count
		}
	}
	"VmCountResultBackup" {
		$xml1 = Import-Clixml "$pathxml\backuptasks.xml"
		$query = $xml1 | Where-Object { $_.JobName -like "$ID" -and $_.Status -like "$ID0" }
		$query1 = $query.Status.Value | Measure-Object
		[string]$query1.count
	}
	"VmCountResultBackupSync" {
		$xml1 = Import-Clixml "$pathxml\backupsynctasks.xml"
		$query = $xml1 | Where-Object { $_.JobName -like "$ID" -and $_.Status -like "$ID0" }
		$query1 = $query.Status.Value | Measure-Object
		[string]$query1.count
	}
	"Type" {
		$xml1 = Import-Clixml "$pathxml\backupbackup.xml"
		$query = $xml1 | Where-Object { $_.JobId -like "*$ID*" }
		[string]$query.JobType
	}
	"NextRunTime" {
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
		$query = $xml1 | where { $_.Id -like "*$ID*" }
		$query1 = $query.ScheduleOptions
		$result = $query1.NextRun
		$result1 = $nextdate, $nexttime = $result.Split(" ")
		$newdate = [datetime]("$($nextdate -replace "(\d{2})-(\d{2})", "`$2-`$1") $nexttime")
		$date = get-date -date "01/01/1970"
		$result2 = (New-TimeSpan -Start $date -end $newdate).TotalSeconds
		[string]$result2
	}
	"RunningJob" {
		$xml1 = Import-Clixml "$pathxml\backupjob.xml"
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
