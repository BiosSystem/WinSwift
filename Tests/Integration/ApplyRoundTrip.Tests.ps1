#Requires -Modules Pester
<#
.SYNOPSIS
    Applies a registry-backed feature for real and verifies the result.
.DESCRIPTION
    Tagged Mutating. This writes to the registry of the machine it runs on.
    Run it inside Windows Sandbox, or on a throwaway VM. See README.md.

    This is scenario 1 of Track 3 in the v3.4.0 plan. Scenario 2, the undo half
    of the round trip, is blocked; see the pending test at the bottom.
#>

Describe 'WinSwift apply round trip' -Tag 'Mutating' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'IntegrationCommon.ps1')
        $repoRoot = Get-WinSwiftRepoRoot
        . (Join-Path $repoRoot 'Scripts\Helpers\Get-RegFileOperations.ps1')

        $script:regFile = Join-Path $repoRoot 'Regfiles\Disable_Telemetry.reg'
        $script:profilePath = Join-Path $TestDrive 'applied.json'
        @{ Switches = @('DisableTelemetry') } | ConvertTo-Json |
            Set-Content -LiteralPath $script:profilePath -Encoding utf8
    }

    It 'applies a registry-backed feature and reports it compliant' -Skip:(-not (Test-IsElevated)) {
        $apply = Invoke-WinSwiftProcess -Arguments @('-Silent', '-CLI', '-DisableTelemetry') -TimeoutSeconds 300
        $apply.TimedOut | Should -BeFalse

        $verify = Invoke-WinSwiftProcess -Arguments @('-Verify', '-VerifyProfile', $script:profilePath)
        $verify.TimedOut | Should -BeFalse
        $verify.Stdout | Should -Match 'Compliant\] DisableTelemetry'
        $verify.ExitCode | Should -Be 0
    }

    It 'wrote every value the feature registry file declares' -Skip:(-not (Test-IsElevated)) {
        # Verification reports one verdict for the feature. This checks the
        # individual values underneath it, so a partially applied .reg file
        # cannot pass as compliant.
        $missing = [System.Collections.Generic.List[string]]::new()

        foreach ($operation in @(Get-RegFileOperations -regFilePath $script:regFile)) {
            if ($operation.Type -ne 'SetValue') { continue }

            $psPath = $operation.Path `
                -replace '^HKEY_LOCAL_MACHINE', 'HKLM:' `
                -replace '^HKEY_CURRENT_USER', 'HKCU:'
            if ($psPath -notmatch '^(HKLM|HKCU):') { continue }

            try {
                $null = Get-ItemProperty -LiteralPath $psPath -Name $operation.Name -ErrorAction Stop
            }
            catch {
                $missing.Add(('{0}\{1}' -f $psPath, $operation.Name))
            }
        }

        $missing | Should -BeNullOrEmpty -Because "values the feature should have written are absent: $($missing -join '; ')"
    }

    It 'restores the pre-apply state through undo' -Skip {
        # BLOCKED, not yet implementable.
        #
        # Undo is reachable only from the GUI. WinSwift.ps1 initialises
        # $script:UndoParams to an empty hashtable and the only code that ever
        # populates it is Scripts/GUI/Show-MainWindow.ps1. Invoke-UndoFeatures
        # and the per-feature RegistryUndoKey metadata all exist and all 112
        # features declare undo text, but nothing on the command line can select
        # a feature for undo.
        #
        # Automating this needs a CLI undo surface first. Until then an
        # unattended deployment cannot revert either, which is the larger
        # problem this test is standing in for.
        $true | Should -BeFalse -Because 'this test should not run until a CLI undo surface exists'
    }
}
