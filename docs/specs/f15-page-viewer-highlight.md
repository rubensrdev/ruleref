# Feature Implementation Spec: Open a match highlighted on its page

## Source Feature

- `id`: f15-page-viewer-highlight
- `area`: page-viewer
- `depends_on`: f13-text-search
- `status`: not_started
- `source`: `feature_list.json`

## Goal

Tapping a match opens the page viewer on the match's page, with the passage rectangle highlighted. The viewer follows ADR-004 to the letter: PDFKit's `PDFView` in one `UIViewRepresentable`, in `RuleRef/Features/PageViewer/`, in a file that imports `SwiftUI` and `PDFKit` only. It opens its own `PDFDocument` from `RulebookStore.fileURL(for:)`, never writes it back, adds one in-memory `.highlight` `PDFAnnotation` with exactly the locator's bounds, then calls `go(to:on:)` with the same bounds and page. The step from a locator to what the viewer receives is a `nonisolated` value with tests.

## Non-Goals

- Any `import UIKit`, or any change to `init.sh`'s UIKit rule. If the representable cannot compile without `import UIKit`, the implementer stops and reports (ADR-004); a gate change is a separate harness decision.
- Selection-based highlights (`highlightedSelections`), Quick Look, `WebView` or rendering the page as an image (ADR-004, Alternatives).
- Saving annotations, sharing, printing, page thumbnails, search inside the viewer, a custom highlight color.
- Changing search (f13, f14) or extraction (f18).

## Job Story

When I find the match that settles the dispute,
I want to see it on its original page, marked,
so everyone at the table can read the rule as printed.

## Users And Permissions

- One on-device user; the viewer reads only the stored copy of the open game's rulebook.

## Acceptance Scenarios

Scenarios 1–3 are automated. They use f06's `SyntheticPDF` and, where a stored file is needed, an in-memory container and a `RulebookStore` over a unique temporary directory, removed at the end of the test (as in f17). Scenario 4 is manual.

### Scenario 1: the viewer receives exactly the locator's page and bounds

Given a two-page synthetic PDF imported into a game, and a match for a term on page 2 from `SearchIndex(rulebook:)`
When `PageHighlight(locator: match.passage.locator)` is built
Then its `rulebookID`, `pageIndex` and `bounds` equal the locator's, with `pageIndex` 1 and `bounds` equal (exactly, `==`) to the stored passage's bounds.

### Scenario 2: the highlight is one annotation with the same bounds, and the file is untouched

Given that imported rulebook's stored file and the `PageHighlight` of scenario 1
When `PageViewer.openDocument(for:store:)` opens it and `PDFPageView.addHighlight(_:to:)` runs
Then it returns the page at `pageIndex` 1; that page has exactly one annotation more than before, whose `bounds == highlight.bounds`; every other page has no new annotation; and the stored file's bytes are equal before and after.

### Scenario 3: a missing file or page is unavailable, not a crash

Given a `RulebookStore` over an empty temporary directory
When `PageViewer.openDocument(for:store:)` runs for any rulebook ID
Then it returns `nil`.
Given a two-page document and a highlight with `pageIndex` 5
When `PDFPageView.addHighlight(_:to:)` runs
Then it returns `nil` and no page gains an annotation.

### Scenario 4: the viewer on the iPhone 16 (manual)

Given Taifa imported on the iPhone 16
When the user searches, taps a match, then goes back
Then the page of that match appears with the passage marked, titled "Page N"; back returns to the matches. On pages 3 and 12 the mark may cover part of an image (domain model, accepted).

## Repository Research

### Files Inspected

- `docs/adr/0004-page-viewer-pdfview.md` — the decision this spec implements, and its "not verified" items.
- `RuleRef/Domain/Locator.swift` (`pdf(rulebookID:pageIndex:bounds:)`), `RulebookID.swift`; `RuleRef/Persistence/RulebookStore.swift` (`app`, `fileURL(for:)`), `Passage.swift` (`extractedPassage(rulebookID:)`).
- f13's spec: `Match` (`passage`, `pageNumber`), `MatchRow`, `GameContent`, the `Page %lld` key, the preview locator exception in `docs/domain-model.md`.
- `ARCHITECTURE.md` (`Features/PageViewer/` arrives with f15; PDFKit only in `Import/` and the page viewer), `DESIGN.md`, `AGENTS.md` (UIKit exception), `init.sh` (`no-uikit-xctest` rejects `import UIKit`).
- Project build settings (read only): `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`, so members declared in UIKit (for example `UIView.backgroundColor`, `UIColor`) are not visible without `import UIKit`.

### Existing Patterns To Follow

- `PDFDocument` is not `Sendable`; it stays on the main actor (default isolation) and never crosses isolation domains.
- `StringProtocol`/argument overloads for user data; content view plus wrapper split (`DESIGN.md`).

### Current Gaps

- f13 and f19 are not implemented yet; this spec relies on the names their specs define. If they differ, f15 follows the implementation and says so in its evidence.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-16:

- `UIViewRepresentable` (iOS 13+, `@MainActor`): `makeUIView(context:)`, `updateUIView(_:context:)`, `associatedtype UIViewType: UIView`; SwiftUI controls the view's frame, so the code never sets it.
- `PDFDocument(url:)` (failable). `PDFView.autoScales` (`@MainActor`). `PDFView.go(to:on:)` (iOS 11+): rect in page space; does nothing if already visible.
- `PDFAnnotation(bounds:forType:withProperties:)` (iOS 11+): bounds in page-space coordinates. `PDFAnnotationSubtype.highlight`. `PDFPage.addAnnotation(_:)`.
- **Not verified** (ADR-004 lists them too): that the representable compiles with `SwiftUI` and `PDFKit` alone under Swift 6 and member import visibility; whether `go(to:on:)` called in `makeUIView` scrolls before the view has a size; whether PDFKit keeps the annotation's `bounds` exactly (scenario 2 checks it; if not exact, stop and report); the highlight's default color and look on iOS 26.0 and 27.

Pieces in `RuleRef/Features/PageViewer/`:

1. `PageHighlight.swift`: `nonisolated struct PageHighlight: Equatable, Sendable { let rulebookID: RulebookID; let pageIndex: Int; let bounds: CGRect; init(locator: Locator) }`. The only path from a locator to the viewer.
2. `PDFPageView.swift`, imports `SwiftUI` and `PDFKit` only: `struct PDFPageView: UIViewRepresentable` with `document: PDFDocument` and `highlight: PageHighlight`.
   - `static func addHighlight(_ highlight: PageHighlight, to document: PDFDocument) -> PDFPage?`: if `0 <= pageIndex < document.pageCount`, add `PDFAnnotation(bounds: highlight.bounds, forType: .highlight, withProperties: nil)` to that page and return it; otherwise `nil`. No color or other property is set.
   - `makeUIView`: `PDFView()`, `autoScales = true`, `document = document`; if `addHighlight` returns a page, `go(to: highlight.bounds, on: page)`. Uses only members declared in PDFKit.
   - `updateUIView`: empty, with a comment: a viewer shows one fixed highlight; another match pushes another viewer.
3. `PageViewerContent.swift`: `PageViewerContent(pageNumber: Int, document: PDFDocument?, highlight: PageHighlight)`. If `document` holds the page: `PDFPageView`; otherwise `ContentUnavailableView("Page Unavailable", systemImage: "exclamationmark.triangle", description: Text("The rulebook file could not be opened."))`. Title `Text("Page \(pageNumber)")` (f13's key), inline display mode.
4. `PageViewer.swift`: wrapper `PageViewer(highlight: PageHighlight, pageNumber: Int, store: RulebookStore = .app)`; `@State private var document: PDFDocument?` set once in `init` from `static func openDocument(for id: RulebookID, store: RulebookStore) -> PDFDocument?` (`PDFDocument(url: store.fileURL(for: id))`). It never calls `write(to:)` or `dataRepresentation()`.
5. Opening from a match (`RuleRef/Features/Game/`): `GameContent` gains a generic destination builder `destination: (Match) -> Destination` and wraps each `MatchRow` in `NavigationLink { destination(match) } label: { MatchRow(match: match) }`. `GameView` passes `PageViewer(highlight: PageHighlight(locator: match.passage.locator), pageNumber: match.pageNumber)`. `GameContent`'s previews pass `EmptyView()`, so no preview opens a stored file.
6. Sample data: `RuleRef/Shared/SamplePDF.swift` (`#if DEBUG`): `static func data() -> Data`, one page with two invented paragraphs drawn with Core Graphics and Core Text (no PDFKit, no UIKit), and `static let secondParagraphBounds: CGRect` computed from the drawing constants. Previews (`#if DEBUG`): `PageViewerContent` "Highlighted" (`PDFDocument(data: SamplePDF.data())`, a highlight on `secondParagraphBounds`) and "Unavailable" (`nil`); `PDFPageView` "Page"; `PageViewer` "Missing File" with a store over an empty temporary directory. The previews' locators use the f13 preview exception.

Texts (key → `es`, `translated`): `Page Unavailable` → `Página no disponible`; `The rulebook file could not be opened.` → `No se ha podido abrir el archivo del reglamento.`

## Expected File Changes

- `RuleRef/Features/PageViewer/PageHighlight.swift`, `PDFPageView.swift`, `PageViewerContent.swift`, `PageViewer.swift` — create.
- `RuleRef/Features/Game/GameContent.swift`, `GameView.swift` — modify; links and destination.
- `RuleRef/Shared/SamplePDF.swift` — create.
- `RuleRef/Localizable.xcstrings` — modify; two keys.
- `RuleRefTests/Features/PageViewer/PageHighlightTests.swift` (scenario 1), `PDFPageViewTests.swift` (scenarios 2–3) — create.

## Visual Design Impact

- UI involved: yes. Design source: `DESIGN.md` and ADR-004.
- States: viewer with highlight; page unavailable. Match rows become navigation links.
- New design artifact required: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`: not needed — `Features/PageViewer/` and its PDFKit use are already defined.
- `AGENTS.md`, `DESIGN.md`, `CONSTRAINTS.md`: not needed. ADR-004: not changed; its open items are recorded in the evidence.

## Implementation Plan

1. Confirm f13 is accepted; otherwise stop.
2. Write scenarios 1–3 as failing tests.
3. Add `PageHighlight`, `PDFPageView` (check first that it compiles without `import UIKit`; if not, stop), `PageViewerContent`, `PageViewer`, `SamplePDF` and the previews.
4. Wire the links in `GameContent`/`GameView`; two keys; `./init.sh`; commit; evidence and `PROGRESS.md`; commit.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] `PageHighlightTests`, `PDFPageViewTests`.
- [ ] `PageHighlight`; `PDFPageView` with `addHighlight`; `PageViewerContent`; `PageViewer` with `openDocument`.
- [ ] Links from matches; `SamplePDF`; previews per `DESIGN.md`.
- [ ] Two catalog keys; `./init.sh` green (`no-uikit-xctest` included); evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0, all checks PASS, `no-uikit-xctest` and `catalog-coverage` included, 0 failed, 0 skipped.
- Focused run: `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/PageHighlightTests -only-testing:RuleRefTests/PDFPageViewTests` → `** TEST SUCCEEDED **`.
- The implementer commits code first and evidence later; the validator reviews the branch: `git diff main...HEAD --stat` lists only the files above plus `feature_list.json` and `PROGRESS.md`; `git diff main...HEAD -- RuleRef/Features/PageViewer/PDFPageView.swift` shows exactly two imports, `SwiftUI` and `PDFKit`; `git diff main...HEAD -- RuleRef/` contains no `import UIKit`, `write(to:` or `dataRepresentation`; `git diff main...HEAD -- init.sh` is empty.
- No UI tests and no E2E. The user checks scenario 4 and the previews.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, code commit, Xcode and simulator.
- The imports of `PDFPageView.swift`; whether the annotation bounds stayed exact.
- `not_verified`: the interface (scenario 4, the highlight's look and position, scrolling to it, the previews); iOS 26.0; a device; Taifa pages 3 and 12; memory with large rulebooks.

## Validator Checklist

- [ ] ADR-004 followed: one representable, imports `SwiftUI` and `PDFKit` only, its own `PDFDocument`, never written, one `.highlight` annotation with exactly the locator's bounds, then `go(to:on:)`.
- [ ] `PageHighlight(locator:)` is the only locator-to-viewer path; scenarios 1–3 pass.
- [ ] A missing file or page shows the unavailable state; no crash path.
- [ ] Previews use `SamplePDF` or an empty temporary store, never `RulebookStore.app` or a stored file; `GameContent` previews do not open the viewer.
- [ ] `init.sh` unchanged; two keys with `es`; `feature_list.json` and `PROGRESS.md` updated correctly; the interface is in `not_verified`.
