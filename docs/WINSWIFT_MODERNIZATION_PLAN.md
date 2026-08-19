# WinSwift Modernization Plan (Windows 11 23H2/24H2)

## 1. Feature Gap Analysis
Following a read-only audit of the current `WinSwift` scripts (including `ExtendedAIPurge.ps1`, `RemoveApps.ps1`, and `Apps.json`), we have identified critical gaps in our coverage of modern Windows 11 features:
- **Missing AI Feature Toggles**: Paint Co-Creator AI, Windows Studio Effects AI, Auto SR (Super Resolution) analytics, Live Captions, and Voice Access background services are not explicitly disabled.
- **Missing Start Menu Overrides**: `BingSearchEnabled` is absent, leaving the Start Menu vulnerable to web search injection.
- **Aggressive Appx Persistence**: Copilot components, Dev Home, and the new Microsoft Teams are mapped in `Apps.json` but require deeper, aggressive registry pruning to prevent automatic re-installation via Windows Update.
- **Cloud/Telemetry Nags**: Windows Backup cloud sync prompts and Smart App Control telemetry remain active.

## 2. Release Tracks

### v3.1.0: Extended AI & Telemetry Purge
**Focus**: Deeply disable new 24H2 AI integrations and telemetry.
- **Modified Scripts**: `Scripts\Features\ExtendedAIPurge.ps1`, `Scripts\Features\TelemetryScheduledTasks.ps1`
- **Actions**:
  - Add registry edits to disable Paint Co-Creator AI and Windows Studio Effects.
  - Disable scheduled tasks related to Auto SR analytics and Dev Drive telemetry.
  - Inject `BingSearchEnabled` = 0 into `Regfiles\Disable_Windows_Suggestions.reg`.

### v3.2.0: Deep Appx Purge & Safety Guardrails
**Focus**: Permanently rip out stubborn modern Appx packages and enforce fallback integrity.
- **Modified Scripts**: `Scripts\AppRemoval\RemoveApps.ps1`, `Scripts\Features\CreateSystemRestorePoint.ps1`, `Scripts\Features\BackupRegistryState.ps1`
- **Actions**:
  - Implement a secondary aggressive DISM fallback in `Remove-AppxApp` for packages like `Microsoft.Windows.AI.Copilot.Provider` and `Microsoft.Windows.DevHome`.
  - Disable Windows Backup cloud sync nags.
  - **Safety Enforcement**: Hardcode a prerequisite check in `WinSwift.ps1` to ensure `CreateSystemRestorePoint.ps1` and `BackupRegistryState.ps1` execute successfully *before* any Phase 2 aggressive app removal runs. If the backup fails, the execution will abort.

## 3. Safety Fallback Architecture
To prevent irreversible damage during the v3.2.0 aggressive Appx purge:
1. **Pre-Flight Check**: The script will invoke `CreateSystemRestorePoint` (with a 90-second timeout) and `BackupRegistryState`.
2. **Validation**: We will modify `InvokeChanges.ps1` to parse the return status of these backups.
3. **Abort Matrix**: If System Restore is disabled and the user refuses to enable it, the aggressive Appx purge array will be bypassed entirely, executing only safe registry tweaks.
