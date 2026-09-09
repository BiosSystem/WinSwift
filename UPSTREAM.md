# Upstream Synchronization Ledger

## Current Baseline

- Upstream repository: `Raphire/Win11Debloat`
- Upstream branch: `master`
- Reviewed commit: `6012b02` (upstream `master` head at review time)
- Reviewed date: 2026-09-05
- Previous baseline: `fff1fcd0b21f6a2130baf0e5e9e790b2eec3f1c3` (2026-08-23)
- WinSwift release line: `3.5.0`
- Upstream changelog review: July 11 2026 upstream release (dropped CustomAppsList format, retired legacy CLI app removal, fixed Copilot removal, dropped sunset apps)

## Upstream Review Log

### 2026-09-05 review: `fff1fcd` to `6012b02`

Five upstream commits were assessed. Verdict per commit:

| Upstream commit | Subject | Disposition |
|---|---|---|
| `ef8811d` | Improve error reporting & handling (#741) | Partially ported (see below) |
| `f431c56` | Bump version | Not applicable, WinSwift maintains its own version line |
| `9b75b1a`, `687ddea`, `6012b02` | CONTRIBUTING.md edits | Declined, WinSwift maintains its own contributor guide |

#### Why `ef8811d` cannot be cherry-picked

`git cherry-pick ef8811d` applies to zero files in this repository. WinSwift renamed every
script touched by that commit when it moved off the upstream hyphenated `Verb-Noun.ps1`
file convention, so the patch would create a parallel set of upstream-named files and
duplicate every function they define. Attempting it would fail static validation on the
duplicate-function check.

| Upstream path | WinSwift path |
|---|---|
| `Scripts/AppRemoval/Invoke-ForceRemoveEdge.ps1` | `Scripts/AppRemoval/ForceRemoveEdge.ps1` |
| `Scripts/AppRemoval/Remove-SelectedApps.ps1` | `Scripts/AppRemoval/RemoveApps.ps1` |
| `Scripts/Features/Import-RegistryFile.ps1` | `Scripts/Features/ImportRegistryFile.ps1` |
| `Scripts/Features/Invoke-Changes.ps1` | `Scripts/Features/InvokeChanges.ps1` |
| `Scripts/Features/Invoke-SystemRestorePoint.ps1` | `Scripts/Features/CreateSystemRestorePoint.ps1` |
| `Scripts/Features/Replace-StartMenu.ps1` | `Scripts/Features/ReplaceStartMenu.ps1` |
| `Scripts/Features/Set-StoreSearchSuggestions.ps1` | `Scripts/Features/StoreSearchSuggestions.ps1` |
| `Scripts/Features/Telemetry-ScheduledTasks.ps1` | `Scripts/Features/TelemetryScheduledTasks.ps1` |
| `Scripts/Features/Windows-OptionalFeatures.ps1` | `Scripts/Features/WindowsOptionalFeatures.ps1` |
| `Scripts/Helpers/Import-ConfigToParams.ps1` | `Scripts/Helpers/ImportConfigToParams.ps1` |

#### Ported: `ForceRemoveEdge` hardening

`ForceRemoveEdge.ps1` was the only file in `ef8811d` that had not also diverged in content,
so its hardening was ported manually:

- Added a `WhatIf` guard. The function is exposed as the `ForceRemoveEdge` FeatureId and
  could previously run destructively when invoked directly under dry-run.
- Wrapped the routine in `try`/`catch`/`finally` and disposed the three open registry keys.
- Added `-Force -ErrorAction Stop` to Edge stub creation so a partial stub is not silently
  skipped.
- Captured the uninstaller exit code through `Invoke-NonBlocking` and reported nonzero.
- Replaced silent leftover deletion with per-path error reporting.
- Replaced four blind `reg delete ... *>$null` calls with `Remove-EdgeAutostartValue`,
  which distinguishes an already-absent value from a failure to inspect or remove one.
- Returned `$true`/`$false`. Both `Request-EdgeForceRemove` call sites discard the result
  with `$null =` to keep the caller's pipeline output unchanged.

#### Deferred

The remaining `ef8811d` changes target files where WinSwift content has diverged
substantially, so each needs an individual port rather than a patch application. Not
scheduled, tracked here so the decision is not relitigated:

`RemoveApps.ps1`, `ImportRegistryFile.ps1`, `InvokeChanges.ps1`,
`CreateSystemRestorePoint.ps1`, `ReplaceStartMenu.ps1`, `StoreSearchSuggestions.ps1`,
`TelemetryScheduledTasks.ps1`, `WindowsOptionalFeatures.ps1`, the GUI call sites, and the
new upstream `Test-ConfigConsistency.ps1` helper.

## Integrated Safety Changes

- Enforce Windows PowerShell 5.1 before loading runtime modules.
- Quote paths, scalar values, arrays, and unbound arguments during UAC elevation.
- Handle Mark-of-the-Web on PowerShell source files when Group Policy sets execution policy.
- Warn when Group Policy can override changes on a domain-joined machine.
- Validate required configuration, assets, schemas, and registry paths before execution.
- Initialize registry and app-removal failure counters.
- Support `-SkipExplorerRestart` while preserving `-NoRestartExplorer` as an alias.
- Support `-SkipRegistryBackup` for controlled deployment workflows.

## WinSwift-Owned Differences vs. Upstream

WinSwift diverges from the upstream Win11Debloat base in the following areas. These differences are intentional, maintained independently, and must not be overwritten during upstream reconciliation.

### Gaming and Low-Latency Subsystem

Upstream Win11Debloat covers only basic UI-level gaming tweaks (disabling GameDVR recording and Game Bar). WinSwift adds a full kernel-level latency optimization stack not present in any upstream release:

| WinSwift Module | Registry or Boot Target | Upstream Equivalent |
|---|---|---|
| `GamingMode.ps1` | High Performance power plan, Nagle disable, HAGS enable, GameDVR off | GameDVR off only |
| `CompetitiveGaming.ps1` | 0.5ms GlobalTimerResolutionRequests, BCD useplatformtick, disabledynamictick, MMCSS NetworkThrottlingIndex, MMCSS Games GPU Priority 8, CPU core parking ValueMax=0 | None |
| `AddDefenderGamingExclusions.ps1` | `Add-MpPreference` whitelist for Steam, Epic, GOG directories | None |

### Extended AI Purge (24H2 and 25H2)

Most of the granular AI-suppression regfiles are shared with upstream (verified identical at `6012b02`): `Disable_AI_Recall.reg`, `Disable_AI_Service_Auto_Start.reg`, `Disable_Click_to_Do.reg`, `Disable_Edge_AI_Features.reg`, `Disable_Paint_AI_Features.reg`, and `Disable_Notepad_AI_Features.reg`. WinSwift's own additions to the AI surface, without the binary deletion that would destabilize `explorer.exe` or `SearchHost.exe`, are:

- `Disable_Narrator_AI_Voices.reg` - removes online AI voice packs (not in upstream)
- `Disable_Photos_Generative_Fill.reg` - blocks Photos generative fill (not in upstream)
- `ExtendedAIPurge.ps1` - orchestrates the full sequence and adds the 24H2/25H2 GPO suppressions (Phone Link, Ink AI, cloud clipboard, Recall optional-component removal, M365 auto-install block, Narrator online voices, and more)

### 24H2 BitLocker Auto-Encryption Guard

The 24H2 change that enables software BitLocker XTS-AES 128 silently on clean installations is handled by `Disable_Bitlocker_Auto_Encryption.reg`, which sets `PreventDeviceEncryption = 1` under `HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker` before the first-run encryption trigger fires. This regfile is shared with upstream (identical content at `6012b02`), not a WinSwift-only addition.

### Telemetry Firewall and Scheduler Block

Upstream disables telemetry registry flags. WinSwift adds two additional layers:

- `BlockTelemetryFirewall.ps1` - applies Windows Firewall outbound block rules targeting Microsoft telemetry endpoints
- `TelemetryScheduledTasks.ps1` - disables the full set of Windows telemetry scheduled tasks in Task Scheduler

### Desired-State Verification Engine

Upstream does not implement post-apply state verification. WinSwift adds:

- `DesiredStateVerification.ps1` - reads actual registry values and Appx package states and compares against requested configuration
- `-Verify` parameter for inline verification after apply
- `-VerifyProfile` parameter for unattended compliance auditing against a JSON profile
- Exit code `2` for noncompliance, drift, or unsupported feature state
- Metadata-driven verification adapters for gaming, AI purge, security hardening, and telemetry firewall modules

### Unattend XML Generator and Software Installer

Upstream does not provide OOBE bypass tooling or silent software installation. WinSwift adds:

- `UnattendGenerator.ps1` - generates a Windows `unattend.xml` to bypass OOBE tracking and Microsoft Account requirements during setup
- `SoftwareInstaller.ps1` - silently installs user-selected essential applications via winget

## Capability Matrix: WinSwift vs. Ecosystem Alternatives

| Capability | WinSwift | Win11Debloat (Raphire) | WinUtil (Chris Titus) | SophiApp (farag2) | AtlasOS and ReviOS |
|---|---|---|---|---|---|
| **Architecture** | Native PowerShell 5.1 modular engine | PowerShell 5.1 script | PowerShell + WPF GUI | PowerShell module suite | AME Playbook / stripped ISO |
| **Execution footprint** | Pure in-memory, no install required | Pure in-memory | Web download + package manager | Local module import required | Full OS wipe + clean install |
| **Gaming latency stack** | Full stack (0.5ms timer, BCD clock, Nagle, MMCSS, HAGS, core unparking) | None | Basic (power plan + Game Mode) | Service toggles only | Varies per build |
| **Anti-cheat compatibility** | 100% verified (Vanguard, EAC, BattlEye, FACEIT) | 100% safe | 100% safe | 100% safe | High risk (stripped components trigger bans) |
| **24H2 BitLocker guard** | Registry fix (shared with upstream) | Same registry fix | Partial (recent micro-patch) | Registry-based | Stripped at ISO level |
| **24H2 AI purge depth** | Granular non-destructive GPO suppression | Basic Copilot removal | Recall and Copilot toggle | Granular service disables | Total binary removal (risk of shell crashes) |
| **Windows Update lifecycle** | Fully intact | Fully intact | Intact (unless update service killed) | Fully intact | Broken or frozen |
| **Post-apply verification** | Built-in -Verify and -VerifyProfile engine with exit code 2 | None | None | None | None |
| **Rollback capability** | Pre-run snapshot, automatic rollback on failed apply, System Restore, per-feature `-Undo` | Basic registry backup | System Restore only | Detailed restore script | Impossible without OS reinstall |
| **Standalone single-file build** | Yes (WinSwift-Standalone.ps1 bundles all modules) | No | No | No | N/A |

## Why WinSwift Uses Non-Destructive GPO Suppression

Alternative tools that delete `CoreAIComponents` binaries or strip UWP system packages from the Windows image cause the following documented failures in Windows 11 24H2:

- `explorer.exe` and `SearchHost.exe` crash loops when Recall or Click To Do binary dependencies are missing
- Windows Update error `0x800f081e` when cumulative updates attempt to patch stripped system packages
- Kernel anti-cheat initialization failures (Vanguard, EAC) when Xbox Identity Provider or Code Integrity service registrations are absent
- `Class Not Registered` COM errors in PowerShell 7 when DISM-backed service registrations are removed

WinSwift applies only policy and registry suppression that the Windows kernel honors without requiring the associated binary to be absent. This preserves shell stability, update chain integrity, and anti-cheat compatibility permanently.

## Release Hardening Verification

- Recheck the Windows PowerShell 5.1 guard against upstream before loading any runtime module.
- Recheck Win32-safe quoting for paths, scalar values, arrays, and unbound elevation arguments.
- Recheck Mark-of-the-Web handling against upstream and limit unblocking to marked PowerShell source files.
- Protect the three upstream safety contracts with Pester regression tests.
- Apply the same Win32-safe quoting contract to bootstrap launcher arguments and propagate child exit codes.
- Add metadata-driven verification adapters for WinSwift gaming, extended AI purge, security hardening, and telemetry firewall modules.
- Enforce a direct command-line parameter for every configured feature ID.
- Require a restore point before applying the four high-impact custom modules.

## Reconciliation Procedure

WinSwift and upstream no longer share git ancestry. Branch-relative comparisons such as
`git rev-list --count HEAD..upstream/master` report the whole of upstream's history and are
meaningless here. Diff against the reviewed commit recorded above instead:

```
git fetch upstream
git log --oneline <reviewed commit>..upstream/master
```

That range is accurate because the reviewed commit still exists in the upstream remote,
whether or not it is reachable from this repository's history.

1. Fetch `upstream/master`.
2. Record the new upstream commit in this ledger.
3. Review safety, app-removal, registry, user-hive, and deployment changes.
4. Port compatible behavior through WinSwift modules.
5. Preserve upstream attribution and MIT license notices.
6. Run `Tests/Invoke-StaticValidation.ps1 -RequirePSScriptAnalyzer`.
7. Run every Pester file under `Tests/Unit`.
8. Rebuild `WinSwift-Standalone.ps1`.
9. Confirm the generated script parses under Windows PowerShell 5.1.
