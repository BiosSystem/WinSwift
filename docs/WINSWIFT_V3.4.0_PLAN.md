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

## 3. Track 1 — Automatic rollback on failed apply (delivered)

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

### 3.6 Decisions taken, and what shipped

The two open questions from section 9 were settled before implementation:

- **Rollback is always automatic**, with `-NoAutoRollback` to opt out. One code path
  behaves the same interactive and unattended. A prompt at failure time would ask the user
  to decide with the least information they will ever have about what just broke.
- **Exit `3` means failed and rolled back cleanly; exit `4` means rollback itself failed.**
  4 is the only outcome that needs someone at the machine, so it stays distinct rather than
  folding into a single code. `0`, `1` and `2` keep their existing meanings.

Three defects were found while wiring it up, each of which would have made the feature
quietly useless:

- **`Invoke-ApplyFeatures` does not catch per-feature errors**, and a missing `.reg` file
  throws rather than only incrementing the failure counter. The exception escaped
  `Invoke-AllChanges` entirely, so the harshest failure mode skipped rollback altogether.
  The apply phase is now wrapped, and both a thrown error and a counted failure trigger
  rollback.
- **`$script:RunStartTime` was read but never assigned**, so the run summary export was
  guarded on a value that was always null. No summary had ever been written, in GUI or CLI,
  which also meant the GUI's "View Last Report" had nothing to open. Rollback had nowhere
  to be recorded until this was fixed.
- **`Export-RunSummary` rejected empty arrays.** `UndoneFeatureIds` was a mandatory
  `string[]`, which refuses `@()`, so an apply-only run would have thrown even once the
  guard passed. Both collection parameters now allow empty.

Undo is skipped after a failed apply. The system has just been restored, or is known to be
partially changed, and undo work on top of either makes the final state harder to reason
about.

`$script:AppRemovalFailures` is initialised and never incremented anywhere, so the
app-removal branch of the policy table has nothing to read. That is not a problem in
practice: the correct behaviour is for app removal failures not to trigger rollback, which
is what happens. Recorded here so the dead counter is not mistaken for working logic.

### 3.7 Not verified end to end

The rollback path itself has not been executed. It is covered by source-level assertions in
the unit suite, which CI runs, and by `RollbackContract.Tests.ps1`, which injects a real
failure by copying the repository and deleting one feature's `.reg` file. Those are tagged
`Mutating` and need Windows Sandbox, so they have not run yet. The run summary rollback
section was verified directly, both triggered and clean.


## 4. Track 2 — Verification coverage to 112/112 (delivered)

### 4.1 The gap, as actually found

The initial count of ten unverifiable features was measured from `Features.json` metadata
alone, and that overstated the gap. Three of the ten were already verified at runtime by a
hardcoded FeatureId list inside `Test-WinSwiftFeature`:

```powershell
if ($FeatureId -in @('RemoveApps', 'RemoveGamingApps', 'RemoveHPApps')) { ... }
```

So the metadata was incomplete, not the coverage. That is its own problem — routing by a
hardcoded list means `Features.json` does not describe how a feature is verified, and the
unit suite cannot tell a declared gap from an undeclared one.

The corrected picture:

| FeatureId | State before | Resolution |
|---|---|---|
| `RemoveApps`, `RemoveGamingApps`, `RemoveHPApps` | Verified, but by hardcoded list | Declared `AppxAbsence`; routing moved to metadata |
| `ForceRemoveEdge` | Genuinely unverified | New `EdgeRemoved` adapter |
| `ClearStart`, `ClearStartAllUsers`, `ReplaceStart`, `ReplaceStartAllUsers` | Genuinely unverified | New `StartLayout` adapter |
| `Apps` | Genuinely unverified | Exempt — it is a value-carrying CLI parameter, not a toggle |
| `CreateRestorePoint` | Genuinely unverified | Exempt — a one-shot action, not a desired state |

Real new verification work was five features, not ten. Two are exemptions rather than gaps.

### 4.2 What was built

- **Metadata-driven routing.** The hardcoded FeatureId list is gone. `Test-WinSwiftFeature`
  now dispatches on the declared `VerificationAdapter`, so `Features.json` is the single
  source of truth for how every feature is verified.
- **`AppxAbsence`** — resolves the app list through the existing `Get-WinSwiftFeatureAppIds`
  and checks installed *and* provisioned state. Provisioned state matters: a package can be
  uninstalled per-user while still provisioned and due to return on the next servicing pass.
- **`EdgeRemoved`** — checks the Edge uninstall key in the 32-bit registry view, plus the
  four autostart values `Remove-EdgeAutostartValue` clears. These are exactly the artifacts
  `ForceRemoveEdge` manipulates, so absence is a true applied-state signal.
- **`StartLayout`** — SHA-256 compares the on-disk `start2.bin` against the expected
  template: the bundled blank template for `ClearStart*`, the caller-supplied one for
  `ReplaceStart*`. The all-users variants check every user profile plus the default profile,
  since new users inherit from it.
- **`NotApplicable`** — a new verification status for entries with no persistent desired
  state. It is reported distinctly and feeds neither the failure nor the error count, so it
  cannot affect exit code `2`.

### 4.3 Acceptance criteria

All met:

- `Test-FeaturesJson.ps1` asserts every feature declares `RegistryKey` or a
  `VerificationAdapter`, so a new feature cannot be added without a verification story.
- A second assertion pins the exemption list to exactly `Apps` and `CreateRestorePoint`, so
  `NotApplicable` cannot become a dumping ground for features nobody wanted to verify.
- `NotApplicable` contributes to neither `FailedCount` nor `ErrorCount`.

### 4.4 Not verified end to end

`EdgeRemoved` and `StartLayout` were exercised directly against real registry and
filesystem state, including the negative cases. What has *not* been observed is a full
`-Verify` run across all 112 features on a live machine — that needs elevation and belongs
to the Track 3 integration suite.

## 5. Track 3 — Integration tests (delivered)

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

## 9. Decisions, resolved

1. **Failure policy.** Rollback is always automatic, with `-NoAutoRollback` to opt out. One
   behaviour interactive and unattended; a prompt at failure time asks the user to decide
   with the least information they will ever have.
2. **Exit codes.** `3` means failed and rolled back cleanly, `4` means rollback itself
   failed. `4` is the only outcome needing someone at the machine.
3. **Integration tests inform, they do not gate.** CI runs the `ReadOnly` and `DryRun` tags
   on every PR. `Mutating` needs Windows Sandbox, which hosted runners do not provide, so
   it stays a pre-release step rather than a merge gate.
4. **`InvokeChanges.ps1` ordering.** Rollback was written against the current code and the
   deferred upstream port will be reconciled once, on top of it, with the integration suite
   as the safety net.

## 10. What remains

Both items need hardware this work could not reach:

- **The rollback path has never executed.** It is covered by source-level assertions in CI
  and by `RollbackContract.Tests.ps1`, which injects a real failure by copying the
  repository and deleting one feature's `.reg` file. Those are tagged `Mutating` and need
  Windows Sandbox. Running them is the gate before tagging.
- **Track 4 field validation** needs a 24H2 machine with Copilot, Dev Home, or the new
  Teams still provisioned.
