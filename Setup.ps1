param(
    [switch]$no_elevate
)

function Restart-Zabbix {
    $Zabbix_Service = Get-Service -Name 'Zabbix Agent' -ErrorAction SilentlyContinue
    if ($Zabbix_Service -ne $null -and $Zabbix_Service.Status -eq 'Running') {
        $Zabbix_Service | Restart-Service
    }
}

function Get-ZabbixAgent {
    $service_config = Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Services\Zabbix Agent' -ErrorAction SilentlyContinue
    if ($service_config -ne $null) {
        $image_path = $service_config.GetValue('ImagePath')
        if ($image_path -match "^`"([^`"]*)`".*$") {
            return $Matches[1]
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

    return ((Get-ChildItem -Path (Get-ZabbixAgent)).DirectoryName + '/')
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

function Setup-PowerShell3 {
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
        $arch = "x64"
    } else {
        $arch = "x86"
    }

    $win_version = (Get-WmiObject Win32_OperatingSystem).Version -split '\.'
    $base_version = $win_version[0] + '.' + $win_version[1]

    if ($base_version -eq '6.0') {
        $package = 'Windows6.0-KB2506146'
    } elseif ($base_version -eq '6.1') {
        $package = 'Windows6.1-KB2506143'
    }
    $url = "https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/${package}-${arch}.msu"
    $msu_file = $msi_file = [System.IO.Path]::GetTempPath() + "${package}-${arch}.msu"

    $client = new-object System.Net.WebClient
    $client.DownloadFile($url, $msu_file)

    Start-Process WUSA -ArgumentList ($msu_file, '/quiet', '/norestart') -Wait
}

# If main script, launch setup
if ($MyInvocation.PSCommandPath -eq $null) {
    if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
        if ($PSVersionTable.PSCompatibleVersions -notcontains "3.0") {
            Setup-PowerShell3
        }
        Setup-VeeamAgent
    } elseif (-not $no_elevate.IsPresent) {
        # PowerShell 2.0 do not set $PSCommandPath. So use current file invocation.
        if ($PSCommandPath -eq $null) {
			$PSCommandPath = $MyInvocation.InvocationName
		}
        Start-Process Powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -no_elevate"
    } else {
        throw "Cannot elevate setup."
    }
}