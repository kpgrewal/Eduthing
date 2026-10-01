# servicedesk-toolkit

Small, dependency-free PowerShell scripts for Level 2 service desk work. No modules to install, just PowerShell 5.1+ on Windows. Each script has built-in help (`Get-Help .\scripts\<name>.ps1 -Full`).

| Script | Use it when... |
|---|---|
| [Get-SystemHealth.ps1](scripts/Get-SystemHealth.ps1) | "My PC is slow." One-page snapshot: uptime, RAM, disks, pending reboot, last patch, top processes. Optional HTML output to attach to the ticket. |
| [Test-NetworkTriage.ps1](scripts/Test-NetworkTriage.ps1) | "I can't get to X." Tests adapter, gateway, DNS, internet, then an optional host and port, and names the first failing layer. |
| [Get-EventLogSummary.ps1](scripts/Get-EventLogSummary.ps1) | Repeated crashes or reboots. Groups recent errors and flags BSOD, unexpected shutdown and disk-error events. |
| [Clear-UserTempFiles.ps1](scripts/Clear-UserTempFiles.ps1) | Low disk space. Cleans temp and browser caches safely. Supports `-WhatIf` to preview. |
| [Export-InstalledSoftware.ps1](scripts/Export-InstalledSoftware.ps1) | Licence audits and "what version do they have?" Exports installed apps to CSV without touching `Win32_Product`. |

## Usage

```powershell
git clone https://github.com/kpgrewal/Eduthing
cd Eduthing\servicedesk-toolkit\scripts
.\Get-SystemHealth.ps1
.\Test-NetworkTriage.ps1 -Target fileserver01 -Port 445
.\Clear-UserTempFiles.ps1 -WhatIf
```

If scripts are blocked: `Set-ExecutionPolicy -Scope Process Bypass`

## About this project

Built with AI assistance (Claude Code) and reviewed and tested by a working service desk engineer. The scripts are read-only by default. The one that deletes anything (`Clear-UserTempFiles`) supports `-WhatIf`, only removes files older than a set age, and skips system locations unless elevated.

## Licence

MIT
