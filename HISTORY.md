# Project History

## Origins
WinSwift is a private, rebranded fork of the widely successful open-source project `Raphire/Win11Debloat`. The original project provided a powerful PowerShell script with an extensive GUI built in WPF to customize and debloat Windows 11.

## Evolution
We cloned the repository to create a bespoke internal version that is easier to maintain and strictly aligns with our organizational needs. 

### Key Milestones:
1. **Initial Fork & Rebranding**: The project was cloned to the `classic` branch. All scripts, variables, and documentation referencing "Win11Debloat" were rebranded to "WinSwift". Original developer credits were maintained.
2. **Build System Integration**: Added a `build.ps1` script to dynamically merge the modularized `Scripts/` and `Schemas/` folders into a single, portable `WinSwift-Standalone.ps1` executable.
3. **UI Redesign**: Re-engineered the Graphical User Interface to be denser and more responsive. The 3-column category layout was reduced to 2 columns to limit vertical scrolling, and padding/margins were trimmed. High-contrast theming was applied to dropdowns to fix readability issues.
4. **Code Organization**: Abstracted extensive UAC elevation logic and path initialization out of the primary entry script and into dedicated helper scripts (`Ensure-Admin.ps1` and `Initialize-Environment.ps1`).

## Future Roadmap
- Implementation of a CI/CD pipeline via GitHub Actions to automate the bundling of `WinSwift-Standalone.ps1` on every push to `master`.
- Integration with external telemetry and dashboard services for remote execution monitoring.
