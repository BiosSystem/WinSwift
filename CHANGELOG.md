## [v3.2.0] - 2026-08-19
### Added
- Track 2 Guardrails: Hardcoded a mandatory System Restore execution in InvokeChanges.ps1 prior to bulk app removal.
- Fallback DISM uninstaller injected into RemoveApps.ps1 for resilient packages like Dev Home, new Teams, and Copilot Provider.
- CBS Registry backups triggered before feature modifications.

## [v3.1.0] - 2026-08-19
### Added
- Track 1 AI Purge: Deep disables for Paint Co-Creator AI, Windows Studio Effects AI telemetry, Auto SR (Super Resolution) analytics, Live Captions, and Voice Access.
- Start Menu Overrides: Injected BingSearchEnabled lock into Disable_Bing_Cortana_In_Search.reg.
- Appx Targets: Mapped Microsoft.Windows.AI.Copilot.Provider for complete removal alongside existing Copilot components.
- Cloud Nag Suppression: Silenced Windows Backup cloud sync nags and Smart App Control telemetry.

## [3.2.0] - 2026-08-14

### Added
* **OS R&D:** Audited 24H2 cumulative updates to ensure system stability against aggressive debloating practices.
* **Copilot Purge:** Integrated explicit system-wide registry blocks for Windows Copilot (`TurnOffWindowsCopilot`) in `ExtendedAIPurge.ps1`.
* **Safeguards:** Verified structural `CreateSystemRestorePoint` enforcement across all feature applications.
* **Docs:** Authored `WINDOWS_OS_DISCOVERY_REPORT.md` mapping current Windows architecture community findings.

## [3.1.0] - 2026-07-25

### Added
* **Modern Bloatware and AI Purge:** Added 24H2/25H2 AI purge targets (Photos Generative Fill, Clipboard AI, M365 silent install block, Outlook Copilot, Narrator AI).
* **Telemetry:** Refreshed telemetry block list with dual-method Firewall and HOSTS fallback. Expanded scheduled tasks purge from 8 to 24 critical tasks.
* **Privacy Hardening:** Added service-level telemetry disabling (DiagTrack, WerSvc, DPS).
* **Advertising ID:** Added explicit disable for Microsoft Advertising ID.
* **Voice Activation:** Added disable for voice activation wakeword listeners.
* **Windows Update Hardening:** Added blocks for Windows Update driver search and feature version upgrades.
* **Pester Tests:** Added structural unit tests for Features.json, Apps.json, and all registry files via GitHub Actions.
* **Run Summary:** Added ExportRunSummary.ps1 to generate a timestamped JSON report of all applied changes and removed apps.
* **Unattend Generator:** Rewrote UnattendGenerator.ps1 to embed WinSwift first-boot execution, local admin creation, and computer name.

### Changed
* **CI/CD:** Re-engineered Dependabot configuration to group development and production dependencies, enforcing a weekly Sunday execution array to eliminate notification spam and maintain strict validation gates.
* **Git History:** Rewrote git history (via git filter-branch) across all commits to strip invalid AI signatures and conventional commit prefixes, complying with global BiosSystem repository rules.
* **Modernization:** Completed full architectural audit and competitive gap analysis against WinUtil and SophiaScript. Added WINSWIFT_MODERNIZATION_PLAN.md as the master execution ledger and completed execution of Track 1, Track 2, and Track 3.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [3.0.0](https://github.com/BiosSystem/WinSwift/compare/v2.4.0...v3.0.0) (2026-07-16)

### New Features

* **Update Watchdog:** Added a scheduled task that monitors Windows Updates and alerts if telemetry or bloatware is secretly re-enabled.
* **Telemetry Firewall Block:** Added hardcoded Windows Defender Firewall outbound rules to block Microsoft telemetry domains (vortex, sqm, watson) permanently.
* **Defender Gaming Exclusions:** Added automated exemption of Steam, Epic, and GOG libraries from real-time scans to reduce disk I/O stuttering.

## [2.4.0] - 2026-07-11

### Added
- **`autounattend.xml` Generator** (`-GenerateUnattend`): Generates an offline Windows installation answer file (at `C:\autounattend.xml` or custom `-UnattendOutPath`) that skips the Microsoft Account requirement, disables OOBE telemetry prompts, and bypasses Windows 11 setup limitations. 

---

## [2.3.0] - 2026-07-11

### Added
- **Software Installer** (`-InstallSoftware`): Winget-powered installer for a curated list of essential software (7-Zip, Brave, VLC, Notepad++, PowerToys, Git, VS Code). Accepts a custom list via `-SoftwareList`.
- **Community Preset Profiles** (`-Preset <path.json>`): Load JSON files containing an array of switches to apply instantly, allowing users to share "Gaming Rig" or "Privacy First" configurations.
- **Dry-Run Mode** (`-DryRun`): Simulates changes without applying them (sets `$WhatIfPreference = $true`), allowing you to preview exactly what registry keys and services will be affected.

---

## [2.2.0] - 2026-07-11

### Added
- **Competitive Gaming Mode** (`-EnableCompetitiveGaming`): Ultimate Performance power plan, high-precision timer resolution (`GlobalTimerResolutionRequests`), BCD `useplatformtick`/`disabledynamictick`, MMCSS `NetworkThrottlingIndex=0xFFFFFFFF` and `SystemResponsiveness=0`, MMCSS Games task `GPU Priority=8`/`Priority=6`/`Scheduling=High`, CPU core parking disable, optional Memory Integrity/VBS disable (`-DisableMemoryIntegrity`).
- **Settings App Ads Kill** (`-DisableSettingsAds`): Suppress all 25H2 Settings suggestions, personalized tips, post-OOBE nags (`ScoobeSystemSettingEnabled`), Windows Backup nudge, Teams reinstall prompts, and silent app installs by Microsoft.
- **Widgets Deep Disable** (`-DisableWidgetsDeep`): Remove `MicrosoftWindows.Client.WebExperience` package, kill data collection process, set Group Policy `AllowNewsAndInterests=0` (survives Windows Update), disable taskbar widget button.
- **Auto-Update Check**: On every launch, WinSwift silently queries the GitHub releases API and displays a banner if a newer version is available. Pass `-SkipUpdateCheck` to suppress.
- **Bios-System attribution signatures** in all four new modules.

---



### Added
- **Gaming Mode** (`-EnableGamingMode`): High Performance power plan, Nagle disable, raw mouse input, HAGS, maintenance disable, startup delay removal.
- **Performance Tweaks** (`-EnablePerformanceTweaks`): Disable SysMain/Superfetch, WSearch indexing, Hibernate (frees hiberfil.sys), Aero Shake, WER. NumLock ON, seconds in clock.
- **Security Hardening** (`-EnableSecurityHardening`): Disable SMBv1, RDP, AutoRun, TLS 1.0/1.1. Block ports 135/139/445. Disable Windows Script Host.
- **Extended AI Purge** (`-EnableExtendedAIPurge`): 24H2/25H2 targets - Recall snapshots, Phone Link deep-disable, Windows Ink AI, Sluggishness Telemetry tasks, OneDrive silent sign-in, Cloud Clipboard.
- **Kill Windows Ads** (`-DisableWindowsAds`): Lock screen Spotlight, File Explorer banners, Start menu suggested apps, Advertising ID, device-usage personalization, Windows Spotlight.
- **Bios-System attribution signatures** embedded in all new feature modules for fork attribution.

### Fixed
- Quick-run one-liner (`irm ... | iex`) broken due to `[CmdletBinding()]` at top level. Replaced with correct `irm -OutFile + & ` pattern in README.

---


## [2.0.0] - 2026-07-11

### Added
- **Standalone Bundler**: `build.ps1` compiles the entire project into a single self-contained `WinSwift-Standalone.ps1` executable - no extraction or folder structure required.
- **AI/Copilot Purge Module**: Comprehensive purge of Microsoft Copilot, Windows Recall, Click to Do, Edge AI, Paint AI, Notepad AI, and the underlying `WSAIFabricSvc` service.
- **Version Constant**: `WINSWIFT_VERSION` embedded directly in `WinSwift.ps1` for runtime version reporting.
- **Git Branching Strategy**: Production-ready `master`, active `dev`, and legacy-archive `classic` branches.
- **Full Documentation**: Initialized `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, architecture Mermaid diagram, and feature overview in `README.md`.

### Changed
- **Rebranding**: All project references migrated from `Win11Debloat` to `WinSwift` across all scripts, schemas, and assets.
- **UI Redesign**: Re-engineered the GUI from a 3-column to a responsive 2-column grid layout to drastically reduce vertical scrolling.
- **UI Styling**: Adjusted Category Card margins and padding; updated `ComboBox` high-contrast background colors for both light and dark themes.
- **Code Modularization**: Extracted admin verification and path initialization into `Ensure-Admin.ps1` and `Initialize-Environment.ps1`.
- **Credit**: Added explicit attribution to Raphire/Win11Debloat in README.

### Fixed
- Broken `readme-typing-svg` domain link in README.
- Path resolution bug introduced by dev branch refactoring.

---

## [1.0.0] - 2026-07-04

### Added
- Initial fork of [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat).
- Base rebranding to WinSwift across all scripts.



