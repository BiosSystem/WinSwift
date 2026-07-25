# ⚙️ Execution Architecture

WinSwift is designed as a modular, extensible PowerShell engine. Rather than a single massive script of hardcoded registry commands, it dynamically reads from JSON feature definitions.

## 1. UAC Elevation
When `WinSwift.ps1` is executed, it first checks `[Security.Principal.WindowsPrincipal]` to determine if the user has Administrative rights. If not, it automatically restarts itself using `Start-Process powershell -Verb RunAs`.

## 2. Features.json & The Core Loop
All tweaks are defined in `Config/Features.json`. This structure allows contributors to add new tweaks without modifying the core engine logic.

* **Categories**: Define logical groups (e.g., `Privacy`, `Gaming`).
* **Tweaks**: Define individual actions with `Registry`, `Service`, `Appx`, and `ScheduledTask` properties.

The core loop in `Scripts/InvokeChanges.ps1` parses this JSON and dispatches the execution to specialized helpers (`Set-RegistryValue`, `Remove-Appx`, etc.).

## 3. Dry-Run Mode (`$WhatIfPreference`)
If the user passes the `-DryRun` switch, WinSwift leverages PowerShell native `-WhatIf` binding. All core helpers respect `$WhatIfPreference = $true`, meaning they will log what *would* happen to the console without writing to the disk or registry. This ensures 100% safe testing.
