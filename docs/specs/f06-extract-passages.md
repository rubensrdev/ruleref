# Feature Implementation Spec: Extract ordered passages

## Source Feature

- `id`: f06-extract-passages
- `area`: extraction
- `depends_on`: f05-rulebook-id
- `status`: not_started
- `source`: `feature_list.json`

## Goal

A pure extraction function turns an already opened `PDFDocument` and a `RulebookID` (f05) into an ordered array of `ExtractedPassage` values (text, ordinal, locator). Lines come from PDFKit; a fixed vertical-gap rule cuts them into passages; a page break always cuts. f06 also defines `Locator`, the value type every later feature (import, search, page viewer) relies on. Extraction has no errors of its own.

## Non-Goals

- Joining line-break hyphenation and normalising whitespace (f07).
- Multi-column reading order (ADR-002, not written yet); lines are taken in PDFKit order.
- Any rule based on font, font size or indentation.
- Reading the picked file, opening the `PDFDocument`, persistence, the `Passage` model, moving work off the main thread (f08).
- Errors: unreadable, encrypted (f10), no text layer (f09). A document with no text simply yields `[]`.
- Any interface.

## Job Story

When the app imports a rulebook,
I want its text cut into paragraph-sized passages, each pointing to its exact region on its page,
so I can search them and highlight the matching paragraph later.

## Users And Permissions

- None: internal domain logic.

## Acceptance Scenarios

Scenarios 1–7 use synthetic PDFs built in the test (see Technical Approach); 8–9 use `PageLine` values.

### Scenario 1: two paragraphs on one page

Given a one-page PDF with two paragraphs of 2 and 3 lines, separated by a gap of at least 1.0 × line height
When it is extracted
Then there are two passages, ordinals 0 and 1, pageIndex 0, with the expected texts (lines joined with "\n") in drawing order.

### Scenario 2: paragraph continued on the next page

Given a two-page PDF whose only paragraph has its last lines at the top of page 2, with in-paragraph spacing
When it is extracted
Then there are two passages, one per page (pageIndex 0 and 1), ordinals 0 and 1.

### Scenario 3: text wrapping an image

Given a page with a filled rectangle standing in for an image, and one paragraph whose middle lines are narrower and shifted right in x, with the same line spacing as the rest
When it is extracted
Then that paragraph is a single passage.

### Scenario 4: bounds

Given the PDFs of scenarios 1–3
When they are extracted
Then every passage's bounds is non-empty, lies inside its page's crop box, and contains the PDFKit bounds of each of its lines.

### Scenario 5: a page without text

Given a three-page PDF where page 1 (0-based) has no text
When it is extracted
Then no passage has pageIndex 1, passages from pages 0 and 2 carry pageIndex 0 and 2, and ordinals stay consecutive.

### Scenario 6: determinism

Given one synthetic PDF
When it is extracted twice
Then both arrays are equal (`==`, exact values).

### Scenario 7: rulebook ID

Given a `RulebookID` built from known bytes
When a PDF is extracted with it
Then every locator carries that exact `RulebookID`.

### Scenario 8: cut threshold

Given lines on one page with a median height of 10
When the gap between two lines is exactly 5.0, and in another case 5.01
Then the first stays in one passage and the second starts a new one.

### Scenario 9: ignored lines and clipping

Given lines where one is whitespace-only, one extends past the page edge, and a group lies entirely outside the page
When they are segmented
Then the whitespace line adds no text and does not affect the median; the overhanging segment's bounds are clipped to the page; the outside group yields no segment, so it never takes an ordinal.

## Repository Research

### Files Inspected

- `docs/domain-model.md` — Passage (never spans two pages), Locator (variant, equality, guarantees, determinism), edge cases (paragraph across a page break, image-only pages, multi-column).
- `docs/risks-and-open-questions.md` — the segmentation rule was open, to be settled on Taifa pp. 3 and 12; risk 1 (layout extraction) and 4 (keep extraction pure).
- `CONTEXT.md` — terms Passage, Locator, Rulebook ID, Text layer.
- `feature_list.json` — f06 entry; f07 and f08 depend on it.
- `init.sh` — `no-uikit-xctest` scans `RuleRef/` and `RuleRefTests/`; `no-pdf-in-app` forbids bundled PDFs.
- `RuleRef/`, `RuleRefTests/` — only the app shell and a smoke test; no domain code yet.
- `docs/specs/f02-create-game.md`, `docs/specs/f05-rulebook-id.md` — approved references for detail level; f05 defines `RulebookID` (`nonisolated struct`, `Hashable`, `Sendable`).
- `docs/adr/0001-stack-and-build-doctrine.md` — ingestion with PDFKit; `docs/adr/0003-scope-cut.md` — one `pdf` locator variant.

### Existing Patterns To Follow

- Default isolation is `MainActor`; pure domain logic is `nonisolated` explicitly.
- Swift Testing only; synchronized folders need no project change.

### Current Gaps

- `RulebookID` does not exist yet; f05 must be accepted first (`depends_on`).
- ADR-002 is referenced but not written; f06 does not need it.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled May 2026):

- `PDFDocument.pageCount`, `page(at:) -> PDFPage?`; `init?(data:)` (tests only).
- `PDFPage.numberOfCharacters`; `selection(for: NSRange) -> PDFSelection?`, which **raises an exception if the range length is 0**, so pages with `numberOfCharacters == 0` are skipped before calling it.
- `PDFSelection.selectionsByLine()` (one selection per line), `string: String?` (may contain linefeeds), `bounds(for: PDFPage) -> CGRect` (page space, 72 dpi, origin lower-left).
- `PDFPage.bounds(for: .cropBox)`: falls back to the media box when there is no crop box; the result is intersected with the media box; coordinates are unrotated page space.
- Isolation: the docs show `@MainActor` on `PDFView` members only. `PDFDocument`, `PDFPage` and `PDFSelection` are plain `NSObject` subclasses with no `@MainActor` and no `Sendable` conformance. The local iOS 27.0 simulator SDK headers carry no actor annotation on them either. The iOS 26 SDK is not installed here, so its headers were **not verified** directly.
- Test PDFs: `CGDataConsumer(data: CFMutableData)`, `CGContext(consumer:mediaBox:_:)`, `beginPDFPage(_:)`, `endPDFPage()`, `closePDF()`; Core Text `CTFontCreateWithName(_:_:_:)`, `kCTFontAttributeName`, `CTLineCreateWithAttributedString(_:)`, `CTLineDraw(_:_:)`. All without UIKit.

Types (all `nonisolated`):

1. `Locator`: `enum`, `Equatable`, `Sendable`, single case `pdf(rulebookID: RulebookID, pageIndex: Int, bounds: CGRect)`. Synthesized equality: exact values. "Only extraction builds locators" is a convention: within a single module any code can call the case. **Accepted gap**; no access trick is attempted.
2. `ExtractedPassage`: `struct`, `Equatable`, `Sendable`: `text: String`, `ordinal: Int`, `locator: Locator`.
3. `PageLine`: `struct`, `Equatable`, `Sendable`: `text: String`, `bounds: CGRect`.
4. `PassageSegmenter`: `enum`, pure, no PDFKit. `static let paragraphGapRatio: CGFloat = 0.5`. `static func segments(of lines: [PageLine], pageBounds: CGRect) -> [Segment]`, with `Segment` (`text`, `bounds`), in this order:
   - drop lines whose text is empty or whitespace-only;
   - median height of the remaining lines' bounds (even count: mean of the two middle values);
   - walk lines in order; `gap = previous.bounds.minY - current.bounds.maxY`; start a new segment when `gap > paragraphGapRatio * median` (strictly greater); a negative gap never cuts;
   - text: line texts joined with `"\n"`; bounds: union of line bounds, then `intersection(pageBounds)`; drop the segment if the result `isEmpty` (covers null).
5. `PassageExtractor`: `enum`. `static func lines(on page: PDFPage) -> [PageLine]`: skip if `numberOfCharacters == 0`; whole-page selection by range `0..<numberOfCharacters`; `selectionsByLine()` in PDFKit order; text is `string ?? ""` with trailing `.newlines` characters removed; bounds from `bounds(for: page)`. `static func extract(from document: PDFDocument, rulebookID: RulebookID) -> [ExtractedPassage]`: for `pageIndex in 0..<pageCount` (a `nil` page yields nothing), segment with the page's crop box, then assign ordinals from 0, consecutive across the rulebook.

Guarantees from f06: `0 <= pageIndex < pageCount`; bounds non-empty and inside the crop box; same input → equal output. "The rulebook ID refers to a rulebook in the library" only holds after import (f08).

Isolation: `PassageExtractor` is `nonisolated` because PDFKit's model classes are not main-actor isolated and the logic is pure and synchronous; it runs on the caller's isolation. `PDFDocument` is not `Sendable`, so a caller must not share one document across isolation domains. Where extraction runs is f08's decision. If the compiler shows these classes are `@MainActor` on the iOS 26 SDK, stop and report rather than adding isolation escapes.

Accepted consequence: a heading set close to its paragraph lands in the same passage. The ratio is recalibrated on Taifa in f08 if needed.

Test helper `SyntheticPDF` (in `RuleRefTests/`): builds `Data` page by page from explicit line specs (text, x, baseline y), Helvetica 12 pt via Core Text, optional filled rectangles (image stand-ins) and blank pages; returns `PDFDocument(data:)` and fails the test if it is `nil`. Spacing: within a paragraph the gap is ≤ 0.25 × line height, between paragraphs ≥ 1.0 ×. Each PDF-based test first `#require`s that precondition on the measured `PageLine` bounds, so a wrong layout fails loudly instead of passing by accident.

## Expected File Changes

- `RuleRef/Locator.swift`, `RuleRef/ExtractedPassage.swift`, `RuleRef/PageLine.swift` — create.
- `RuleRef/PassageSegmenter.swift` — create; cut rule, joining, union and clipping.
- `RuleRef/PassageExtractor.swift` — create; PDFKit line reading and ordinals.
- `RuleRefTests/SyntheticPDF.swift` — create; test PDF builder.
- `RuleRefTests/PassageSegmenterTests.swift` — create; scenarios 8–9.
- `RuleRefTests/PassageExtractorTests.swift` — create; scenarios 1–7.

## Visual Design Impact

- UI involved: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- `docs/risks-and-open-questions.md`: update — the passage segmentation rule moves from open to decided (gap > 0.5 × median line height, page break always cuts; recalibration on Taifa in f08).
- `docs/domain-model.md`: update — one line saying "only extraction builds locators" is a convention, not enforced in a single module.

## Implementation Plan

1. Write `SyntheticPDF` and a reader test confirming `lines(on:)` returns the drawn texts, in order, one per drawn line.
2. Write failing `PassageSegmenterTests` (scenarios 8–9); add `PageLine` and `PassageSegmenter`.
3. Write failing `PassageExtractorTests` (scenarios 1–7); add `Locator`, `ExtractedPassage`, `PassageExtractor`.
4. Update the two docs; run `./init.sh`; record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] `SyntheticPDF.swift` (no UIKit) and the reader test with its spacing precondition.
- [ ] `PageLine.swift`, `PassageSegmenter.swift` with `paragraphGapRatio`; `PassageSegmenterTests`.
- [ ] `Locator.swift`, `ExtractedPassage.swift`, `PassageExtractor.swift`; `PassageExtractorTests`.
- [ ] Docs updated; `./init.sh` green; evidence and `PROGRESS.md` updated.

## Verification Plan

- `./init.sh` exits 0 with every check PASS; test-results shows the new tests, 0 failed, 0 skipped.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/PassageSegmenterTests -only-testing:RuleRefTests/PassageExtractorTests`.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests); f06 has no interface.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–9.
- `not_verified`: real rulebooks and the Taifa calibration (f08); multi-column layouts; rotated pages; iOS 26 SDK isolation of PDFKit classes; iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–9 are covered by passing tests; PDFs are built in the test without UIKit.
- [ ] `Locator` has exactly one case, `pdf(rulebookID:pageIndex:bounds:)`, `Equatable` and `Sendable`; all new types are `nonisolated`.
- [ ] The cut uses only the vertical gap with the named 0.5 constant (strictly greater); no font or indentation rule.
- [ ] Pages with zero characters never reach `selection(for: NSRange)`.
- [ ] Text is joined with "\n" with no hyphen joining or whitespace normalising.
- [ ] No errors, file reading, persistence or UI were added.
- [ ] Both docs updated; `feature_list.json` and `PROGRESS.md` updated correctly.
