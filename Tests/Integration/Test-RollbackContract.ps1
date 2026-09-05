#Requires -Modules Pester
<#
.SYNOPSIS
    Executable specification for the Track 1 automatic rollback feature.
.DESCRIPTION
    Tagged Mutating. Runs inside Windows Sandbox only. See README.md.

    These are scenarios 3 and 4 of Track 3 in the v3.4.0 plan, and they are the
    reason Track 3 lands before Track 1: without them, auto-rollback is an
    untested claim.

    Rollback does not exist yet. Rather than sit in a comment, the contract is
    written as assertions that skip themselves until InvokeChanges.ps1 actually
    references the restore entry point. When Track 1 wires it up, these run.

    They also pin the two open decisions in section 9 of the plan. If the
    failure policy changes, these assertions are what has to change with it.
#>

BeforeDiscovery {
    $invokeChanges = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) 'Scripts\Features\InvokeChanges.ps1'
    $script:RollbackImplemented = (Test-Path -LiteralPath $invokeChanges) -and
        ((Get-Content -LiteralPath $invokeChanges -Raw) -match 'Restore-RegistryBackupState')
}

Describe 'WinSwift automatic rollback' -Tag 'Mutating' -Skip:(-not $script:RollbackImplemented) {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'IntegrationCommon.ps1')
        $repoRoot = Get-WinSwiftRepoRoot
        . (Join-Path $repoRoot 'Scripts\Helpers\Get-RegFileOperations.ps1')
        $script:regFile = Join-Path $repoRoot 'Regfiles\Disable_Telemetry.reg'
    }

    Context 'when a registry import fails' {

        It 'restores the values captured before the apply phase' {
            $before = Get-RegFileValueSnapshot -RegFilePath $script:regFile

            # The injection mechanism is Track 1's to define. A corrupt .reg in a
            # copied Regfiles directory is the least invasive option and keeps the
            # failure inside the import step rather than the harness.
            $result = Invoke-WinSwiftProcess -Arguments @('-Silent', '-CLI', '-DisableTelemetry') -TimeoutSeconds 300

            $result.TimedOut | Should -BeFalse

            $after = Get-RegFileValueSnapshot -RegFilePath $script:regFile
            $changed = Compare-RegValueSnapshot -Before $before -After $after
            $changed | Should -BeNullOrEmpty -Because "rollback should have restored: $($changed -join '; ')"
        }

        It 'records the rollback in the run summary' {
            # Plan section 3.3: the run summary gains a rollback section saying
            # whether it triggered, what triggered it, and whether it succeeded.
            $summary = Get-ChildItem -Path $env:TEMP -Filter 'WinSwift*Summary*.json' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

            $summary | Should -Not -BeNullOrEmpty
            $content = Get-Content -LiteralPath $summary.FullName -Raw | ConvertFrom-Json
            $content.PSObject.Properties.Name | Should -Contain 'Rollback'
        }

        It 'returns an exit code distinct from plain failure and from verification drift' {
            # Plan section 3.3: "failed and was rolled back" needs its own code.
            # Exit 2 already means verification noncompliance and must not be reused.
            $result = Invoke-WinSwiftProcess -Arguments @('-Silent', '-CLI', '-DisableTelemetry') -TimeoutSeconds 300

            $result.ExitCode | Should -Not -Be 0
            $result.ExitCode | Should -Not -Be 2
        }
    }

    Context 'when only an app removal fails' {

        It 'does not roll back' {
            # The load-bearing case. A registry restore cannot bring back an
            # uninstalled Appx package, so rolling back here would report a
            # recovery that did not happen while the apps stay gone.
            $before = Get-RegFileValueSnapshot -RegFilePath $script:regFile

            $result = Invoke-WinSwiftProcess -Arguments @(
                '-Silent', '-CLI', '-DisableTelemetry',
                '-RemoveApps', '-Apps', 'WinSwift.IntegrationTest.NotAReal.Package'
            ) -TimeoutSeconds 300

            $result.TimedOut | Should -BeFalse

            $after = Get-RegFileValueSnapshot -RegFilePath $script:regFile
            $changed = Compare-RegValueSnapshot -Before $before -After $after
            $changed | Should -Not -BeNullOrEmpty -Because 'the registry changes should have been kept, not reverted'
        }
    }

    Context 'when rollback is disabled' {

        It 'leaves the half-applied state in place under -NoAutoRollback' {
            # Plan section 3.3: an operator who would rather inspect a broken
            # state than have it reverted underneath them.
            $result = Invoke-WinSwiftProcess -Arguments @(
                '-Silent', '-CLI', '-DisableTelemetry', '-NoAutoRollback'
            ) -TimeoutSeconds 300

            $result.TimedOut | Should -BeFalse
            $result.Stdout | Should -Not -Match 'Applying registry restore'
        }

        It 'warns at run start when -SkipRegistryBackup removes the safety net' {
            # Plan section 3.4: this must fail loudly up front, not silently at
            # the moment rollback is needed.
            $result = Invoke-WinSwiftProcess -Arguments @(
                '-Silent', '-CLI', '-DisableTelemetry', '-SkipRegistryBackup'
            ) -TimeoutSeconds 300

            $result.TimedOut | Should -BeFalse
            $result.Stdout | Should -Match 'rollback'
        }
    }

    Context 'dry runs' {

        It 'never restores anything under -WhatIf' {
            $result = Invoke-WinSwiftProcess -Arguments @('-DryRun', '-Silent', '-CLI', '-DisableTelemetry')

            $result.TimedOut | Should -BeFalse
            $result.Stdout | Should -Not -Match 'Applying registry restore'
        }
    }
}
