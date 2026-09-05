function AwaitKeyToExit {
    param(
        # Defaults to 0 so existing callers keep exiting successfully.
        [int]$ExitCode = 0
    )

    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = [System.Console]::ReadKey()
    }

    Stop-Transcript
    Exit $ExitCode
}
