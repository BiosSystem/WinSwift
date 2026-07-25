<#
.SYNOPSIS
    Generates a JSON run summary after a WinSwift apply or undo operation.
.DESCRIPTION
    Collects the operation results, system metadata, and elapsed time, then
    writes a timestamped JSON file to %TEMP%. The GUI surfaces this via a
    "View Last Report" button in the completion modal.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

function Export-RunSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$AppliedFeatureIds,

        [Parameter(Mandatory)]
        [string[]]$UndoneFeatureIds,

        [string[]]$RemovedApps = @(),

        [hashtable[]]$FeatureErrors = @(),

        [Parameter(Mandatory)]
        [datetime]$StartTime,

        [Parameter(Mandatory)]
        [string]$WinSwiftVersion
    )

    $endTime   = Get-Date
    $elapsed   = [math]::Round(($endTime - $StartTime).TotalSeconds, 1)
    $timestamp = $StartTime.ToString('yyyyMMdd_HHmmss')
    $outPath   = Join-Path $env:TEMP "WinSwift_RunSummary_$timestamp.json"

    # Collect Windows build info
    $winBuild = try {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).CurrentBuildNumber
    } catch { 'Unknown' }

    $winVersion = try {
        $reg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        "$($reg.ProductName) $($reg.DisplayVersion)"
    } catch { 'Unknown' }

    # Build applied feature detail list
    $appliedDetails = foreach ($id in $AppliedFeatureIds) {
        $errEntry = $FeatureErrors | Where-Object { $_.FeatureId -eq $id } | Select-Object -First 1
        [ordered]@{
            FeatureId = $id
            Status    = if ($errEntry) { 'Error' } else { 'Applied' }
            Error     = if ($errEntry) { $errEntry.Message } else { $null }
        }
    }

    $undoneDetails = foreach ($id in $UndoneFeatureIds) {
        $errEntry = $FeatureErrors | Where-Object { $_.FeatureId -eq $id } | Select-Object -First 1
        [ordered]@{
            FeatureId = $id
            Status    = if ($errEntry) { 'Error' } else { 'Undone' }
            Error     = if ($errEntry) { $errEntry.Message } else { $null }
        }
    }

    $summary = [ordered]@{
        WinSwiftVersion      = $WinSwiftVersion
        GeneratedAt          = $endTime.ToString('o')
        DurationSeconds      = $elapsed
        WindowsVersion       = $winVersion
        WindowsBuild         = $winBuild
        FeaturesApplied      = @($appliedDetails)
        FeaturesUndone       = @($undoneDetails)
        AppsRemoved          = @($RemovedApps)
        TotalFeaturesChanged = $AppliedFeatureIds.Count + $UndoneFeatureIds.Count
        ErrorCount           = $FeatureErrors.Count
    }

    try {
        $summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $outPath -Encoding UTF8 -Force
        Write-Host ""
        Write-Host "  [Report] Run summary saved to: $outPath" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [WARN] Could not save run summary: $_" -ForegroundColor Yellow
    }

    # Store path on script scope so the GUI can surface it
    $script:LastRunSummaryPath = $outPath
}

function Open-LastRunSummary {
    if (-not [string]::IsNullOrWhiteSpace($script:LastRunSummaryPath) -and (Test-Path $script:LastRunSummaryPath)) {
        Start-Process notepad.exe -ArgumentList $script:LastRunSummaryPath
    } else {
        Write-Host "No run summary available yet." -ForegroundColor DarkGray
    }
}
