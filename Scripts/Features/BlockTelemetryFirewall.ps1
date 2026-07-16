function Invoke-BlockTelemetryFirewall {
    param (
        [switch]$WhatIf
    )

    $telemetryDomains = @(
        "vortex.data.microsoft.com",
        "settings-win.data.microsoft.com",
        "watson.telemetry.microsoft.com",
        "telemetry.microsoft.com",
        "sqm.microsoft.com",
        "oca.telemetry.microsoft.com.nsatc.net"
    )

    Write-Host "`n[*] Blocking Telemetry endpoints via Windows Defender Firewall..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would create outbound firewall rules for telemetry endpoints:" -ForegroundColor Yellow
        foreach ($domain in $telemetryDomains) {
            Write-Host "  - $domain" -ForegroundColor DarkGray
        }
        return
    }

    try {
        foreach ($domain in $telemetryDomains) {
            $ruleName = "WinSwift_BlockTelemetry_$domain"
            
            # Remove existing rule if present
            $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            if ($existing) {
                Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            }

            # Try to resolve to IP
            $ips = @()
            try {
                $ips = (Resolve-DnsName -Name $domain -ErrorAction SilentlyContinue | Where-Object {$_.Type -eq "A" -or $_.Type -eq "AAAA"}).IPAddress
            } catch {}

            if ($null -ne $ips -and $ips.Count -gt 0) {
                New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block -RemoteAddress $ips -ErrorAction Stop | Out-Null
                Write-Host "  [+] Blocked $domain ($($ips -join ', '))" -ForegroundColor Green
            } else {
                Write-Host "  [-] Could not resolve $domain (May already be DNS blocked)" -ForegroundColor DarkGray
            }
        }
        Write-Host "  [+] Telemetry Firewall blocks applied." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to apply Firewall blocks: $_" -ForegroundColor Red
    }
}
