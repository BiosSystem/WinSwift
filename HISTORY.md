# Project History

## Origins
WinSwift is a public, rebranded fork of the widely successful open-source project `Raphire/Win11Debloat`. The original project provided a powerful PowerShell script with an extensive GUI built in WPF to customize and debloat Windows 11.

## Evolution
The project was cloned and independently evolved by Bios-System to become a full-featured Windows optimization toolkit, adding unique modules not present in the upstream project.

### Key Milestones

1. **Initial Fork & Rebranding** (`v1.0.0`, 2026-07-04): The project was cloned to the `classic` branch. All scripts, variables, and documentation referencing "Win11Debloat" were rebranded to "WinSwift". Original developer credits were maintained.

2. **Build System Integration** (`v2.0.0`, 2026-07-11): Added a `build.ps1` script to dynamically merge the modularized `Scripts/` and `Schemas/` folders into a single, portable `WinSwift-Standalone.ps1` executable. GitHub Actions CI added for automated releases on tag push.

3. **UI Redesign** (`v2.0.0`): Re-engineered the Graphical User Interface to be denser and more responsive. The 3-column category layout was reduced to 2 columns, and High-Contrast theming was applied to dropdowns.

4. **Code Organization** (`v2.0.0`): Abstracted UAC elevation logic and path initialization out of the primary entry script into `Ensure-Admin.ps1` and `Initialize-Environment.ps1`.

5. **Extended Feature Modules** (`v2.1.0`, 2026-07-11 - Bios-System exclusive):
   - **Gaming Mode**: Power plan switching, Nagle disable, HAGS, raw mouse input, maintenance disable.
   - **Performance Tweaks**: Superfetch/SysMain, WSearch, Hibernate, Aero Shake, NumLock, WER.
   - **Security Hardening**: SMBv1, RDP, AutoRun, TLS 1.0/1.1, port blocking, WSH disable.
   - **Extended AI Purge**: 24H2/25H2 targets including Recall, Phone Link, Cloud Clipboard, Sluggishness Telemetry.
   - **Kill Windows Ads**: Lock screen Spotlight, File Explorer banners, Start menu promotions, Advertising ID.
   - Fixed the `irm|iex` one-liner bug that prevented quick-run from GitHub.
   - Embedded Bios-System attribution signatures across all new feature modules.

## Future Roadmap
- JSON-driven community preset profiles for sharing configurations.
- Dry-run mode (`-DryRun`) to preview changes before applying.
- Auto-update check against latest GitHub release tag.
- Multi-language support (Hebrew/English minimum).
