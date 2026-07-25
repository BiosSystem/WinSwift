<#
.SYNOPSIS
    Extended AI and Copilot+ purge for Windows 11 24H2/25H2.
.DESCRIPTION
    Targets new AI integrations added in the 24H2/25H2 update cycle that were
    not present in earlier WinSwift AI purge routines: Phone Link deep disable,
    Sluggishness Telemetry tasks, Windows Ink AI suggestions, OneDrive silent
    sign-in suppression, and Copilot Actions permissions lockdown.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

function Disable-ExtendedAIPurge {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "> Running extended AI purge (24H2/25H2 targets)..." -ForegroundColor Cyan

    # 1. Phone Link - deep registry disable
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Phone Link")) {
        $mobilityPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Mobility"
        if (-not (Test-Path $mobilityPath)) { New-Item -Path $mobilityPath -Force | Out-Null }
        Set-ItemProperty -Path $mobilityPath -Name "PhoneLinkEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mobilityPath -Name "OptedIn" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Phone Link disabled"
    }

    # 2. Disable Windows Ink Workspace AI suggestions
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Windows Ink AI")) {
        $inkPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace"
        if (-not (Test-Path $inkPath)) { New-Item -Path $inkPath -Force | Out-Null }
        Set-ItemProperty -Path $inkPath -Name "AllowWindowsInkWorkspace" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Windows Ink Workspace AI disabled"
    }

    # 3. Disable Sluggishness Telemetry (CloudExperienceHost scheduled tasks)
    if ($PSCmdlet.ShouldProcess("Scheduled Tasks", "Disable Sluggishness Telemetry")) {
        $slugTasks = @(
            @{ Path = "\Microsoft\Windows\CloudExperienceHost\"; Name = "CreateObjectTask" },
            @{ Path = "\Microsoft\Windows\Shell\"; Name = "FamilySafetyMonitor" },
            @{ Path = "\Microsoft\Windows\Shell\"; Name = "FamilySafetyRefreshTask" },
            @{ Path = "\Microsoft\Windows\Device Inventory\"; Name = "RunUpdateUserDeviceInventoryTask" }
        )
        foreach ($task in $slugTasks) {
            $taskObj = Get-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction SilentlyContinue
            if ($taskObj -and $taskObj.State -ne 'Disabled') {
                try {
                    Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null
                    Write-Host "  [OK] Disabled task: $($task.Path)$($task.Name)"
                } catch {
                    Write-Host "  [WARN] Could not disable $($task.Name): $_" -ForegroundColor Yellow
                }
            }
        }
    }

    # 4. Suppress OneDrive silent sign-in from Microsoft account
    if ($PSCmdlet.ShouldProcess("Registry", "Suppress OneDrive auto sign-in")) {
        $odPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (-not (Test-Path $odPath)) { New-Item -Path $odPath -Force | Out-Null }
        Set-ItemProperty -Path $odPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        $od2Path = "HKCU:\Software\Microsoft\OneDrive"
        if (Test-Path $od2Path) {
            Set-ItemProperty -Path $od2Path -Name "DisablePersonalSync" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  [OK] OneDrive auto sign-in suppressed"
    }

    # 5. Disable clipboard cloud sync (cross-device clipboard history)
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Cloud Clipboard Sync")) {
        $clipPath = "HKCU:\Software\Microsoft\Clipboard"
        if (-not (Test-Path $clipPath)) { New-Item -Path $clipPath -Force | Out-Null }
        Set-ItemProperty -Path $clipPath -Name "EnableCloudClipboard" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        $clipPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
        if (-not (Test-Path $clipPolicy)) { New-Item -Path $clipPolicy -Force | Out-Null }
        Set-ItemProperty -Path $clipPolicy -Name "AllowCrossDeviceClipboard" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Cloud clipboard sync disabled"
    }

    # 6. Disable Recall snapshot folder (Copilot+ PC)
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Recall")) {
        $recallPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
        if (-not (Test-Path $recallPath)) { New-Item -Path $recallPath -Force | Out-Null }
        Set-ItemProperty -Path $recallPath -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $recallPath -Name "AllowRecallEnablement" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Windows Recall snapshots fully disabled"
    }

    # 7. Disable Photos app Generative Fill (24H2 AI image editing)
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Photos Generative Fill")) {
        $photosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Photos"
        if (-not (Test-Path $photosPath)) { New-Item -Path $photosPath -Force | Out-Null }
        Set-ItemProperty -Path $photosPath -Name "DisableGenerativeFill" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Photos Generative Fill disabled"
    }

    # 8. Disable AI Suggested Clipboard Actions (AI reads clipboard to suggest tasks)
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Suggested Clipboard Actions")) {
        $clipPath = "HKCU:\Software\Microsoft\Clipboard"
        if (-not (Test-Path $clipPath)) { New-Item -Path $clipPath -Force | Out-Null }
        Set-ItemProperty -Path $clipPath -Name "EnableSuggestedClipboardActions" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] AI Suggested Clipboard Actions disabled"
    }

    # 9. Block Microsoft 365 silent auto-install push (delivered via Windows Update post-24H2)
    if ($PSCmdlet.ShouldProcess("Registry", "Block M365 auto-install")) {
        $m365Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common"
        if (-not (Test-Path $m365Path)) { New-Item -Path $m365Path -Force | Out-Null }
        Set-ItemProperty -Path $m365Path -Name "PreventProductInstall" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Microsoft 365 silent auto-install blocked"
    }

    # 10. Disable Copilot in Outlook (new Outlook AI suggestions)
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Outlook Copilot")) {
        $olPath = "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\options\mail"
        if (-not (Test-Path $olPath)) { New-Item -Path $olPath -Force | Out-Null }
        Set-ItemProperty -Path $olPath -Name "DisableCopilot" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Outlook Copilot AI suggestions disabled"
    }

    # 11. Disable Power Automate Desktop UIFlowService autostart
    if ($PSCmdlet.ShouldProcess("Registry", "Disable UIFlowService autostart")) {
        $uiflowKey = "HKLM:\SYSTEM\CurrentControlSet\Services\UIFlowService"
        if (Test-Path $uiflowKey) {
            Set-ItemProperty -Path $uiflowKey -Name "Start" -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Power Automate Desktop UIFlowService set to disabled"
        } else {
            Write-Host "  [SKIP] UIFlowService not found (Power Automate Desktop not installed)" -ForegroundColor DarkGray
        }
    }

    # 12. Disable Narrator AI online voices (24H2 natural AI speech)
    if ($PSCmdlet.ShouldProcess("Registry", "Disable Narrator AI voices")) {
        $narrPath = "HKCU:\Software\Microsoft\Narrator\NoRoam"
        if (-not (Test-Path $narrPath)) { New-Item -Path $narrPath -Force | Out-Null }
        Set-ItemProperty -Path $narrPath -Name "OnlineVoicesEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Narrator AI online voices disabled"
    }

    Write-Host ""
    Write-Host "Extended AI purge complete." -ForegroundColor Green
    Write-Host ""
}

function Enable-ExtendedAIPurgeRevert {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "> Reverting extended AI purge..." -ForegroundColor Cyan

    # Re-enable Phone Link
    $mobilityPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Mobility"
    if (Test-Path $mobilityPath) {
        Set-ItemProperty -Path $mobilityPath -Name "PhoneLinkEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mobilityPath -Name "OptedIn" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    # Re-enable Cloud Clipboard
    $clipPath = "HKCU:\Software\Microsoft\Clipboard"
    if (Test-Path $clipPath) {
        Remove-ItemProperty -Path $clipPath -Name "EnableCloudClipboard" -Force -ErrorAction SilentlyContinue
    }

    Write-Host "  [OK] Extended AI settings reverted (Phone Link and Cloud Clipboard restored)"
    Write-Host ""
}

