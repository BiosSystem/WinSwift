[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [switch]$RequirePSScriptAnalyzer
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path $PSScriptRoot -Parent
}
$errors = [System.Collections.Generic.List[string]]::new()
$powershellFiles = @(Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File |
    Where-Object {
        $_.Extension -in '.ps1', '.psm1', '.psd1' -and
        $_.FullName -notmatch '[\\/]Release[\\/]'
    })

foreach ($file in $powershellFiles) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )

    foreach ($parseError in @($parseErrors)) {
        $errors.Add("$($file.FullName):$($parseError.Extent.StartLineNumber): $($parseError.Message)")
    }

    $duplicates = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true) | Group-Object Name | Where-Object Count -gt 1)

    foreach ($duplicate in $duplicates) {
        $errors.Add("$($file.FullName): duplicate function '$($duplicate.Name)'")
    }
}

foreach ($jsonFile in Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Config') -Recurse -File -Filter '*.json') {
    try {
        Get-Content -LiteralPath $jsonFile.FullName -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null
    }
    catch {
        $errors.Add("$($jsonFile.FullName): invalid JSON: $($_.Exception.Message)")
    }
}

$analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer |
    Sort-Object Version -Descending |
    Select-Object -First 1
if ($analyzer) {
    Import-Module $analyzer.Path -Force
    $analysisResults = @(Invoke-ScriptAnalyzer -Path $RepositoryRoot -Recurse -Severity Error |
        Where-Object { $_.ScriptPath -notmatch '[\\/]Release[\\/]' })
    foreach ($analysisResult in $analysisResults) {
        $errors.Add("$($analysisResult.ScriptPath):$($analysisResult.Line): $($analysisResult.RuleName): $($analysisResult.Message)")
    }
}
elseif ($RequirePSScriptAnalyzer) {
    $errors.Add('PSScriptAnalyzer is required but is not installed.')
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host ("Validated {0} PowerShell files and all configuration JSON files." -f $powershellFiles.Count)
exit 0
