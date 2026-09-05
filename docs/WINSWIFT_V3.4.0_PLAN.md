# WinSwift v3.4.0 Plan — Recoverability and Proof

## 1. Context

The last three releases each added one half of a safety story and stopped:

| Release | Added | Left open |
|---|---|---|
| v3.2.0 | Registry backup and system restore enforcement before bulk removal | Nothing consumes the backup automatically |
| v3.3.0 | Desired-state verification with registry read-back and Appx checks | 10 of 112 features cannot be verified at all |
| v3.3.0 | Static validation and Pester unit coverage | `Tests/Integration/` is empty; nothing exercises a real apply |

WinSwift can now take a backup and can prove whether a change landed. It still cannot
*undo a failed run on its own*, and the proof does not cover the features most likely to
fail. v3.4.0 closes that loop.

Everything in this release extends infrastructure that already ships. No new subsystem is
introduced.

## 2. Scope

**Headline:** automatic rollback when an apply run fails.

**Supporting:**

- Verification coverage from 102/112 to 112/112.
- An integration test suite that exercises apply, failure, and rollback for real.
- Field validation of the 24H2 DISM fallback repaired in #9.

## 3. Track 1 — Automatic rollback on failed apply

### 3.1 Why this is mostly wiring

`Invoke-AllChanges` in `Scripts/Features/InvokeChanges.ps1` already runs in phases:

```
Phase 1  Registry backup          <- rollback material is created here
Phase 2  System restore point
Phase 3  Apply features           <- failures are counted here
Phase 4  Undo features
Final    Report failures, Export-RunSummary
```

The backup is taken *before* the apply phase, so at the moment of failure the material
needed to recover already exists on disk. `Restore-RegistryBackupState -Backup $backup` in
`Scripts/Features/RestoreRegistryBackup.ps1` is a complete, working restore entry point,
including the loaded-hive path for `DefaultUserProfile` and `User:*` targets.

`InvokeChanges.ps1` contains **zero** references to any restore function. The three missing
pieces are a handle, a policy, and a call.

### 3.2 What to build

**A handle.** Phase 1 discards the backup object once written. Capture it into a
run-scoped variable (`$script:RunRegistryBackup`) holding the backup payload and its file
path, so Phase 3 can reach it without re-reading from disk.

**A failure policy.** This is the one real design decision in the release, and it must be
settled before code is written. `$script:RegistryImportFailures` already counts registry
import failures, and `$script:AppRemovalFailures` counts removals. Neither currently
triggers anything except a yellow warning in the Final phase.

Proposed policy, to be confirmed:

| Condition | Action |
|---|---|
| Any registry import failure | Prompt to roll back; roll back automatically under `-Unattend` |
| App removal failure only | Do **not** roll back — removals are not restored by a registry backup, so rolling back the registry would misrepresent what was recovered |
| User cancellation (`$script:CancelRequested`) | Roll back changes already applied in this run |
| Failure during rollback itself | Abort, report loudly, leave the backup file in place and name it |

The app-removal exclusion matters. A registry restore cannot bring back an uninstalled
Appx package, so treating a removal failure as a rollback trigger would produce a run that
claims to have recovered while leaving apps gone.

**A call.** Invoke the restore between Phase 3 and Phase 4, before any undo work, so a
failed apply is not compounded by undo operations against a half-applied system.

### 3.3 Surfacing

- Extend `Export-RunSummary` (`Scripts/Features/ExportRunSummary.ps1`) with a rollback
  section: whether it triggered, what condition triggered it, which roots were restored,
  and whether the restore itself succeeded.
- Add a `-NoAutoRollback` switch for operators who would rather inspect a broken state
  than have it reverted underneath them.
- Return a distinct exit code for "apply failed and was rolled back" so unattended callers
  can tell it apart from a plain failure. v3.3.0 already established exit code `2` for
  verification noncompliance; this needs its own value rather than reusing `2`.

### 3.4 Acceptance criteria

- A run with an injected registry import failure restores the affected roots and reports
  it in the run summary.
- A run with an app removal failure and no registry failure does **not** roll back.
- `-WhatIf` never restores anything and says what it would have done, matching the
  existing `Restore-RegistryBackupState` WhatIf branch.
- A failed restore is reported with the backup file path so recovery can be finished by
  hand.
- `-SkipRegistryBackup` disables auto-rollback with an explicit warning at run start,
  rather than failing silently at the moment it is needed.

### 3.5 Upstream note

Upstream `Raphire/Win11Debloat` has an open issue (#612) and PR (#613) for automatic
registry rollback. Review both before finalizing the policy table — not to port the code,
since `InvokeChanges.ps1` is on the deferred-port list in `UPSTREAM.md` and has diverged,
but to avoid a gratuitously different failure model.

## 4. Track 2 — Verification coverage to 112/112

### 4.1 The gap

Of 112 features in `Config/Features.json`, 93 verify through `RegistryKey` read-back and 9
through a `VerificationAdapter`. Ten have neither and are silently unverifiable:

| FeatureId | Why registry read-back cannot cover it |
|---|---|
| `RemoveApps`, `Apps`, `RemoveGamingApps`, `RemoveHPApps` | Package state, not a registry value |
| `ForceRemoveEdge` | Package state plus filesystem leftovers |
| `ClearStart`, `ClearStartAllUsers`, `ReplaceStart`, `ReplaceStartAllUsers` | Start layout lives in a per-user layout file |
| `CreateRestorePoint` | An event, not a persistent desired state |

### 4.2 Approach

There is already a precedent in the codebase. `Test-FeatureApplied` in
`Scripts/Features/GetCurrentTweakState.ps1` handles `DisableWidgets` by querying
`Get-AppxPackage` and treating package absence as the applied state. The four app-removal
features and `ForceRemoveEdge` follow that pattern directly.

- **App removal features:** new `AppxAbsence` adapter resolving the feature's app list via
  the existing `Get-WinSwiftFeatureAppIds`, then checking installed *and* provisioned
  state. Provisioned state matters — a package can be uninstalled per-user while still
  provisioned and due to return on the next servicing pass.
- **`ForceRemoveEdge`:** extend the above with the leftover shortcut paths and autostart
  values that `Remove-EdgeAutostartValue` already knows about.
- **Start layout features:** new `StartLayout` adapter comparing the on-disk layout file
  against the expected shape.
- **`CreateRestorePoint`:** do not add an adapter. It is an action, not a desired state.
  Mark it explicitly exempt in `Features.json` and have the verification engine report it
  as `NotApplicable` rather than counting it as an unverifiable gap. Add a unit assertion
  that this is the *only* permitted exemption, so the count cannot silently regress.

### 4.3 Acceptance criteria

- `Test-FeaturesJson.ps1` asserts every feature has `RegistryKey`, `VerificationAdapter`,
  or the explicit exemption — so a new feature cannot be added without a verification story.
- `-Verify` reports a real verdict for all 111 verifiable features.
- Exit code `2` continues to mean noncompliant, and `NotApplicable` never contributes to it.

## 5. Track 3 — Integration tests

`Tests/Integration/` has existed since July and is still empty. CI runs static validation
and six unit files (470 lines total), none of which apply anything to a live system.

### 5.1 Scope

Windows Sandbox is the right harness: disposable, scriptable, present on Windows 11 Pro,
and it discards state on close so a destructive test cannot damage the host.

Target scenarios, in priority order:

1. Apply a small registry-only feature set, verify with `-Verify`, assert exit code `0`.
2. Apply, then undo, then assert the system returns to the pre-apply state.
3. Inject a registry import failure, assert rollback triggers and restores.
4. Inject an app removal failure, assert rollback does **not** trigger.
5. `-WhatIf` over the full feature set mutates nothing.

Scenarios 3 and 4 are the ones that give Track 1 its value — without them, auto-rollback
is an untested claim.

### 5.2 CI reality

Windows Sandbox is not available on GitHub-hosted runners. Options, in order of preference:

1. Keep integration tests **out** of the PR gate; run them on a self-hosted runner or
   manually before a release tag, and record the result in the release notes.
2. Split the suite: the parts that need no live mutation (`-WhatIf`, exit codes, profile
   parsing) run in CI; the mutating parts stay manual.

Do not block this track on solving CI. A manually run suite with a documented procedure is
worth more than no suite.

## 6. Track 4 — Field validation of the DISM fallback

The wildcard `/PackageName` bug fixed in #9 was never observed failing; it was diagnosed
from DISM's documented contract and the tell-tale tolerance of exit code 87. The fix is
reasoned, not measured.

Before tagging v3.4.0, on a real 24H2 machine with Copilot, Dev Home, or the new Teams
still provisioned:

1. Confirm `Get-AppxProvisionedPackage -Online` returns the expected package names.
2. Run the fallback and capture the actual `$LASTEXITCODE`.
3. Confirm the package is gone from the provisioned list afterwards.
4. Record the result in `CHANGELOG.md`.

If the fallback still fails, that is a v3.4.0 blocker, not a footnote — it is the path that
exists specifically for the packages 24H2 is most aggressive about reinstalling.

## 7. Explicitly out of scope

Deferred so they are not relitigated mid-release:

- **Localization.** Upstream PRs #764 and #643 and issue #499 all want it. The WinSwift GUI
  has diverged from upstream and its strings are hardcoded, so neither PR ports cleanly.
  This is its own release track.
- **Preset library.** Only `gaming-rig.json` exists. Cheap and user-visible, but it is
  breadth, not recoverability. Candidate headline for v3.5.0.
- **The deferred `ef8811d` port backlog.** Nine files listed in `UPSTREAM.md`. Note that
  `InvokeChanges.ps1` appears on both that list and Track 1 of this plan — see §8.
- **New tweaks from upstream enhancement issues** (#560, #482, #343, #267).

## 8. Sequencing and the one collision

```
Track 2 (verification)  ─┐
Track 3 (integration)   ─┼─> Track 1 (rollback) ─> Track 4 (field validation) ─> tag
                         ┘
```

Tracks 2 and 3 are independent and can run in parallel. Both should land **before** Track 1,
not after: rollback is the change most likely to break something, and it should be built
against a test suite and a verification engine that can actually catch the breakage.

**The collision:** Track 1 rewrites `InvokeChanges.ps1`, which is also on the deferred
upstream port list in `UPSTREAM.md`. Decide before starting whether to port upstream's
error handling for that file first or to write the rollback wiring against the current
code and re-reconcile afterwards. Doing both independently will produce a conflict that is
harder to resolve than either change alone. Recommendation: write rollback against the
current code, then reconcile once, with the integration suite from Track 3 as the safety
net.

## 9. Open decisions

These need answers before implementation, not during:

1. The failure policy table in §3.2 — specifically whether a registry import failure should
   prompt or roll back silently in interactive mode.
2. The new exit code value for "failed and rolled back".
3. Whether integration tests gate releases or merely inform them (§5.2).
4. The `InvokeChanges.ps1` ordering question in §8.
