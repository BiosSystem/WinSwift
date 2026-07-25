# WinSwift Modernization Plan

## Overview

This document defines the master modernization roadmap for WinSwift. It is structured into three sequential execution tracks, each mapped to a target semantic version release. No functional scripts are modified during the planning phase. Each track builds on the previous and must be validated before the next begins.

---

## Track 1 - Modern Bloatware and AI Purge (v2.5.0)

Target release: v2.5.0
Focus: Catch up to Windows 11 24H2 and 25H2 AI integration surface area, refresh the bloatware removal list, and update the telemetry endpoint block list.

### 1.1 - Refresh Telemetry Firewall Block List

File: `Scripts/Features/BlockTelemetryFirewall.ps1`

Add the following endpoints to the `$telemetryDomains` array. These are new AI inference and telemetry routes introduced in Windows 11 24H2 that are absent from the current list:

- `us.vortex-win.data.microsoft.com`
- `east.pipe.aria.microsoft.com`
- `api.msai.microsoft.com`
- `inference.windows.microsoft.com`
- `copilot.microsoft.com`
- `substrate.office.com`
- `eus2-azureml-batchai-prod.eastus2.inference.ml.azure.com`
- `canary.designerapp.office.com`

Switch the fallback strategy from DNS-resolution-only to a dual approach: resolve IPs at runtime AND write a HOSTS file entry as a permanent fallback. This prevents firewall rules from going stale when Microsoft rotates IPs.

### 1.2 - Add 24H2 / 25H2 AI Targets to ExtendedAIPurge

File: `Scripts/Features/ExtendedAIPurge.ps1`

Add the following discrete purge targets as new numbered sections inside `Disable-ExtendedAIPurge`:

- **Photos Generative Fill** - Disable `Microsoft.Photos` AI generative features via `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Photos` policy key `DisableGenerativeFill=1`
- **Suggested Clipboard Actions** - Disable `HKCU:\Software\Microsoft\Clipboard` key `EnableSuggestedClipboardActions=0` (AI reads clipboard content to suggest actions)
- **Microsoft 365 Auto-Install Push** - Block the silent M365 trial push that arrives via Windows Update post-24H2 using `HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common` key `PreventProductInstall=1`
- **Outlook (New) AI Suggestions** - Add policy `HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\options\mail` key `DisableCopilot=1`
- **Power Automate Desktop AI** - Disable autostart of `UIFlowService` via registry startup key removal
- **Narrator AI Voices** - Set `HKCU:\Software\Microsoft\Narrator\NoRoam` key `OnlineVoicesEnabled=0`

### 1.3 - Extend AI Category in Features.json

File: `Config/Features.json`

Add four new FeatureId entries under the `"AI"` category:

| FeatureId | Label | MinVersion |
|---|---|---|
| `DisablePhotosGenerativeFill` | Disable AI Generative Fill in Photos | 22621 |
| `DisableSuggestedClipboardActions` | Disable AI Suggested Clipboard Actions | 22621 |
| `DisableM365AutoInstall` | Block Microsoft 365 silent auto-install | null |
| `DisableNarratorAIVoices` | Disable Narrator AI online voices | 22621 |

Each entry requires a corresponding registry file in `Regfiles/` and `Regfiles/Undo/`.

### 1.4 - Expand Scheduled Task Purge

File: `Scripts/Features/TelemetryScheduledTasks.ps1`

The current implementation targets 7 scheduled tasks. Expand to cover the full critical set. Add the following task paths and names:

| Task Path | Task Name | Reason |
|---|---|---|
| `\Microsoft\Windows\Device Information\` | `Device` | Hardware fingerprint census |
| `\Microsoft\Windows\AppID\` | `SmartScreenSpecific` | SmartScreen telemetry |
| `\Microsoft\Windows\Application Experience\` | `Microsoft Compatibility Appraiser` | Upgrade readiness telemetry |
| `\Microsoft\Windows\Application Experience\` | `ProgramDataUpdater` | App usage telemetry |
| `\Microsoft\Windows\Application Experience\` | `StartupAppTask` | Startup impact tracking |
| `\Microsoft\Windows\Autochk\` | `Proxy` | Disk health telemetry to Microsoft |
| `\Microsoft\Windows\Customer Experience Improvement Program\` | `Consolidator` | CEIP data upload |
| `\Microsoft\Windows\Customer Experience Improvement Program\` | `UsbCeip` | USB device CEIP telemetry |
| `\Microsoft\Windows\DiskDiagnostic\` | `Microsoft-Windows-DiskDiagnosticDataCollector` | Disk diagnostic upload |
| `\Microsoft\Windows\Feedback\Siuf\` | `DmClient` | Feedback telemetry client |
| `\Microsoft\Windows\Feedback\Siuf\` | `DmClientOnScenarioDownload` | Feedback scenario data |
| `\Microsoft\Windows\Maps\` | `MapsToastTask` | Location upload via maps |
| `\Microsoft\Windows\Maps\` | `MapsUpdateTask` | Map data telemetry |
| `\Microsoft\Windows\PI\` | `Sqm-Tasks` | Software Quality Metrics |
| `\Microsoft\Windows\WS\` | `WSTask` | Windows Store telemetry |
| `\Microsoft\Windows\Clip\` | `License Validation` | Activation telemetry |

### 1.5 - Add OEM Bloatware Removal Presets

File: `Config/Apps.json`

Add three new OEM vendor groupings with a `"Vendor"` tag field, each containing the known bloatware app IDs:

**Lenovo:**
- `E046963F.LenovoCompanion`
- `E046963F.LenovoSettingsforEnterprise`
- `LenovoInc.LenovoVantage`
- `LenovoPCManager`

**Dell:**
- `DellInc.DellCommandUpdate`
- `DellInc.DellDigitalDelivery`
- `DellInc.DellSupportAssistforPCs`

**ASUS:**
- `B9ECED6F.ASUSArmouryCrate`
- `ASUSTeK.MyAsus`
- `ROGLiveService`

Surface these in the GUI under a new "OEM Apps" section inside the app selection window.

---

## Track 2 - Privacy and Telemetry Hardening (v2.6.0)

Target release: v2.6.0
Focus: Close the remaining privacy gaps identified in the audit, including Advertising ID, service-level telemetry stops, and camera/microphone access controls.

### 2.1 - Disable DiagTrack and Related Telemetry Services

File: `Scripts/Features/TelemetryScheduledTasks.ps1` or new `Scripts/Features/TelemetryServices.ps1`

Stop and set the following services to `Disabled` startup:

| Service Name | Display Name | Risk |
|---|---|---|
| `DiagTrack` | Connected User Experiences and Telemetry | HIGH - primary data pipeline |
| `WerSvc` | Windows Error Reporting Service | MEDIUM |
| `DPS` | Diagnostic Policy Service | MEDIUM |
| `WdiServiceHost` | Diagnostic Service Host | LOW |
| `WdiSystemHost` | Diagnostic System Host | LOW |

Add a corresponding `"DisableTelemetryServices"` FeatureId to `Features.json` under the `"Privacy & Suggested Content"` category with a clear warning in ToolTip that some Windows diagnostic popups may stop functioning.

### 2.2 - Close Advertising ID Gap

File: New `Regfiles/Disable_Advertising_ID.reg` and `Regfiles/Undo/Enable_Advertising_ID.reg`

Target keys:
- `HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo` - set `Enabled=0`
- `HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` - set `DisabledByGroupPolicy=1`
- Apply for all existing user profiles via HKEY_USERS enumeration in the script

Add `"DisableAdvertisingID"` FeatureId. Mark it `SelectedByDefault: false` in `DefaultSettings.json` since it uses policy lockdown.

### 2.3 - Disable Voice Activation Wakeword Listeners

File: New `Regfiles/Disable_Voice_Activation.reg`

Target:
- `HKCU\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps` - set `AgentActivationEnabled=0`
- `HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy` - set `LetAppsActivateWithVoice=2` (deny all)

Add `"DisableVoiceActivation"` FeatureId under `"Privacy & Suggested Content"`.

### 2.4 - Add HOSTS-Based Telemetry Blocking

File: New `Scripts/Features/HostsTelemetryBlock.ps1`

Implement a function `Set-HostsTelemetryBlock` that appends a clearly delimited WinSwift block to `C:\Windows\System32\drivers\etc\hosts`. Include a removal function `Remove-HostsTelemetryBlock` that cleanly strips only the WinSwift-managed section.

Block list should cover all endpoints in the current `BlockTelemetryFirewall.ps1` list plus the new 24H2 endpoints from Track 1.1. The dual-method approach (Firewall + HOSTS) provides defense-in-depth.

Add `"BlockTelemetryHosts"` FeatureId under `"Privacy & Suggested Content"` with a warning that modifying HOSTS requires admin and may affect some enterprise network tools.

### 2.5 - Extend Windows Update Hardening

File: New `Regfiles/Disable_WU_Driver_Search.reg`

Add the following optional controls to the `"Windows Update"` category:

| FeatureId | Label | Key |
|---|---|---|
| `DisableWUDriverSearch` | Prevent Windows Update from installing drivers | `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` - `ExcludeWUDriversInQualityUpdate=1` |
| `DisableFeatureUpdates` | Block Windows feature version upgrades | `TargetReleaseVersion=1` + `TargetReleaseVersionInfo=23H2` |
| `DisablePauseUpdatesNag` | Remove "Resume updates" nag from Settings | `HKCU\Software\Microsoft\Windows\CurrentVersion\...` |

---

## Track 3 - Codebase Refactoring and UI/UX Improvements (v3.0.0)

Target release: v3.0.0
Focus: Architectural improvements, automated testing, GUI enhancements, and developer experience upgrades. This is the major version bump.

### 3.1 - Introduce Pester Test Suite

Directory: New `Tests/` folder at repository root

Structure:
```
Tests/
  Unit/
    Test-RegistryFiles.ps1     - validate all .reg file syntax
    Test-FeaturesJson.ps1      - validate FeatureId uniqueness, required fields
    Test-AppsJson.ps1          - validate AppId format, RemovalMethod enum
  Integration/
    Test-ApplyUndo.ps1         - apply then undo each feature, verify registry state
```

Add a GitHub Actions workflow step `test.yml` that runs the unit tests on every pull request to `dev`.

### 3.2 - Add Dry-Run Mode to GUI

File: `Scripts/GUI/MainWindow-Deployment.ps1`, `Schemas/MainWindow.xaml`

Add a "Dry-Run Preview" toggle in the GUI header bar. When enabled, all apply operations pass `-WhatIf` to the underlying scripts and output a preview log instead of making real changes. This exposes the existing `SupportsShouldProcess` infrastructure that is already present in the PowerShell modules but currently hidden from GUI users.

### 3.3 - Add Run Summary Export

File: New `Scripts/Features/ExportRunSummary.ps1`

After a apply/undo operation completes, generate a timestamped JSON report at `%TEMP%\WinSwift_RunSummary_<timestamp>.json` containing:
- Date and time
- WinSwift version
- Windows build version
- List of features applied (FeatureId + status + any errors)
- List of apps removed
- Total duration in seconds

Surface this in the GUI as a "View Last Report" button in the completion modal.

### 3.4 - Refactor BlockTelemetryFirewall to Use HOSTS Fallback

File: `Scripts/Features/BlockTelemetryFirewall.ps1`

Integrate the HOSTS-based blocking from Track 2.4 as an automatic fallback: if a domain cannot be resolved to an IP at runtime, write it to HOSTS instead of silently skipping it. This eliminates the current silent failure mode.

### 3.5 - Add Search Highlight and AI Widget Disable to Default Preset

File: `Config/DefaultSettings.json`

Add to the `"Settings"` array:
- `DisableSearchHighlights: true`
- `DisableRecall: true`
- `DisableClickToDo: true`
- `DisableAISvcAutoStart: true`

These are safe defaults that should apply in all scenarios without controversy.

### 3.6 - GUI: Add "What Changed" Status Indicators

File: `Scripts/GUI/MainWindow-TweaksBuilder.ps1`, `Schemas/MainWindow.xaml`

Add a visual indicator next to each feature checkbox showing its current system state (Applied / Not Applied / Unknown). Use the existing `GetCurrentTweakState.ps1` infrastructure which already reads the live registry - it just needs to be wired into the UI rendering pipeline.

### 3.7 - Add Unattend.xml Generator to GUI

File: `Scripts/Features/UnattendGenerator.ps1`, `Schemas/MainWindow.xaml`

Surface the existing `UnattendGenerator.ps1` script (currently CLI-only) as a dedicated tab in the GUI. Allow the user to export their current selection as a Windows Setup `unattend.xml` answer file for use in automated deployments or fresh installs.

---

## Release Schedule

| Version | Track | Estimated Scope | Branch Strategy |
|---|---|---|---|
| v2.5.0 | Track 1 - Modern Bloatware and AI Purge | ~4-6 scripts, 10+ reg files, JSON updates | Feature branches -> `dev` -> `master` |
| v2.6.0 | Track 2 - Privacy and Telemetry Hardening | ~3-4 new scripts, 6+ reg files | Feature branches -> `dev` -> `master` |
| v3.0.0 | Track 3 - Refactoring and UI Improvements | Tests, GUI changes, new features | Feature branches -> `dev` -> `master` |

---

## Constraints

- Zero functional script alteration occurs until this plan is explicitly approved per track.
- Each track is validated on a real Windows 11 24H2 system before merging to `master`.
- All new FeatureIds must have a corresponding Undo registry file or explicit `DisableWhenApplied: true` flag.
- All commit messages follow the BiosSystem plain imperative style with no conventional commit prefixes.
- No em-dashes or en-dashes in any commit message or documentation file.
