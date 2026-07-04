# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - (Dev Branch)

### Added
- **Standalone Bundler**: `build.ps1` that compiles the entire project into a single `WinSwift-Standalone.ps1` executable script.
- **Git Branching Strategy**: Project divided into `master` (production ready), `dev` (active development), and `classic` (legacy fork reference) branches.
- **Documentation**: Initialized `CHANGELOG.md` and updated `README.md` to clarify the project structure, history, and usage. Added `SECURITY.md` and `CONTRIBUTING.md`.

### Changed
- **Rebranding**: Changed all project references from "Win11Debloat" to "WinSwift" across all scripts, schemas, and assets.
- **Credit**: Added explicit credit to Raphire/Win11Debloat in the README.
- **UI Redesign**: Re-engineered the Graphical User Interface (`MainWindow.xaml`) to use a responsive 2-column grid instead of 3 columns to reduce vertical scrolling and utilize horizontal space effectively.
- **UI Styling**: Adjusted Category Card margins/padding to reduce empty whitespace.
- **Dropdown Readability**: Updated `ComboBox` High-Contrast background colors in Light and Dark themes to ensure text readability.
- **Code Reorganization**: Extracted repetitive boilerplate code (Admin verification and Paths initialization) from `WinSwift.ps1` into modular `Ensure-Admin.ps1` and `Initialize-Environment.ps1` scripts for improved maintainability.

## [1.0.0] - 2026-07-04 (Classic Branch)

### Added
- Initial clone of the Raphire/Win11Debloat repository.
- Rebranded base scripts to WinSwift.
