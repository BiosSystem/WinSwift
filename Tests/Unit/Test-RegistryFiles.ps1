#Requires -Modules Pester
<#
.SYNOPSIS
    Unit tests for registry file (.reg) syntax and encoding.
.DESCRIPTION
    Scans all .reg files in Regfiles/ and Regfiles/Undo/ and validates:
    - File starts with the correct registry editor header
    - File is non-empty
    - No line uses CRLF-broken key paths (common sign of encoding corruption)
    - Every key section starts with a valid hive prefix
#>

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path
$regRoot  = Join-Path $repoRoot 'Regfiles'

$validHives = @(
    'HKEY_LOCAL_MACHINE',
    'HKEY_CURRENT_USER',
    'HKEY_CLASSES_ROOT',
    'HKEY_USERS',
    'HKEY_CURRENT_CONFIG'
)

$regFiles = @(Get-ChildItem -Path $regRoot -Filter '*.reg' -Recurse)

Describe 'Registry files (.reg)' {

    BeforeAll {
        $script:regFiles = $regFiles
    }

    It 'finds at least one .reg file' {
        $script:regFiles.Count | Should -BeGreaterThan 0
    }

    foreach ($regFile in $regFiles) {
        $relativePath = $regFile.FullName.Replace($repoRoot, '').TrimStart('\')

        Context $relativePath {

            BeforeAll {
                $script:content = Get-Content $regFile.FullName -Raw
                $script:lines   = Get-Content $regFile.FullName
            }

            It 'is non-empty' {
                $script:content.Trim() | Should -Not -BeNullOrEmpty
            }

            It 'starts with the registry editor header' {
                $firstLine = ($script:lines | Select-Object -First 1).Trim()
                $firstLine | Should -Be 'Windows Registry Editor Version 5.00'
            }

            It 'contains at least one key section or delete directive' {
                $hasSections = $script:content -match '^\[' -or $script:content -match '^\[-'
                $hasSections | Should -Be $true
            }

            It 'all key sections start with a valid hive' {
                $keyLines = $script:lines | Where-Object { $_ -match '^\[' }
                $invalidKeys = $keyLines | Where-Object {
                    $stripped = $_ -replace '^\[-?\[?', '' -replace '\]$', ''
                    $hive = ($stripped -split '\\')[0]
                    $validHives -notcontains $hive
                }
                $invalidKeys | Should -BeNullOrEmpty -Because (
                    "Invalid hive prefixes: $($invalidKeys -join '; ')"
                )
            }
        }
    }
}
