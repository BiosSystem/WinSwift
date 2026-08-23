# Execution Architecture

WinSwift is a modular, extensible PowerShell 5.1 engine. The core orchestrator reads JSON feature definitions at runtime, dispatches work to self-contained module scripts, captures system state before and after execution, and verifies compliance through a desired-state engine.

## Pre-Execution Safety Gate

Before any module executes, WinSwift validates the runtime environment:

1. **PowerShell version guard** - Halts if the host is not Windows PowerShell 5.1. PowerShell 7 cannot reliably invoke Appx removal cmdlets or system restore APIs.
2. **Administrator elevation** - Checks `[Security.Principal.WindowsPrincipal]` and restarts under `Start-Process powershell -Verb RunAs` if elevation is absent. UAC arguments are quoted using Win32-safe escaping.
3. **Mark-of-the-Web handling** - Unblocks only marked PowerShell source files when Group Policy overrides the execution policy. Executable and data files are not unblocked.
4. **Domain-join warning** - Detects domain-joined systems and warns that Group Policy may override applied registry changes after the next policy refresh.
5. **Path and asset validation** - Confirms that all required directories (`Assets`, `Config`, `Regfiles`, `Schemas`, `Scripts`) are present before loading any module.
6. **Registry backup** - Exports a timestamped `.reg` snapshot of all scheduled modification targets to `%TEMP%\WinSwift_Backup_<timestamp>` unless `-SkipRegistryBackup` is explicitly specified.
7. **System restore point** - Creates a system restore point before executing any of the four high-impact custom modules: gaming optimization, extended AI purge, security hardening, or telemetry firewall.

## Feature Definition: Config/Features.json

All tweaks are defined declaratively in `Config/Features.json`. The schema allows contributors to add new features without modifying the core engine:

- `Categories` - logical groupings shown in the GUI (Privacy, Gaming, AI, System, etc.)
- `UiGroups` - radio or dropdown groups for mutually exclusive options (e.g., taskbar search style)
- `Features` - individual feature definitions containing:
  - `Label` and `ToolTip` for the GUI
  - `Category` for placement
  - `InvokeFeature` and `UndoFeature` pointing to the apply and revert function names
  - `VerifyFeature` pointing to the verification adapter function name
  - `Reg` array of registry operations (path, name, type, value, target state)
  - `Appx` array of package names to remove
  - `Service` array of service names and startup types to configure
  - `ScheduledTask` array of task paths to disable

## Core Apply Engine

`Scripts/Features/InvokeChanges.ps1` dispatches each enabled feature through `Invoke-WinSwiftFeature`. The engine:

1. Reads the feature definition from the in-memory parsed JSON.
2. Calls `ShouldProcess` before every registry write, Appx removal, or service change, enabling full `-WhatIf` dry-run support.
3. Applies registry values via `Set-ItemProperty` with explicit type casting.
4. Removes Appx packages via `Remove-AppxPackage` (current user) and `Remove-AppxProvisionedPackage` (provisioned image).
5. Configures services via `Set-Service -StartupType` and `Stop-Service`.
6. Disables scheduled tasks via `Disable-ScheduledTask`.
7. Increments per-operation success and failure counters for the run summary.

No Windows binary files are deleted. No Windows service registrations are removed from the service control manager database. All changes are reversible through the rollback mechanism.

## Custom Modules

Four WinSwift-owned modules extend beyond the upstream feature set and are invoked through a unified routing layer:

| Module | Script | Key Operations |
|---|---|---|
| Gaming Mode | `GamingMode.ps1` | High Performance power plan, Nagle Algorithm disable, HAGS registry enable, GameDVR off, Sticky Keys off, startup delay zero, automatic maintenance disable |
| Competitive Esports | `CompetitiveGaming.ps1` | Ultimate Performance power plan, 0.5ms GlobalTimerResolutionRequests, BCD useplatformtick and disabledynamictick, MMCSS NetworkThrottlingIndex 0xFFFFFFFF and SystemResponsiveness 0, MMCSS Games GPU Priority 8 and Priority 6, CPU core parking ValueMax 0 |
| Extended AI Purge | `ExtendedAIPurge.ps1` | Recall suppression, Click To Do disable, AI service startup prevention, Edge AI feature disables, Paint and Notepad AI removes |
| Security Hardening | `SecurityHardening.ps1` | SMBv1 disable, TLS 1.0 and 1.1 disable, AutoRun and Windows Script Host restriction, BitLocker auto-encryption prevention |
| Telemetry Firewall | `BlockTelemetryFirewall.ps1` and `TelemetryScheduledTasks.ps1` | Outbound Windows Firewall rules blocking Microsoft telemetry endpoints, full disable of telemetry and diagnostic scheduled tasks |

## Desired-State Verification Engine

`Scripts/Features/DesiredStateVerification.ps1` implements the compliance verification layer. At verification time:

1. For each requested feature, the engine reads the current system state.
2. Registry values are read back via `Get-ItemPropertyValue` and compared to the expected target value.
3. Appx package presence is checked via `Get-AppxPackage` and `Get-AppxProvisionedPackage`.
4. Custom module state is verified through metadata-driven adapter functions referenced by `VerifyFeature` in the JSON definition.
5. Each feature is marked `Compliant`, `NonCompliant`, `Unsupported`, or `Failed`.
6. The engine exits with code `0` if all verified features are compliant, or code `2` if any feature is noncompliant, unsupported, or produced a verification failure.

Verification can be triggered three ways:

```powershell
# Inline after apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinSwift.ps1 -DisableTelemetry -DisableCopilot -Verify -Silent

# Standalone compliance audit against a profile
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinSwift.ps1 -VerifyProfile .\Config\DefaultSettings.json -Silent

# Parameter-driven verification of specific features
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinSwift.ps1 -Verify -DisableRecall -DisableGameDVR -Silent
```

## Rollback Protocols

### Registry Rollback

Apply the timestamped `.reg` export via:

```powershell
reg import "%TEMP%\WinSwift_Backup_<timestamp>.reg"
```

Or through the built-in revert flow:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinSwift.ps1 -Revert
```

### System Restore Rollback

For changes applied through the four high-impact custom modules, the System Restore point created before execution provides a full OS-level rollback path accessible through `rstrui.exe` or the Settings app.

### Appx Package Restore

Removed Appx packages can be reinstalled from the Microsoft Store. Provisioned packages can be restored using `Add-AppxProvisionedPackage` with the appropriate cabinet file from a Windows installation image.

## WhatIf Mode

Pass `-DryRun` to engage WhatIf mode across all apply operations:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\WinSwift.ps1 -DisableTelemetry -DisableCopilot -DryRun
```

All registry writes, Appx removals, and service configuration calls will log what they would do without modifying the system. The run summary at completion shows the full list of planned operations.
