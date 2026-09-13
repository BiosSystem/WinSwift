<#
    .SYNOPSIS
        Validates that an import/export configuration is structurally consistent before it is
        applied.

    .DESCRIPTION
        Ported from upstream Win11Debloat (Test-ConfigConsistency), adapted to Winnow: plain
        error strings instead of upstream's Get-Translation, since Winnow has no equivalent
        message-key API. Checks the shared Apps/Tweaks/Deployment import format, not the
        Settings-list format used by DefaultSettings.json.

        Both the CLI import (ImportConfigToParams) and the GUI import (Import-Configuration)
        call this so an invalid config is rejected before any parameter is added. The apply
        pipeline silently skips unrecognised entries, so without this check a malformed config
        could import nothing and still look like it worked.

    .OUTPUTS
        System.String. $null when the config is valid, otherwise the first problem found.
#>
function Test-ConfigConsistency {
    param($Config)

    if (-not $Config) {
        return 'The configuration is empty or could not be read.'
    }

    if (-not $Config.Version) {
        return 'The configuration is missing a Version.'
    }

    if (-not $Config.Apps -and -not $Config.Tweaks -and -not $Config.Deployment) {
        return 'The configuration contains no importable data.'
    }

    # Apps is a flat list of package-id strings.
    if ($null -ne $Config.Apps) {
        if ($Config.Apps -isnot [string] -and $Config.Apps -isnot [System.Collections.IEnumerable]) {
            return 'Apps entries must be strings.'
        }
        foreach ($app in @($Config.Apps)) {
            if ($app -isnot [string]) {
                return 'Apps entries must be strings.'
            }
        }
    }

    # Tweaks and Deployment are lists of { Name, Value } entries.
    foreach ($categoryName in @('Tweaks', 'Deployment')) {
        $category = $Config.$categoryName
        if ($null -eq $category) { continue }

        if ($category -is [string] -or $category -isnot [System.Collections.IEnumerable]) {
            return "$categoryName entries must contain Name and Value properties."
        }
        foreach ($setting in @($category)) {
            $hasName = if ($setting -is [System.Collections.IDictionary]) { $setting.Contains('Name') } else { $null -ne $setting.PSObject.Properties['Name'] }
            $hasValue = if ($setting -is [System.Collections.IDictionary]) { $setting.Contains('Value') } else { $null -ne $setting.PSObject.Properties['Value'] }
            if (-not $setting -or -not $hasName -or -not $hasValue -or $setting.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($setting.Name)) {
                return "$categoryName entries must contain Name and Value properties."
            }
        }
    }

    # Cross-consistency between the app-removal scope and the deployment target. Both are
    # stored as numeric indexes in Deployment; a scope that targets a specific user is only
    # meaningful with a matching deployment target.
    $lookup = @{}
    foreach ($setting in @($Config.Deployment)) {
        if ($setting -and $setting.Name) {
            $lookup[$setting.Name] = $setting.Value
        }
    }

    $hasScope = $lookup.ContainsKey('AppRemovalScopeIndex')
    $hasUser = $lookup.ContainsKey('UserSelectionIndex')

    $scopeIndex = $null
    if ($hasScope) {
        if (-not [int]::TryParse("$($lookup['AppRemovalScopeIndex'])", [ref]$scopeIndex) -or $scopeIndex -notin @(0, 1, 2)) {
            return 'AppRemovalScopeIndex must be a supported numeric value (0, 1, or 2).'
        }
    }

    $userIndex = $null
    if ($hasUser) {
        if (-not [int]::TryParse("$($lookup['UserSelectionIndex'])", [ref]$userIndex) -or $userIndex -notin @(0, 1, 2)) {
            return 'UserSelectionIndex must be a supported numeric value (0, 1, or 2).'
        }
    }

    # Scope 1 ("Current user only") is only valid with the "Current User" target (index 0).
    if ($hasScope -and $scopeIndex -eq 1) {
        if (-not $hasUser -or $userIndex -ne 0) {
            return "AppRemovalScopeIndex 'Current user only' requires the deployment target 'Current User'."
        }
    }

    # Scope 2 ("Target user only") is only valid with the "Other User" target (index 1) and a name.
    if ($hasScope -and $scopeIndex -eq 2) {
        if (-not $hasUser -or $userIndex -ne 1) {
            return "AppRemovalScopeIndex 'Target user only' requires the deployment target 'Other User'."
        }
        if (-not $lookup.ContainsKey('OtherUsername') -or [string]::IsNullOrWhiteSpace("$($lookup['OtherUsername'])")) {
            return "AppRemovalScopeIndex 'Target user only' requires an 'OtherUsername' value."
        }
    }

    return $null
}
