#Requires -Modules Pester

Describe 'WinSwift custom feature execution contracts' {
    BeforeAll {
        . (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) 'Scripts\Features\InvokeChanges.ps1')
        function Enable-GamingMode { }
        function Disable-ExtendedAIPurge { }
        function Enable-SecurityHardening { }
        function Invoke-BlockTelemetryFirewall { param([switch]$WhatIf) }
    }

    BeforeEach {
        $script:Params = @{}
        $script:Features = @{
            EnableGamingMode = [PSCustomObject]@{ ApplyText = 'Enabling gaming mode'; RegistryKey = $null }
            EnableExtendedAIPurge = [PSCustomObject]@{ ApplyText = 'Applying AI purge'; RegistryKey = $null }
            EnableSecurityHardening = [PSCustomObject]@{ ApplyText = 'Applying security hardening'; RegistryKey = $null }
            EnableFirewallTelemetryBlock = [PSCustomObject]@{ ApplyText = 'Blocking telemetry'; RegistryKey = $null }
        }
    }

    It 'routes the gaming profile through the unified feature engine' {
        Mock Enable-GamingMode { }

        Invoke-FeatureApply -FeatureId 'EnableGamingMode'

        Should -Invoke Enable-GamingMode -Times 1
    }

    It 'routes the extended AI purge through the unified feature engine' {
        Mock Disable-ExtendedAIPurge { }

        Invoke-FeatureApply -FeatureId 'EnableExtendedAIPurge'

        Should -Invoke Disable-ExtendedAIPurge -Times 1
    }

    It 'routes security hardening through the unified feature engine' {
        Mock Enable-SecurityHardening { }

        Invoke-FeatureApply -FeatureId 'EnableSecurityHardening'

        Should -Invoke Enable-SecurityHardening -Times 1
    }

    It 'routes telemetry blocking through the unified feature engine' {
        Mock Invoke-BlockTelemetryFirewall { param($WhatIf) }

        Invoke-FeatureApply -FeatureId 'EnableFirewallTelemetryBlock'

        Should -Invoke Invoke-BlockTelemetryFirewall -Times 1
    }
}
