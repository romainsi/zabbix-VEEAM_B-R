# Script: zabbix_vbr_job
# Author: Romainsi
# Description: Query Veeam job information
# 
# This script is intended for use with Zabbix > 3.X
#
# USAGE:
#   as a script:    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" <ITEM_TO_QUERY> <JOBID>"
#   as an item:     vbr[<ITEM_TO_QUERY>,<JOBID>]
#
# Add to Zabbix Agent
#   UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Zabbix Agent\scripts\zabbix_vbr_job.ps1" "$1" "$2"
#

$pathxml = 'C:\Program Files\Zabbix Agent\scripts'
$pathsender = 'C:\Program Files\Zabbix Agent'

$ITEM = [string]$args[0]
$ID = [string]$args[1]

# The function is to bring to the format understands zabbix
function convertto-encoding ([string]$from, [string]$to){
	begin{
		$encfrom = [system.text.encoding]::getencoding($from)
		$encto = [system.text.encoding]::getencoding($to)
	}
	process{
		$bytes = $encto.getbytes($_)
		$bytes = [system.text.encoding]::convert($encfrom, $encto, $bytes)
		$encto.getstring($bytes)
	}
}

# Start Load VEEAM Snapin (if not already loaded)
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
	if (!(Add-PSSnapin -PassThru VeeamPSSnapIn)) {
		# Error out if loading fails
		Write-Error "`nERROR: Cannot load the VEEAM Snapin."
		Exit
	}
}

switch ($ITEM) {
  "Discovery" {
    $output =  "{`"data`":["
    $connectVeeam = Connect-VBRServer
      $query = Get-VBRJob | Where-Object {$_.IsScheduleEnabled -eq "true"} | Select-Object Id,Name, IsScheduleEnabled
    $disconnectVeeam = Disconnect-VBRServer
      $count = $query | Measure-Object
      $count = $count.count
      foreach ($object in $query) {
        $Id = [string]$object.Id
        $Name = [string]$object.Name
        $Schedule = [string]$object.IsScheduleEnabled
        if ($count -eq 1) {
          $output = $output + "{`"{#JOBID}`":`"$Id`",`"{#JOBNAME}`":`"$Name`",`"{#JOBSCHEDULED}`":`"$Schedule`"}"
        } else {
          $output = $output + "{`"{#JOBID}`":`"$Id`",`"{#JOBNAME}`":`"$Name`",`"{#JOBSCHEDULED}`":`"$Schedule`"},"
        }
        $count--
    }
    $output = $output + "]}"
    Write-Host $output
  }
    
   "DiscoveryRepo" {
    $output =  "{`"data`":["
    $connectVeeam = Connect-VBRServer
      $query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Select-object Name
    $disconnectVeeam = Disconnect-VBRServer
      $count = $query | Measure-Object
      $count = $count.count
      foreach ($object in $query) {
        $Name = [string]$object.Name
        if ($count -eq 1) {
          $output = $output + "{`"{#REPONAME}`":`"$Name`"}"
        } else {
          $output = $output + "{`"{#REPONAME}`":`"$Name`"},"
        }
        $count--
    }
    $output = $output + "]}"
    Write-Host $output
  }

   "DiscoveryTape" {
    $output =  "{`"data`":["
    $connectVeeam = Connect-VBRServer
      $query = Get-VBRTapeJob | Select-Object Id,Name
    $disconnectVeeam = Disconnect-VBRServer
      $count = $query | Measure-Object
      $count = $count.count
      foreach ($object in $query) {
        $Id = [string]$object.Id
        $Name = [string]$object.Name
      if ($count -eq 1) {
          $output = $output + "{`"{#JOBTAPEID}`":`"$Id`",`"{#JOBTAPENAME}`":`"$Name`"}"
        } else {
          $output = $output + "{`"{#JOBTAPEID}`":`"$Id`",`"{#JOBTAPENAME}`":`"$Name`"},"
        }
        $count--
    }
    $output = $output + "]}"
    Write-Host $output
  }

    "DiscoveryEndpointJobs" {
    $output =  "{`"data`":["
    $connectVeeam = Connect-VBRServer
      $query = Get-VBREPJob | Select-Object Id,Name
    $disconnectVeeam = Disconnect-VBRServer
      $count = $query | Measure-Object
      $count = $count.count
      foreach ($object in $query) {
        $Id = [string]$object.Id
        $Name = [string]$object.Name
      if ($count -eq 1) {
          $output = $output + "{`"{#JOBENDPOINTID}`":`"$Id`",`"{#JOBENDPOINTNAME}`":`"$Name`"}"
        } else {
          $output = $output + "{`"{#JOBENDPOINTID}`":`"$Id`",`"{#JOBENDPOINTNAME}`":`"$Name`"},"
        }
        $count--
    }
    $output = $output + "]}"
    Write-Host $output
  }

   "ExportXml" {
  write-host "Command Send"
  $connectVeeam = Connect-VBRServer
  Get-VBRBackupSession | Export-Clixml "$pathxml\backupsessiontemp.xml"
  Get-VBRJob | Export-Clixml "$pathxml\backupjobtemp.xml"
  Get-VBRBackup | Export-Clixml "$pathxml\backupbackuptemp.xml"
  Get-VBREPJob | Export-Clixml "$pathxml\backupendpointtemp.xml"
  $disconnectVeeam = Disconnect-VBRServer
  Copy-Item -Path $pathxml\backupsessiontemp.xml -Destination "$pathxml\backupsession.xml"
  Copy-Item -Path $pathxml\backupjobtemp.xml -Destination "$pathxml\backupjob.xml"
  Copy-Item -Path $pathxml\backupbackuptemp.xml -Destination "$pathxml\backupbackup.xml"
  Copy-Item -Path $pathxml\backupendpointtemp.xml -Destination "$pathxml\backupendpoint.xml"
  Remove-Item "$pathxml\backupsessiontemp.xml"
  Remove-Item "$pathxml\backupjobtemp.xml"
  Remove-Item "$pathxml\backupbackuptemp.xml"
  Remove-Item "$pathxml\backupendpointtemp.xml"
    }

    "Result"  {
  $xml1 = Import-Clixml "$pathxml\backupjob.xml" 
  $query = $xml1 | Where-Object {$_.Id -like "*$ID*"}
  $xml = Import-Clixml "$pathxml\backupsession.xml"
  $query1 = $xml | Where {$_.jobId -eq $query.Id.Guid} | Sort creationtime -Descending | Select -First 1
  $query2 = $query1.Result
  if (!$query2.value){
  cd $pathsender
  $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k Result.[$ID] -o 4 -v
   if ($trapper[0].Contains("processed: 1"))
    {write-host "Execution reussie"}
    else {write-host "Result Empty or Backup Task Disabled"} 
  }
  else {
  if ($query2.value -ne "None"){
  $query3 = $query2.value
  $query4 = "$query3".replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
  cd $pathsender
  $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k Result.[$ID] -o $query4 -v
    if ($trapper[0].Contains("processed: 1"))
    {write-host "Execution reussie"}
    else {write-host "Execution non reussie"}
   }
  else {$queryn1 = $xml | Where {$_.jobId -eq $query.Id.Guid} | Sort creationtime -Descending | Select -First 2 | Select -Index 1
  $queryn2 = $queryn1.Result
  $queryn3 = $queryn2.value
  $queryn4 = "$queryn3".replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
  cd $pathsender
  $trapper1 = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k Result.[$ID] -o $queryn4 -v
   if ($trapper1[0].Contains("processed: 1"))
    {write-host "Execution reussie"}
    else {write-host "Execution non reussie"}
   }}}

  "ResultTape"  {
    if (!$ID){
  Write-Host "-- ERROR --   Switch 'ResultTape' need ID of the Veeam task"
  Write-Host ""
  Write-Host "Example : ./zabbix_vbr_job.ps1 ResultTape 'c333cedf-db4a-44ed-8623-17633300d7fe'"}
  else {
  $connectVeeam = Connect-VBRServer
  $query = Get-VBRTapeJob | Where-Object {$_.Id -like "*$ID*"}
  $disconnectVeeam = Disconnect-VBRServer
  $query1 = $query | Where {$_.Id -eq $query.Id} | Sort creationtime -Descending | Select -First 1
  $query2 = $query1.LastResult
   if (!$query2){
   $query3 = $query1.GetLastResult()
   $query4 = "$query3".replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
   cd $pathsender
   $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k ResultTape.[$ID] -o $query4 -v
     if ($trapper[0].Contains("processed: 1"))
     {write-host "Execution reussie"}
       else {write-host "Execution non reussie"}}}
   else {
   $query3 = "$query2".replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
   cd $pathsender
   $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k ResultTape.[$ID] -o $query3 -v
   if ($trapper[0].Contains("processed: 1"))
   {write-host "Execution reussie"}
   else {write-host "Execution non reussie"}}
    }

      "ResultEndpoint"  {
    if (!$ID){
  Write-Host "-- ERROR --   Switch 'ResultEndpoint' need ID of the Veeam Endpoint Task"
  Write-Host ""
  Write-Host "Example : ./zabbix_vbr_job.ps1 ResultEndpoint 'c333cedf-db4a-44ed-8623-17633300d7fe'"}
  else {
  $xml3 = Import-Clixml "$pathxml\backupendpoint.xml" 
  $query = $xml3 | Where-Object {$_.Id -like "*$ID*"}
  $query1 = $query | Where {$_.Id -eq $query.Id} | Sort creationtime -Descending | Select -First 1
  $query2 = $query1.LastResult
  if (!$query2){
  cd $pathsender
  $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k ResultEndpoint.[$ID] -o 4 -v
   if ($trapper[0].Contains("processed: 1"))
    {write-host "Execution reussie"}
    else {write-host "Result Empty or Backup Task Disabled"} 
  }
  else {
   $query4 = $query2.value
   $query3 = $query4.replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
   cd $pathsender
   $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k ResultEndpoint.[$ID] -o $query3 -v
   if ($trapper[0].Contains("processed: 1"))
   {write-host "Execution reussie"}
   else {write-host "Execution non reussie"}}
    }}

    "RepoCapacity" {
  $query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object {$_.Name -eq "$ID"}
  $query|Select-Object -ExpandProperty Capacity
    }
    "RepoFree" {
  $query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object {$_.Name -eq "$ID"}
  $query|Select-Object -ExpandProperty FreeSpace
    }
    "RunStatus" {
  $xml1 = Import-Clixml "$pathxml\backupjob.xml" 
  $query = $xml1 | Where-Object {$_.Id -like "*$ID*"}
  if ($query.IsRunning) { return "1" } else { return "0"}
  }
  "IncludedSize"{
  $xml1 = Import-Clixml "$pathxml\backupjob.xml" 
  $query = $xml1 | Where-Object {$_.Id -like "*$ID*"}
  [string]$query.Info.IncludedSize
  }
  "ExcludedSize"{
  $xml1 = Import-Clixml "$pathxml\backupjob.xml" 
  $query = $xml1 | Where-Object {$_.Id -like "*$ID*"}
  [string]$query.Info.ExcludedSize
  }
  "VmCount" {
  $xml1 = Import-Clixml "$pathxml\backupbackup.xml" 
  $query = $xml1 | Where-Object {$_.JobId -like "*$ID*"}
  [string]$query.VmCount
  }
  "Type" {
  $xml1 = Import-Clixml "$pathxml\backupbackup.xml" 
  $query = $xml1 | Where-Object {$_.JobId -like "*$ID*"}
  [string]$query.JobType
  }
  "NextRunTime" {
  $xml1 = Import-Clixml "$pathxml\backupjob.xml" 
  $query = $xml1 | where {$_.Id -like "*$ID*"}
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
  if ($query) {
	[string]$query.Count
    } else {
	return "0"
    }
  }
  default {
      Write-Host "-- ERROR -- : Need an option !"
  }
}
