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
