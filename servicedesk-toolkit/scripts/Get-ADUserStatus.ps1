<#
.SYNOPSIS
    Answers "why can't this user log in?" in one view, or lists expiring/locked accounts.
.DESCRIPTION
    Requires the ActiveDirectory module (RSAT). Read-only unless -Unlock is used.
    Single user: enabled, locked, password age and expiry, last logon, bad password count.
    Report mode: -Expiring lists users whose password expires within N days;
    -LockedOut lists all currently locked accounts.
.PARAMETER Identity
    SamAccountName (or UPN/DN) of the user to inspect.
.PARAMETER Unlock
    Unlock the account after showing status (supports -WhatIf / -Confirm).
.PARAMETER Expiring
    List enabled users whose password expires within this many days.
.PARAMETER LockedOut
    List all locked-out accounts.
.EXAMPLE
    .\Get-ADUserStatus.ps1 -Identity jsmith
.EXAMPLE
    .\Get-ADUserStatus.ps1 -Identity jsmith -Unlock -WhatIf
.EXAMPLE
    .\Get-ADUserStatus.ps1 -Expiring 7
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'User')]
param(
    [Parameter(ParameterSetName = 'User', Mandatory, Position = 0)][string]$Identity,
    [Parameter(ParameterSetName = 'User')][switch]$Unlock,
    [Parameter(ParameterSetName = 'Expiring', Mandatory)][int]$Expiring,
    [Parameter(ParameterSetName = 'Locked', Mandatory)][switch]$LockedOut
)

if (-not (Get-Module -ListAvailable ActiveDirectory)) {
    throw 'ActiveDirectory module not found. Install RSAT: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
}
Import-Module ActiveDirectory

$props = 'Enabled', 'LockedOut', 'PasswordLastSet', 'PasswordNeverExpires', 'PasswordExpired',
         'LastLogonDate', 'BadLogonCount', 'AccountExpirationDate', 'msDS-UserPasswordExpiryTimeComputed', 'EmailAddress'

function Get-Expiry($u) {
    if ($u.PasswordNeverExpires) { return $null }
    $raw = $u.'msDS-UserPasswordExpiryTimeComputed'
    if ($raw -and $raw -lt [datetime]::MaxValue.ToFileTime()) { [datetime]::FromFileTime($raw) }
}

switch ($PSCmdlet.ParameterSetName) {
    'User' {
        $u = Get-ADUser -Identity $Identity -Properties $props
        $exp = Get-Expiry $u
        $status = [pscustomobject]@{
            Name             = $u.Name
            Account          = $u.SamAccountName
            Enabled          = $u.Enabled
            LockedOut        = $u.LockedOut
            PasswordExpired  = $u.PasswordExpired
            PasswordLastSet  = $u.PasswordLastSet
            PasswordExpires  = if ($u.PasswordNeverExpires) { 'Never' } else { $exp }
            AccountExpires   = if ($u.AccountExpirationDate) { $u.AccountExpirationDate } else { 'Never' }
            LastLogon        = $u.LastLogonDate
            BadLogonCount    = $u.BadLogonCount
        }
        $status | Format-List | Out-Host

        $problems = @()
        if (-not $u.Enabled)         { $problems += 'Account is DISABLED' }
        if ($u.LockedOut)            { $problems += 'Account is LOCKED OUT' }
        if ($u.PasswordExpired)      { $problems += 'Password has EXPIRED' }
        if ($u.AccountExpirationDate -and $u.AccountExpirationDate -lt (Get-Date)) { $problems += 'Account has EXPIRED' }
        if ($problems) { $problems | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Red } }
        else           { Write-Host '  No account-side problems found. Check workstation, network, MFA.' -ForegroundColor Green }

        if ($Unlock -and $u.LockedOut -and $PSCmdlet.ShouldProcess($u.SamAccountName, 'Unlock AD account')) {
            Unlock-ADAccount -Identity $u
            Write-Host "  Unlocked $($u.SamAccountName)." -ForegroundColor Green
        }
    }
    'Expiring' {
        $limit = (Get-Date).AddDays($Expiring)
        Get-ADUser -Filter 'Enabled -eq $true -and PasswordNeverExpires -eq $false' -Properties $props |
            ForEach-Object { $_ | Add-Member Expiry (Get-Expiry $_) -PassThru } |
            Where-Object { $_.Expiry -and $_.Expiry -le $limit } |
            Sort-Object Expiry |
            Select-Object Name, SamAccountName, EmailAddress, @{n='Expires';e={$_.Expiry}},
                          @{n='DaysLeft';e={[math]::Round(($_.Expiry - (Get-Date)).TotalDays, 0)}} |
            Format-Table -AutoSize
    }
    'Locked' {
        Search-ADAccount -LockedOut | Get-ADUser -Properties LockedOut, LastLogonDate |
            Select-Object Name, SamAccountName, LastLogonDate | Format-Table -AutoSize
    }
}
