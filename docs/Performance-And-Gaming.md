# 🎮 Performance & Gaming Optimization

For gamers and power users, WinSwift modifies the Windows Kernel scheduler and multimedia classes to prioritize foreground game performance.

## MMCSS Tuning
The Multimedia Class Scheduler Service (MMCSS) throttles network traffic when multimedia apps are running. We remove this bottleneck:
* `NetworkThrottlingIndex` = `0xFFFFFFFF` (Disables throttling).
* `SystemResponsiveness` = `0` (Allocates 100% CPU time to games, default is 80%).

## Timer Resolution
By default, Windows uses a 15.6ms system timer. This means the CPU wakes up to process input every 15.6ms. We force `GlobalTimerResolutionRequests` to allow programs to request `0.5ms` resolution, significantly reducing input lag in competitive shooters.

## CPU Core Parking & Dynamics
* `disabledynamictick=yes`: Stops Windows from dynamically pausing the system timer to save battery on desktops.
* Core Parking is disabled, ensuring all cores remain awake and ready for multi-threaded game engines, preventing latency spikes.

## Windows Defender Exclusions
Real-time scanning causes massive disk I/O bottlenecks when loading game assets. WinSwift automatically adds exclusion paths for standard install directories:
* `C:\Program Files (x86)\Steam\steamapps\common`
* `C:\Program Files\Epic Games`
* `C:\GOG Games`
