<#
.SYNOPSIS
    Deep Widgets disable for Windows 11 25H2.
.DESCRIPTION
    Removes all Widgets infrastructure including the data collection service,
    the web experience host package, and the hover-activation trigger.
    In 25H2, Widgets no longer opens on hover but continues to collect data.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

function Disable-WidgetsDeep {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "> Deep-disabling Widgets (25H2)..." -ForegroundColor Cyan

    # Kill running Widgets process before removal
    if ($PSCmdlet.ShouldProcess("WidgetService process", "Stop running processes")) {
        Get-Process -Name "WidgetService", "WebExperienceHost", "Widgets" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Widgets processes stopped"
    }

    # Remove Widgets UWP packages
    if ($PSCmdlet.ShouldProcess("Appx packages", "Remove Widgets packages")) {
        $widgetPackages = @(
            "MicrosoftWindows.Client.WebExperience",
            "Microsoft.WidgetsPlatformRuntime",
            "Microsoft.StartExperiencesApp"
        )
        foreach ($pkg in $widgetPackages) {
            Get-AppxPackage -Name "*$pkg*" -AllUsers -ErrorAction SilentlyContinue |
                Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }
        Write-Host "  [OK] Widgets UWP packages removed"
    }

    # Block via Group Policy (prevents reinstall via Windows Update)
    if ($PSCmdlet.ShouldProcess("Registry", "Block Widgets via policy")) {
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
        if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
        Set-ItemProperty -Path $policyPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Widgets policy block set (survives Windows Update)"
    }

    # Disable Widgets from taskbar registry
    if ($PSCmdlet.ShouldProcess("Registry", "Remove Widgets from taskbar")) {
        $tbPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $tbPath -Name "TaskbarDa" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Widgets hidden from taskbar"
    }

    # Kill News and Interests scheduled task
    if ($PSCmdlet.ShouldProcess("Scheduled Task", "Disable Widgets data collection task")) {
        $task = Get-ScheduledTask -TaskName "ReportGlobalUserConfigChanged" -ErrorAction SilentlyContinue
        if ($task) {
            Disable-ScheduledTask -TaskName "ReportGlobalUserConfigChanged" -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  [OK] Widgets data collection scheduled task disabled"
        }
    }

    Write-Host ""
    Write-Host "Widgets deep-disabled (data collection blocked, policy lock set)." -ForegroundColor Green
    Write-Host ""
}

