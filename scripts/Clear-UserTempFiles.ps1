<#
.SYNOPSIS
    Safely frees disk space by clearing temp files and caches, with a preview mode.
.DESCRIPTION
    Targets: user temp, Windows temp, Windows Update download cache, and browser
    caches (Edge/Chrome). Only deletes files older than -OlderThanDays. Supports
    -WhatIf so you can show the user what would be removed first.
    Windows-level locations need an elevated prompt; skipped otherwise.
.PARAMETER OlderThanDays
    Only remove files not modified in this many days. Default 7.
.EXAMPLE
    .\Clear-UserTempFiles.ps1 -WhatIf
.EXAMPLE
    .\Clear-UserTempFiles.ps1 -OlderThanDays 3
#>
[CmdletBinding(SupportsShouldProcess)]
param([int]$OlderThanDays = 7)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$targets = [ordered]@{
    'User temp'        = $env:TEMP
    'Edge cache'       = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    'Chrome cache'     = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
}
if ($isAdmin) {
    $targets['Windows temp']          = "$env:WINDIR\Temp"
    $targets['Windows Update cache']  = "$env:WINDIR\SoftwareDistribution\Download"
} else {
    Write-Warning 'Not elevated: skipping Windows temp and Update cache.'
}

$cutoff = (Get-Date).AddDays(-$OlderThanDays)
$report = foreach ($name in $targets.Keys) {
    $path = $targets[$name]
    if (-not (Test-Path $path)) { continue }
    $files = Get-ChildItem $path -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object LastWriteTime -lt $cutoff
    $bytes = ($files | Measure-Object Length -Sum).Sum
    if ($PSCmdlet.ShouldProcess($path, "Delete $($files.Count) files older than $OlderThanDays days")) {
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    [pscustomobject]@{ Location = $name; Files = $files.Count; 'MB' = [math]::Round(($bytes / 1MB), 1) }
}

$report | Format-Table -AutoSize
$total = ($report | Measure-Object MB -Sum).Sum
Write-Host ("Total: {0} MB {1}" -f $total, $(if ($WhatIfPreference) { 'would be freed' } else { 'freed' })) -ForegroundColor Green
