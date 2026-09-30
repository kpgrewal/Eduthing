<#
.SYNOPSIS
    Walks the network stack bottom-up so you can see where connectivity breaks.
.DESCRIPTION
    Checks: active adapter/IP -> default gateway -> DNS servers -> name resolution
    -> internet reachability -> optional target host and TCP port.
    Each step prints PASS/FAIL and the first failing layer is called out at the end.
.PARAMETER Target
    Optional host name to test (DNS + ping).
.PARAMETER Port
    Optional TCP port to test on -Target (e.g. 443, 3389, 445).
.EXAMPLE
    .\Test-NetworkTriage.ps1 -Target fileserver01 -Port 445
#>
[CmdletBinding()]
param(
    [string]$Target,
    [int]$Port
)

$results = New-Object System.Collections.Generic.List[object]
function Add-Step($Name, [bool]$Ok, $Detail) {
    $results.Add([pscustomobject]@{ Step = $Name; Result = $(if ($Ok) { 'PASS' } else { 'FAIL' }); Detail = $Detail })
}

# 1. Adapter and IP
$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
$ip = $cfg.IPv4Address.IPAddress
$apipa = $ip -like '169.254.*'
Add-Step 'Adapter has valid IP' ([bool]$ip -and -not $apipa) $(if ($ip) { "$ip on $($cfg.InterfaceAlias)$(if ($apipa) {' (APIPA - DHCP failed)'})" } else { 'No active adapter with a gateway' })

# 2. Gateway
$gw = $cfg.IPv4DefaultGateway.NextHop
if ($gw) { Add-Step 'Default gateway reachable' (Test-Connection $gw -Count 2 -Quiet) $gw }

# 3. DNS servers
$dns = @($cfg.DNSServer | Where-Object AddressFamily -eq 2 | ForEach-Object ServerAddresses)
if ($dns) { Add-Step 'DNS server reachable' (Test-Connection $dns[0] -Count 2 -Quiet) ($dns -join ', ') }

# 4. Name resolution
try { $r = Resolve-DnsName 'www.microsoft.com' -Type A -ErrorAction Stop | Select-Object -First 1; Add-Step 'DNS resolves external name' $true $r.IPAddress }
catch { Add-Step 'DNS resolves external name' $false $_.Exception.Message }

# 5. Internet
Add-Step 'Internet reachable (1.1.1.1)' (Test-Connection 1.1.1.1 -Count 2 -Quiet) ''

# 6. Optional target
if ($Target) {
    try { $t = Resolve-DnsName $Target -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1; Add-Step "Resolve $Target" $true $t.IPAddress }
    catch { Add-Step "Resolve $Target" $false $_.Exception.Message }
    Add-Step "Ping $Target" (Test-Connection $Target -Count 2 -Quiet) 'ICMP may be blocked by firewall'
    if ($Port) {
        $tcp = Test-NetConnection $Target -Port $Port -WarningAction SilentlyContinue
        Add-Step "TCP $Target`:$Port" $tcp.TcpTestSucceeded ''
    }
}

$results | Format-Table -AutoSize -Wrap
$first = $results | Where-Object Result -eq 'FAIL' | Select-Object -First 1
if ($first) { Write-Host "First failing layer: $($first.Step)" -ForegroundColor Red }
else        { Write-Host 'All checks passed.' -ForegroundColor Green }
