<#
.SYNOPSIS
    Runs the WinSwift integration suite with a tag filter chosen by risk.

.DESCRIPTION
    Integration tests run WinSwift.ps1 as a real process, so they are gated by
    what they can do to the machine running them:

      ReadOnly   The -Verify path. Reads state and exits before applying
                 anything, so it cannot write even if the engine regresses.
                 Safe anywhere. This is the default.

      DryRun     Asserts that -DryRun writes nothing. A regression in the
                 dry-run guard would write to this host, so it needs an
                 ephemeral machine: a CI runner or Windows Sandbox.

      Mutating   Deliberately applies changes. Windows Sandbox only.

    Nothing beyond ReadOnly runs unless you ask for it.

.PARAMETER Ephemeral
    Adds the DryRun tag. Use on CI runners and inside Sandbox.

.PARAMETER Mutating
    Adds the Mutating tag. Implies -Ephemeral. Windows Sandbox only.

.PARAMETER PassThru
    Returns the Pester result object instead of exiting.

.EXAMPLE
    .\Invoke-IntegrationTests.ps1
    Read-only checks. Safe on a workstation.

.EXAMPLE
    .\Invoke-IntegrationTests.ps1 -Mutating
    The full suite. Only do this in Windows Sandbox.
#>
[CmdletBinding()]
param(
    [switch]$Ephemeral,
    [switch]$Mutating,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0.0' })) {
    throw 'The integration suite requires Pester 5. Install it with: Install-Module Pester -MinimumVersion 5.7.1 -Force -SkipPublisherCheck -Scope CurrentUser'
}

Import-Module Pester -MinimumVersion 5.7.1 -ErrorAction Stop

$tags = @('ReadOnly')
if ($Ephemeral -or $Mutating) { $tags += 'DryRun' }
if ($Mutating) { $tags += 'Mutating' }

$isElevated = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host ''
Write-Host 'WinSwift integration suite' -ForegroundColor Cyan
Write-Host ("  tags     : {0}" -f ($tags -join ', '))
Write-Host ("  elevated : {0}" -f $isElevated)
if (-not $isElevated) {
    Write-Host '  WinSwift refuses to run without elevation, so most cases will skip.' -ForegroundColor Yellow
}
if ($Mutating) {
    Write-Host '  MUTATING: this will change the registry of this machine.' -ForegroundColor Red
}
Write-Host ''

$configuration = New-PesterConfiguration
$configuration.Run.Path = $PSScriptRoot
$configuration.Filter.Tag = $tags
$configuration.Output.Verbosity = 'Detailed'
$configuration.Run.PassThru = $true

$result = Invoke-Pester -Configuration $configuration

if ($PassThru) {
    return $result
}

if ($result.FailedCount -gt 0) {
    Write-Error ("{0} integration test(s) failed." -f $result.FailedCount)
    exit 1
}

exit 0
