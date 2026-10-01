<#
.SYNOPSIS
    Exports installed software (name, version, publisher, install date) to CSV.
.DESCRIPTION
    Reads the 64-bit, 32-bit and current-user uninstall registry keys, so it
    finds more than Get-WmiObject Win32_Product and never triggers MSI repairs.
.PARAMETER Path
    Output CSV. Default: .\InstalledSoftware-<computer>.csv
.PARAMETER Filter
    Optional wildcard on the name, e.g. "*Adobe*".
.EXAMPLE
    .\Export-InstalledSoftware.ps1 -Filter "*Office*"
#>
[CmdletBinding()]
param(
    [string]$Path = ".\InstalledSoftware-$env:COMPUTERNAME.csv",
    [string]$Filter = '*'
)

$keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'

$apps = Get-ItemProperty $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayName -like $Filter -and -not $_.SystemComponent } |
    Select-Object @{n='Name';e={$_.DisplayName}}, @{n='Version';e={$_.DisplayVersion}},
                  @{n='Publisher';e={$_.Publisher}}, @{n='InstallDate';e={$_.InstallDate}} |
    Sort-Object Name -Unique

$apps | Export-Csv $Path -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($apps.Count) applications to $Path" -ForegroundColor Green
