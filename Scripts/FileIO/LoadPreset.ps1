# Loads a preset profile from Config/Presets or from an explicit path.
#
# A preset names feature switches to turn on. Every name is checked before the
# run starts, because an unrecognised switch is dropped later by the apply
# phase without a word, so a single typo used to produce a run that applied
# nothing and still reported success.

# Six switches are dispatched by explicit blocks in Winnow.ps1 rather than
# through Features.json. They are valid in a preset even though they are not
# feature entries, and gaming-rig.json has always relied on that.
$script:PresetExtraSwitches = @(
    'EnablePerformanceTweaks',
    'DisableWindowsAds',
    'EnableCompetitiveGaming',
    'DisableMemoryIntegrity',
    'DisableSettingsAds',
    'DisableWidgetsDeep'
)

<#
    .SYNOPSIS
    Resolves a preset name or path to a file on disk.

    .DESCRIPTION
    A bare name such as 'gaming-rig' is looked up in Config/Presets, with or
    without the .json suffix. Anything else is treated as a path.

    .OUTPUTS
    System.String, or $null when nothing matches.
#>
function Resolve-PresetPath {
    param(
        [Parameter(Mandatory)]
        [string]$Preset,
        [string]$PresetsPath = $script:PresetsPath
    )

    if (-not [string]::IsNullOrWhiteSpace($PresetsPath)) {
        foreach ($candidate in @($Preset, "$Preset.json")) {
            $named = Join-Path $PresetsPath $candidate
            if (Test-Path -LiteralPath $named -PathType Leaf) {
                return $named
            }
        }
    }

    if (Test-Path -LiteralPath $Preset -PathType Leaf) {
        return (Resolve-Path -LiteralPath $Preset).Path
    }

    return $null
}

<#
    .SYNOPSIS
    Lists the presets shipped in Config/Presets.

    .OUTPUTS
    PSCustomObject per preset with Name, PresetName, Description and Count.
#>
function Get-AvailablePreset {
    param(
        [string]$PresetsPath = $script:PresetsPath
    )

    if ([string]::IsNullOrWhiteSpace($PresetsPath) -or -not (Test-Path -LiteralPath $PresetsPath)) {
        return @()
    }

    $results = foreach ($file in Get-ChildItem -LiteralPath $PresetsPath -Filter '*.json' -ErrorAction SilentlyContinue) {
        $data = LoadJsonFile -filePath $file.FullName -optionalFile
        if (-not $data) { continue }

        [PSCustomObject]@{
            Name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            PresetName = [string]$data.PresetName
            Description = [string]$data.Description
            Count = @($data.Switches).Count
        }
    }

    return @($results)
}

<#
    .SYNOPSIS
    Reads a preset and returns the switches it selects.

    .DESCRIPTION
    Throws rather than warns. A preset that cannot be read, names a switch that
    does not exist, or selects two values from the same mutually exclusive
    group is a mistake in the profile, and continuing would apply a different
    configuration from the one asked for.

    Mutual exclusion is read from the UiGroups block in Features.json, so the
    check follows the shipped metadata rather than a list kept in step by hand.

    .OUTPUTS
    System.String[]. The switch names to enable.
#>
function Import-PresetSwitches {
    param(
        [Parameter(Mandatory)]
        [string]$Preset,
        [string]$PresetsPath = $script:PresetsPath
    )

    $path = Resolve-PresetPath -Preset $Preset -PresetsPath $PresetsPath
    if (-not $path) {
        $available = @(Get-AvailablePreset -PresetsPath $PresetsPath | ForEach-Object { $_.Name })
        $hint = if ($available.Count -gt 0) { " Available presets: $($available -join ', ')." } else { '' }
        throw "Preset '$Preset' was not found.$hint"
    }

    $data = LoadJsonFile -filePath $path
    if (-not $data) {
        throw "Preset '$path' could not be read as JSON."
    }

    $switches = @($data.Switches | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    if ($switches.Count -eq 0) {
        throw "Preset '$path' does not name any switches."
    }

    $unknown = @($switches | Where-Object {
        -not $script:Features.ContainsKey($_) -and $_ -notin $script:PresetExtraSwitches
    })
    if ($unknown.Count -gt 0) {
        throw "Preset '$path' names switches that do not exist: $($unknown -join ', ')."
    }

    $duplicates = @($switches | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    if ($duplicates.Count -gt 0) {
        throw "Preset '$path' lists the same switch more than once: $($duplicates -join ', ')."
    }

    foreach ($group in @($script:FeatureUiGroups)) {
        $groupIds = @($group.Values | ForEach-Object { $_.FeatureIds })
        $selected = @($switches | Where-Object { $_ -in $groupIds })
        if ($selected.Count -gt 1) {
            throw "Preset '$path' selects more than one value for '$($group.GroupId)': $($selected -join ', ')."
        }
    }

    return $switches
}
