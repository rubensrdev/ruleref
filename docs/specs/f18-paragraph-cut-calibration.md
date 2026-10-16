# Feature Implementation Spec: Paragraph cut calibrated on Taifa

Approval: approved by the user on 2026-10-16

## Source Feature

- `id`: f18-paragraph-cut-calibration
- `area`: extraction
- `depends_on`: f08-atomic-import
- `status`: not_started
- `source`: `feature_list.json`

## Goal

Importing Taifa 3.0 yields one passage per paragraph instead of one per page body, so a match and its highlight cover one paragraph. Only the cut ratio of f06's segmentation rule changes: `PassageSegmenter.paragraphGapRatio`, today `0.5`. The implementer measures the vertical gaps of Taifa with `PassageExtractor.lines(on:)`, picks a ratio that separates the gaps inside a paragraph from the gaps between paragraphs, records the measured values in the evidence, and adapts the synthetic f06 tests that depend on the old ratio or on the old synthetic line spacing, as declared below.

## Non-Goals

- Reconstructing reading order, columns or tables (ADR-002). Vision.
- Changing that a page break always cuts, or that a line above the previous one always cuts.
- A font, size, indentation or heading rule; dropping heading or page-number passages. Accepted risk: headings ("5.2 Combate") and printed page numbers may remain passages of their own; f16 measures it later.
- Re-importing rulebooks already stored: there is no migration. A rulebook imported before f18 keeps its passages until it is deleted (f12, after m4) and imported again.
- Search, viewer or interface changes.

## Job Story

When I search Taifa and open a match,
I want the match to be the paragraph that says it,
so I can read the rule without scanning the whole page.

## Users And Permissions

- No user-facing change in permissions; the import pipeline is unchanged except for the ratio.

## Acceptance Scenarios

Scenarios 1–3 run on `RuleRefTests/Fixtures/taifa-3.0.pdf`, opened with `PDFDocument(url:)` from the test bundle (missing fixture → the test fails, never skips) and extracted with `PassageExtractor.extract(from:rulebookID:)`. "Begins a passage" means a passage whose `pageIndex` is the given page and whose `text` has the given prefix. Page numbers below are printed numbers; page 5 is `pageIndex` 4.

### Scenario 1: a numbered paragraph begins a passage

Given the Taifa fixture
When it is extracted
Then a passage on page 5 begins with `6. Si el atacante gana`.

### Scenario 2: a plain paragraph begins a passage

Given the Taifa fixture
When it is extracted
Then a passage on page 5 begins with `Seguidamente el defensor suma`.

### Scenario 3: a line in the middle of a paragraph does not

Given the Taifa fixture
When it is extracted
Then no passage on page 5 begins with `avanzar una posición en su marcador de Bonus de Carta`, and the passage that begins with `6. Si el atacante gana` contains `avanzar una posición en su marcador de Bonus de Carta`.

### Scenario 4: the synthetic segmentation tests keep their meaning

Given the f06 and f07 synthetic tests, changed only as declared in "Declared test changes"
When `./init.sh` runs
Then they all pass, and each still checks what it checked before (the cut boundary, the median, ignored lines, clipping, page breaks, the wrapped image, hyphenation).

## Repository Research

### Files Inspected

- `RuleRef/Import/PassageSegmenter.swift` — `paragraphGapRatio = 0.5`; a cut when `previous.minY - line.maxY > ratio × median height` of the page's non-blank lines, or when `line.midY > previous.midY`.
- `RuleRef/Import/PassageExtractor.swift` — `lines(on:)` (one `PageLine` per `selectionsByLine()` entry) and `extract(from:rulebookID:)`.
- `RuleRefTests/Import/PassageSegmenterTests.swift` — five tests tied to `0.5` or to a gap that `0.5` keeps inside a paragraph.
- `RuleRefTests/Support/SyntheticPDF.swift` — `fontSize 12`, `lineStep 14`, `paragraphStep 32`; `requireSpacing` allows in-paragraph gaps up to `0.25 ×` height.
- `RuleRefTests/Import/PassageExtractorTests.swift`, `HyphenationExtractionTests.swift` — multi-line synthetic paragraphs that must stay one passage.
- `RuleRefTests/Persistence/TaifaImportTests.swift` — asserts `pageCount == 16` and non-empty passages, and attaches `taifa-passages.txt`; it asserts no passage count. Its private `TaifaFixtureToken` pattern for `Bundle(for:)`.
- `docs/adr/0002-multi-column-extraction.md` (revision 2026-10-16), `docs/risks-and-open-questions.md` (segmentation row), `feature_list.json` (f18 notes).

### Planner measurement (reference only, not evidence)

Measured on 2026-10-16 with PDFKit on macOS 27 (same `selectionsByLine()` code, not the iOS simulator), as gap ÷ page median line height (13.22 on every page checked):

- Taifa, all 16 pages: inside a paragraph −0.033 to −0.017; between paragraphs and after headings 0.069 to 0.25 (most 0.15–0.20); page numbers above 0.7. Pages 3 and 12 (text around images) follow the same values. A line split by an inline icon on page 5 ("…con el símbolo" / "(permanente)…") reads as two lines at the same height (gap −1.0), which does not cut.
- Synthetic PDFs: line height 12; in-paragraph gap 2.0 = 0.167 × height with `lineStep 14`; 0.0 with `lineStep 12`; between paragraphs 20.0 = 1.67 ×.

Consequence: a ratio that separates Taifa (somewhere in about 0.0–0.07) cuts every synthetic multi-line paragraph unless `SyntheticPDF.lineStep` shrinks. The iOS simulator may give other values; the implementer's measurement is the one that counts.

### Existing Patterns To Follow

- Fixture loading as in `TaifaImportTests` (a private token class per file, `#require` on the URL).
- `Attachment.record(_:named:)` for measurements readable from the result bundle (already used by f08).
- Pure logic is `nonisolated`; Swift Testing only.

### Current Gaps

- The validator cannot export attachments (`xcresulttool export` is not on its allowlist); measured values in the evidence are checked through the scenario tests, not re-extracted.

## Technical Approach

1. Measure. Add a test `taifaGapMeasurement` in the new `TaifaSegmentationTests` that, for each of the 16 pages, records every non-blank line's gap ÷ the page median and its first 40 characters with `Attachment.record(…, named: "taifa-gaps.txt")`. It asserts only that the fixture has 16 pages. Run it with a focused `xcodebuild test -only-testing:RuleRefTests/TaifaSegmentationTests` run, not `./init.sh` (which deletes its result bundle when it passes), and export the attachment from that run's result bundle with `xcrun xcresulttool export attachments`.
2. Choose the ratio from that file:
   - `maxInside`: the largest gap between two lines of the same paragraph, over all pages.
   - `minBetween`: the smallest gap before a line that starts a paragraph or heading, over all pages, ignoring the cut before a page number.
   - The ratio is a value with at most two decimals, `maxInside < ratio < minBetween`, as close to the middle as two decimals allow. If no such value exists, stop and report: the rule needs another cut criterion, which is out of scope.
3. Set `PassageSegmenter.paragraphGapRatio` to it. Its doc comment stays true; add one line naming f18 and the measured `maxInside`/`minBetween`.
4. Apply the declared test changes, then add scenarios 1–3.

### Declared test changes

`PassageSegmenterTests` (f06):
- `cutThresholdRatioIsOneHalf` → `cutThresholdRatioIsCalibratedOnTaifa`; expects the new value.
- `cutThresholdGapOfExactlyHalfTheMedianStaysInOnePassage` → `cutThresholdGapOfExactlyTheRatioStaysInOnePassage`, and `cutThresholdGapJustAboveHalfTheMedianStartsANewPassage` → `cutThresholdGapJustAboveTheRatioStartsANewPassage`: the gap becomes `paragraphGapRatio × height` and that plus 0.01. Keep the guard that the measured gap equals the threshold exactly; if floating point breaks it, change the line height (not the guard) until it holds.
- `ignoredLinesWhitespaceLineAddsNoText`: Beta moves up to touch Alpha (gap 0), because a 0.3 gap now cuts; the expected union bounds change accordingly.
- `ignoredLinesWhitespaceLineDoesNotAffectTheMedian`: the gap becomes `11.5 × paragraphGapRatio` (between the thresholds for medians 11 and 12), so the test still fails if the blank line counts.
- The other five tests do not change.

`SyntheticPDF` (f06 test support):
- `lineStep` 14 → 12 (equal to `fontSize`), so in-paragraph lines touch as in Taifa; `paragraphStep` stays 32.
- `requireSpacing`: the in-paragraph bound becomes `gap <= 0.5 × PassageSegmenter.paragraphGapRatio × height` (was `0.25 ×`), so a synthetic layout can never sit on the cut; the between-paragraph bound stays `>= 1.0 ×`.
- No assertion of `PassageExtractorTests`, `HyphenationExtractionTests` or the import tests changes. If any of them fails after these changes, stop and report.

Existing Taifa tests: no change. `TaifaImportTests` asserts no passage count; only its attachment content changes (more passages).

## Expected File Changes

- `RuleRef/Import/PassageSegmenter.swift` — modify; the ratio and one comment line.
- `RuleRefTests/Import/TaifaSegmentationTests.swift` — create; scenarios 1–3 and `taifaGapMeasurement`.
- `RuleRefTests/Import/PassageSegmenterTests.swift`, `RuleRefTests/Support/SyntheticPDF.swift` — modify; only the declared changes.
- `docs/risks-and-open-questions.md` — modify; the "Passage segmentation rule" row states the chosen ratio and that f18 measured it on Taifa with PDFKit.

## Visual Design Impact

- UI involved: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`: not needed — no new folder or dependency.
- `CONSTRAINTS.md`: not needed — the repo has none.
- `AGENTS.md`, `DESIGN.md`: not needed.
- Other docs: `docs/risks-and-open-questions.md` (above). ADR-002 already records that f18 recalibrates the ratio; no new ADR.

## Implementation Plan

1. Confirm f08 is accepted; otherwise stop.
2. Add `TaifaSegmentationTests.taifaGapMeasurement`, run it, export `taifa-gaps.txt`, choose the ratio.
3. Change the ratio, apply the declared test changes, add scenarios 1–3.
4. `./init.sh`; export `taifa-passages.txt` from a focused run of `TaifaImportTests` (same way as step 2) and read pages 3, 5 and 12; update the risks row; commit; record evidence and `PROGRESS.md`; commit.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] Gap measurement test and attachment; `maxInside`, `minBetween` and the ratio chosen by the rule above.
- [ ] `paragraphGapRatio` set, with its comment line.
- [ ] Declared changes to `PassageSegmenterTests` and `SyntheticPDF`; nothing else in existing tests.
- [ ] Scenarios 1–3 in `TaifaSegmentationTests`.
- [ ] Risks row updated; `./init.sh` green; evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0, all checks PASS, 0 failed, 0 skipped; the test count rises by the new tests only.
- Focused run: `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/TaifaSegmentationTests -only-testing:RuleRefTests/PassageSegmenterTests -only-testing:RuleRefTests/PassageExtractorTests -only-testing:RuleRefTests/HyphenationExtractionTests` → `** TEST SUCCEEDED **`.
- The implementer commits the code first and the evidence (`feature_list.json`, `PROGRESS.md`) in a later commit, so the validator reviews the whole branch: `git diff main...HEAD --stat` lists only the files above plus `feature_list.json` and `PROGRESS.md`; `git diff main...HEAD -- RuleRefTests/Import/PassageSegmenterTests.swift RuleRefTests/Support/SyntheticPDF.swift` shows only the declared changes; `git diff main...HEAD -- RuleRef/` touches only `PassageSegmenter.swift`.
- No UI tests; no E2E.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, code commit, Xcode and simulator.
- From `taifa-gaps.txt` on the simulator: `maxInside` and `minBetween` with the page and line where each occurs, and the chosen ratio.
- From `taifa-passages.txt`: total passages and per page (was 40); the passages of pages 3, 5 and 12, with a sentence on whether the text around the images on pages 3 and 12 stays in its paragraph.
- `not_verified`: the measurement on iOS 26.0 and on a device (only the iOS 27.0 simulator); other rulebooks than Taifa; how matches look in the app (no search yet); re-extraction of the attachments by the validator.

## Validator Checklist

- [ ] Only the ratio changed in app code; reading order, page-break cut and the "line above" cut are untouched.
- [ ] The ratio lies strictly between the recorded `maxInside` and `minBetween`, and scenarios 1–3 pass on the fixture.
- [ ] Changes to existing tests match "Declared test changes" exactly; no assertion was weakened or removed beyond them.
- [ ] Pages 3 and 12 are reported in the evidence.
- [ ] The risks row states the new ratio; `feature_list.json` and `PROGRESS.md` were updated correctly.
- [ ] No search, viewer, interface or heading/page-number rule was added.
