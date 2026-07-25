# List of known Windows telemetry-related scheduled tasks
<#
    .SYNOPSIS
    Returns the list of known Windows telemetry-related scheduled tasks.

    .DESCRIPTION
    Returns an array of hashtables, each with a Path and Name key, representing
    scheduled tasks that collect or report telemetry data on Windows.

    .EXAMPLE
    Get-TelemetryScheduledTasks
#>
function Get-TelemetryScheduledTasks {
    return @(
        # Application Experience
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" },
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser Exp" },
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" },
        @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "StartupAppTask" },
        # Customer Experience Improvement Program
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" },
        @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "UsbCeip" },
        # Disk and Storage Telemetry
        @{ Path = "\Microsoft\Windows\DiskDiagnostic\"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" },
        @{ Path = "\Microsoft\Windows\Autochk\"; Name = "Proxy" },
        # Device Census (hardware fingerprint upload)
        @{ Path = "\Microsoft\Windows\Device Information\"; Name = "Device" },
        # AppID / SmartScreen Telemetry
        @{ Path = "\Microsoft\Windows\AppID\"; Name = "SmartScreenSpecific" },
        # Feedback / SIUF Telemetry
        @{ Path = "\Microsoft\Windows\Feedback\Siuf\"; Name = "DmClient" },
        @{ Path = "\Microsoft\Windows\Feedback\Siuf\"; Name = "DmClientOnScenarioDownload" },
        # Maps Telemetry
        @{ Path = "\Microsoft\Windows\Maps\"; Name = "MapsToastTask" },
        @{ Path = "\Microsoft\Windows\Maps\"; Name = "MapsUpdateTask" },
        # Software Quality Metrics
        @{ Path = "\Microsoft\Windows\PI\"; Name = "Sqm-Tasks" },
        # Windows Store Telemetry
        @{ Path = "\Microsoft\Windows\WS\"; Name = "WSTask" },
        # Activation / License Telemetry
        @{ Path = "\Microsoft\Windows\Clip\"; Name = "License Validation" },
        # CloudExperienceHost
        @{ Path = "\Microsoft\Windows\CloudExperienceHost\"; Name = "CreateObjectTask" },
        # Shell / Family Safety (used for usage telemetry)
        @{ Path = "\Microsoft\Windows\Shell\"; Name = "FamilySafetyMonitor" },
        @{ Path = "\Microsoft\Windows\Shell\"; Name = "FamilySafetyRefreshTask" },
        # Device Inventory
        @{ Path = "\Microsoft\Windows\Device Inventory\"; Name = "RunUpdateUserDeviceInventoryTask" }
    )
}

<#
    .SYNOPSIS
    Disables known Windows telemetry-related scheduled tasks.

    .DESCRIPTION
    Iterates over a predefined list of Windows scheduled tasks associated with
    telemetry and disables each one that exists and is not already disabled.
    Supports -WhatIf to preview changes without applying them.

    .EXAMPLE
    Disable-TelemetryScheduledTasks
#>
function Disable-TelemetryScheduledTasks {
    Write-Host "> Disabling telemetry scheduled tasks..."
    $tasks = Get-TelemetryScheduledTasks

    foreach ($task in $tasks) {
        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host "[WhatIf] Disable Scheduled Task: $($task.Path)$($task.Name)" -ForegroundColor Cyan
            continue
        }

        $result = Invoke-NonBlocking -ScriptBlock {
            param($path, $name)
            Import-Module ScheduledTasks -ErrorAction SilentlyContinue
            $taskObj = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue
            if (-not $taskObj) {
                return @{ Success = $true; Status = 'NotFound' }
            }
            if ($taskObj.State -ne 'Disabled') {
                try {
                    Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
                    return @{ Success = $true; Status = 'Disabled' }
                }
                catch {
                    return @{ Success = $false; Status = 'Error'; Error = $_.Exception.Message }
                }
            }
            return @{ Success = $true; Status = 'AlreadyDisabled' }
        } -ArgumentList @($task.Path, $task.Name)

        switch ($result.Status) {
            'Disabled'        { Write-Host "Disabled Scheduled Task: $($task.Path)$($task.Name)" }
            'AlreadyDisabled' { Write-Host "Scheduled Task $($task.Path)$($task.Name) is already disabled" -ForegroundColor DarkGray }
            'NotFound'        { Write-Host "Scheduled Task $($task.Path)$($task.Name) not found" -ForegroundColor DarkGray }
            'Error'           { Write-Host "Failed to disable Scheduled Task: $($task.Path)$($task.Name) - $($result.Error)" -ForegroundColor Yellow }
        }
    }

    Write-Host ""
}

<#
    .SYNOPSIS
    Enables known Windows telemetry-related scheduled tasks.

    .DESCRIPTION
    Iterates over a predefined list of Windows scheduled tasks associated with
    telemetry and enables each one that exists and is currently disabled.
    Supports -WhatIf to preview changes without applying them.

    .EXAMPLE
    Enable-TelemetryScheduledTasks
#>
function Enable-TelemetryScheduledTasks {
    Write-Host "> Enabling telemetry scheduled tasks..."
    $tasks = Get-TelemetryScheduledTasks

    foreach ($task in $tasks) {
        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host "[WhatIf] Enable Scheduled Task: $($task.Path)$($task.Name)" -ForegroundColor Cyan
            continue
        }

        $result = Invoke-NonBlocking -ScriptBlock {
            param($path, $name)
            Import-Module ScheduledTasks -ErrorAction SilentlyContinue
            $taskObj = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue
            if (-not $taskObj) {
                return @{ Success = $true; Status = 'NotFound' }
            }
            if ($taskObj.State -eq 'Disabled') {
                try {
                    Enable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
                    return @{ Success = $true; Status = 'Enabled' }
                }
                catch {
                    return @{ Success = $false; Status = 'Error'; Error = $_.Exception.Message }
                }
            }
            return @{ Success = $true; Status = 'AlreadyEnabled' }
        } -ArgumentList @($task.Path, $task.Name)

        switch ($result.Status) {
            'Enabled'        { Write-Host "Enabled Scheduled Task: $($task.Path)$($task.Name)" }
            'AlreadyEnabled' { Write-Host "Scheduled Task $($task.Path)$($task.Name) is already enabled." -ForegroundColor DarkGray }
            'NotFound'       { Write-Host "Scheduled Task $($task.Path)$($task.Name) not found." -ForegroundColor DarkGray }
            'Error'          { Write-Host "Failed to enable Scheduled Task: $($task.Path)$($task.Name) - $($result.Error)" -ForegroundColor Yellow }
        }
    }

    Write-Host ""
}
