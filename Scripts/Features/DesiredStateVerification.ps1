function Invoke-WinSwiftFeature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    if (-not $script:Features.ContainsKey($FeatureId)) {
        throw "Unknown WinSwift feature: $FeatureId"
    }

    Invoke-FeatureApply -FeatureId $FeatureId
}

function Undo-WinSwiftFeature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    if (-not $script:Features.ContainsKey($FeatureId)) {
        throw "Unknown WinSwift feature: $FeatureId"
    }

    $feature = $script:Features[$FeatureId]
    $undoText = if ($feature.ApplyUndoText) { $feature.ApplyUndoText } else { $FeatureId }
    if ($feature.RegistryUndoKey) {
        ImportRegistryFile "> $undoText" (Resolve-UndoRegFilePath $feature.RegistryUndoKey)
    }

    Invoke-FeatureUndo -FeatureId $FeatureId
}

function Get-WinSwiftFeatureAppIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId,
        [string[]]$RequestedAppIds
    )

    switch ($FeatureId) {
        'RemoveApps' {
            if ($RequestedAppIds) {
                return @($RequestedAppIds)
            }
            return @(GenerateAppsList)
        }
        'RemoveGamingApps' {
            return @('Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay')
        }
        'RemoveHPApps' {
            return @(
                'AD2F1837.HPAIExperienceCenter',
                'AD2F1837.HPJumpStarts',
                'AD2F1837.HPPCHardwareDiagnosticsWindows',
                'AD2F1837.HPPowerManager',
                'AD2F1837.HPPrivacySettings',
                'AD2F1837.HPSupportAssistant',
                'AD2F1837.HPSureShieldAI',
                'AD2F1837.HPSystemInformation',
                'AD2F1837.HPQuickDrop',
                'AD2F1837.HPWorkWell',
                'AD2F1837.myHP',
                'AD2F1837.HPDesktopSupportUtilities',
                'AD2F1837.HPQuickTouch',
                'AD2F1837.HPEasyClean',
                'AD2F1837.HPConnectedMusic',
                'AD2F1837.HPFileViewer',
                'AD2F1837.HPRegistration',
                'AD2F1837.HPWelcome',
                'AD2F1837.HPConnectedPhotopoweredbySnapfish',
                'AD2F1837.HPPrinterControl'
            )
        }
        default {
            return @()
        }
    }
}

function Test-WinSwiftAppRemoved {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        [string]$Scope = 'AllUsers'
    )

    if ($Scope -eq 'AllUsers') {
        $installed = @(Get-AppxPackage -Name $AppId -AllUsers -ErrorAction SilentlyContinue)
        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -like $AppId -or
                $_.PackageName -like "$AppId*"
            })
    }
    elseif ($Scope -eq 'CurrentUser') {
        $installed = @(Get-AppxPackage -Name $AppId -ErrorAction SilentlyContinue)
        $provisioned = @()
    }
    else {
        $targetSid = ResolveUserSid -UserName $Scope
        if ([string]::IsNullOrWhiteSpace($targetSid)) {
            throw "Unable to resolve Appx verification target user: $Scope"
        }
        $installed = @(Get-AppxPackage -Name $AppId -User $targetSid -ErrorAction SilentlyContinue)
        $provisioned = @()
    }

    return ($installed.Count -eq 0 -and $provisioned.Count -eq 0)
}

function Test-WinSwiftRegistryExpectations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Expectations
    )

    foreach ($expectation in $Expectations) {
        try {
            $actual = Get-ItemPropertyValue -LiteralPath $expectation.Path -Name $expectation.Name -ErrorAction Stop
        }
        catch {
            return $false
        }

        if ($actual -ne $expectation.Value) {
            return $false
        }
    }

    return $true
}

function Test-WinSwiftGamingModeState {
    $expectations = @(
        @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseSpeed'; Value = '0' },
        @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold1'; Value = '0' },
        @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseThreshold2'; Value = '0' },
        @{ Path = 'HKCU:\Control Panel\Accessibility\StickyKeys'; Name = 'Flags'; Value = '506' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Value = 0 },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; Name = 'StartupDelayInMSec'; Value = 0 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name = 'HwSchMode'; Value = 2 },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance'; Name = 'MaintenanceDisabled'; Value = 1 }
    )
    if (-not (Test-WinSwiftRegistryExpectations -Expectations $expectations)) {
        return $false
    }

    $interfaceKeys = @(Get-ChildItem -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue)
    if ($interfaceKeys.Count -eq 0) {
        return $false
    }
    foreach ($interfaceKey in $interfaceKeys) {
        $interfaceExpectations = @(
            @{ Path = $interfaceKey.PSPath; Name = 'TcpAckFrequency'; Value = 1 },
            @{ Path = $interfaceKey.PSPath; Name = 'TCPNoDelay'; Value = 1 }
        )
        if (-not (Test-WinSwiftRegistryExpectations -Expectations $interfaceExpectations)) {
            return $false
        }
    }

    try {
        $powerCfg = Get-Command powercfg.exe -ErrorAction Stop
        $activeScheme = (& $powerCfg.Source /getactivescheme 2>$null | Out-String)
        return ($activeScheme -match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c')
    }
    catch {
        return $false
    }
}

function Test-WinSwiftExtendedAIPurgeState {
    $expectations = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Mobility'; Name = 'PhoneLinkEnabled'; Value = 0 },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Mobility'; Name = 'OptedIn'; Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace'; Name = 'AllowWindowsInkWorkspace'; Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name = 'DisableFileSyncNGSC'; Value = 1 },
        @{ Path = 'HKCU:\Software\Microsoft\Clipboard'; Name = 'EnableCloudClipboard'; Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowCrossDeviceClipboard'; Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'AllowRecallEnablement'; Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Photos'; Name = 'DisableGenerativeFill'; Value = 1 },
        @{ Path = 'HKCU:\Software\Microsoft\Clipboard'; Name = 'EnableSuggestedClipboardActions'; Value = 0 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common'; Name = 'PreventProductInstall'; Value = 1 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1 },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\options\mail'; Name = 'DisableCopilot'; Value = 1 },
        @{ Path = 'HKCU:\Software\Microsoft\Narrator\NoRoam'; Name = 'OnlineVoicesEnabled'; Value = 0 }
    )
    if (-not (Test-WinSwiftRegistryExpectations -Expectations $expectations)) {
        return $false
    }

    if (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\OneDrive') {
        if (-not (Test-WinSwiftRegistryExpectations -Expectations @(
            @{ Path = 'HKCU:\Software\Microsoft\OneDrive'; Name = 'DisablePersonalSync'; Value = 1 }
        ))) {
            return $false
        }
    }
    if (Test-Path -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\UIFlowService') {
        if (-not (Test-WinSwiftRegistryExpectations -Expectations @(
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\UIFlowService'; Name = 'Start'; Value = 4 }
        ))) {
            return $false
        }
    }

    $tasks = @(
        @{ Path = '\Microsoft\Windows\CloudExperienceHost\'; Name = 'CreateObjectTask' },
        @{ Path = '\Microsoft\Windows\Shell\'; Name = 'FamilySafetyMonitor' },
        @{ Path = '\Microsoft\Windows\Shell\'; Name = 'FamilySafetyRefreshTask' },
        @{ Path = '\Microsoft\Windows\Device Inventory\'; Name = 'RunUpdateUserDeviceInventoryTask' }
    )
    foreach ($task in $tasks) {
        $scheduledTask = Get-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction SilentlyContinue
        if ($scheduledTask -and $scheduledTask.State -ne 'Disabled') {
            return $false
        }
    }

    return $true
}

function Test-WinSwiftSecurityHardeningState {
    $expectations = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'; Name = 'fDenyTSConnections'; Value = 1 },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoDriveTypeAutoRun'; Value = 255 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'; Name = 'Enabled'; Value = 0 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'; Name = 'DisabledByDefault'; Value = 1 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'; Name = 'Enabled'; Value = 0 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'; Name = 'DisabledByDefault'; Value = 1 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'; Name = 'Enabled'; Value = 0 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'; Name = 'DisabledByDefault'; Value = 1 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'; Name = 'Enabled'; Value = 0 },
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'; Name = 'DisabledByDefault'; Value = 1 },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings'; Name = 'Enabled'; Value = 0 }
    )
    if (-not (Test-WinSwiftRegistryExpectations -Expectations $expectations)) {
        return $false
    }

    try {
        $smbConfiguration = Get-SmbServerConfiguration -ErrorAction Stop
        if ($smbConfiguration.EnableSMB1Protocol -ne $false) {
            return $false
        }
        $smbFeature = Get-WindowsOptionalFeature -Online -FeatureName 'SMB1Protocol' -ErrorAction Stop
        if ($smbFeature.State -notin @('Disabled', 'DisabledWithPayloadRemoved')) {
            return $false
        }
    }
    catch {
        return $false
    }

    $portRules = @(
        @{ Name = 'Block-RPC-135'; Port = '135' },
        @{ Name = 'Block-NetBIOS-139'; Port = '139' },
        @{ Name = 'Block-SMB-445'; Port = '445' }
    )
    foreach ($expectedRule in $portRules) {
        $rules = @(Get-NetFirewallRule -DisplayName $expectedRule.Name -ErrorAction SilentlyContinue |
            Where-Object { $_.Enabled -eq $true -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Block' })
        if ($rules.Count -eq 0) {
            return $false
        }
        $portMatches = @($rules | ForEach-Object {
            Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_ -ErrorAction SilentlyContinue
        } | Where-Object { $_.Protocol -eq 'TCP' -and $_.LocalPort -contains $expectedRule.Port })
        if ($portMatches.Count -eq 0) {
            return $false
        }
    }

    return $true
}

function Test-WinSwiftTelemetryFirewallState {
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $hostsContent = if (Test-Path -LiteralPath $hostsPath) {
        Get-Content -LiteralPath $hostsPath -Raw -ErrorAction SilentlyContinue
    }
    else {
        ''
    }

    foreach ($domain in @(Get-WinSwiftTelemetryDomains)) {
        $ruleName = "WinSwift_BlockTelemetry_$domain"
        $firewallMatch = @(Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue |
            Where-Object { $_.Enabled -eq $true -and $_.Direction -eq 'Outbound' -and $_.Action -eq 'Block' }).Count -gt 0
        $hostsMatch = $hostsContent -match ("(?m)^\s*0\.0\.0\.0\s+{0}\s*$" -f [regex]::Escape($domain))
        if (-not $firewallMatch -and -not $hostsMatch) {
            return $false
        }
    }

    return $true
}

function Test-WinSwiftCustomFeatureState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId,
        [Parameter(Mandatory)]
        [string]$Adapter
    )

    switch ($Adapter) {
        'CurrentFeatureState' { return (Test-FeatureApplied -FeatureId $FeatureId) }
        'GamingMode' { return (Test-WinSwiftGamingModeState) }
        'ExtendedAIPurge' { return (Test-WinSwiftExtendedAIPurgeState) }
        'SecurityHardening' { return (Test-WinSwiftSecurityHardeningState) }
        'TelemetryFirewall' { return (Test-WinSwiftTelemetryFirewallState) }
        default { throw "Unknown verification adapter: $Adapter" }
    }
}

function New-WinSwiftVerificationResult {
    param(
        [string]$FeatureId,
        [string]$Target,
        [ValidateSet('Compliant', 'NonCompliant', 'Unsupported', 'Error')]
        [string]$Status,
        [string]$Details
    )

    [PSCustomObject]@{
        FeatureId = $FeatureId
        Target = $Target
        DesiredState = 'Applied'
        Status = $Status
        Details = $Details
    }
}

function Test-WinSwiftFeature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId,
        [string[]]$AppIds
    )

    if (-not $script:Features.ContainsKey($FeatureId)) {
        return New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $FeatureId -Status Unsupported -Details 'Feature metadata is unavailable.'
    }

    try {
        if ($FeatureId -in @('RemoveApps', 'RemoveGamingApps', 'RemoveHPApps')) {
            $targets = @(Get-WinSwiftFeatureAppIds -FeatureId $FeatureId -RequestedAppIds $AppIds)
            if ($targets.Count -eq 0) {
                return New-WinSwiftVerificationResult -FeatureId $FeatureId -Target 'Appx' -Status Unsupported -Details 'No Appx targets were supplied.'
            }

            $appRemovalScope = if ($script:Params.ContainsKey('AppRemovalTarget')) {
                [string]$script:Params.AppRemovalTarget
            }
            else {
                'AllUsers'
            }
            $results = foreach ($appId in $targets) {
                if (Test-WinSwiftAppRemoved -AppId $appId -Scope $appRemovalScope) {
                    New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $appId -Status Compliant -Details 'Appx package and provisioned package are absent.'
                }
                else {
                    New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $appId -Status NonCompliant -Details 'Appx package or provisioned package is present.'
                }
            }
            return @($results)
        }

        $feature = $script:Features[$FeatureId]
        $adapter = if ($feature.RegistryKey) { 'CurrentFeatureState' } else { [string]$feature.VerificationAdapter }
        if ([string]::IsNullOrWhiteSpace($adapter)) {
            return New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $FeatureId -Status Unsupported -Details 'No desired-state test is defined for this custom feature.'
        }

        $isApplied = if ($script:Params.ContainsKey('Sysprep') -or $script:Params.ContainsKey('User')) {
            $targetUserName = if ($script:Params.ContainsKey('Sysprep')) { 'Default' } else { $script:Params.User }
            $verificationRequest = [PSCustomObject]@{ FeatureId = $FeatureId; Adapter = $adapter }
            Invoke-WithTargetUserHive -TargetUserName $targetUserName -ArgumentObject $verificationRequest -ScriptBlock {
                param($Request)
                Test-WinSwiftCustomFeatureState -FeatureId $Request.FeatureId -Adapter $Request.Adapter
            }
        }
        else {
            Test-WinSwiftCustomFeatureState -FeatureId $FeatureId -Adapter $adapter
        }

        if ($isApplied) {
            return New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $FeatureId -Status Compliant -Details 'The current state matches the feature definition.'
        }

        return New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $FeatureId -Status NonCompliant -Details 'The current state does not match the feature definition.'
    }
    catch {
        return New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $FeatureId -Status Error -Details $_.Exception.Message
    }
}

function Get-WinSwiftVerificationInput {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$ProfilePath,
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    $featureIds = [System.Collections.Generic.List[string]]::new()
    $appIds = [System.Collections.Generic.List[string]]::new()

    foreach ($name in $Parameters.Keys) {
        if ($name -notin $script:ControlParams -and $name -notin @('Apps', 'SoftwareList', 'UnattendOutPath', 'CreateRestorePoint') -and $name -notin $featureIds) {
            $featureIds.Add($name)
        }
    }

    if ($Parameters.ContainsKey('Apps') -and $Parameters.Apps -is [string] -and $Parameters.Apps -ne 'Default') {
        foreach ($appId in $Parameters.Apps.Split(',')) {
            if (-not [string]::IsNullOrWhiteSpace($appId)) {
                $appIds.Add($appId.Trim())
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ProfilePath)) {
        $resolvedPath = (Resolve-Path -LiteralPath $ProfilePath -ErrorAction Stop).Path
        $profile = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        foreach ($name in @($profile.Switches)) {
            if ($name -is [string] -and $name -notin $featureIds) {
                $featureIds.Add($name)
            }
        }

        foreach ($setting in @($profile.Tweaks) + @($profile.Settings)) {
            if ($setting -and $setting.Name -and $setting.Value -eq $true -and $setting.Name -ne 'CreateRestorePoint' -and $setting.Name -notin $featureIds) {
                $featureIds.Add([string]$setting.Name)
            }
        }

        foreach ($appId in @($profile.Apps)) {
            if ($appId -is [string] -and -not [string]::IsNullOrWhiteSpace($appId)) {
                $appIds.Add($appId.Trim())
            }
        }

        if ($appIds.Count -gt 0 -and 'RemoveApps' -notin $featureIds) {
            $featureIds.Add('RemoveApps')
        }
    }

    if ($featureIds.Count -eq 0) {
        throw 'No verifiable features were selected. Supply feature switches or a profile path.'
    }

    [PSCustomObject]@{
        FeatureIds = @($featureIds)
        AppIds = @($appIds)
    }
}

function Invoke-WinSwiftVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$FeatureIds,
        [string[]]$AppIds
    )

    $results = foreach ($featureId in $FeatureIds) {
        Test-WinSwiftFeature -FeatureId $featureId -AppIds $AppIds
    }
    $results = @($results)

    Write-Host ''
    Write-Host 'WinSwift desired-state verification' -ForegroundColor Cyan
    foreach ($result in $results) {
        $color = switch ($result.Status) {
            'Compliant' { 'Green' }
            'NonCompliant' { 'Yellow' }
            default { 'Red' }
        }
        Write-Host ("[{0}] {1}: {2}" -f $result.Status, $result.Target, $result.Details) -ForegroundColor $color
    }

    $failedCount = @($results | Where-Object Status -eq 'NonCompliant').Count
    $errorCount = @($results | Where-Object Status -in @('Error', 'Unsupported')).Count
    Write-Host ("Verification complete: {0} compliant, {1} noncompliant, {2} error or unsupported." -f
        @($results | Where-Object Status -eq 'Compliant').Count,
        $failedCount,
        $errorCount)

    [PSCustomObject]@{
        Results = $results
        FailedCount = $failedCount
        ErrorCount = $errorCount
    }
}
