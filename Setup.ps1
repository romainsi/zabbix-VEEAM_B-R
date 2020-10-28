function Restart-Zabbix {
    $Zabbix_Service = Get-Service -Name 'Zabbix Agent' -ErrorAction SilentlyContinue
    if ($Zabbix_Service -ne $null -and $Zabbix_Service.Status -eq 'Running') {
        $Zabbix_Service.Stop()
        $Zabbix_Service.WaitForStatus('Stopped')
        $Zabbix_Service.Start()
    }
}

function Get-ZabbixAgent {
    $service_config = Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Services\Zabbix Agent' -ErrorAction SilentlyContinue
    if ($service_config -ne $null) {
        $image_path = $service_config.GetValue('ImagePath')
        if ($image_path -match "^`"([^`"]*)`".*$") {
            return $Matches.1
        }
        return $image_path -replace "--config .*", ""
    }

    throw 'Zabbix not installed'
}

function Get-ZabbixPath {
    $install_x64 = Get-Item 'HKLM:\SOFTWARE\Zabbix SIA\Zabbix Agent (64-bit)' -ErrorAction SilentlyContinue
    if ($install_x64 -ne $null) {
        return $install_x64.GetValue('InstallFolder')
    }

    $install_x86 = Get-Item 'HKLM:\SOFTWARE\Zabbix SIA\Zabbix Agent' -ErrorAction SilentlyContinue
    if ($install_x86 -ne $null) {
        return $install_x86.GetValue('InstallFolder')
    }

    return (Get-ChildItem -Path (Get-ZabbixAgent)).DirectoryName
}

function Setup-VeeamAgent {
    param(
        [string]$zabbix_path = (Get-ZabbixPath)
    )

    $wmi_product = Get-WmiObject -Class Win32_Product -Filter 'Name = "Veeam Backup & Replication Server"'
    if ($wmi_product -eq $null) {
        Write-Debug 'Veeam server not installed. Skip.'
        return
    }

    $zabbix_config = "
EnableRemoteCommands=1
UnsafeUserParameters=1
Alias=service.discovery.veeam:service.discovery
Timeout=30
UserParameter=vbr[*],powershell -NoProfile -ExecutionPolicy Bypass -File ""${zabbix_path}scripts\zabbix_vbr_job.ps1"" ""`$1"" ""`$2"" ""`$3""
    " -replace "`r`n", "`n"

    #$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    #[System.IO.File]::WriteAllLines($zabbix_path + 'zabbix_agentd.conf.d\veeam_agent.conf', $zabbix_config, $Utf8NoBomEncoding)
    Set-Content -Path ($zabbix_path + 'zabbix_agentd.conf.d\veeam_agent.conf') -Value $zabbix_config -Encoding Ascii

    $script_directory = $zabbix_path + 'scripts'
    if (-not (Test-Path -Path $script_directory)) {
        New-Item -ItemType Directory -Path $script_directory
    }

    $client = new-object System.Net.WebClient
    $download_path = [System.IO.Path]::GetTempFileName()
    $client.DownloadFile('https://raw.githubusercontent.com/bontiv/zabbix-VEEAM_B-R/master/zabbix_vbr_job.ps1', $download_path)

    $script_content = Get-Content -Path $download_path
    Set-Content -Path ($zabbix_path + 'scripts\zabbix_vbr_job.ps1') -Value ($script_content -replace "pathxml = 'C:\\Program Files\\Zabbix Agent\\scripts\\TempXmlVeeam'", "pathxml = '${zabbix_path}scripts\TempXmlVeeam'")
    Remove-Item -Path $download_path

    Restart-Zabbix
}

Setup-VeeamAgent