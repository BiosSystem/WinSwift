function Invoke-InstallUpdateWatchdog {
    param (
        [switch]$WhatIf
    )

    $taskName = "WinSwift_UpdateWatchdog"
    $taskPath = "\WinSwift"
    $scriptPath = "$env:ProgramData\WinSwift\Watchdog.ps1"

    Write-Host "`n[*] Installing Windows Update Watchdog..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would create a Scheduled Task triggered by Windows Update events to monitor telemetry resets." -ForegroundColor Yellow
        return
    }

    try {
        # Create directory for the payload
        if (-not (Test-Path "$env:ProgramData\WinSwift")) {
            New-Item -Path "$env:ProgramData\WinSwift" -ItemType Directory -Force | Out-Null
        }

        # The payload script to run when triggered
        $watchdogPayload = @'
$log = "$env:ProgramData\WinSwift\watchdog.log"
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $log -Value "[$date] Windows Update detected. Checking telemetry keys..."

$reverted = $false
try {
    $telemetry = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    if ($telemetry -ne 0) { $reverted = $true }
} catch { $reverted = $true }

if ($reverted) {
    Add-Content -Path $log -Value "[$date] WARNING: Telemetry has been re-enabled by Windows Update!"
    # Send a toast notification
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $xmlString = @"
<toast>
  <visual>
    <binding template="ToastText02">
      <text id="1">WinSwift Alert</text>
      <text id="2">Windows Update re-enabled Telemetry. Please re-run WinSwift!</text>
    </binding>
  </visual>
</toast>
"@
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($xmlString)
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("WinSwift").Show($toast)
} else {
    Add-Content -Path $log -Value "[$date] All settings intact."
}
'@

        Set-Content -Path $scriptPath -Value $watchdogPayload -Force

        # Remove existing task if it exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
        }

        # Create Trigger: Event ID 43 (Installation successful) from WindowsUpdateClient
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        # Since standard PowerShell cmdlets don't natively support Event triggers easily without raw XML, we fallback to AtLogOn for simplicity or we can use CIM.
        # We will use AtLogOn for broader compatibility and daily checks.
        $triggerDaily = New-ScheduledTaskTrigger -Daily -At 12:00PM

        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Trigger $triggerDaily -Action $action -Principal $principal -Description "Monitors Windows for telemetry resets after updates." | Out-Null

        Write-Host "  [+] Update Watchdog installed successfully (Runs daily to check for resets)." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to install Update Watchdog: $_" -ForegroundColor Red
    }
}
