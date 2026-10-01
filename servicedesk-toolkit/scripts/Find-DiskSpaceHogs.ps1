<#
.SYNOPSIS
    Shows what is eating disk space: biggest top-level folders and biggest files.
.DESCRIPTION
    Read-only. Scans a path (default C:\Users) and reports the largest folders one
    level down, then the largest individual files. Run it after Get-SystemHealth
    flags a low-disk warning. Inaccessible folders are skipped, so run elevated
    for a complete picture of other users' profiles.
.PARAMETER Path
    Root to scan. Default C:\Users.
.PARAMETER Top
    How many folders and files to list. Default 10.
.PARAMETER MinFileMB
    Ignore files smaller than this when listing biggest files. Default 100.
.EXAMPLE
    .\Find-DiskSpaceHogs.ps1
.EXAMPLE
    .\Find-DiskSpaceHogs.ps1 -Path D:\ -Top 15 -MinFileMB 500
#>
[CmdletBinding()]
param(
    [string]$Path = 'C:\Users',
    [int]$Top = 10,
    [int]$MinFileMB = 100
)

if (-not (Test-Path $Path)) { throw "Path not found: $Path" }

Write-Host "`nScanning $Path (this can take a few minutes on large profiles)..." -ForegroundColor DarkGray

$files = Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue

Write-Host "`n== Largest folders (one level below $Path) ==" -ForegroundColor Cyan
$root = (Resolve-Path $Path).Path.TrimEnd('\')
$files | Group-Object {
        $rel = $_.FullName.Substring($root.Length).TrimStart('\')
        $first = $rel.Split('\')[0]
        if ($rel -eq $first) { '(files in root)' } else { $first }
    } |
    ForEach-Object { [pscustomobject]@{ Folder = $_.Name; 'Size GB' = [math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1GB, 2); Files = $_.Count } } |
    Sort-Object 'Size GB' -Descending | Select-Object -First $Top | Format-Table -AutoSize | Out-Host

Write-Host "== Largest files (>= $MinFileMB MB) ==" -ForegroundColor Cyan
$files | Where-Object Length -ge ($MinFileMB * 1MB) | Sort-Object Length -Descending | Select-Object -First $Top |
    Select-Object @{n='Size MB';e={[math]::Round($_.Length / 1MB, 0)}}, LastWriteTime, FullName |
    Format-Table -AutoSize -Wrap | Out-Host

$total = [math]::Round(($files | Measure-Object Length -Sum).Sum / 1GB, 2)
Write-Host "Total scanned: $total GB in $($files.Count) files" -ForegroundColor Green
