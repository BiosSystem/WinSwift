# WinSwift integration tests

Unit tests exercise functions in isolation. These run `WinSwift.ps1` as a real
process, which is the only way to cover startup guards, parameter binding,
config loading, and exit codes together.

That difference is not theoretical. The first thing this suite found was that
the administrator guard did not stop anything: `Ensure-Admin.ps1` is dot-sourced,
`exit` inside a dot-sourced script does not terminate the caller, and a
non-elevated run walked straight into the apply pipeline. Three releases of unit
tests and static validation never caught it, because none of them ran the script.

## Risk tags

Every `Describe` block carries one tag, chosen by what it can do to the machine:

| Tag | What it does | Safe to run on |
|---|---|---|
| `ReadOnly` | Exercises `-Verify`, which reads state and exits before applying anything | Anywhere, including your workstation |
| `DryRun` | Asserts `-DryRun` writes nothing. A regression in the dry-run guard *would* write here | An ephemeral machine: CI runner or Sandbox |
| `Mutating` | Deliberately applies changes | Windows Sandbox only |

Nothing beyond `ReadOnly` runs unless you ask for it.

## Running them

Read-only checks, safe on a workstation:

```powershell
.\Tests\Integration\Invoke-IntegrationTests.ps1
```

Adding the dry-run checks, on a machine you can throw away:

```powershell
.\Tests\Integration\Invoke-IntegrationTests.ps1 -Ephemeral
```

The full suite runs in Windows Sandbox. Open `Sandbox\WinSwift-Tests.wsb`: it
maps the repository read-only, maps `Sandboxesults` writable, installs Pester,
and runs everything inside the sandbox. Edit both `HostFolder` paths in that file
if the repository is not at the default path.

**Windows Sandbox has to be enabled first.** It ships with Windows 11 Pro and
Enterprise but is off by default. From an elevated PowerShell:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -All
```

That needs a reboot. Check whether it is already on with
`Test-Path C:\Windows\System32\WindowsSandbox.exe`.

Results land in `Sandboxesults` on the host: `integration-results.xml` (NUnit),
`integration-summary.json` (counts plus the name and message of every failure),
and `sandbox-transcript.log`. Nothing else survives the sandbox closing, console
output included, so a run whose bootstrap fails is still diagnosable from the
transcript and the summary.

Requires Pester 5.7.1 or later. WinSwift refuses to run without elevation, so an
unelevated session will skip most cases and say so.

## What is covered

**`VerifyContract.Tests.ps1`** — `ReadOnly`. Exit-code contract for `-Verify` and
profile parsing. Every case is deterministic on any machine: whether a real tweak
is currently applied depends on how the host is configured, so none of these
assert on one. The cases that are machine-independent are an exempt-only profile
(`NotApplicable` must never fail a run), an unknown feature, an empty profile, a
missing profile path, and an app id that cannot exist.

**`DryRunSafety.Tests.ps1`** — `DryRun`. Proves `-DryRun` reaches the apply
pipeline and still changes nothing. The assertion targets the exact values the
selected feature would write, read out of its `.reg` file, rather than sweeping
the registry broadly.

**`ApplyRoundTrip.Tests.ps1`** — `Mutating`. Applies a registry-backed feature and
checks both the verification verdict and the individual values underneath it, so
a partially applied `.reg` file cannot pass as compliant.

**`RollbackContract.Tests.ps1`** — `Mutating`. The executable specification for
Track 1 automatic rollback. Rollback does not exist yet, so the whole block skips
itself until `InvokeChanges.ps1` references `Restore-RegistryBackupState`. When
Track 1 wires that up, these activate on their own.

They also pin the two open decisions in section 9 of the plan. The load-bearing
one is that an app-removal failure must **not** trigger rollback: a registry
restore cannot bring back an uninstalled Appx package, so rolling back there
would report a recovery that did not happen while the apps stay gone. If the
failure policy changes, these assertions are what has to change with it.

## File naming

Pester 5 only discovers files matching `*.Tests.ps1` when given a directory, so
these are named that way rather than following the `Test-*.ps1` convention used
in `Tests/Unit`, which CI invokes by explicit path. The runner fails when it
discovers nothing, because an empty suite otherwise reports success.

## Known gaps

**Undo cannot be tested.** Scenario 2 of Track 3 was an apply/undo round trip.
It is not writable yet. `WinSwift.ps1` initialises `$script:UndoParams` to an
empty hashtable and the only code that ever populates it is
`Scripts/GUI/Show-MainWindow.ps1`. `Invoke-UndoFeatures` and the per-feature
`RegistryUndoKey` metadata all exist, and all 112 features declare undo text, but
nothing on the command line can select a feature for undo.

The test is present and skipped, with the reason inline. The larger problem it
stands in for is that an unattended deployment cannot revert either.

**CI runs more than the plan expected.** Section 5.2 assumed CI would be limited
to non-mutating cases because Windows Sandbox is unavailable on hosted runners.
In practice the `windows-2025` runner is build 26100 and runs elevated, so it
clears both the Windows version gate and the administrator guard, and the
`ReadOnly` and `DryRun` tags both run there. Sandbox is still needed for
`Mutating`, because Server 2025 has no Start menu `start2.bin` and a limited Appx
stack.
