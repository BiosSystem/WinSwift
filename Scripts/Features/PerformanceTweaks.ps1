<#
.SYNOPSIS
    Performance tweaks for WinSwift - SSD/RAM optimizations and system responsiveness.
.DESCRIPTION
    Applies performance-oriented registry and service tweaks.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

function Enable-PerformanceTweaks {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "> Applying performance tweaks..." -ForegroundColor Cyan

    # 1. Disable SysMain (Superfetch) - unnecessary on SSDs
    if ($PSCmdlet.ShouldProcess("SysMain Service", "Disable Superfetch")) {
        try {
            Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  [OK] Superfetch (SysMain) disabled"
        } catch {
            Write-Host "  [WARN] Could not disable SysMain: $_" -ForegroundColor Yellow
        }
    }

    # 2. Disable Windows Search indexing service
    if ($PSCmdlet.ShouldProcess("WSearch Service", "Disable Search Indexing")) {
        try {
            Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  [OK] Windows Search indexing disabled"
        } catch {
            Write-Host "  [WARN] Could not disable WSearch: $_" -ForegroundColor Yellow
        }
    }

    # 3. Disable Hibernate (frees hiberfil.sys - often 8-32 GB)
    if ($PSCmdlet.ShouldProcess("Hibernate", "Disable and free hiberfil.sys")) {
        try {
            powercfg -h off | Out-Null
            Write-Host "  [OK] Hibernate disabled (hiberfil.sys freed)"
        } catch {
            Write-Host "  [WARN] Could not disable hibernate: $_" -ForegroundColor Yellow
        }
    }

    # 4. Trim startup delay
    if ($PSCmdlet.ShouldProcess("Registry", "Remove startup delay")) {
        $startupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        if (-not (Test-Path $startupPath)) { New-Item -Path $startupPath -Force | Out-Null }
        Set-ItemProperty -Path $startupPath -Name "StartupDelayInMSec" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Startup delay removed"
    }

    # 5. Disable Windows Error Reporting
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Windows Error Reporting")) {
        $werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
        if (-not (Test-Path $werPath)) { New-Item -Path $werPath -Force | Out-Null }
        Set-ItemProperty -Path $werPath -Name "Disabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Windows Error Reporting disabled"
    }

    # 6. Disable Print Spooler (if no printer is needed)
    if ($PSCmdlet.ShouldProcess("Spooler Service", "Disable Print Spooler")) {
        try {
            Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "Spooler" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "  [OK] Print Spooler disabled"
        } catch {
            Write-Host "  [WARN] Could not disable Spooler: $_" -ForegroundColor Yellow
        }
    }

    # 7. Disable Aero Shake (shake to minimize windows)
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Aero Shake")) {
        $aeroPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $aeroPath -Name "DisallowShaking" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Aero Shake (shake-to-minimize) disabled"
    }

    # 8. Set NumLock ON at startup
    if ($PSCmdlet.ShouldProcess("Registry", "Enable NumLock at startup")) {
        $numlockPath = "HKU:\.DEFAULT\Control Panel\Keyboard"
        if (Test-Path $numlockPath) {
            Set-ItemProperty -Path $numlockPath -Name "InitialKeyboardIndicators" -Value "2" -Force -ErrorAction SilentlyContinue
        }
        $numlockPath2 = "HKCU:\Control Panel\Keyboard"
        Set-ItemProperty -Path $numlockPath2 -Name "InitialKeyboardIndicators" -Value "2" -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] NumLock will be ON at startup"
    }

    # 9. Show seconds in system clock
    if ($PSCmdlet.ShouldProcess("Registry", "Show seconds in clock")) {
        $clockPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $clockPath -Name "ShowSecondsInSystemClock" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] System clock now shows seconds"
    }

    Write-Host ""
    Write-Host "Performance tweaks applied. A restart is recommended." -ForegroundColor Green
    Write-Host ""
}

function Disable-PerformanceTweaks {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "> Reverting performance tweaks..." -ForegroundColor Cyan

    # Re-enable SysMain
    if ($PSCmdlet.ShouldProcess("SysMain Service", "Re-enable Superfetch")) {
        Set-Service -Name "SysMain" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "SysMain" -ErrorAction SilentlyContinue
        Write-Host "  [OK] Superfetch (SysMain) re-enabled"
    }

    # Re-enable WSearch
    if ($PSCmdlet.ShouldProcess("WSearch Service", "Re-enable Search Indexing")) {
        Set-Service -Name "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
        Write-Host "  [OK] Windows Search indexing re-enabled"
    }

    # Re-enable Hibernate
    if ($PSCmdlet.ShouldProcess("Hibernate", "Re-enable Hibernate")) {
        powercfg -h on | Out-Null
        Write-Host "  [OK] Hibernate re-enabled"
    }

    # Re-enable Print Spooler
    if ($PSCmdlet.ShouldProcess("Spooler Service", "Re-enable Print Spooler")) {
        Set-Service -Name "Spooler" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "Spooler" -ErrorAction SilentlyContinue
        Write-Host "  [OK] Print Spooler re-enabled"
    }

    Write-Host ""
    Write-Host "Performance tweaks reverted." -ForegroundColor Yellow
    Write-Host ""
}

