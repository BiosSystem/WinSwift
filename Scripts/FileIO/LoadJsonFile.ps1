# Loads a JSON file from the specified path and returns the parsed object
# Returns $null if the file doesn't exist or if parsing fails
function LoadJsonFile {
    param (
        [string]$filePath,
        [string]$expectedVersion = $null,
        [switch]$optionalFile
    )
    
    if (-not (Test-Path $filePath)) {
        if (-not $optionalFile) {
            Write-Error "File not found: $filePath"
        }
        return $null
    }
    
    try {
        # -Encoding UTF8 is required. Windows PowerShell 5.1 falls back to the
        # ANSI codepage for a UTF-8 file with no BOM, which double-encodes any
        # accented character in a translation catalogue.
        $jsonContent = Get-Content -Path $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Validate version if specified
        if ($expectedVersion -and $jsonContent.Version -and $jsonContent.Version -ne $expectedVersion) {
            Write-Error "$(Split-Path $filePath -Leaf) version mismatch (expected $expectedVersion, found $($jsonContent.Version))"
            return $null
        }
        
        return $jsonContent
    }
    catch {
        Write-Error "Failed to parse JSON file: $filePath"
        return $null
    }
}
