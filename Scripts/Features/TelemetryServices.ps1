<#
.SYNOPSIS
    Disables Windows telemetry and diagnostic data collection services.
.DESCRIPTION
    Stops and disables the core service-level telemetry pipeline that cannot be
    fully controlled via registry alone: DiagTrack (Connected User Experiences
    and Telemetry), WerSvc (Windows Error Reporting), DPS (Diagnostic Policy
    Service), and related hosting services.

    All services have reversible undo functions. A restart is recommended after
    applying to ensure services are fully quiesced.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

$script:TelemetryServices = @(
    @{
        Name        = "DiagTrack"
        DisplayName = "Connected User Experiences and Telemetry"
        DefaultStart = "Automatic"
        Risk        = "HIGH - primary Microsoft data upload pipeline"
    },
    @{
        Name        = "WerSvc"
        DisplayName = "Windows Error Reporting Service"
        DefaultStart = "Manual"
        Risk        = "MEDIUM - uploads crash dumps and error reports to Microsoft"
    },
    @{
        Name        = "DPS"
        DisplayName = "Diagnostic Policy Service"
        DefaultStart = "Automatic"
        Risk        = "MEDIUM - enables problem detection and diagnostics"
    },
    @{
        Name        = "WdiServiceHost"
        DisplayName = "Diagnostic Service Host"
        DefaultStart = "Manual"
        Risk        = "LOW - hosts diagnostic scenarios for the DPS"
    },
    @{
        Name        = "WdiSystemHost"
        DisplayName = "Diagnostic System Host"
        DefaultStart = "Manual"
        Risk        = "LOW - system-level host for diagnostic scenarios"
    }
)

function Disable-TelemetryServices {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "> Disabling telemetry and diagnostic services..." -ForegroundColor Cyan
    Write-Host "  (A restart is recommended after applying these changes)" -ForegroundColor DarkGray
    Write-Host ""

    foreach ($svc in $script:TelemetryServices) {
        if ($PSCmdlet.ShouldProcess($svc.Name, "Stop and disable service")) {
            $serviceObj = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if (-not $serviceObj) {
                Write-Host "  [SKIP] $($svc.Name) not found on this system" -ForegroundColor DarkGray
                continue
            }

            try {
                if ($serviceObj.Status -ne 'Stopped') {
                    Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop

                # Also set via registry to survive group policy refresh
                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)"
                if (Test-Path $regPath) {
                    Set-ItemProperty -Path $regPath -Name "Start" -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
                }

                Write-Host "  [OK] Disabled: $($svc.Name) - $($svc.DisplayName)" -ForegroundColor Green
            }
            catch {
                Write-Host "  [WARN] Could not disable $($svc.Name): $_" -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    Write-Host "Telemetry services disabled. Restart recommended." -ForegroundColor Green
    Write-Host ""
}

function Enable-TelemetryServices {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "> Restoring telemetry and diagnostic services..." -ForegroundColor Cyan
    Write-Host ""

    foreach ($svc in $script:TelemetryServices) {
        if ($PSCmdlet.ShouldProcess($svc.Name, "Restore service to default startup")) {
            $serviceObj = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if (-not $serviceObj) {
                Write-Host "  [SKIP] $($svc.Name) not found" -ForegroundColor DarkGray
                continue
            }

            try {
                $startType = switch ($svc.DefaultStart) {
                    "Automatic" { "Automatic" }
                    "Manual"    { "Manual" }
                    default     { "Manual" }
                }
                Set-Service -Name $svc.Name -StartupType $startType -ErrorAction Stop
                Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
                Write-Host "  [OK] Restored: $($svc.Name) to $startType" -ForegroundColor Green
            }
            catch {
                Write-Host "  [WARN] Could not restore $($svc.Name): $_" -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    Write-Host "Telemetry services restored." -ForegroundColor Yellow
    Write-Host ""
}
