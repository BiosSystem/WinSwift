<#
.SYNOPSIS
    Auto-update check for WinSwift against the latest GitHub release.
.DESCRIPTION
    On launch, queries the GitHub releases API and compares the published
    latest tag against the embedded WINSWIFT_VERSION constant. Prints a
    banner if a newer version is available.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

function Invoke-UpdateCheck {
    param(
        [string]$CurrentVersion = $WINSWIFT_VERSION,
        [switch]$Silent
    )

    try {
        $apiUrl  = "https://api.github.com/repos/BiosSystem/WinSwift/releases/latest"
        $headers = @{ "User-Agent" = "WinSwift/$CurrentVersion" }

        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 5 -ErrorAction Stop
        $latestTag = $response.tag_name.TrimStart('v')

        # Compare versions
        $current = [System.Version]::new($CurrentVersion)
        $latest  = [System.Version]::new($latestTag)

        if ($latest -gt $current) {
            Write-Host ""
            Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
            Write-Host "  ║  WinSwift Update Available!                          ║" -ForegroundColor Yellow
            Write-Host "  ║  Current: v$CurrentVersion  ->  Latest: v$latestTag               ║" -ForegroundColor Yellow
            Write-Host "  ║  https://github.com/BiosSystem/WinSwift/releases     ║" -ForegroundColor Yellow
            Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Yellow
            Write-Host ""
        } elseif (-not $Silent) {
            Write-Host "  [OK] WinSwift v$CurrentVersion is up to date." -ForegroundColor DarkGray
        }
    } catch {
        # Silently skip update check if offline or rate-limited
        if (-not $Silent) {
            Write-Host "  [INFO] Update check skipped (no internet or rate-limited)." -ForegroundColor DarkGray
        }
    }
}

