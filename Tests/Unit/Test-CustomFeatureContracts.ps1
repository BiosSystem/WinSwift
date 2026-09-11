#Requires -Modules Pester

Describe 'Winnow custom feature execution contracts' {
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

    It 'keeps the custom undo list in step with Invoke-FeatureUndo' {
        # Test-FeatureIsUndoable trusts this list. A case added to the switch but
        # not listed here would be rejected by -Undo despite being undoable.
        $source = Get-Content (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) 'Scripts\Features\InvokeChanges.ps1') -Raw

        # The list is declared immediately after the function, so the span
        # between them is exactly the switch to check.
        $start = $source.IndexOf('function Invoke-FeatureUndo')
        $end = $source.IndexOf('$script:CustomUndoFeatureIds = @(')
        $start | Should -BeGreaterThan -1
        $end | Should -BeGreaterThan $start

        $undoBody = $source.Substring($start, $end - $start)
        $undoBody | Should -Not -BeNullOrEmpty

        $switchCases = @([regex]::Matches($undoBody, "(?m)^\s{8}'(?<id>[^']+)'\s*\{") | ForEach-Object { $_.Groups['id'].Value })
        $switchCases.Count | Should -BeGreaterThan 0

        foreach ($caseId in $switchCases) {
            $script:CustomUndoFeatureIds | Should -Contain $caseId -Because "Invoke-FeatureUndo handles $caseId, so -Undo must accept it"
        }
    }

    It 'treats a feature with neither an undo reg file nor a custom case as not undoable' {
        $script:Features = @{
            HasUndoReg = [PSCustomObject]@{ FeatureId = 'HasUndoReg'; RegistryUndoKey = 'Undo_Something.reg' }
            NoUndoPath = [PSCustomObject]@{ FeatureId = 'NoUndoPath'; RegistryUndoKey = $null }
            DisableTelemetry = [PSCustomObject]@{ FeatureId = 'DisableTelemetry'; RegistryUndoKey = $null }
        }

        Test-FeatureIsUndoable -FeatureId 'HasUndoReg' | Should -BeTrue
        Test-FeatureIsUndoable -FeatureId 'DisableTelemetry' | Should -BeTrue -Because 'it has a custom undo case'
        Test-FeatureIsUndoable -FeatureId 'NoUndoPath' | Should -BeFalse
        Test-FeatureIsUndoable -FeatureId 'DoesNotExist' | Should -BeFalse
    }
}
