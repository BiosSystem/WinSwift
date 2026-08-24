# Security Policy for WinSwift

WinSwift is a modular Windows 11 optimization and debloating toolkit. Because WinSwift modifies Windows system configurations, security and OS stability are paramount.

---

## Supported Versions

| Version | Supported | Status |
|---|---|---|
| `3.3.x` | Yes | Active production release supporting Windows 11 23H2, 24H2, and 25H2 |
| `< 3.3.0` | No | Legacy baseline |

---

## Reporting a Vulnerability

Report vulnerabilities to `security@bios-system.net`. Do not open public GitHub issues.

---

## Security Principles & Hardening

### 1. Non-Destructive GPO / Policy Suppression
- WinSwift uses Group Policy and registry configurations to disable telemetry, Copilot, Recall, and background services. It **never deletes system binaries** (`explorer.exe`, `SearchHost.exe`), ensuring cumulative Windows Updates and anti-cheat drivers (Vanguard, EAC, BattlEye, FACEIT) remain 100 percent operational.

### 2. UAC Elevation & Win32 Argument Quoting
- Re-elevation processes rigorously escape paths, script parameters, and user flags to prevent command injection via crafted folder names or CLI arguments.

### 3. Mark-of-the-Web Safety
- The orchestrator validates execution policy and unblocks only signed/validated PowerShell scripts without disabling system-wide execution restrictions.

### 4. Desired-State Verification
- Integrated `-Verify` and `-VerifyProfile` audit modes allow administrators to inspect system state and verify drift with exit code `2` before applying changes.
