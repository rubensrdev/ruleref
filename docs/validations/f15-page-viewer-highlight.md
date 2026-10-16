# Validations: f15-page-viewer-highlight

## Validation 1 — revise — 2026-10-16
- Commit validated: fdfade7 (code e41a0f4, base main 6d183b5)
- Checks rerun: `./init.sh` exit 0, all 11 checks PASS (109 tests, 0 failed, 0 skipped, 0 expected failures); focused `xcodebuild test -only-testing:RuleRefTests/PageHighlightTests -only-testing:RuleRefTests/PDFPageViewTests` TEST SUCCEEDED (4 of 4); `git diff main...HEAD --stat` the 13 expected files; `git diff main...HEAD -- init.sh` empty; `PDFPageView.swift` imports `PDFKit` and `SwiftUI` only; manual read of `git diff main...HEAD -- RuleRef/` finds no `import UIKit`, `write(to:` or `dataRepresentation`; `PageHighlightTests.swift` line 1 is `import CoreGraphics` (no stray placeholder).
- Findings:
  - Medium (F1): `RuleRef/Shared/SamplePDF.swift` declares `previewHighlight: PageHighlight`, a `Features/` type, breaking the `ARCHITECTURE.md` rule "a folder uses only the folders below it"; not in spec item 7.
  - Low: `.task` early return unless `.loading` — acceptable, enforces "opens once".
  - Low: "Missing File" preview uses a never-created temporary path — acceptable, same outcome as an empty directory.
  - Low: `PageViewerFixture` lives in `PageHighlightTests.swift` rather than `RuleRefTests/Support/` — does not block; the spec's file list allows no extra file.
  - Low: `MatchRow.swift` doc comment "Not tappable until the page viewer (f15)" is stale — does not block; outside the spec's file list, noted in `PROGRESS.md`.
  - Low: a second `makeUIView` for the same document would add a second annotation — does not block; residual risk in `not_verified`.
  - Info: ADR-004 followed in full; PDFKit keeps the annotation bounds exactly; security checklist found nothing relevant.
- Not verified: scenario 4 (Taifa on the iPhone 16: search, tap a match, page titled "Page N" with the passage marked, back); the highlight's color and position and whether `go(to:on:)` in `makeUIView` scrolls before the view has a size; the previews (not rendered; `SamplePDF.data()` not run by any check); whether `NavigationLink` builds destinations eagerly; that `makeUIView` runs once per viewer; Taifa pages 3 and 12 and memory with large rulebooks; the Spanish texts on screen; iOS 26.0, a physical device, a Release build; a fresh clone with clean DerivedData; a grep/pickaxe run of the forbidden-API check (hook blocked it; covered by reading the diff); xcresult details.
- Repair brief:

  Implementation Repair Brief (revise 1 of 3)
  Scope: only `RuleRef/Shared/SamplePDF.swift` and the preview blocks of the page viewer files that already use `SamplePDF.previewHighlight`. Do not add or modify any other file. The spec's `--stat` check must still list exactly the same 13 files.

  1. In `RuleRef/Shared/SamplePDF.swift`:
     - Replace `static var previewHighlight: PageHighlight` with `static var previewLocator: Locator`, returning the same `.pdf(rulebookID: RulebookID(bytes: Data("sample page".utf8)), pageIndex: 0, bounds: secondParagraphBounds)`.
     - Keep the doc comment about the preview exception in `docs/domain-model.md`.
     - Afterwards, `SamplePDF.swift` must not mention any type from `Features/`.
  2. In the `#if DEBUG` preview blocks, replace `SamplePDF.previewHighlight` with `PageHighlight(locator: SamplePDF.previewLocator)`:
     - `RuleRef/Features/PageViewer/PDFPageView.swift` ("Page")
     - `RuleRef/Features/PageViewer/PageViewerContent.swift` ("Loading", "Highlighted", "Unavailable")
     - `RuleRef/Features/PageViewer/PageViewer.swift` ("Missing File")
     - A private `#if DEBUG` helper inside each preview file is fine. Do not put one in `Shared/`.
  3. Make no other changes. Leave the `MatchRow` comment and the location of `PageViewerFixture` as they are.
  4. Verify:
     - `./init.sh` ends with `init.sh: PASS` and 109 tests, 0 failed, 0 skipped.
     - The focused `xcodebuild test` from the spec passes 4 of 4.
     - `git diff main...HEAD -- RuleRef/Shared/` mentions no `PageHighlight` and no other `Features/` type.
     - `git diff main...HEAD --stat` still lists only the spec's files plus `feature_list.json` and `PROGRESS.md`.
  5. Commit as `fix(page-viewer): keep preview sample data below Features`, then add a new evidence entry with the new commit and leave the status `passing`.
