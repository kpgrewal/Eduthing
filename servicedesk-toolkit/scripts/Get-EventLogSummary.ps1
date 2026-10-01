<#
.SYNOPSIS
    Summarises recent Critical/Error events, grouped so patterns stand out.
.DESCRIPTION
    Pulls System and Application errors from the last N hours, groups them by
    source and event ID, and flags known crash indicators (unexpected shutdown,
    BugCheck/BSOD, disk errors, application crashes).
.PARAMETER Hours
    How far back to look. Default 24.
.PARAMETER ComputerName
    Target computer. Default local.
.EXAMPLE
    .\Get-EventLogSummary.ps1 -Hours 72
#>
[CmdletBinding()]
param(
    [int]$Hours = 24,
    [string]$ComputerName = $env:COMPUTERNAME
)

$since = (Get-Date).AddHours(-$Hours)
$events = foreach ($log in 'System', 'Application') {
    Get-WinEvent -ComputerName $ComputerName -ErrorAction SilentlyContinue -FilterHashtable @{
        LogName = $log; Level = 1, 2; StartTime = $since
    }
}

if (-not $events) { Write-Host "No Critical/Error events in the last $Hours hours." -ForegroundColor Green; return }

Write-Host "`n== Top error sources (last $Hours h) ==" -ForegroundColor Cyan
$events | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 10 |
    ForEach-Object {
        $sample = $_.Group[0]
        [pscustomobject]@{
            Count  = $_.Count
            Source = $sample.ProviderName
            EventID = $sample.Id
            Log    = $sample.LogName
            Latest = ($_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated
            Message = ($sample.Message -split "`r?`n")[0]
        }
    } | Format-Table -AutoSize -Wrap

# Known crash indicators
$flags = @{
    41   = 'Kernel-Power 41: unexpected shutdown or power loss'
    1001 = 'BugCheck/WER 1001: possible blue screen or app fault report'
    6008 = 'EventLog 6008: previous shutdown was unexpected'
    7    = 'Disk 7: bad block - check drive health'
    11   = 'Disk 11: controller error - check cabling/drive'
    153  = 'Disk 153: I/O retried - failing storage or driver'
    1000 = 'Application Error 1000: an application crashed'
}
$hit = $events | Where-Object { $flags.ContainsKey([int]$_.Id) } | Group-Object Id
if ($hit) {
    Write-Host '== Crash indicators ==' -ForegroundColor Yellow
    foreach ($h in $hit) { Write-Host ("  {0} x{1}" -f $flags[[int]$h.Name], $h.Count) }
}
