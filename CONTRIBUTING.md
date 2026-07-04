# Contributing to WinSwift

First off, thank you for considering contributing to WinSwift! It's people like you that make WinSwift such a great tool.

## Where do I go from here?

If you've noticed a bug or have a feature request, make sure to check if there's an existing issue. If not, feel free to open a new one!

## Branching Strategy

Our repository uses a 3-branch strategy:
- **`master`**: The stable, production-ready branch. Do not commit directly to `master`.
- **`dev`**: The active development branch. All Pull Requests should be targeted at the `dev` branch.
- **`classic`**: A historical archive branch representing the original un-refactored fork.

## Pull Requests

1. Fork the repo and create your branch from `dev`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs or features, update the documentation.
4. Ensure the script still works correctly (e.g. running `build.ps1` to bundle).
5. Ensure your code follows the existing style and conventions.
6. Open your Pull Request against the `dev` branch.

## Code Style

WinSwift uses standard PowerShell conventions. 
- Try to keep scripts modular by utilizing the `Scripts/` folder structure instead of adding everything into `WinSwift.ps1`.
- UI changes should be made carefully inside `Schemas/`.

## Golden Rules

- **Identity**: Never include any AI signatures or bot references in commits or code comments. All code must appear human-authored.
- **Credit**: Maintain credits to the original upstream repository (Raphire/Win11Debloat) where applicable.

Thanks again for contributing!
