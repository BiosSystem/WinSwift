Describe 'WinSwift desired-state verification' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        function Test-FeatureApplied { return $false }
        function Invoke-FeatureApply { param($FeatureId) }
        function Invoke-FeatureUndo { param($FeatureId) }
        function ImportRegistryFile { param($Message, $Path) }
        function Resolve-UndoRegFilePath { param($FileName) return $FileName }
        . (Join-Path $repoRoot 'Scripts\Features\DesiredStateVerification.ps1')
    }

    BeforeEach {
        $script:Params = @{}
        $script:ControlParams = @('Verify', 'VerifyProfile', 'Silent')
        $script:Features = @{
            DisableTelemetry = [PSCustomObject]@{
                FeatureId = 'DisableTelemetry'
                RegistryKey = 'Disable_Telemetry.reg'
            }
            RemoveApps = [PSCustomObject]@{
                FeatureId = 'RemoveApps'
                RegistryKey = $null
            }
            EnableGamingMode = [PSCustomObject]@{
                FeatureId = 'EnableGamingMode'
                RegistryKey = $null
                VerificationAdapter = 'GamingMode'
            }
            EnableExtendedAIPurge = [PSCustomObject]@{
                FeatureId = 'EnableExtendedAIPurge'
                RegistryKey = $null
                VerificationAdapter = 'ExtendedAIPurge'
            }
            EnableSecurityHardening = [PSCustomObject]@{
                FeatureId = 'EnableSecurityHardening'
                RegistryKey = $null
                VerificationAdapter = 'SecurityHardening'
            }
            EnableFirewallTelemetryBlock = [PSCustomObject]@{
                FeatureId = 'EnableFirewallTelemetryBlock'
                RegistryKey = $null
                VerificationAdapter = 'TelemetryFirewall'
            }
        }
    }

    It 'reports a compliant registry-backed feature' {
        Mock Test-FeatureApplied { $true }

        $result = Test-WinSwiftFeature -FeatureId 'DisableTelemetry'

        $result.Status | Should -Be 'Compliant'
        $result.DesiredState | Should -Be 'Applied'
    }

    It 'routes apply operations through the feature contract' {
        Mock Invoke-FeatureApply { }

        Invoke-WinSwiftFeature -FeatureId 'DisableTelemetry'

        Should -Invoke Invoke-FeatureApply -Times 1 -ParameterFilter { $FeatureId -eq 'DisableTelemetry' }
    }

    It 'routes undo operations through the feature contract' {
        Mock Invoke-FeatureUndo { }

        Undo-WinSwiftFeature -FeatureId 'DisableTelemetry'

        Should -Invoke Invoke-FeatureUndo -Times 1 -ParameterFilter { $FeatureId -eq 'DisableTelemetry' }
    }

    It 'reports a noncompliant registry-backed feature' {
        Mock Test-FeatureApplied { $false }

        $result = Test-WinSwiftFeature -FeatureId 'DisableTelemetry'

        $result.Status | Should -Be 'NonCompliant'
    }

    It 'reports unknown feature metadata as unsupported' {
        $result = Test-WinSwiftFeature -FeatureId 'UnknownFeature'

        $result.Status | Should -Be 'Unsupported'
    }

    It 'verifies each requested Appx target' {
        Mock Test-WinSwiftAppRemoved { param($AppId) return $AppId -eq 'Removed.App' }

        $results = @(Test-WinSwiftFeature -FeatureId 'RemoveApps' -AppIds @('Removed.App', 'Present.App'))

        $results.Count | Should -Be 2
        ($results | Where-Object Target -eq 'Removed.App').Status | Should -Be 'Compliant'
        ($results | Where-Object Target -eq 'Present.App').Status | Should -Be 'NonCompliant'
    }

    It 'loads feature and app targets from a profile' {
        $profilePath = Join-Path $TestDrive 'profile.json'
        @{
            Switches = @('DisableTelemetry')
            Apps = @('Microsoft.TestApp')
        } | ConvertTo-Json | Set-Content -LiteralPath $profilePath

        $input = Get-WinSwiftVerificationInput -ProfilePath $profilePath -Parameters @{}

        $input.FeatureIds | Should -Contain 'DisableTelemetry'
        $input.FeatureIds | Should -Contain 'RemoveApps'
        $input.AppIds | Should -Contain 'Microsoft.TestApp'
    }

    It 'dispatches every release custom verification adapter' {
        Mock Test-WinSwiftCustomFeatureState { $true }

        $featureIds = @(
            'EnableGamingMode',
            'EnableExtendedAIPurge',
            'EnableSecurityHardening',
            'EnableFirewallTelemetryBlock'
        )
        foreach ($featureId in $featureIds) {
            $result = Test-WinSwiftFeature -FeatureId $featureId
            $result.Status | Should -Be 'Compliant'
        }

        Should -Invoke Test-WinSwiftCustomFeatureState -Times 4
    }

    It 'reports custom feature drift as noncompliant' {
        Mock Test-WinSwiftCustomFeatureState { $false }

        $result = Test-WinSwiftFeature -FeatureId 'EnableSecurityHardening'

        $result.Status | Should -Be 'NonCompliant'
    }
}
