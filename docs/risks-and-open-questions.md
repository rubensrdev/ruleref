# Risks and open questions

Status of every open decision from `docs/idea.md`:

| Decision | Status | Where |
|---|---|---|
| App name | **Decided**: RuleRef, final | `CONTEXT.md` |
| One game or many | **Decided**: many games, one rulebook each | `docs/build-brief.md` (MVP slice), `docs/domain-model.md` |
| Cheat sheet in MVP / auto-fed | **Decided**: out until m4; when built, explicit action only, never auto-fed | `docs/build-brief.md` (Non-goals), `CONTEXT.md` |
| History: queries or disputes | **Decided**: disputes only; built after m4 | `CONTEXT.md`, `docs/domain-model.md` (Reserved) |
| Answer not in rulebook / exceptions | **Decided for m4**: explicit no-match state, never approximate (F14). AI behaviour **Deferred**: after m4, measured with 3–5 unanswerable questions in the eval set | `docs/build-brief.md` F14 |
| Multi-column extraction | **Decided**: PDFKit line order in the MVP; tables and the two-column contents are accepted degradations, measured by F16 | `docs/adr/0002-multi-column-extraction.md` |
| UI language | **Decided**: Spanish and English via String Catalog (`Localizable.xcstrings`) | this table |
| Passage segmentation rule | **Decided** (f06): a new passage starts when the vertical gap is greater than 0.5 × the page's median line height or a line lies above the previous one; a page break always cuts; no font or indentation rule. The ratio is recalibrated on Taifa in f18 | `docs/specs/f06-extract-passages.md`, `PassageSegmenter` |

## Blocking next phase

None.

## Implementation-time

- **Taifa segmentation finding for ADR-002 (f08, 2026-10-15).** With the 0.5 ratio unchanged, Taifa imports as 16 pages and 40 passages, mostly 2 per page: the body of each page is one passage of up to about 2,000 characters (23 of 40 are over 500), because its paragraph gaps are not above 0.5 × the median line height. The printed page number is its own passage on every page. No line-break hyphen is left inside a passage; a word split across a page break ("utiliza-" / "do).") stays split, since a passage never spans two pages. Search still finds the right page, but a match is a whole page and the highlight covers most of it. Decided 2026-10-16 (ADR-002 revision): f18 recalibrates the ratio on Taifa, measured with PDFKit; page-number and heading passages that remain are accepted and measured by the f16 baseline.
- **Ranking ties and match display.** F13 fixes the order. Whether a match shows a text excerpt or only the page number is decided in its spec.
- **Page viewer and "no UIKit" (F15).** Decided in ADR-004: PDFKit's `PDFView` in one `UIViewRepresentable` whose file imports `SwiftUI` and `PDFKit` only; `init.sh` does not change. Still open: whether it compiles without `import UIKit`; if not, f15 stops and the gate change is a separate harness decision.

## Later (after m4)

- **Eval set.** 25 questions written on 2026-10-15 (13 normal, 4 table, 4 false premise, 4 absent), scored by page. It lands as `RuleRefTests/Fixtures/taifa-3.0-eval.json` with F16's spec.
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
