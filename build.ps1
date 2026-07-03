param (
    [string]$SourceFolder = "$PSScriptRoot",
    [string]$OutputFile = "$PSScriptRoot\WinSwift-Standalone.ps1"
)

Write-Host "Building WinSwift Standalone..." -ForegroundColor Cyan

# 1. Zip the required files
$TempZip = "$env:TEMP\WinSwift_Build.zip"
if (Test-Path $TempZip) { Remove-Item $TempZip -Force }

$IncludeItems = @(
    "Assets",
    "Config",
    "Regfiles",
    "Schemas",
    "Scripts",
    "WinSwift.ps1",
    "Run.bat"
)

Write-Host "Compressing files..."
$ItemsToZip = $IncludeItems | ForEach-Object { Join-Path $SourceFolder $_ }
Compress-Archive -Path $ItemsToZip -DestinationPath $TempZip -Force

# 2. Convert Zip to Base64
Write-Host "Converting to Base64..."
$Bytes = [System.IO.File]::ReadAllBytes($TempZip)
$Base64String = [System.Convert]::ToBase64String($Bytes)

# 3. Create the Standalone Script Wrapper
Write-Host "Generating Standalone Wrapper..."

$WrapperCode = @"
<#
.SYNOPSIS
    WinSwift Standalone Executable
.DESCRIPTION
    This script extracts the WinSwift payload to a temporary directory and executes it.
#>

`$VerbosePreference = 'SilentlyContinue'

# Payload (Base64 Zip)
`$Payload = "$Base64String"

# Extraction Path
`$ExtractPath = Join-Path `$env:TEMP "WinSwift_Run_`$([Guid]::NewGuid().ToString().Substring(0,8))"
if (-not (Test-Path `$ExtractPath)) {
    New-Item -ItemType Directory -Path `$ExtractPath -Force | Out-Null
}

`$ZipPath = Join-Path `$ExtractPath "payload.zip"

try {
    # Decode and save
    `$Bytes = [System.Convert]::FromBase64String(`$Payload)
    [System.IO.File]::WriteAllBytes(`$ZipPath, `$Bytes)
    
    # Extract
    Expand-Archive -Path `$ZipPath -DestinationPath `$ExtractPath -Force
    
    # Run the real script
    `$ScriptPath = Join-Path `$ExtractPath "WinSwift.ps1"
    
    if (Test-Path `$ScriptPath) {
        `$ArgsList = @("-ExecutionPolicy", "Bypass", "-NoProfile", "-File", "`$ScriptPath") + `$args
        Write-Host "Launching WinSwift..." -ForegroundColor Cyan
        Start-Process -FilePath "powershell.exe" -ArgumentList `$ArgsList -NoNewWindow -Wait
    } else {
        Write-Error "Failed to locate WinSwift.ps1 in extracted payload."
    }
} catch {
    Write-Error "An error occurred while launching WinSwift: `$_"
} finally {
    # Cleanup
    if (Test-Path `$ExtractPath) {
        Remove-Item `$ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
"@

# 4. Save to Output File
[System.IO.File]::WriteAllText($OutputFile, $WrapperCode)
Remove-Item $TempZip -Force

Write-Host "Build complete! Standalone script saved to: $OutputFile" -ForegroundColor Green
