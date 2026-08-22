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
        $supportedCustomFeatures = @(
            'DisableWidgets',
            'DisableStoreSearchSuggestions',
            'EnableWindowsSandbox',
            'EnableWindowsSubsystemForLinux',
            'DisableTelemetryServices'
        )
        if (-not $feature.RegistryKey -and $FeatureId -notin $supportedCustomFeatures) {
            return New-WinSwiftVerificationResult -FeatureId $FeatureId -Target $FeatureId -Status Unsupported -Details 'No desired-state test is defined for this custom feature.'
        }

        $isApplied = if ($script:Params.ContainsKey('Sysprep') -or $script:Params.ContainsKey('User')) {
            $targetUserName = if ($script:Params.ContainsKey('Sysprep')) { 'Default' } else { $script:Params.User }
            Invoke-WithTargetUserHive -TargetUserName $targetUserName -ArgumentObject $FeatureId -ScriptBlock {
                param($TargetFeatureId)
                Test-FeatureApplied -FeatureId $TargetFeatureId
            }
        }
        else {
            Test-FeatureApplied -FeatureId $FeatureId
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
