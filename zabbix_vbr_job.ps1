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

Add-PsSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue

switch ($ITEM) {
  "Discovery" {
    $output =  "{`"data`":["
    $connectVeeam = 'Connect-VBRServer'
      $query = Get-VBRJob | Where-Object {$_.IsScheduleEnabled -eq "true"} | Select-Object Id,Name, IsScheduleEnabled
    $disconnectVeeam = 'Disconnect-VBRServer'
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
    $connectVeeam = 'Connect-VBRServer'
      $query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Select-object Name
    $disconnectVeeam = 'Disconnect-VBRServer'
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
    $connectVeeam = 'Connect-VBRServer'
      $query = Get-VBRTapeJob | Select-Object Id,Name
    $disconnectVeeam = 'Disconnect-VBRServer'
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

   "ExportXml" {
  write-host "Command Send"
  $connectVeeam = 'Connect-VBRServer'
  Get-VBRBackupSession | Export-Clixml "$pathxml\backupsessiontemp.xml"
  $disconnectVeeam = 'Disconnect-VBRServer'
  Copy-Item -Path $pathxml\backupsessiontemp.xml -Destination "$pathxml\backupsession.xml"
  Remove-Item "$pathxml\backupsessiontemp.xml"
    }

    "Result"  {
  $connectVeeam = 'Connect-VBRServer'
  $query = Get-VBRJob | Where-Object {$_.Id -like "*$ID*" -and $_.IsScheduleEnabled -eq "true"}
  $disconnectVeeam = 'Disconnect-VBRServer'
  $xml = Import-Clixml "$pathxml\backupsession.xml"
  $query1 = $xml | Where {$_.jobId -eq $query.Id.Guid} | Sort creationtime -Descending | Select -First 1
  $query2 = $query1.Result

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
  if (!$queryn2){
  $queryn3 = $queryn2.value
  cd $pathsender
  $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k Result.[$ID] -o 4 -v
    if ($trapper[0].Contains("processed: 1"))
    {write-host "Execution reussie"}
    else {write-host "Execution non reussie"}}
  else {
  $queryn3 = $queryn2.value
  $queryn4 = "$queryn3".replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
  cd $pathsender
  $trapper1 = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k Result.[$ID] -o $queryn4 -v
   if ($trapper1[0].Contains("processed: 1"))
    {write-host "Execution reussie"}
    else {write-host "Execution non reussie"}
   }}}

  "ResultTape"  {
  $connectVeeam = 'Connect-VBRServer'
  $query = Get-VBRTapeJob | Where-Object {$_.Id -like "*$ID*"}
  $disconnectVeeam = 'Disconnect-VBRServer'
  $query1 = $query | Where {$_.Id -eq $query.Id} | Sort creationtime -Descending | Select -First 1
  $query2 = $query1.LastResult
   if (!$query2){
   $query3 = $query1.GetLastResult()
   $query4 = "$query3".replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
   cd $pathsender
   $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k ResultTape.[$ID] -o $query4 -v
     if ($trapper[0].Contains("processed: 1"))
     {write-host "Execution reussie"}
       else {write-host "Execution non reussie"}}
   else {
   $query3 = "$query2".replace('Failed','0').replace('Warning','1').replace('Success','2').replace('None','2').replace('idle','3')
   cd $pathsender
   $trapper = .\zabbix_sender.exe -c .\zabbix_agentd.conf -k ResultTape.[$ID] -o $query3 -v
   if ($trapper[0].Contains("processed: 1"))
   {write-host "Execution reussie"}
   else {write-host "Execution non reussie"}}
    }

    "RepoCapacity" {
  $query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object {$_.Name -eq "$ID"}
  $query|Select-Object -ExpandProperty Capacity
    }
    "RepoFree" {
  $query = Get-WmiObject -Class Repository -ComputerName $env:COMPUTERNAME -Namespace ROOT\VeeamBS | Where-Object {$_.Name -eq "$ID"}
  $query|Select-Object -ExpandProperty FreeSpace
    }
    "RunStatus" {
  $connectVeeam = 'Connect-VBRServer'
  $query = Get-VBRJob | Where-Object {$_.Id -like "*$ID*"}
  $disconnectVeeam = 'Disconnect-VBRServer'
  if ($query.IsRunning) { return "1" } else { return "0"}
  }
  "IncludedSize"{
  $connectVeeam = 'Connect-VBRServer'
  $query = Get-VBRJob | Where-Object {$_.Id -like "*$ID*"}
  $disconnectVeeam = 'Disconnect-VBRServer'
  [string]$query.Info.IncludedSize
  }
  "ExcludedSize"{
  $connectVeeam = 'Connect-VBRServer'
  $query = Get-VBRJob | Where-Object {$_.Id -like "*$ID*"}
  $disconnectVeeam = 'Disconnect-VBRServer'
  [string]$query.Info.ExcludedSize
  }
  "VmCount" {
  $connectVeeam = 'Connect-VBRServer'
  $query = Get-VBRBackup | Where-Object {$_.JobId -like "*$ID*"}
  $disconnectVeeam = 'Disconnect-VBRServer'
  [string]$query.VmCount
  }
  "Type" {
  $connectVeeam = 'Connect-VBRServer'
  $query = Get-VBRBackup | Where-Object {$_.JobId -like "*$ID*"}
  $DisconnectVeeam = 'Disconnect-VBRServer'
  [string]$query.JobType
  }
    "RunningJob" {
  $connectVeeam = 'Connect-VBRServer'
  $query = $xml | where { $_.isCompleted -eq $false } | Measure
  $DisconnectVeeam = 'Disconnect-VBRServer'
  if ($query) {
	[string]$query.Count
    } else {
	return "0"
    }
  }
  default {
      Write-Host "-- ERREUR -- : Besoin d'une option !"
  }
}
