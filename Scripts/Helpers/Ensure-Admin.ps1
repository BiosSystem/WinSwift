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
        $elevatedArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $OriginalCommandPath)

        foreach ($paramName in $OriginalBoundParameters.Keys) {
            $paramValue = $OriginalBoundParameters[$paramName]

            if ($paramValue -is [System.Management.Automation.SwitchParameter]) {
                if ($paramValue.IsPresent) {
                    $elevatedArgs += "-$paramName"
                }
            }
            else {
                $elevatedArgs += "-$paramName"
                $elevatedArgs += "$paramValue"
            }
        }

        if ($OriginalUnboundArguments.Count -gt 0) {
            $elevatedArgs += $OriginalUnboundArguments
        }

        Start-Process powershell -ArgumentList $elevatedArgs -Verb RunAs
    }
    
    # Exit process if not admin
    [Environment]::Exit(0)
}
