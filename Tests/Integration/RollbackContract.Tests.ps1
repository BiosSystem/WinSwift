#Requires -Modules Pester
<#
.SYNOPSIS
    Contract for automatic rollback after a failed apply.
.DESCRIPTION
    Tagged Mutating. Runs inside Windows Sandbox only. See README.md.

    Scenarios 3 and 4 of Track 3 in the v3.4.0 plan, and the reason Track 3
    landed before Track 1: without these, auto-rollback is an untested claim.

    Failure is injected by copying the repository and corrupting one .reg file
    in the copy, so the failure happens inside the import step rather than in
    the harness, and the real repository is never modified.

    The corrupted feature is not the one under observation. Telemetry values are
    written successfully first, then the second feature's import fails, so a
    correct rollback has something real to restore.
#>

BeforeDiscovery {
    $invokeChanges = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) 'Scripts\Features\InvokeChanges.ps1'
    $script:RollbackImplemented = (Test-Path -LiteralPath $invokeChanges) -and
        ((Get-Content -LiteralPath $invokeChanges -Raw) -match 'Restore-RegistryBackupState')
}

Describe 'WinSwift automatic rollback' -Tag 'Mutating' -Skip:(-not $script:RollbackImplemented) {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'IntegrationCommon.ps1')
        $script:repoRoot = Get-WinSwiftRepoRoot
        . (Join-Path $script:repoRoot 'Scripts\Helpers\Get-RegFileOperations.ps1')

        $script:watchedRegFile = Join-Path $script:repoRoot 'Regfiles\Disable_Telemetry.reg'

        <#
            Copies the repository and breaks one feature's .reg file, then runs
            the copy. Returns the process result.
        #>
        function Invoke-WinSwiftWithBrokenFeature {
            param(
                [Parameter(Mandatory)][string]$BreakRegFile,
                [string[]]$Arguments
            )

            $sandboxRoot = Join-Path $TestDrive ('run-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            Copy-Item -LiteralPath $script:repoRoot -Destination $sandboxRoot -Recurse -Force

            $target = Join-Path $sandboxRoot "Regfiles\$BreakRegFile"
            if (-not (Test-Path -LiteralPath $target)) {
                throw "Cannot inject a failure: $target is missing from the copy."
            }

            # Removing the file makes ImportRegistryFile throw, which is the
            # harsher of the two failure paths and the one that used to escape
            # Invoke-AllChanges entirely.
            Remove-Item -LiteralPath $target -Force

            $entry = Join-Path $sandboxRoot 'WinSwift.ps1'
            $quoted = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $entry)) + $Arguments

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'powershell.exe'
            $psi.Arguments = ($quoted -join ' ')
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.RedirectStandardInput = $true
            $psi.UseShellExecute = $false

            $process = [System.Diagnostics.Process]::Start($psi)
            $process.StandardInput.Close()
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $null = $process.WaitForExit(300000)

            return [PSCustomObject]@{
                ExitCode = $process.ExitCode
                Stdout = $stdout
                Stderr = $stderr
            }
        }
    }

    Context 'when a registry import fails' {

        It 'restores the values captured before the apply phase and exits 3' {
            $before = Get-RegFileValueSnapshot -RegFilePath $script:watchedRegFile
            $before.Count | Should -BeGreaterThan 0 -Because 'the test is meaningless without values to watch'

            $result = Invoke-WinSwiftWithBrokenFeature -BreakRegFile 'Disable_Copilot.reg' `
                -Arguments @('-Silent', '-CLI', '-DisableTelemetry', '-DisableCopilot')

            $result.Stdout | Should -Match 'Rolling back registry changes'

            $after = Get-RegFileValueSnapshot -RegFilePath $script:watchedRegFile
            $changed = Compare-RegValueSnapshot -Before $before -After $after
            $changed | Should -BeNullOrEmpty -Because "rollback should have restored: $($changed -join '; ')"

            # 3 is "failed and rolled back cleanly", distinct from 1 and from
            # 2, which means verification drift.
            $result.ExitCode | Should -Be 3
        }

        It 'records the rollback in the run summary' {
            $summary = Get-ChildItem -Path $env:TEMP -Filter 'WinSwift_RunSummary_*.json' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

            $summary | Should -Not -BeNullOrEmpty
            $content = Get-Content -LiteralPath $summary.FullName -Raw | ConvertFrom-Json

            $content.PSObject.Properties.Name | Should -Contain 'Rollback'
            $content.Rollback.Triggered | Should -BeTrue
            $content.Rollback.Outcome | Should -Be 'RolledBack'
            $content.Rollback.Reason | Should -Not -BeNullOrEmpty
            $content.Rollback.BackupPath | Should -Not -BeNullOrEmpty
        }

        It 'does not run undo work after a failed apply' {
            $result = Invoke-WinSwiftWithBrokenFeature -BreakRegFile 'Disable_Copilot.reg' `
                -Arguments @('-Silent', '-CLI', '-DisableTelemetry', '-DisableCopilot')

            $result.Stdout | Should -Match 'Rolling back registry changes'
        }
    }

    Context 'when rollback is disabled' {

        It 'leaves the changes in place under -NoAutoRollback' {
            $before = Get-RegFileValueSnapshot -RegFilePath $script:watchedRegFile

            $result = Invoke-WinSwiftWithBrokenFeature -BreakRegFile 'Disable_Copilot.reg' `
                -Arguments @('-Silent', '-CLI', '-DisableTelemetry', '-DisableCopilot', '-NoAutoRollback')

            $result.Stdout | Should -Match 'Rollback skipped because -NoAutoRollback'
            $result.Stdout | Should -Not -Match 'Rolling back registry changes'

            $after = Get-RegFileValueSnapshot -RegFilePath $script:watchedRegFile
            $changed = Compare-RegValueSnapshot -Before $before -After $after
            $changed | Should -Not -BeNullOrEmpty -Because 'the applied changes should have been kept'

            # Nothing was rolled back, so this is a plain failure, not a 3.
            $result.ExitCode | Should -Not -Be 3
        }

        It 'warns at run start when -SkipRegistryBackup removes the safety net' {
            $result = Invoke-WinSwiftWithBrokenFeature -BreakRegFile 'Disable_Copilot.reg' `
                -Arguments @('-Silent', '-CLI', '-DisableTelemetry', '-DisableCopilot', '-SkipRegistryBackup')

            $result.Stdout | Should -Match '-SkipRegistryBackup disables automatic rollback'
            $result.Stdout | Should -Match 'no registry backup is available'
        }
    }

    Context 'when only an app removal fails' {

        It 'does not roll back' {
            # The load-bearing case. A registry restore cannot bring back an
            # uninstalled Appx package, so rolling back here would report a
            # recovery that did not happen while the apps stay gone.
            $before = Get-RegFileValueSnapshot -RegFilePath $script:watchedRegFile

            $result = Invoke-WinSwiftProcess -Arguments @(
                '-Silent', '-CLI', '-DisableTelemetry',
                '-RemoveApps', '-Apps', 'WinSwift.IntegrationTest.NotAReal.Package'
            ) -TimeoutSeconds 300

            $result.Stdout | Should -Not -Match 'Rolling back registry changes'

            $after = Get-RegFileValueSnapshot -RegFilePath $script:watchedRegFile
            $changed = Compare-RegValueSnapshot -Before $before -After $after
            $changed | Should -Not -BeNullOrEmpty -Because 'the registry changes should have been kept, not reverted'
        }
    }

    Context 'dry runs' {

        It 'never restores anything under -DryRun' {
            $result = Invoke-WinSwiftWithBrokenFeature -BreakRegFile 'Disable_Copilot.reg' `
                -Arguments @('-DryRun', '-Silent', '-CLI', '-DisableTelemetry', '-DisableCopilot')

            $result.Stdout | Should -Not -Match 'Rolling back registry changes'
            $result.ExitCode | Should -Be 0
        }
    }
}
