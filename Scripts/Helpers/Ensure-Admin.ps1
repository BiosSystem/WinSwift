[CmdletBinding()]
param(
    [string]$OriginalCommandPath,
    [hashtable]$OriginalBoundParameters,
    [array]$OriginalUnboundArguments
)

# This script is dot-sourced, and `exit` inside a dot-sourced script does not
# terminate the caller. Relying on it let a non-elevated run continue into the
# apply pipeline. The outcome is reported through $script:ElevationOutcome
# instead, and Winnow.ps1 exits on anything other than 'Elevated'.
$script:ElevationOutcome = 'Elevated'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Winnow must be run as Administrator." -ForegroundColor Red

    # Prompting is pointless when nothing can answer, and a redirected read
    # returns immediately, which previously read as a declined prompt.
    $inputIsRedirected = $false
    try { $inputIsRedirected = [Console]::IsInputRedirected } catch { }

    if ($inputIsRedirected) {
        Write-Host "No interactive console is available to confirm elevation. Re-run Winnow from an elevated session." -ForegroundColor Red
        $script:ElevationOutcome = 'Denied'
        return
    }

    $choice = Read-Host "Restart as Administrator? (y/n)"

    if ($choice -match '^[Yy]$') {
        function Format-ElevatedArg {
            param([AllowEmptyString()][string]$Value)

            $escaped = $Value -replace '(\\*)"', '$1$1\"'
            $escaped = $escaped -replace '(\\+)$', '$1$1'
            return '"' + $escaped + '"'
        }

        $elevatedArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Format-ElevatedArg $OriginalCommandPath))

        foreach ($paramName in $OriginalBoundParameters.Keys) {
            $paramValue = $OriginalBoundParameters[$paramName]

            if ($paramValue -is [System.Management.Automation.SwitchParameter]) {
                if ($paramValue.IsPresent) {
                    $elevatedArgs += "-$paramName"
                }
            }
            else {
                $elevatedArgs += "-$paramName"
                if ($paramValue -is [array]) {
                    $elevatedArgs += (Format-ElevatedArg (($paramValue | ForEach-Object { [string]$_ }) -join ','))
                }
                else {
                    $elevatedArgs += (Format-ElevatedArg ([string]$paramValue))
                }
            }
        }

        if ($OriginalUnboundArguments.Count -gt 0) {
            foreach ($unboundArg in $OriginalUnboundArguments) {
                $elevatedArgs += (Format-ElevatedArg ([string]$unboundArg))
            }
        }

        try {
            Start-Process powershell.exe -ArgumentList $elevatedArgs -Verb RunAs -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to start Winnow as Administrator: $_"
            $script:ElevationOutcome = 'Failed'
            return
        }

        # The elevated child owns the run from here; this process must stop so the
        # two do not execute concurrently.
        $script:ElevationOutcome = 'Relaunched'
        return
    }

    $script:ElevationOutcome = 'Denied'
    return
}
