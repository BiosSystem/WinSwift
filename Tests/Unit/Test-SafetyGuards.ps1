#Requires -Modules Pester

Describe 'WinSwift startup safety guards' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $script:entryScript = Get-Content (Join-Path $repoRoot 'WinSwift.ps1') -Raw
        $script:adminScript = Get-Content (Join-Path $repoRoot 'Scripts\Helpers\Ensure-Admin.ps1') -Raw
        $script:launcherScript = Get-Content (Join-Path $repoRoot 'Scripts\Get.ps1') -Raw
    }

    It 'stops PowerShell Core before loading runtime modules' {
        $guardPosition = $script:entryScript.IndexOf("if (`$PSVersionTable.PSEdition -eq 'Core')")
        $modulePosition = $script:entryScript.IndexOf('Ensure-Admin.ps1')

        $guardPosition | Should -BeGreaterThan -1
        $guardPosition | Should -BeLessThan $modulePosition
        $script:entryScript | Should -Match "(?s)PSEdition -eq 'Core'.*?exit 1"
    }

    It 'limits Mark-of-the-Web handling to PowerShell source files' {
        $script:entryScript | Should -Match 'Zone\.Identifier'
        $script:entryScript | Should -Match '\.ps1.*\.psm1.*\.psd1'
        $script:entryScript | Should -Match 'Get-ExecutionPolicy -Scope MachinePolicy'
        $script:entryScript | Should -Match 'Get-ExecutionPolicy -Scope UserPolicy'
    }

    It 'uses Win32-safe elevation argument escaping' {
        $script:adminScript | Should -Match 'function Format-ElevatedArg'
        $script:adminScript | Should -Match '\$escaped = \$Value -replace'
        $script:adminScript | Should -Match 'Start-Process powershell\.exe'
        $script:adminScript | Should -Match '-ErrorAction Stop'
    }

    It 'reports the elevation outcome instead of relying on exit' {
        # `exit` inside a dot-sourced script does not terminate the caller, so a
        # non-elevated run used to continue into the apply pipeline.
        $script:adminScript | Should -Match "\`$script:ElevationOutcome = 'Elevated'"
        $script:adminScript | Should -Match "\`$script:ElevationOutcome = 'Denied'"
        $script:adminScript | Should -Match "\`$script:ElevationOutcome = 'Relaunched'"
        $script:adminScript | Should -Match "\`$script:ElevationOutcome = 'Failed'"
        $script:adminScript | Should -Not -Match '(?m)^\s*exit \d'
    }

    It 'stops the run when elevation was not obtained' {
        $guardPosition = $script:entryScript.IndexOf('$script:ElevationOutcome -ne')
        $environmentPosition = $script:entryScript.IndexOf('Initialize-Environment.ps1')

        $guardPosition | Should -BeGreaterThan -1
        $guardPosition | Should -BeLessThan $environmentPosition -Because 'the run must stop before any runtime module loads'
    }

    It 'refuses a non-interactive run that cannot elevate' -Skip:(
        ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    ) {
        # Only meaningful unelevated. CI runners are administrators, so this is
        # skipped there and the source assertions above carry the contract.
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -DryRun -Silent -CLI -DisableTelemetry' -f (Join-Path $repoRoot 'WinSwift.ps1')
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.RedirectStandardInput = $true
        $psi.UseShellExecute = $false

        $process = [System.Diagnostics.Process]::Start($psi)
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEnd()
        $null = $process.WaitForExit(90000)

        $process.ExitCode | Should -Not -Be 0
        $stdout | Should -Not -Match '\[WhatIf\]' -Because 'the apply pipeline must never be reached without elevation'
    }

    It 'quotes bound arrays and unbound arguments during elevation' {
        $script:adminScript | Should -Match 'paramValue -is \[array\]'
        $script:adminScript | Should -Match 'OriginalUnboundArguments'
        $script:adminScript | Should -Match 'Format-ElevatedArg'
    }

    It 'quotes bootstrap arguments before administrator launch' {
        $script:launcherScript | Should -Match 'function Format-LauncherArg'
        $script:launcherScript | Should -Match '\$boundParameter\.Value -is \[array\]'
        $script:launcherScript | Should -Match 'Format-LauncherArg \$argumentValue'
        $script:launcherScript | Should -Match '-ArgumentList \$launchArguments'
    }

    It 'propagates bootstrap launch failures and child exit codes' {
        $script:launcherScript | Should -Match 'Start-Process powershell\.exe.*-ErrorAction Stop'
        $script:launcherScript | Should -Match '\$exitCode = \$debloatProcess\.ExitCode'
        $script:launcherScript | Should -Match 'Exit \$exitCode'
    }
}
