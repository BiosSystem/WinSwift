[CmdletBinding()]
param(
    [string]$OriginalCommandPath,
    [hashtable]$OriginalBoundParameters,
    [array]$OriginalUnboundArguments
)

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "WinSwift must be run as Administrator." -ForegroundColor Red

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
            Write-Error "Failed to start WinSwift as Administrator: $_"
            exit 1
        }

        exit 0
    }

    exit 1
}
