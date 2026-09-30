<#
.SYNOPSIS
    One-page health snapshot of a Windows machine for first-look ticket triage.
.DESCRIPTION
    Reports uptime, OS build, CPU/RAM load, disk space, pending reboot state,
    last installed hotfix, and the top memory-hungry processes.
    Works locally or against a remote machine (needs WinRM/CIM access).
.PARAMETER ComputerName
    Target computer. Defaults to the local machine.
.PARAMETER Html
    Optional path to also save the report as an HTML file.
.EXAMPLE
    .\Get-SystemHealth.ps1
.EXAMPLE
    .\Get-SystemHealth.ps1 -ComputerName PC-0421 -Html C:\Temp\PC-0421.html
#>
[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [string]$Html
)

$isLocal = $ComputerName -in $env:COMPUTERNAME, 'localhost', '.'
# Splat remoting parameters only for remote targets (local runs must not need WinRM)
$remote = if ($isLocal) { @{} } else { @{ ComputerName = $ComputerName } }
$cim = $remote + @{ ErrorAction = 'Stop' }
$os   = Get-CimInstance Win32_OperatingSystem @cim
$cpu  = Get-CimInstance Win32_Processor @cim | Measure-Object LoadPercentage -Average
$disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' @cim

$uptime = (Get-Date) - $os.LastBootUpTime
$memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$memFree  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)

$rebootCheck = {
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
}
$pendingReboot = if ($isLocal) { & $rebootCheck } else { Invoke-Command @remote -ErrorAction SilentlyContinue -ScriptBlock $rebootCheck }
if ($null -eq $pendingReboot) { $pendingReboot = 'Unknown' }

$lastPatch = Get-HotFix @remote -ErrorAction SilentlyContinue |
    Sort-Object InstalledOn -Descending | Select-Object -First 1

$summary = [pscustomobject]@{
    Computer      = $ComputerName
    OS            = "$($os.Caption) (build $($os.BuildNumber))"
    Uptime        = '{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    'CPU load %'  = [math]::Round($cpu.Average, 0)
    'RAM used'    = "$([math]::Round($memTotal - $memFree, 1)) / $memTotal GB"
    PendingReboot = $pendingReboot
    LastHotfix    = if ($lastPatch) { "$($lastPatch.HotFixID) on $($lastPatch.InstalledOn.ToShortDateString())" } else { 'None found' }
}

$diskReport = $disks | ForEach-Object {
    $pct = [math]::Round($_.FreeSpace / $_.Size * 100, 0)
    [pscustomobject]@{
        Drive  = $_.DeviceID
        SizeGB = [math]::Round($_.Size / 1GB, 0)
        FreeGB = [math]::Round($_.FreeSpace / 1GB, 1)
        'Free %' = $pct
        Status = if ($pct -lt 10) { 'CRITICAL' } elseif ($pct -lt 20) { 'Low' } else { 'OK' }
    }
}

$topProcs = Get-Process @remote -ErrorAction SilentlyContinue |
    Sort-Object WorkingSet64 -Descending | Select-Object -First 5 |
    ForEach-Object { [pscustomobject]@{ Process = $_.ProcessName; 'RAM MB' = [math]::Round($_.WorkingSet64 / 1MB, 0) } }

Write-Host "`n== System summary ==" -ForegroundColor Cyan;  $summary | Format-List | Out-Host
Write-Host "== Disks =="            -ForegroundColor Cyan;  $diskReport | Format-Table -AutoSize | Out-Host
Write-Host "== Top 5 by memory =="  -ForegroundColor Cyan;  $topProcs | Format-Table -AutoSize | Out-Host

if ($Html) {
    $frag = @(
        ($summary    | ConvertTo-Html -As List  -Fragment -PreContent '<h2>Summary</h2>'),
        ($diskReport | ConvertTo-Html -Fragment -PreContent '<h2>Disks</h2>'),
        ($topProcs   | ConvertTo-Html -Fragment -PreContent '<h2>Top processes</h2>')
    )
    ConvertTo-Html -Title "Health: $ComputerName" -Body ($frag | ForEach-Object { $_ } | Out-String) |
        Out-File -FilePath $Html -Encoding utf8
    Write-Host "Saved HTML report to $Html" -ForegroundColor Green
}
