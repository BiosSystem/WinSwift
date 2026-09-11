# 🕵️ Telemetry & Privacy Hardening

Winnow uses a "Defense in Depth" approach to telemetry blocking.

## Service & Registry Disablement
We disable `DiagTrack` (Connected User Experiences and Telemetry) and `dmwappushservice`. 
Targeted ads and App Launch tracking are disabled via `HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo`.

## Dual-Layer Firewall Blocking
Microsoft often resets telemetry registry keys during major updates. To combat this, Winnow hardcodes outbound Windows Defender Firewall rules to block traffic to:
* `vortex.data.microsoft.com`
* `telemetry.microsoft.com`
* `settings-win.data.microsoft.com`
* `oca.telemetry.microsoft.com`

Even if the service starts, the traffic is dropped at the network layer.

## The Update Watchdog
With the `-EnableUpdateWatchdog` switch, Winnow registers a lightweight Scheduled Task (`\Winnow\Winnow_UpdateWatchdog`) that runs as SYSTEM. It triggers on the Windows Update install events (Event ID `19` and `43` from `Microsoft-Windows-WindowsUpdateClient`), with a daily fallback if the event trigger cannot be created. When it fires it re-applies the telemetry settings Windows Update most often resets, the `AllowTelemetry` policy and the `DiagTrack` service, and logs what it did to `%ProgramData%\Winnow\watchdog.log`.
