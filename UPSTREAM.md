# Upstream synchronization ledger

## Current baseline

- Upstream repository: `Raphire/Win11Debloat`
- Upstream branch: `master`
- Reviewed commit: `fff1fcd0b21f6a2130baf0e5e9e790b2eec3f1c3`
- Reviewed date: 2026-08-23
- WinSwift release line: `3.3.0`

## Integrated safety changes

- Enforce Windows PowerShell 5.1 before loading runtime modules.
- Quote paths, scalar values, arrays, and unbound arguments during UAC elevation.
- Handle Mark-of-the-Web on PowerShell source files when Group Policy sets execution policy.
- Warn when Group Policy can override changes on a domain-joined machine.
- Validate required configuration, assets, schemas, and registry paths before execution.
- Initialize registry and app-removal failure counters.
- Support `-SkipExplorerRestart` while preserving `-NoRestartExplorer` as an alias.
- Support `-SkipRegistryBackup` for controlled deployment workflows.

## WinSwift-owned differences

- Keep WinSwift naming, BiosSystem authorship, standalone packaging, presets, and run summaries.
- Keep WinSwift AI, gaming, telemetry firewall, update watchdog, software installation, and unattended setup modules.
- Route core apply and undo actions through `Invoke-WinSwiftFeature` and `Undo-WinSwiftFeature`.
- Verify requested registry-backed and Appx-removal state through `Test-WinSwiftFeature`.
- Return a nonzero process code when unattended verification detects drift or cannot verify a requested feature.

## Reconciliation procedure

1. Fetch `upstream/master`.
2. Record the new upstream commit in this ledger.
3. Review safety, app-removal, registry, user-hive, and deployment changes.
4. Port compatible behavior through WinSwift modules.
5. Preserve upstream attribution and MIT license notices.
6. Run `Tests/Invoke-StaticValidation.ps1 -RequirePSScriptAnalyzer`.
7. Run every Pester file under `Tests/Unit`.
8. Rebuild `WinSwift-Standalone.ps1`.
9. Confirm the generated script parses under Windows PowerShell 5.1.
