<#
.SYNOPSIS
    Winget-powered software installer for WinSwift.
.DESCRIPTION
    Installs a curated list of popular software using Winget.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

function Install-Software {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string[]]$SoftwareList
    )

    Write-Host "> Installing software via Winget..." -ForegroundColor Cyan

    # Ensure Winget is available
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [ERROR] Winget is not installed or not in PATH." -ForegroundColor Red
        return
    }

    # Default curated list if none provided
    if (-not $SoftwareList -or $SoftwareList.Count -eq 0) {
        $SoftwareList = @(
            "7zip.7zip",
            "Brave.Brave",
            "VideoLAN.VLC",
            "Notepad++.Notepad++",
            "Microsoft.PowerToys",
            "Git.Git",
            "Microsoft.VisualStudioCode"
        )
    }

    foreach ($app in $SoftwareList) {
        if ($PSCmdlet.ShouldProcess($app, "Install via Winget")) {
            Write-Host "  Installing $app..."
            try {
                $process = Start-Process -FilePath "winget" -ArgumentList "install --id `"$app`" -e --accept-package-agreements --accept-source-agreements --silent" -Wait -NoNewWindow -PassThru
                if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 2316632065) {
                    Write-Host "  [OK] Successfully installed $app"
                } else {
                    Write-Host "  [WARN] Failed to install $app (Exit code: $($process.ExitCode))" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  [WARN] Error installing $app: $_" -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    Write-Host "Software installation complete." -ForegroundColor Green
    Write-Host ""
}

