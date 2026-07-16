function Invoke-AddDefenderGamingExclusions {
    param (
        [switch]$WhatIf
    )

    Write-Host "`n[*] Adding Windows Defender Gaming Exclusions..." -ForegroundColor Cyan

    $gamePaths = @(
        "C:\Program Files (x86)\Steam\steamapps\common",
        "C:\Program Files\Epic Games",
        "C:\Program Files (x86)\GOG Galaxy\Games",
        "D:\SteamLibrary\steamapps\common",
        "E:\SteamLibrary\steamapps\common"
    )

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would add the following paths to Windows Defender exclusions:" -ForegroundColor Yellow
        foreach ($path in $gamePaths) {
            if (Test-Path $path) {
                Write-Host "  - $path (Detected)" -ForegroundColor DarkGray
            } else {
                Write-Host "  - $path (Not found)" -ForegroundColor DarkGray
            }
        }
        return
    }

    try {
        $added = 0
        foreach ($path in $gamePaths) {
            if (Test-Path $path) {
                Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
                Write-Host "  [+] Excluded $path" -ForegroundColor Green
                $added++
            }
        }
        
        if ($added -eq 0) {
            Write-Host "  [-] No default gaming directories found to exclude." -ForegroundColor DarkGray
        } else {
            Write-Host "  [+] Windows Defender Gaming Exclusions applied." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  [ERROR] Failed to add Defender exclusions: $_" -ForegroundColor Red
    }
}
