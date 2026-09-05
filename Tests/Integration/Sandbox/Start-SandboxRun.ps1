<#
.SYNOPSIS
    Bootstraps and runs the mutating integration suite inside Windows Sandbox.
.DESCRIPTION
    Launched by WinSwift-Tests.wsb. Installs Pester, copies the repository out
    of the read-only mapped folder so the tests can write alongside it, runs the
    full suite, and holds the window open so the result can be read before the
    sandbox is closed and everything is discarded.
#>
$ErrorActionPreference = 'Stop'

Write-Host 'WinSwift integration suite, Windows Sandbox' -ForegroundColor Cyan
Write-Host ''

try {
    $source = 'C:\WinSwift'
    $working = 'C:\WinSwift-Run'

    if (-not (Test-Path -LiteralPath $source)) {
        throw "The repository is not mapped at $source. Check HostFolder in WinSwift-Tests.wsb."
    }

    # The mapped folder is read-only by design. Tests need a writable tree, and
    # a copy also guarantees the host working tree cannot be touched.
    Write-Host 'Copying repository to a writable location...'
    Copy-Item -LiteralPath $source -Destination $working -Recurse -Force

    Write-Host 'Installing Pester 5.7.1...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module Pester -RequiredVersion 5.7.1 -Force -SkipPublisherCheck -Scope CurrentUser

    Write-Host ''
    Write-Host 'Running the full suite, including mutating tests...' -ForegroundColor Yellow
    Write-Host ''

    & "$working\Tests\Integration\Invoke-IntegrationTests.ps1" -Mutating
    $exitCode = $LASTEXITCODE

    Write-Host ''
    if ($exitCode -eq 0) {
        Write-Host 'Integration suite passed.' -ForegroundColor Green
    }
    else {
        Write-Host "Integration suite failed with exit code $exitCode." -ForegroundColor Red
    }
}
catch {
    Write-Host ''
    Write-Host "Sandbox run failed before the suite completed: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host ''
    Write-Host 'This sandbox and every change made inside it is discarded when you close the window.'
    Write-Host 'Press Enter to close.'
    [void](Read-Host)
}
