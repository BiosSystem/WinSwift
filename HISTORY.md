## [v3.2.0] - 2026-08-19
### Artifacts
- **Release Package**: WinSwift_v3.2.0.zip
- **SHA256**: 82AA1FB35BF980182A8587AC288366BA2D65A03D396A408BE65725F4A63E32C9
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

# Project History

## Origins
WinSwift is a private, rebranded fork of the widely successful open-source project `Raphire/Win11Debloat`. The original project provided a powerful PowerShell script with an extensive GUI built in WPF to customize and debloat Windows 11.

## Evolution
We cloned the repository to create a bespoke internal version that is easier to maintain and strictly aligns with our organizational needs. 

### Key Milestones:
1. **Initial Fork & Rebranding**: The project was cloned to the `classic` branch. All scripts, variables, and documentation referencing "Win11Debloat" were rebranded to "WinSwift". Original developer credits were maintained.
2. **Structural Split**: Separated core monolithic scripts into granular PowerShell components (`Features/`, `AppRemoval/`, `GUI/`).
3. **Data Localization**: Extracted massive hardcoded parameter arrays (apps, telemetry services) into standard JSON configuration files (`Apps.json`, `Features.json`).
4. **24H2/25H2 Adaptation (July 2026)**: Added deep blocks for modern Microsoft Copilot+, Windows Recall, and generative AI features injected into standard system apps.
5. **Modernization Audit (August 2026)**: Cross-referenced community bug reports to ensure debloat practices don't break Component-Based Servicing or Windows Updates, and formalized structural system restore logic.
2. **Build System Integration**: Added a `build.ps1` script to dynamically merge the modularized `Scripts/` and `Schemas/` folders into a single, portable `WinSwift-Standalone.ps1` executable.
3. **UI Redesign**: Re-engineered the Graphical User Interface to be denser and more responsive. The 3-column category layout was reduced to 2 columns to limit vertical scrolling, and padding/margins were trimmed. High-contrast theming was applied to dropdowns to fix readability issues.
4. **Code Organization**: Abstracted extensive UAC elevation logic and path initialization out of the primary entry script and into dedicated helper scripts (`Ensure-Admin.ps1` and `Initialize-Environment.ps1`).

## Future Roadmap
- Implementation of a CI/CD pipeline via GitHub Actions to automate the bundling of `WinSwift-Standalone.ps1` on every push to `master`.
- Integration with external telemetry and dashboard services for remote execution monitoring.




