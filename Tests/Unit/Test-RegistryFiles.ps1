#Requires -Modules Pester

Describe 'Registry files' {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path
        $script:regFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'Regfiles') -Filter '*.reg' -Recurse)
        $script:validHives = @(
            'HKEY_LOCAL_MACHINE',
            'HKEY_CURRENT_USER',
            'HKEY_CLASSES_ROOT',
            'HKEY_USERS',
            'HKEY_CURRENT_CONFIG'
        )
    }

    It 'finds registry files' {
        $script:regFiles.Count | Should -BeGreaterThan 0
    }

    It 'validates every registry file' {
        $failures = [System.Collections.Generic.List[string]]::new()

        foreach ($regFile in $script:regFiles) {
            $content = Get-Content -LiteralPath $regFile.FullName -Raw
            $lines = @(Get-Content -LiteralPath $regFile.FullName)

            if ([string]::IsNullOrWhiteSpace($content)) {
                $failures.Add("$($regFile.FullName): file is empty")
                continue
            }
            if ($lines.Count -eq 0 -or $lines[0].Trim() -ne 'Windows Registry Editor Version 5.00') {
                $failures.Add("$($regFile.FullName): invalid registry header")
            }
            if ($content -notmatch '(?m)^\[-?[^\]]+\]') {
                $failures.Add("$($regFile.FullName): no registry key section")
            }

            foreach ($keyLine in @($lines | Where-Object { $_ -match '^\[' })) {
                $stripped = $keyLine -replace '^\[-?', '' -replace '\]$', ''
                $hive = ($stripped -split '\\')[0]
                if ($script:validHives -notcontains $hive) {
                    $failures.Add("$($regFile.FullName): invalid hive '$hive'")
                }
            }
        }

        $failures | Should -BeNullOrEmpty -Because ($failures -join [Environment]::NewLine)
    }
}
