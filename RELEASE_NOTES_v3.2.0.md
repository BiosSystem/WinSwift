# WinSwift v3.2.0 Release Notes

WinSwift v3.2.0 stabilizes the build pipeline, resolves structural syntax blockers, and clears
significant technical debt from the release source.

## 🐛 Bug Fixes

- Correct the malformed Copilot `AppId` array in `Config/Apps.json`.
- Fix invalid variable interpolation in `Scripts/Features/SoftwareInstaller.ps1`.

## 🧹 Technical Debt & Refactoring

- Remove 460 lines of duplicated PowerShell function declarations from
  `Scripts/Features/InvokeChanges.ps1`.

## ✅ Validation

- Validate 144 application records and 146 application identifiers.
- Confirm zero parse errors across all 98 tracked PowerShell files.
- Confirm the standalone package builds and parses successfully.
