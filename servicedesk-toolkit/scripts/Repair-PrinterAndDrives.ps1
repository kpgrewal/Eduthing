<#
.SYNOPSIS
    Standard fix routine for "printer stuck" and "mapped drive missing" tickets.
.DESCRIPTION
    Report mode (default): lists printers, stuck print jobs, spooler state and
    mapped drives with their connection status.
    Fix mode (-Fix): restarts the Print Spooler, clears stuck jobs, and reconnects
    any mapped drives that show as unavailable. Needs an elevated prompt for the
    spooler steps. Supports -WhatIf.
.EXAMPLE
    .\Repair-PrinterAndDrives.ps1
.EXAMPLE
    .\Repair-PrinterAndDrives.ps1 -Fix -WhatIf
.EXAMPLE
    .\Repair-PrinterAndDrives.ps1 -Fix
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Fix)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# --- Report ---------------------------------------------------------------
$spooler = Get-Service Spooler
Write-Host "`n== Print Spooler ==" -ForegroundColor Cyan
Write-Host "Status: $($spooler.Status)"

Write-Host "`n== Printers ==" -ForegroundColor Cyan
Get-Printer -ErrorAction SilentlyContinue |
    Select-Object Name, DriverName, PortName, PrinterStatus, @{n='Jobs';e={(Get-PrintJob -PrinterObject $_ -ErrorAction SilentlyContinue | Measure-Object).Count}} |
    Format-Table -AutoSize | Out-Host

$spoolDir = "$env:WINDIR\System32\spool\PRINTERS"
$stuck = Get-ChildItem $spoolDir -File -ErrorAction SilentlyContinue
Write-Host "Spool files waiting: $(($stuck | Measure-Object).Count)"

Write-Host "`n== Mapped drives ==" -ForegroundColor Cyan
$drives = Get-SmbMapping -ErrorAction SilentlyContinue
if ($drives) { $drives | Select-Object LocalPath, RemotePath, Status | Format-Table -AutoSize | Out-Host }
else         { Write-Host 'No mapped drives found for this user.' }

if (-not $Fix) { Write-Host "`nRun with -Fix to restart the spooler, clear jobs and reconnect drives." -ForegroundColor DarkGray; return }

# --- Fix ------------------------------------------------------------------
if (-not $isAdmin) { Write-Warning 'Not elevated: spooler steps will be skipped. Re-run as administrator.' }
else {
    if ($PSCmdlet.ShouldProcess('Print Spooler', 'Stop, clear spool folder, start')) {
        Stop-Service Spooler -Force
        Get-ChildItem $spoolDir -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Start-Service Spooler
        Write-Host 'Spooler restarted and queue cleared.' -ForegroundColor Green
    }
}

foreach ($d in $drives | Where-Object Status -ne 'OK') {
    if ($PSCmdlet.ShouldProcess($d.RemotePath, "Reconnect $($d.LocalPath)")) {
        try {
            Remove-SmbMapping -LocalPath $d.LocalPath -Force -UpdateProfile:$false -ErrorAction SilentlyContinue
            New-SmbMapping -LocalPath $d.LocalPath -RemotePath $d.RemotePath -Persistent $true -ErrorAction Stop | Out-Null
            Write-Host "Reconnected $($d.LocalPath) -> $($d.RemotePath)" -ForegroundColor Green
        } catch { Write-Warning "Could not reconnect $($d.LocalPath): $($_.Exception.Message)" }
    }
}
