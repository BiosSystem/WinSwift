#Requires -Modules Pester
<#
.SYNOPSIS
    End-to-end contract for the -Verify exit codes and profile parsing.
.DESCRIPTION
    Runs Winnow.ps1 as a real process. The -Verify path reads state and exits
    before anything is applied, so these cases cannot write to the host even if
    the verification engine regresses.

    Every case here is deterministic on any machine. Compliance of a real tweak
    depends on how the host is configured, so none of these assert on one.
#>

BeforeDiscovery {
    # -Skip: is evaluated during discovery, before any BeforeAll runs, so the
    # elevation check has to be resolved here.
    . (Join-Path $PSScriptRoot 'IntegrationCommon.ps1')
    $script:IsElevated = Test-IsElevated
}

Describe 'Winnow -Verify contract' -Tag 'ReadOnly' {

    BeforeAll {
        . (Join-Path $PSScriptRoot 'IntegrationCommon.ps1')
        $script:elevated = Test-IsElevated
        $script:profileDir = Join-Path $TestDrive 'profiles'
        New-Item -ItemType Directory -Path $script:profileDir -Force | Out-Null

        function New-VerifyProfile {
            param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Content)
            $path = Join-Path $script:profileDir "$Name.json"
            $Content | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding utf8
            return $path
        }
    }

    It 'exits 0 when the only selected entry carries no desired state' -Skip:(-not $script:IsElevated) {
        # CreateRestorePoint is exempt, so it verifies as NotApplicable. This is
        # the end-to-end proof that an exemption never fails a run.
        $path = New-VerifyProfile -Name 'exempt-only' -Content @{ Switches = @('CreateRestorePoint') }

        $result = Invoke-WinnowProcess -Arguments @('-Verify', '-VerifyProfile', $path)

        $result.TimedOut | Should -BeFalse
        $result.Stdout | Should -Match 'NotApplicable'
        $result.ExitCode | Should -Be 0
    }

    It 'exits 2 when a selected feature is unknown' -Skip:(-not $script:IsElevated) {
        $path = New-VerifyProfile -Name 'unknown-feature' -Content @{ Switches = @('NoSuchFeatureExists') }

        $result = Invoke-WinnowProcess -Arguments @('-Verify', '-VerifyProfile', $path)

        $result.TimedOut | Should -BeFalse
        $result.ExitCode | Should -Be 2
    }

    It 'exits 2 when the profile selects nothing verifiable' -Skip:(-not $script:IsElevated) {
        $path = New-VerifyProfile -Name 'empty' -Content @{ Switches = @() }

        $result = Invoke-WinnowProcess -Arguments @('-Verify', '-VerifyProfile', $path)

        $result.TimedOut | Should -BeFalse
        $result.ExitCode | Should -Be 2
    }

    It 'exits 2 when the profile path does not exist' -Skip:(-not $script:IsElevated) {
        $missing = Join-Path $script:profileDir 'does-not-exist.json'

        $result = Invoke-WinnowProcess -Arguments @('-Verify', '-VerifyProfile', $missing)

        $result.TimedOut | Should -BeFalse
        $result.ExitCode | Should -Be 2
    }

    It 'reads app targets from a profile and routes them through AppxAbsence' -Skip:(-not $script:IsElevated) {
        # A package name that cannot exist is necessarily absent, and absent is
        # the applied state for a removal feature. That makes this deterministic
        # while still proving the profile -> RemoveApps -> AppxAbsence path.
        $fakeApp = 'Winnow.IntegrationTest.NotAReal.Package'
        $path = New-VerifyProfile -Name 'apps' -Content @{ Switches = @(); Apps = @($fakeApp) }

        $result = Invoke-WinnowProcess -Arguments @('-Verify', '-VerifyProfile', $path)

        $result.TimedOut | Should -BeFalse
        $result.Stdout | Should -Match ([regex]::Escape($fakeApp))
        $result.ExitCode | Should -Be 0
    }

    It 'refuses to verify without elevation' -Skip:($script:IsElevated) {
        # The mirror of the case above: unelevated, the run must stop at the
        # admin guard rather than reaching the verification engine.
        $path = Join-Path $script:profileDir 'unelevated.json'
        @{ Switches = @('CreateRestorePoint') } | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8

        $result = Invoke-WinnowProcess -Arguments @('-Verify', '-VerifyProfile', $path)

        $result.ExitCode | Should -Be 1
        $result.Stdout | Should -Not -Match 'desired-state verification'
    }
}
