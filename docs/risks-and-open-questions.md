# Risks and open questions

Status of every open decision from `docs/idea.md`:

| Decision | Status | Where |
|---|---|---|
| App name | **Decided**: RuleRef, final | `CONTEXT.md` |
| One game or many | **Decided**: many games, one rulebook each | `docs/build-brief.md` (MVP slice), `docs/domain-model.md` |
| Cheat sheet in MVP / auto-fed | **Decided**: out until m4; when built, explicit action only, never auto-fed | `docs/build-brief.md` (Non-goals), `CONTEXT.md` |
| History: queries or disputes | **Decided**: disputes only; built after m4 | `CONTEXT.md`, `docs/domain-model.md` (Reserved) |
| Answer not in rulebook / exceptions | **Decided for m4**: explicit no-match state, never approximate (F14). AI behaviour **Deferred**: after m4, measured with 3–5 unanswerable questions in the eval set | `docs/build-brief.md` F14 |
| Multi-column extraction | **Deferred**: ADR-002 (T3) | below |
| UI language | **Decided**: Spanish and English via String Catalog (`Localizable.xcstrings`) | this table |

## Blocking next phase

None.

## Implementation-time

- **Multi-column extraction (ADR-002, T3).** Geometry-based reading order vs. Vision document recognition. The MVP ships single-column only.
- **Passage segmentation rule.** How paragraphs are cut from PDFKit lines (vertical gap threshold, indentation). Settle on Taifa pp. 3 and 12 (text wrapping images) early, before search is built on top.
- **Ranking ties and match display.** F13 fixes the order. Whether a match shows a text excerpt or only the page number is decided in its spec.
- **Page viewer and "no UIKit" (F15).** The viewer will use PDFKit's `PDFView` inside a `UIViewRepresentable`, the only exception to "no UIKit" (ADR-001). To be decided in its own ADR within the T4 spec (P4). Check whether `import PDFKit` is enough or that single file also needs `import UIKit`; `init.sh` currently rejects any UIKit import, so the ADR must also say how the gate allows it.

## Later (after m4)

- **Eval set authoring.** ~25 real questions with expected page, including 3–5 with no answer in the rulebook. Owner: the user. Needed before F16.
- AI answering with Foundation Models and @Generable; abstention when the rulebook is silent; citing several passages (rule + exception).
- Embeddings hypothesis (NLContextualEmbedding + cosine). Kept only if it beats the baseline on page precision.
- Open question for disputes: whether a dispute whose rulebook is gone is shown as "stale".
- Scope already listed in `docs/build-brief.md` Non-goals (sharing, cheat sheet, photos, web importer) needs no further decision now.

## Assumptions

- Every Taifa 3.0 page with body text has a usable text layer, and PDFKit returns per-line bounds for it.
- Taifa 3.0 (CC BY-NC-SA) can be versioned in the test target with an attribution file, never shipped in the app.
- Xcode 27 and an iOS 27 simulator are available on the dev machine. The iPhone 16 runs iOS 27.
- Queries and rulebook share a language (Spanish for the demo).
- Text search alone answers enough eval questions for the baseline to be a meaningful comparison.

## Risks

1. **Layout extraction** is where the project can actually get stuck. Mitigation: F06/F07 with synthetic PDFs first, then the Taifa fixture in F08; multi-column out of scope.
2. **Highlight imprecision**: the union rectangle can overlap images on wrapped pages. Accepted for the MVP.
3. **Language mismatch** between query and rulebook degrades search and looks like a bug in a demo. Mitigation: Spanish demo end to end.
4. **SwiftData under strict concurrency** may slow F08 (atomic import off the main actor). Mitigation: keep extraction a pure function and persist in one step.
5. **Fragmented availability** (spare moments, weekends). Mitigation: slices are small and independent; cut from the end of the list, not the middle.
