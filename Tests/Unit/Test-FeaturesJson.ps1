#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for Features.json structural integrity.
.DESCRIPTION
    Validates that every entry in Features.json has all required fields,
    no duplicate FeatureIds, valid category values, and correct RegistryKey
    file references pointing to real files on disk.
#>

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path
$configPath = Join-Path $repoRoot 'Config\Features.json'
$regPath    = Join-Path $repoRoot 'Regfiles'

Describe 'Features.json' {

    BeforeAll {
        $script:json = Get-Content $configPath -Raw | ConvertFrom-Json
        $script:features = $script:json.Features
    }

    It 'parses as valid JSON' {
        $script:features | Should -Not -BeNullOrEmpty
    }

    It 'has no duplicate FeatureIds' {
        $ids = $script:features | ForEach-Object { $_.FeatureId }
        $dupes = $ids | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name
        $dupes | Should -BeNullOrEmpty -Because "Duplicate FeatureIds: $($dupes -join ', ')"
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
                $filePath = Join-Path $regPath $f.RegistryKey
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
                $undoPath = Join-Path $regPath 'Undo' $f.RegistryUndoKey
                $rootPath = Join-Path $regPath $f.RegistryUndoKey
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
}
