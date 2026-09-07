#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for the preset library and its loader.
#>

Describe 'WinSwift presets' {

    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path
        . (Join-Path $repoRoot 'Scripts\FileIO\LoadJsonFile.ps1')
        . (Join-Path $repoRoot 'Scripts\FileIO\LoadPreset.ps1')

        $script:repoRoot = $repoRoot
        $script:config = Get-Content (Join-Path $repoRoot 'Config\Features.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    BeforeEach {
        $script:Features = @{}
        foreach ($f in $script:config.Features) { $script:Features[$f.FeatureId] = $f }
        $script:FeatureUiGroups = @($script:config.UiGroups)
        $script:PresetsPath = Join-Path $script:repoRoot 'Config\Presets'
    }

    Context 'the shipped library' {

        It 'ships more than one preset' {
            @(Get-AvailablePreset).Count | Should -BeGreaterThan 1
        }

        It 'gives every preset a name and a description' {
            foreach ($preset in Get-AvailablePreset) {
                $preset.PresetName | Should -Not -BeNullOrEmpty -Because "$($preset.Name) needs a PresetName"
                $preset.Description | Should -Not -BeNullOrEmpty -Because "$($preset.Name) needs a Description"
                $preset.Count | Should -BeGreaterThan 0 -Because "$($preset.Name) needs switches"
            }
        }

        It 'loads every shipped preset without error' {
            # This is the drift guard. A preset added with a mistyped switch,
            # a duplicate, or two values from one exclusive group fails here
            # rather than silently applying nothing at runtime.
            foreach ($preset in Get-AvailablePreset) {
                { Import-PresetSwitches -Preset $preset.Name } |
                    Should -Not -Throw -Because "$($preset.Name) must be valid"
            }
        }
    }

    Context 'name resolution' {

        It 'resolves a bare preset name' {
            Resolve-PresetPath -Preset 'gaming-rig' | Should -Not -BeNullOrEmpty
        }

        It 'resolves a name that already carries the extension' {
            Resolve-PresetPath -Preset 'gaming-rig.json' | Should -Not -BeNullOrEmpty
        }

        It 'resolves an explicit path' {
            $path = Join-Path $script:PresetsPath 'gaming-rig.json'
            Resolve-PresetPath -Preset $path | Should -Not -BeNullOrEmpty
        }

        It 'returns nothing for a name that does not exist' {
            Resolve-PresetPath -Preset 'no-such-preset' | Should -BeNullOrEmpty
        }
    }

    Context 'validation' {

        BeforeEach {
            $script:presetFile = Join-Path $TestDrive 'candidate.json'
        }

        function Set-Preset {
            param([string[]]$Switches)
            @{ PresetName = 'Candidate'; Description = 'test'; Switches = $Switches } |
                ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:presetFile -Encoding UTF8
        }

        It 'rejects a switch that does not exist' {
            Set-Preset -Switches @('DisableTelemetry', 'DisableTelemtry')

            { Import-PresetSwitches -Preset $script:presetFile } |
                Should -Throw -ExpectedMessage '*do not exist*DisableTelemtry*'
        }

        It 'rejects the same switch listed twice' {
            Set-Preset -Switches @('DisableTelemetry', 'DisableTelemetry')

            { Import-PresetSwitches -Preset $script:presetFile } |
                Should -Throw -ExpectedMessage '*more than once*'
        }

        It 'rejects a preset that names no switches' {
            Set-Preset -Switches @()

            { Import-PresetSwitches -Preset $script:presetFile } |
                Should -Throw -ExpectedMessage '*does not name any switches*'
        }

        It 'rejects two values from one mutually exclusive group' {
            # UiGroups declares these as alternatives, so both cannot apply.
            Set-Preset -Switches @('ExplorerToThisPC', 'ExplorerToDownloads')

            { Import-PresetSwitches -Preset $script:presetFile } |
                Should -Throw -ExpectedMessage '*more than one value*ExplorerLocation*'
        }

        It 'names the available presets when one is not found' {
            { Import-PresetSwitches -Preset 'no-such-preset' } |
                Should -Throw -ExpectedMessage '*Available presets:*gaming-rig*'
        }

        It 'accepts switches dispatched outside Features.json' {
            # Six switches are handled by explicit blocks in WinSwift.ps1.
            # gaming-rig.json has always relied on them being valid.
            Set-Preset -Switches @('EnableCompetitiveGaming', 'DisableWidgetsDeep')

            { Import-PresetSwitches -Preset $script:presetFile } | Should -Not -Throw
        }

        It 'returns the switches it read' {
            Set-Preset -Switches @('DisableTelemetry', 'DisableCopilot')

            $switches = Import-PresetSwitches -Preset $script:presetFile

            $switches.Count | Should -Be 2
            $switches | Should -Contain 'DisableTelemetry'
        }
    }
}
