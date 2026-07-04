# AI Handover Document

## Project Overview
**Name**: WinSwift (Formerly Win11Debloat by Raphire)
**Purpose**: A lightweight, portable PowerShell GUI application used to optimize, debloat, and configure Windows.
**Architecture**: 
- **PowerShell** backend.
- **WPF (XAML)** frontend layout for the UI (`Schemas/`).
- Code is modularized inside the `Scripts/` folder and is bundled into a single standalone executable script via `build.ps1`.

## Branch Strategy
We utilize three core branches:
1. **`master`**: Production-ready code.
2. **`dev`**: Active development and refactoring (where current changes are made).
3. **`classic`**: Historical archive containing the unmodified, rebranded fork of Raphire/Win11Debloat for reference.

## Recent Architectural Changes
- **Modularization**: Boilerplate UAC elevation checks and environment initialization were extracted from `WinSwift.ps1` into `Scripts/Helpers/Ensure-Admin.ps1` and `Initialize-Environment.ps1`.
- **UI Redesign**: The main XAML UI (`Schemas/MainWindow.xaml`) was redesigned to use a 2-column grid to reduce vertical scrolling, along with decreased padding/whitespace.
- **Dropdown Readability**: `ComboBox` themes in `Scripts/GUI/SetWindowThemeResources.ps1` were updated to use high-contrast backgrounds to ensure dropdown text is readable against the application theme.

## Known Constraints & Limitations
- **UAC Elevation**: `WinSwift.ps1` requires Administrator privileges to execute successfully. Because of this, standard headless background tasks running in an unelevated context cannot bypass the UAC prompt.
- **GUI Screenshots**: Automated tools (like `CopyFromScreen`) cannot capture screenshots of the GUI while it is elevated due to session isolation and handle limitations. All UI screenshots (e.g., `Assets/Images/menu.png`) must be captured manually by the human user.
- **Identity Rules**: NEVER include names like 'Claude', 'Antigravity', 'Gemini', or 'AI Assistant' in git commits, code comments, or README files. Ensure all authorship appears human.

## Next Steps
- Verify the CI/CD pipeline automation (GitHub Actions).
- Monitor NAS dashboard telemetry integration for "all my services" (Carry-over from a prior related context).
- Replace `Assets/Images/menu.png` with a manual screenshot of the new UI layout.
