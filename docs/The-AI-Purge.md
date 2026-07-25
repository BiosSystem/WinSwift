# 🤖 The AI Purge (24H2/25H2)

Microsoft's aggressive integration of Generative AI into Windows 11 (24H2 and later) introduces new services that consume RAM and index local activity. WinSwift aggressively roots these out.

## Windows Recall & Snapshots
Windows Recall takes screenshots of your activity. We neutralize it by setting:
* `HKCU\Software\Policies\Microsoft\Windows\WindowsAI` -> `DisableAIDataAnalysis` = `1`
* We also forcefully disable the `WSAIFabricSvc` (Windows AI Fabric Service) from starting on boot.

## Microsoft Copilot
Copilot integration is removed from the taskbar, Windows Search, and Edge.
* `HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot` -> `TurnOffWindowsCopilot` = `1`
* Edge Discover & Copilot panels are suppressed via `HubsSidebarEnabled=0`.

## Click to Do & App AI
Generative AI in Paint and Notepad is disabled via localized policy registry injections, ensuring offline native apps stay offline.
