# Changelog

Document all notable WinSwift changes in this file.

Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.4.0] - 2026-09-06

### Added

- Roll back registry changes automatically when the apply phase fails, restoring the backup taken before the run.
- Add `-NoAutoRollback` to keep a failed run in place for inspection.
- Add `-Undo` to select features for undo from the command line. Undo was previously reachable only from the GUI, so unattended deployments could apply changes but never revert them.
- Return exit code `3` when an apply failed and was rolled back, and `4` when the rollback itself failed.
- Record rollback outcome, reason, and backup path in the run summary.
- Add the `AppxAbsence`, `StartLayout`, and `EdgeRemoved` verification adapters, giving all 112 features a verification story.
- Add the `NotApplicable` verification status for entries that carry no persistent desired state.
- Add an integration test suite that runs WinSwift as a real process, tagged by what it can change on the host.
- Add a Windows Sandbox harness for the mutating tests that writes results back to the host.

### Changed

- Route verification through the adapter declared in `Features.json` instead of a hardcoded feature list.
- Skip undo work after a failed apply.
- Pass exact provisioned package names to the 24H2 DISM fallback.
- Advance the upstream reconciliation baseline to `6012b02`.

### Fixed

- Stop a non-elevated run from continuing past the administrator guard. `exit` inside a dot-sourced script does not terminate the caller, so every exit in the guard was inert and the run proceeded into the apply pipeline.
- Catch apply-phase exceptions so rollback is reachable. A missing `.reg` file threw and escaped the run entirely.
- Write the run summary at all. Its export was guarded on `$script:RunStartTime`, which nothing ever assigned.
- Accept empty collections in `Export-RunSummary`, which rejected apply-only and undo-only runs.
- Remove a duplicate 24H2 DISM fallback that re-ran the same removal without error handling.
- Harden `ForceRemoveEdge` with a `WhatIf` guard, exit-code checking, and per-path cleanup reporting.

## [3.3.0] - 2026-08-23

### Added

- Add desired-state verification with registry read-back and installed plus provisioned Appx checks.
- Add `-Verify` and `-VerifyProfile` for unattended compliance checks.
- Return exit code `2` for noncompliant, unsupported, or failed verification.
- Add metadata-driven verification adapters for gaming mode, extended AI purge, security hardening, and telemetry firewall state.
- Add static PowerShell parsing, duplicate-function detection, JSON validation, and PSScriptAnalyzer enforcement.
- Add Pester coverage for verification, custom feature routing, and startup safety contracts.
- Add `UPSTREAM.md` and `CREDITS.md` for upstream reconciliation and attribution.

### Changed

- Require Windows PowerShell 5.1 before loading Appx and system restore code.
- Quote UAC elevation arguments with Win32-safe escaping.
- Limit Mark-of-the-Web handling to marked PowerShell source files when Group Policy overrides execution policy.
- Warn on domain-joined systems and return nonzero exit codes for missing runtime files.
- Route verified custom modules through the unified feature execution engine.
- Expose every configured feature through a direct command-line parameter.
- Require a system restore point before gaming, extended AI purge, security hardening, or telemetry firewall changes.
- Direct single-file quick-start installations to the standalone release asset.
- Propagate the modular process exit code through the standalone wrapper.
- Quote bootstrap launcher arguments safely and propagate the child process exit code.
- Run unit and static validation on pushes to `master` and `dev`.

### Fixed

- Remove an undefined extended AI purge expression.
- Initialize runtime parameters before the update check.
- Repair the malformed WPF fallback warning.
- Replace a Windows PowerShell 5.1-incompatible update banner.
- Keep registry backup progress counts consistent when `-SkipRegistryBackup` is used.
- Correct malformed application JSON and invalid software-installer interpolation found during release stabilization.
- Remove duplicate feature function declarations that bypassed parser-only validation.

## [3.2.0] - 2026-08-14

### Added

- Add system restore enforcement before bulk app removal.
- Add Component-Based Servicing registry backup support.
- Add a DISM fallback for resistant Appx packages.
- Add explicit system-wide Copilot policy blocks.
- Add Windows 11 architecture discovery documentation.

### Changed

- Validate 144 application records and the complete standalone payload before publication.

## [3.1.0] - 2026-07-25

### Added

- Add Windows 11 24H2 and 25H2 AI controls for Photos, Clipboard, Microsoft 365, Outlook, and Narrator.
- Add telemetry service and scheduled-task controls.
- Add Advertising ID and voice activation controls.
- Add Windows Update driver and feature-update policies.
- Add Pester tests for feature metadata, applications, and registry files.
- Add JSON run summaries and unattended Windows setup generation.

### Changed

- Expand telemetry firewall and HOSTS fallback coverage.
- Modernize the modular feature architecture and release validation workflow.

## [3.0.0] - 2026-07-16

### Added

- Add the Windows Update watchdog scheduled task.
- Add telemetry firewall and HOSTS endpoint blocking.
- Add Defender gaming exclusions for common game libraries.

## [2.4.0] - 2026-07-11

### Added

- Add `autounattend.xml` generation with configurable output paths.

## [2.3.0] - 2026-07-11

### Added

- Add Winget software installation for a curated application list.
- Add reusable JSON preset profiles.
- Add dry-run execution through `-DryRun`.

## [2.2.0] - 2026-07-11

### Added

- Add competitive gaming mode with power, timer, scheduler, and optional Memory Integrity controls.
- Add Settings advertising suppression.
- Add deep Widgets removal and policy enforcement.
- Add automatic release update checks.

## [2.1.0] - 2026-07-11

### Added

- Add gaming and performance profiles.
- Add security hardening and extended AI purge modules.
- Add Windows advertising suppression.

### Fixed

- Replace the incompatible pipeline quick-run command with file-based execution.

## [2.0.0] - 2026-07-11

### Added

- Add the standalone source bundler.
- Add the AI and Copilot purge module.
- Add the WinSwift version constant and branch release model.
- Add project documentation, security policy, and contribution guidelines.

### Changed

- Rebrand the Win11Debloat fork as WinSwift while preserving upstream attribution.
- Modularize administrator checks and environment initialization.
- Redesign the WPF interface around a responsive two-column layout.

## [1.0.0] - 2026-07-04

### Added

- Create the WinSwift fork from [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat).

[3.3.0]: https://github.com/BiosSystem/WinSwift/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/BiosSystem/WinSwift/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/BiosSystem/WinSwift/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/BiosSystem/WinSwift/compare/v2.4.0...v3.0.0
[2.4.0]: https://github.com/BiosSystem/WinSwift/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/BiosSystem/WinSwift/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/BiosSystem/WinSwift/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/BiosSystem/WinSwift/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/BiosSystem/WinSwift/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/BiosSystem/WinSwift/releases/tag/v1.0.0
