# 🕵️ Telemetry & Privacy Hardening

WinSwift uses a "Defense in Depth" approach to telemetry blocking.

## Service & Registry Disablement
We disable `DiagTrack` (Connected User Experiences and Telemetry) and `dmwappushservice`. 
Targeted ads and App Launch tracking are disabled via `HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo`.

## Dual-Layer Firewall Blocking
Microsoft often resets telemetry registry keys during major updates. To combat this, WinSwift hardcodes outbound Windows Defender Firewall rules to block traffic to:
* `vortex.data.microsoft.com`
* `telemetry.microsoft.com`
* `settings-win.data.microsoft.com`
* `oca.telemetry.microsoft.com`

Even if the service starts, the traffic is dropped at the network layer.

## The Update Watchdog
WinSwift registers a lightweight Scheduled Task (`\WinSwift\TelemetryWatchdog`). 
This task triggers on Event ID `43` (Windows Update Installation). It silently checks if `DiagTrack` was re-enabled by Microsoft. If it was, it warns the user via a Toast Notification to re-run WinSwift.
