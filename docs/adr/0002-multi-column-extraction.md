# ADR 0002: Multi-column extraction — PDFKit order in the MVP

## Status
Accepted

## Context
Board game rulebooks are often laid out in columns, with boxes, tables and text wrapped around images. Extraction (f06) takes lines in the order PDFKit returns them and starts a new passage on a paragraph gap or when a line lies above the previous one. Reading order across columns was left open until the demo fixture was checked.

Layout check of `RuleRefTests/Fixtures/taifa-3.0.pdf` on 2026-10-14, all 16 pages rendered and read:
- The body is single-column with a text layer.
- Text wraps around images, as on pages 3 and 12.
- Pages 2 and 10 hold small tables.
- The table of contents on page 16 is in two columns.

## Decision
- The MVP keeps PDFKit's line order and f06's segmentation. No reading-order reconstruction and no Vision pass.
- Multi-column rulebooks stay out of the MVP, as the build brief says.
- Taifa's tables and two-column table of contents are accepted as known degradations: a passage there may mix cells or columns.
- The baseline eval (f16) includes questions answered in a table, so the degradation is measured, not assumed.

## Alternatives Considered
- **Geometry-based reading order**: group lines into columns by their horizontal position and read column by column. Own code and cheap to start, but fragile with wrapped text and boxes, and Taifa does not need it.
- **Vision `RecognizeDocumentsRequest` (iOS 26)**: recognizes paragraphs, lists and tables from a page image. Native, but it works from rendered pages instead of the PDF text layer, adds per-page cost to the import, and its results need mapping back to PDF coordinates for locators and highlights.

## Consequences
- f06, f07 and f08 stay as specified.
- A match on a table or on the table of contents may show a mixed passage; the page and the highlight still point to the right place.
- Revisit after m4 if the f16 baseline shows misses on table questions, or if a target rulebook is multi-column. Either alternative is additive behind the import contract (ADR-003).
