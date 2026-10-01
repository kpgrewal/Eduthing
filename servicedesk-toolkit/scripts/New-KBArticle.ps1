<#
.SYNOPSIS
    Turns ticket resolution notes into a consistently formatted KB article (Markdown).
.DESCRIPTION
    Fill in the parameters (or run with none and answer the prompts) and get a
    ready-to-paste article with Summary, Symptoms, Cause, Resolution steps,
    Verification and Escalation sections. Saves to a file named after the title.
.PARAMETER Title
    Short, searchable title, e.g. "Outlook keeps asking for password".
.PARAMETER Symptoms
    What the user sees. One string per symptom.
.PARAMETER Cause
    Root cause, if known.
.PARAMETER Steps
    Resolution steps, in order.
.PARAMETER Tags
    Keywords to help search.
.PARAMETER TicketRef
    Optional ticket number this was derived from.
.PARAMETER OutDir
    Where to save the article. Default: current folder.
.EXAMPLE
    .\New-KBArticle.ps1 -Title "Outlook keeps asking for password" `
        -Symptoms "Credential prompt loops","Status shows Need Password" `
        -Cause "Stale cached credentials in Credential Manager" `
        -Steps "Close Outlook","Open Credential Manager","Remove MicrosoftOffice16 entries","Reopen Outlook and sign in" `
        -Tags outlook,credentials -TicketRef INC0012345
#>
[CmdletBinding()]
param(
    [string]$Title,
    [string[]]$Symptoms,
    [string]$Cause,
    [string[]]$Steps,
    [string[]]$Tags,
    [string]$TicketRef,
    [string]$OutDir = '.'
)

function Read-List($prompt) {
    Write-Host "$prompt (one per line, blank line to finish)" -ForegroundColor Cyan
    $items = @(); while (($l = Read-Host '  -') -ne '') { $items += $l }; $items
}

if (-not $Title)    { $Title    = Read-Host 'Title' }
if (-not $Symptoms) { $Symptoms = Read-List 'Symptoms' }
if (-not $Cause)    { $Cause    = Read-Host 'Cause (blank if unknown)' }
if (-not $Steps)    { $Steps    = Read-List 'Resolution steps' }
if (-not $Tags)     { $Tags     = (Read-Host 'Tags (comma separated)') -split '\s*,\s*' | Where-Object { $_ } }

$n = 0
$md = @"
# $Title

**Last updated:** $(Get-Date -Format 'yyyy-MM-dd')  |  **Author:** $env:USERNAME$(if ($TicketRef) { "  |  **Source ticket:** $TicketRef" })
**Tags:** $($Tags -join ', ')

## Symptoms
$(($Symptoms | ForEach-Object { "- $_" }) -join "`n")

## Cause
$(if ($Cause) { $Cause } else { 'Not yet confirmed.' })

## Resolution
$(($Steps | ForEach-Object { $n++; "$n. $_" }) -join "`n")

## Verification
- [ ] User confirms the issue no longer occurs
- [ ] Issue does not return after a restart / next sign-in

## Escalate if
- The steps above do not resolve the issue, or the issue affects multiple users.
- Attach: ticket number, steps already tried, screenshots or error text.
"@

$safe = ($Title -replace '[^\w\- ]', '' -replace '\s+', '-').ToLower()
$path = Join-Path $OutDir "KB-$safe.md"
$md | Set-Content -Path $path -Encoding utf8
Write-Host "Saved $path" -ForegroundColor Green
