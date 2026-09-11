function Invoke-InstallUpdateWatchdog {
    param (
        [switch]$WhatIf
    )

    $taskName = "Winnow_UpdateWatchdog"
    $taskPath = "\Winnow"
    $scriptPath = "$env:ProgramData\Winnow\Watchdog.ps1"

    Write-Host "`n[*] Installing Windows Update Watchdog..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would create a Scheduled Task triggered by Windows Update events to monitor telemetry resets." -ForegroundColor Yellow
        return
    }

    try {
        # Create directory for the payload
        if (-not (Test-Path "$env:ProgramData\Winnow")) {
            New-Item -Path "$env:ProgramData\Winnow" -ItemType Directory -Force | Out-Null
        }

        # The payload script to run when triggered
        # Runs as SYSTEM, so it re-applies the settings directly rather than
        # showing a toast (a session-0 toast never reaches the desktop) or asking
        # the user to re-run Winnow. Scoped to the two controls Windows Update
        # most often resets: the AllowTelemetry policy and the DiagTrack service.
        $watchdogPayload = @'
$log  = "$env:ProgramData\Winnow\watchdog.log"
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
function Write-WatchdogLog($message) { Add-Content -Path $log -Value "[$date] $message" }

Write-WatchdogLog "Windows Update event fired. Re-asserting telemetry settings..."
$reAsserted = @()
try {
    $dc = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (-not (Test-Path $dc)) { New-Item -Path $dc -Force | Out-Null }
    $current = (Get-ItemProperty -Path $dc -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
    if ($current -ne 0) {
        Set-ItemProperty -Path $dc -Name "AllowTelemetry" -Value 0 -Type DWord -Force
        $reAsserted += "AllowTelemetry policy"
    }

    $diagTrack = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    if ($diagTrack -and $diagTrack.StartType -ne "Disabled") {
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
        $reAsserted += "DiagTrack service"
    }
}
catch {
    Write-WatchdogLog "ERROR while re-asserting telemetry: $($_.Exception.Message)"
}

if ($reAsserted.Count -gt 0) {
    Write-WatchdogLog ("Windows Update had reset: " + ($reAsserted -join ", ") + ". Re-applied.")
} else {
    Write-WatchdogLog "Telemetry settings intact, nothing to re-apply."
}
'@

        Set-Content -Path $scriptPath -Value $watchdogPayload -Force

        # Remove existing task if it exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
        }

        # Trigger on Windows Update install events (Microsoft-Windows-WindowsUpdateClient
        # in the System log). New-ScheduledTaskTrigger cannot build an event trigger, so
        # it is created through CIM. EventID 19 is "installation successful" and 43 is
        # "installation started"; both are caught so a reset is corrected promptly.
        $eventTrigger = $null
        try {
            $triggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler -ErrorAction Stop
            $eventTrigger = New-CimInstance -CimClass $triggerClass -ClientOnly
            $eventTrigger.Enabled = $true
            $eventTrigger.Subscription = '<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[Provider[@Name=''Microsoft-Windows-WindowsUpdateClient''] and (EventID=19 or EventID=43)]]</Select></Query></QueryList>'
        }
        catch {
            Write-Host "  [WARN] Could not build the update-event trigger; falling back to the daily check only." -ForegroundColor Yellow
        }

        # Daily fallback so a missed event is still corrected within a day.
        $triggerDaily = New-ScheduledTaskTrigger -Daily -At 12:00PM
        $triggers = if ($eventTrigger) { @($eventTrigger, $triggerDaily) } else { @($triggerDaily) }

        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Trigger $triggers -Action $action -Principal $principal -Description "Re-asserts Winnow telemetry settings after a Windows update resets them." | Out-Null

        $triggerDesc = if ($eventTrigger) { "on Windows Update install events, with a daily fallback" } else { "daily (event trigger unavailable)" }
        Write-Host "  [+] Update Watchdog installed. It runs $triggerDesc and re-applies telemetry settings." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to install Update Watchdog: $_" -ForegroundColor Red
    }
}
