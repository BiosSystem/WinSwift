# WinSwift Technical Wiki

Welcome to the comprehensive technical documentation for **WinSwift**. This wiki covers the internal architecture, core features, deployment methods, and security practices of the WinSwift engine.

## 🏗️ Architecture

WinSwift operates on a modular, PowerShell-driven architecture designed to ensure safe, traceable, and revertible system modifications without requiring external dependencies or installations.

### Core Engine (`WinSwift.ps1`)
The main script acts as the orchestrator. It manages:
- **Initialization:** Privilege elevation (UAC), strict error handling, and parameter parsing.
- **State Backup:** Snapshotting registry states before making destructive changes.
- **Module Loading:** Dynamically invoking targeted sub-components (Tweaks, Appx Removals, Privacy settings).

### Execution Flow
1. **User Execution:** The user triggers the script (locally or via web request).
2. **Elevation Check:** WinSwift verifies administrator privileges, prompting UAC if necessary.
3. **Parameter Processing:** Command-line switches and parameters are parsed to configure the run (e.g., Dry-Run mode, specific module inclusion).
4. **Targeted Operations:** The core engine dispatches tasks to specific modules:
   - *Telemetry & Privacy*
   - *Appx Package Removal*
   - *UI/UX Modifications*
   - *AI/Copilot Purge*
5. **Completion & Summary:** The script outputs a detailed summary of all modified keys, services, and packages.

## ✨ Features

WinSwift is divided into multiple targeted functionality groups:

### App Removal & Bloatware
- Cleans the Start Menu by removing OEM and pre-installed bloatware (e.g., TikTok, Candy Crush).
- Leverages PowerShell `Get-AppxPackage` and `Remove-AppxPackage`.

### Privacy & Telemetry Hardening
- Disables Windows diagnostic data collection and activity history.
- Applies hardcoded firewall and HOSTS file rules to block telemetry endpoints.
- Turns off targeted advertising IDs.

### The AI Purge (24H2 / 25H2)
- Neutralizes Copilot integrations system-wide.
- Disables Windows Recall snapshots.
- Disables embedded generative AI features in Paint, Notepad, and Photos.

### Performance Modes
- **Gaming Mode:** Switches to High Performance power plan, optimizes network latency, disables mouse acceleration.
- **Competitive Esports Mode:** Unlocks Ultimate Performance plan, sets ultra-low system timer resolutions (0.5ms), adjusts CPU/GPU scheduling.
- **Defender Exclusions:** Whitelists game libraries (Steam, Epic, GOG) to prevent real-time scan overhead.

### System-Wide Ad Blocker
- Disables Start Menu suggested apps, Settings app promotional banners, and Lock Screen ads.

### Advanced Tweaks
- Unattend XML Generator: Creates Windows installation files to bypass OOBE tracking and MS Account requirements.
- Automated Software Installer: Silently installs user-selected essential applications.
- Dry-Run Mode: Simulates execution and logs proposed changes without applying them.

## 🚀 Deployment

WinSwift is designed for flexible deployment across varying IT environments.

### 1. Web Execution (Quick Method)
Execute directly from the repository. Best for quick, one-off system setups.
```powershell
$f = New-TemporaryFile | Rename-Item -NewName { $_.Name + '.ps1' } -PassThru
irm https://raw.githubusercontent.com/BiosSystem/WinSwift/master/WinSwift.ps1 -OutFile $f
& $f
Remove-Item $f -Force
```

### 2. Standalone Build
For environments without internet access, use the standalone compiled script (`WinSwift-Standalone.ps1`), which bundles all modules and assets into a single portable file.

### 3. Enterprise Deployment
System Administrators can deploy WinSwift using management tools (e.g., Intune, SCCM). Use advanced parameters to execute silently:
```powershell
.\WinSwift.ps1 -Silent -AcceptEULA -ApplyTelemetryFixes
```

## 🛡️ Security

WinSwift implements strict security guidelines to protect the host system:

- **State Reversion:** Modifications are designed to be easily reversible. Users can undo changes via built-in revert scripts.
- **Protocol Hardening:** Closes common attack vectors by disabling outdated protocols (SMBv1, TLS 1.0) and blocking AutoRun and Windows Script Host.
- **Code Integrity:** All components are written in standard PowerShell. WinSwift strictly avoids downloading compiled binary executables (`.exe`) from untrusted third parties.
- **Open Source Transparency:** The entire codebase is open-source, allowing for full security audits before deployment.

---

*This wiki is maintained by the BiosSystem team.*
