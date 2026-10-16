# ARCHITECTURE.md

How the app and test targets are divided. Each folder is a boundary, not a file list: a file goes in the folder that owns its responsibility.

## RuleRef/

| Folder | Owns | May use |
|---|---|---|
| `App/` | The app entry point and its scene. | Everything below. |
| `Features/<Screen>/` | One screen: its views, its screen state and the messages it shows. Today `Library` and `Game`; `PageViewer` arrives with f15. | Everything below. |
| `Shared/` | Preview sample data (inside `#if DEBUG`) and helpers used by more than one feature. | Everything below. |
| `Search/` | Query folding, matching and ranking. Arrives with f13. | `Persistence/`, `Import/`, `Domain/`. |
| `Persistence/` | SwiftData models, the `Library` service over a `ModelContext`, import outcomes and the rulebook file store. | `Import/`, `Domain/`. |
| `Import/` | Reading a PDF and preparing its passages before anything is stored. | `Domain/`. |
| `Domain/` | Value types, identifiers and errors. | Foundation, CoreGraphics and CryptoKit only. |
| root | `Assets.xcassets` and `Localizable.xcstrings` (`init.sh` expects the catalog there). | |

## Rules

- A folder uses only the folders below it in the table, never one above.
- SwiftUI appears only in `App/`, `Features/` and `Shared/`. SwiftData appears only in `App/`, `Features/`, `Shared/`, `Search/` and `Persistence/`. PDFKit appears only in `Import/` and the page viewer (ADR-004).
- `Intelligence/` (Foundation Models) arrives after m4.
- No empty folders: a folder appears with its first file.

## RuleRefTests/

- Tests mirror the app folders: `App/`, `Features/<Screen>/`, `Persistence/`, `Import/`, `Domain/`, and `Search/` from f13.
- `Fixtures/` holds the Taifa fixture, its attribution and the eval set; `Support/` holds shared test helpers such as the synthetic PDF builder and `TestFixture` (test bundle lookup that fails on a missing resource).
- `Evaluation/` holds the eval set model, the page scoring and the baseline run (f16), whose report is exported to `docs/eval/`.
