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

6. **Competitive & System Intelligence Modules** (`v2.2.0`, 2026-07-11 - Bios-System exclusive):
   - **Competitive Gaming Mode**: Ultimate Performance power plan, MMCSS tuning, high-precision timer resolution, BCD platform tick, CPU core unparking, optional VBS/Memory Integrity disable.
   - **Settings App Ad Killer**: 17 ContentDeliveryManager keys targeting 25H2 Settings suggestions, silent installs, post-OOBE nags, Windows Backup nudge.
7. **Ecosystem & Deployment Modules** (`v2.3.0`, 2026-07-11 - Bios-System exclusive):
   - **Software Installer**: `-InstallSoftware` uses Winget to auto-install a curated list of essential apps (7-Zip, VS Code, Git, Brave, etc.).
   - **Community Preset Profiles**: `-Preset <path>` allows loading JSON arrays of parameters for easy configuration sharing.
   - **Dry-Run Mode**: `-DryRun` sets global `$WhatIfPreference = $true` for safe previewing of changes.

8. **Unattended Deployment** (`v2.4.0`, 2026-07-11 - Bios-System exclusive):
   - **`autounattend.xml` Generator**: `-GenerateUnattend` builds an offline OOBE bypass file on-demand, skipping the Microsoft Account requirement and OOBE telemetry out of the box.

## Future Roadmap
- **v2.5.0**: Telemetry firewall block (outbound DNS/IP rules for Microsoft telemetry endpoints).
- **v3.0.0**: GUI v2 with sidebar navigation (Home, Gaming, Privacy, Security, Apps, Presets); multi-language support (Hebrew + English).
