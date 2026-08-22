#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for Features.json structural integrity.
.DESCRIPTION
    Validates that every entry in Features.json has all required fields,
    no duplicate FeatureIds, valid category values, and correct RegistryKey
    file references pointing to real files on disk.
#>

Describe 'Features.json' {

    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path
        $configPath = Join-Path $repoRoot 'Config\Features.json'
        $script:regPath = Join-Path $repoRoot 'Regfiles'
        $script:json = Get-Content $configPath -Raw | ConvertFrom-Json
        $script:features = $script:json.Features
        $tokens = $null
        $errors = $null
        $entryAst = [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $repoRoot 'WinSwift.ps1'),
            [ref]$tokens,
            [ref]$errors
        )
        $script:entryParameterNames = @($entryAst.ParamBlock.Parameters.Name.VariablePath.UserPath)
    }

    It 'parses as valid JSON' {
        $script:features | Should -Not -BeNullOrEmpty
    }

    It 'has no duplicate FeatureIds' {
        $ids = $script:features | ForEach-Object { $_.FeatureId }
        $dupes = $ids | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name
        $dupes | Should -BeNullOrEmpty -Because "Duplicate FeatureIds: $($dupes -join ', ')"
    }

    It 'exposes every feature through a direct CLI parameter' {
        $missing = @($script:features.FeatureId | Where-Object { $_ -notin $script:entryParameterNames })
        $missing | Should -BeNullOrEmpty -Because "Missing WinSwift.ps1 parameters: $($missing -join ', ')"
    }

    It 'every entry has a non-empty FeatureId' {
        $missing = $script:features | Where-Object { [string]::IsNullOrWhiteSpace($_.FeatureId) }
        $missing.Count | Should -Be 0
    }

    It 'every entry has a non-empty Label' {
        $missing = $script:features | Where-Object { [string]::IsNullOrWhiteSpace($_.Label) }
        $missing.Count | Should -Be 0
    }

    It 'every entry with a RegistryKey has a matching file on disk' {
        $broken = @()
        foreach ($f in $script:features) {
            if (-not [string]::IsNullOrWhiteSpace($f.RegistryKey)) {
                $filePath = Join-Path $script:regPath $f.RegistryKey
                if (-not (Test-Path $filePath)) {
                    $broken += "$($f.FeatureId) -> $($f.RegistryKey)"
                }
            }
        }
        $broken | Should -BeNullOrEmpty -Because "Missing registry files: $($broken -join '; ')"
    }

    It 'every entry with a RegistryUndoKey has a matching Undo file on disk' {
        $broken = @()
        foreach ($f in $script:features) {
            if (-not [string]::IsNullOrWhiteSpace($f.RegistryUndoKey)) {
                $undoPath = Join-Path (Join-Path $script:regPath 'Undo') $f.RegistryUndoKey
                $rootPath = Join-Path $script:regPath $f.RegistryUndoKey
                if (-not (Test-Path $undoPath) -and -not (Test-Path $rootPath)) {
                    $broken += "$($f.FeatureId) -> $($f.RegistryUndoKey)"
                }
            }
        }
        $broken | Should -BeNullOrEmpty -Because "Missing undo registry files: $($broken -join '; ')"
    }

    It 'MinVersion values are null or valid integers' {
        $invalid = $script:features | Where-Object {
            $null -ne $_.MinVersion -and -not ($_.MinVersion -is [int] -or $_.MinVersion -is [long])
        }
        $invalid.Count | Should -Be 0
    }

    It 'uses only supported verification adapters' {
        $supportedAdapters = @(
            'CurrentFeatureState',
            'GamingMode',
            'ExtendedAIPurge',
            'SecurityHardening',
            'TelemetryFirewall'
        )
        $invalid = $script:features | Where-Object {
            $_.VerificationAdapter -and $_.VerificationAdapter -notin $supportedAdapters
        }
        $invalid.Count | Should -Be 0
    }

    It 'declares verification metadata for release custom modules' {
        $required = @(
            'EnableGamingMode',
            'EnableExtendedAIPurge',
            'EnableSecurityHardening',
            'EnableFirewallTelemetryBlock'
        )
        foreach ($featureId in $required) {
            $feature = $script:features | Where-Object FeatureId -eq $featureId
            $feature | Should -Not -BeNullOrEmpty
            $feature.VerificationAdapter | Should -Not -BeNullOrEmpty
            $feature.RequiresRestorePoint | Should -BeTrue
        }
    }
}
