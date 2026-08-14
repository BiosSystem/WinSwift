<p align="center">
  <img src="https://readme-typing-svg.herokuapp.com?font=Share+Tech+Mono&weight=bold&size=34&duration=3000&pause=1000&color=00FF72&center=true&vCenter=true&width=600&lines=WinSwift;The+Ultimate+Windows+Debloater;Powered+by+BiosSystem" alt="WinSwift Title" />
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/BiosSystem/WinSwift?color=00ff72&style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/PowerShell-5.1+-blue?style=flat-square&logo=powershell" alt="PowerShell">
  <img src="https://img.shields.io/github/license/BiosSystem/WinSwift?style=flat-square" alt="License">
  <img src="https://img.shields.io/github/stars/BiosSystem/WinSwift?style=flat-square&color=00ff72" alt="Stars">
</p>

> **Notice:** WinSwift is an enterprise-grade, rebranded fork of the open-source project [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat). All original credits and core architecture concepts belong to the Raphire team.

## 🚀 Elevator Pitch

WinSwift is a lightweight, modular PowerShell engine designed to quickly declutter and customize Windows 11 without requiring installation. It instantly strips out pre-installed bloatware, neutralizes telemetry, purges intrusive AI integrations like Copilot and Recall, and hardens system privacy while providing maximum performance for gaming and enterprise deployments.

## ✨ Features

- **App Removal & Bloatware Cleanup:** Instantly remove pre-installed bloatware (TikTok, Candy Crush, OEM apps) and clean up your Start menu.
- **Privacy & Telemetry Hardening:** Disable background diagnostic data collection, activity history, and targeted advertising IDs at the root.
- **The AI Purge (24H2 / 25H2):** Completely neutralize Copilot, Windows Recall, Click to Do, and generative AI features embedded in OS apps.
- **Performance Modes:** Switch between Gaming Mode and Competitive Esports Mode to squeeze maximum performance out of your hardware with ultra-low latency configurations.
- **System-Wide Ad Blocker:** Block promotional banners on the Lock Screen, Start Menu suggested apps, and Settings app ads.

## 📖 Technical Documentation

For an in-depth look at our architecture, registry modifications, deployment methods, and security practices, please visit our technical wiki:

👉 **[Read the WinSwift Technical Wiki](docs/WIKI.md)**

## ⚡ Quick Start

Run WinSwift directly from PowerShell without downloading any files manually:

```PowerShell
$f = New-TemporaryFile | Rename-Item -NewName { $_.Name + '.ps1' } -PassThru
irm https://raw.githubusercontent.com/BiosSystem/WinSwift/master/WinSwift.ps1 -OutFile $f
& $f
Remove-Item $f -Force
```

> [!WARNING]
> While designed to be safe and reversible, modifying OS features carries inherent risks. Use at your own risk. Check out the [Wiki](docs/WIKI.md) for instructions on how to revert changes.

## 🤝 Contributing & License

We welcome contributions! Please see our [Contributing Guidelines](.github/CONTRIBUTING.md).  
WinSwift is released under the MIT license.
