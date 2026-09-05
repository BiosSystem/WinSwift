# Shared helpers for the WinSwift integration suite.
#
# Unit tests exercise functions in isolation. These tests run WinSwift.ps1 as a
# real process, which is the only way to cover startup guards, parameter
# binding, config loading, and exit codes together.

function Get-WinSwiftRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Test-IsElevated {
    return ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
    .SYNOPSIS
    Runs WinSwift.ps1 as a child process and captures its result.

    .DESCRIPTION
    stdin is redirected and closed so the run can never block on a prompt. A
    test that hangs is worse than one that fails, so every invocation is bounded
    by TimeoutSeconds and reports TimedOut rather than stalling the suite.

    .PARAMETER Arguments
    Arguments passed through to WinSwift.ps1.

    .PARAMETER TimeoutSeconds
    How long to wait before killing the process. Defaults to 120.
#>
function Invoke-WinSwiftProcess {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    $entryScript = Join-Path (Get-WinSwiftRepoRoot) 'WinSwift.ps1'

    $quoted = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $entryScript))
    foreach ($argument in $Arguments) {
        $quoted += if ($argument -match '[\s"]') { '"{0}"' -f ($argument -replace '"', '\"') } else { $argument }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = ($quoted -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    $psi.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::Start($psi)
    $process.StandardInput.Close()

    # Read stdout before waiting so a large amount of output cannot fill the
    # pipe buffer and deadlock the child.
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) {
        try { $process.Kill() } catch { }
        return [PSCustomObject]@{
            ExitCode = $null
            Stdout = $stdout
            Stderr = $stderr
            TimedOut = $true
        }
    }

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdout
        Stderr = $stderr
        TimedOut = $false
    }
}

<#
    .SYNOPSIS
    Reads the current values of every SetValue operation in a .reg file.

    .DESCRIPTION
    Returns a map of "path\name" to its current value, or $null where the value
    is absent. Comparing two of these across a run is how the dry-run tests
    prove that nothing was written: the assertion targets the exact values the
    feature would have changed rather than a general sweep of the registry.
#>
function Get-RegFileValueSnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath
    )

    $snapshot = @{}
    foreach ($operation in @(Get-RegFileOperations -regFilePath $RegFilePath)) {
        if ($operation.Type -ne 'SetValue') { continue }

        $psPath = $operation.Path `
            -replace '^HKEY_LOCAL_MACHINE', 'HKLM:' `
            -replace '^HKEY_CURRENT_USER', 'HKCU:' `
            -replace '^HKEY_CLASSES_ROOT', 'HKCR:' `
            -replace '^HKEY_USERS', 'HKU:'

        # Only the hives with a default PSDrive are readable here; anything else
        # is skipped rather than guessed at.
        if ($psPath -notmatch '^(HKLM|HKCU):') { continue }

        $key = '{0}\{1}' -f $psPath, $operation.Name
        $current = $null
        try {
            $item = Get-ItemProperty -LiteralPath $psPath -Name $operation.Name -ErrorAction Stop
            $current = $item.$($operation.Name)
        }
        catch {
            $current = $null
        }

        $snapshot[$key] = $current
    }

    return $snapshot
}

function Compare-RegValueSnapshot {
    param(
        [Parameter(Mandatory)][hashtable]$Before,
        [Parameter(Mandatory)][hashtable]$After
    )

    $changed = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $Before.Keys) {
        $old = $Before[$key]
        $new = $After[$key]
        if ("$old" -ne "$new") {
            $changed.Add(('{0}: [{1}] -> [{2}]' -f $key, $old, $new))
        }
    }

    return @($changed)
}
