# 📚 WinSwift Developer Wiki

Welcome to the technical documentation for WinSwift. These guides are meant for developers, sysadmins, and power users who want a transparent look at exactly how WinSwift operates under the hood. 

We believe in open-source transparency—no "black box" registry hacking. Below you will find deep-dives into the exact mechanisms, services, and paths we modify.

## Technical Guides

1. [⚙️ Execution Architecture](Execution-Architecture.md)
   *Learn how the WinSwift engine elevates privileges, parses `Features.json`, and safely applies changes using the `$WhatIf` dry-run system.*

2. [🤖 The AI Purge (24H2/25H2)](The-AI-Purge.md)
   *A breakdown of the registry keys and services targeted to neutralize Windows Recall, Copilot, and the WSAIFabricSvc.*

3. [🕵️ Telemetry & Privacy Hardening](Telemetry-And-Privacy.md)
   *Discover the exact domains blocked by our firewall rules and how the Update Watchdog scheduled task ensures your privacy survives Windows Updates.*

4. [🎮 Performance & Gaming Optimization](Performance-And-Gaming.md)
   *Understand MMCSS tuning (`NetworkThrottlingIndex`), 0.5ms Timer Resolutions, CPU core parking, and Windows Defender real-time exclusions.*

---
*WinSwift - The Ultimate Windows Debloater*
