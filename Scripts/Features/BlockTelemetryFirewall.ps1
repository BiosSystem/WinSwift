<#
.SYNOPSIS
    Blocks Microsoft telemetry and AI inference endpoints via Windows Firewall and HOSTS file.
.DESCRIPTION
    Creates outbound Windows Defender Firewall rules for all known telemetry domains.
    When DNS resolution fails (e.g., the domain is already sinkholed), falls back to
    writing a permanent HOSTS file entry as defense-in-depth. Covers original telemetry
    endpoints plus new 24H2/25H2 AI inference and data pipeline routes.
#>
function Invoke-BlockTelemetryFirewall {
    param (
        [switch]$WhatIf
    )

    $telemetryDomains = @(
        # Classic telemetry endpoints
        "vortex.data.microsoft.com",
        "settings-win.data.microsoft.com",
        "watson.telemetry.microsoft.com",
        "telemetry.microsoft.com",
        "sqm.microsoft.com",
        "oca.telemetry.microsoft.com.nsatc.net",
        # New 24H2/25H2 AI inference and data pipeline routes
        "us.vortex-win.data.microsoft.com",
        "east.pipe.aria.microsoft.com",
        "api.msai.microsoft.com",
        "inference.windows.microsoft.com",
        "copilot.microsoft.com",
        "substrate.office.com",
        "canary.designerapp.office.com",
        "designer.microsoft.com"
    )

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $hostsMarkerStart = "# WinSwift-TelemetryBlock-Start"
    $hostsMarkerEnd   = "# WinSwift-TelemetryBlock-End"

    Write-Host ""
    Write-Host "[*] Blocking telemetry endpoints via Windows Defender Firewall + HOSTS file..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would create outbound firewall rules and HOSTS entries for:" -ForegroundColor Yellow
        foreach ($domain in $telemetryDomains) {
            Write-Host "    - $domain" -ForegroundColor DarkGray
        }
        return
    }

    $hostsEntries = @()

    try {
        foreach ($domain in $telemetryDomains) {
            $ruleName = "WinSwift_BlockTelemetry_$domain"

            # Remove any existing rule first
            $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            if ($existing) {
                Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            }

            # Attempt DNS resolution
            $ips = @()
            try {
                $ips = (Resolve-DnsName -Name $domain -ErrorAction SilentlyContinue |
                    Where-Object { $_.Type -eq 'A' -or $_.Type -eq 'AAAA' }).IPAddress
            } catch {}

            if ($null -ne $ips -and $ips.Count -gt 0) {
                New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Action Block `
                    -RemoteAddress $ips -ErrorAction Stop | Out-Null
                Write-Host "  [FW] Blocked $domain ($($ips -join ', '))" -ForegroundColor Green
            } else {
                # Fallback: HOSTS file entry
                $hostsEntries += "0.0.0.0 $domain"
                Write-Host "  [HOSTS] DNS unavailable - queued HOSTS entry for $domain" -ForegroundColor DarkGray
            }
        }

        # Write HOSTS entries if any fallbacks were needed
        if ($hostsEntries.Count -gt 0) {
            $currentHosts = Get-Content -Path $hostsPath -Raw -ErrorAction SilentlyContinue

            # Strip any previous WinSwift block
            $currentHosts = $currentHosts -replace "(?s)$hostsMarkerStart.*?$hostsMarkerEnd`r?`n?", ""

            $block = "`r`n$hostsMarkerStart`r`n" + ($hostsEntries -join "`r`n") + "`r`n$hostsMarkerEnd`r`n"
            $currentHosts + $block | Set-Content -Path $hostsPath -Encoding ASCII -Force -ErrorAction Stop
            Write-Host "  [HOSTS] Wrote $($hostsEntries.Count) fallback entries to hosts file" -ForegroundColor Green
        }

        Write-Host "  [+] Telemetry blocks applied (Firewall + HOSTS)." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to apply telemetry blocks: $_" -ForegroundColor Red
    }
}

function Invoke-UnblockTelemetryFirewall {
    param (
        [switch]$WhatIf
    )

    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $hostsMarkerStart = "# WinSwift-TelemetryBlock-Start"
    $hostsMarkerEnd   = "# WinSwift-TelemetryBlock-End"

    Write-Host ""
    Write-Host "[*] Removing WinSwift telemetry blocks..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would remove all WinSwift_BlockTelemetry_ firewall rules and HOSTS entries" -ForegroundColor Yellow
        return
    }

    # Remove firewall rules
    $rules = Get-NetFirewallRule -DisplayName "WinSwift_BlockTelemetry_*" -ErrorAction SilentlyContinue
    foreach ($rule in $rules) {
        Remove-NetFirewallRule -DisplayName $rule.DisplayName -ErrorAction SilentlyContinue
        Write-Host "  [-] Removed firewall rule: $($rule.DisplayName)" -ForegroundColor DarkGray
    }

    # Remove HOSTS block
    if (Test-Path $hostsPath) {
        $currentHosts = Get-Content -Path $hostsPath -Raw -ErrorAction SilentlyContinue
        $cleaned = $currentHosts -replace "(?s)$hostsMarkerStart.*?$hostsMarkerEnd`r?`n?", ""
        $cleaned | Set-Content -Path $hostsPath -Encoding ASCII -Force -ErrorAction SilentlyContinue
        Write-Host "  [-] Removed WinSwift HOSTS block" -ForegroundColor DarkGray
    }

    Write-Host "  [+] Telemetry blocks removed." -ForegroundColor Green
}
