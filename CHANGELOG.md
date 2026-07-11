# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
