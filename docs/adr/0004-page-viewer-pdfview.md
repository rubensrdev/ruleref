# ADR 0004: Page viewer — PDFKit's PDFView, the one UIKit-backed view

## Status
Accepted (2026-10-16)

## Context
f15 opens a match on its original page with the passage highlighted. ADR-001 says SwiftUI only, no UIKit. SwiftUI has no PDF view, and the highlight must mark the passage rectangle that the locator stores: `pdf(rulebookID, pageIndex, bounds)`, with `bounds` in page space.

The rulebook file is stored at import (f08, `RulebookStore.fileURL(for:)`) and is read only by the page viewer ("import means freeze").

`init.sh` rejects any `import UIKit` in `RuleRef/` and `RuleRefTests/`.

## Decision
- The page viewer wraps PDFKit's `PDFView` in one `UIViewRepresentable`, in a single file. It is the only UIKit-backed view in the app.
- That file imports `SwiftUI` and `PDFKit` only. `init.sh`'s UIKit rule does not change. If the file cannot compile without `import UIKit`, the implementer stops and reports; any change to the gate is a separate harness change that the user reviews and applies.
- The viewer opens its own `PDFDocument` from the stored file and never writes it back, so the stored file stays unchanged.
- The highlight is one `PDFAnnotation` of type `.highlight` with exactly the locator's `bounds`, added in memory to the locator's page. The viewer then calls `go(to:on:)` with the same bounds and page.
- The step from a locator to what the viewer receives (page index and highlight bounds) is a plain `nonisolated` value with tests. The rendered page and highlight are checked by hand on the iPhone 16, and the validator lists them in `not_verified`.

## Alternatives Considered
- **`PDFView.highlightedSelections` with `PDFPage.selection(for:)`**: native, but it derives new text bounds at view time. They differ from the stored locator, so f15's check (the bounds passed to the viewer equal the locator's) could not hold, and the text would be read again after import.
- **Quick Look**: it shows the document but gives no control over a highlight rectangle, and it is UIKit-backed as well.
- **SwiftUI `WebView`**: it can render a PDF but cannot highlight a page-space rectangle.
- **Render the page as an image**: pure SwiftUI, but zoom, scroll and sharpness would have to be built by hand.

## Consequences
- f15's spec names the file, the representable and the tested mapping value.
- ADR-001 gets a revision note pointing here; the UIKit line in `AGENTS.md` and the viewer item in `docs/risks-and-open-questions.md` point here too.
- On pages where text wraps an image, the highlight may cover part of the image (domain model, accepted).
- How much the highlight covers depends on the passage: before f18 most Taifa passages are a whole page body.
- Not verified when this ADR was accepted: that `UIViewRepresentable` with a `PDFView` compiles with `SwiftUI` and `PDFKit` alone under Swift 6 strict concurrency; how the highlight looks on iOS 26.0 and 27.
