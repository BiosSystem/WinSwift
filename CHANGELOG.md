# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.0] - 2026-07-11

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
