# Domain model

Terms follow `CONTEXT.md`. Scope is the m4 MVP; reserved concepts are noted at the end.

## Core concepts

- **Game** — name (unique, case- and diacritic-insensitive), optional rulebook.
- **Rulebook** — rulebook ID, page count, import date, stored file copy, ordered passages. Created only by a successful import; never edited afterwards.
- **Passage** — text (hyphenation joined, whitespace normalised), ordinal (reading order within the rulebook), locator. A passage never spans two pages.
- **Locator** — a value type. In the MVP it has one variant, `pdf(rulebookID, pageIndex, bounds)`. Future sources (web, photo) add variants; nothing else in the app changes.
- **Import** — a transient operation from a picked file to a rulebook or a failure. Not persisted.
- **Search** — a query scoped to one game's rulebook, producing matches or the no-match state. Not persisted.

## Relationships

- Library 1 — N Game.
- Game 1 — 0..1 Rulebook. A rulebook belongs to exactly one game.
- Rulebook 1 — N Passage (ordered by ordinal). Deleting a rulebook deletes its passages and stored file; deleting a game deletes its rulebook.
- Passage 1 — 1 Locator.
- Search reads passages only. The stored file is read only by the page viewer, never at search time ("import means freeze").

## The locator

**Identifies** one rectangular region on one page of one rulebook: the region that contains a passage's text.

- `rulebookID`: SHA-256 hex of the imported file's bytes.
- `pageIndex`: 0-based page index in that file.
- `bounds`: rectangle in PDF page space (points, PDFKit page coordinates), the union of the passage's line bounds.

**Equality**: two locators are equal when variant, rulebook ID, page index and bounds are all equal (exact stored values). Locators of different variants are never equal.

**A valid locator guarantees**:
- its rulebook ID refers to a rulebook in the library;
- `0 <= pageIndex < pageCount` of that rulebook;
- `bounds` is non-empty and lies inside that page's bounds;
- the region contains the passage's text, so the viewer can highlight it.

A locator is only constructed by extraction; there is no public way to build one by hand outside tests.

**Survival across re-import**: identity comes from file bytes, not file name or path. Re-importing the same file is a no-op, so existing locators stay valid unchanged. Extraction is deterministic: deleting a rulebook and importing the same file again yields equal locators. A different file (even one byte) is a different rulebook with different locators; there is no replace operation.

**Not handled in the MVP**: wrapping text around images can make `bounds` overlap the image. That's accepted. The highlight still marks the right paragraph.

## States and lifecycles

### Game

| State | Meaning |
|---|---|
| `empty` | No rulebook. Import is offered; search is not. |
| `ready` | Has a rulebook. Search is offered; import is not. |

Transitions: created → `empty`. Successful import: `empty` → `ready`. Delete rulebook (after m4, F12): `ready` → `empty`. Delete game (after m4, F04): any state → removed (cascades).

### Import

| State | Next |
|---|---|
| `picked` | → `fingerprinting` |
| `fingerprinting` (SHA-256) | → `duplicateNoOp` if the same game already holds this ID · → `failed(.alreadyImported(gameName))` if another game holds it · → `extracting` |
| `extracting` (PDFKit, per page) | → `failed(.unreadable)` if the file can't be opened · → `failed(.locked)` if encrypted · → `failed(.noTextLayer)` if zero passages · → `storing` |
| `storing` (file copy + rulebook + passages, one transaction) | → `succeeded` · → `failed(.storage)` with everything rolled back |

Terminal: `succeeded`, `duplicateNoOp`, `failed(reason)`. Every failure leaves zero persisted rows and no stored file. Pages without text in an otherwise readable PDF yield no passages. The import still succeeds.

### Search (per query, not persisted)

`idle` (empty query) → `matches([Match])` or `noMatch`. `noMatch` never falls back to approximate or partial-term matches.

### Rulebook and Passage

No lifecycle: they exist only in a fully imported, immutable state, and are deleted as a unit.

## Important scenarios

1. **First import**: create "Taifa" → import Taifa 3.0 PDF → game becomes `ready` with passages on 16 pages.
2. **Settle a rule**: query "carretera ciudad" → matches with page numbers → open one → page viewer shows the page with the passage highlighted.
3. **Rule not in the book**: query an absent term → no-match state.
4. **Idempotent re-import**: import the same PDF again into "Taifa" → no-op; every locator equal to before.
5. **Same file, other game**: import Taifa into "Catan" → refused, naming "Taifa".
6. **Swap the PDF** (after m4, F04/F12): delete Taifa's rulebook → game `empty` → import another file → new rulebook ID.
7. **Offline**: after import, airplane mode; search and page viewer work unchanged.

## Edge cases

- Image-only PDF → `.noTextLayer`, nothing stored.
- Encrypted or corrupt file → `.locked` / `.unreadable`, nothing stored.
- Paragraph split across a page break → two passages, one per page.
- Hyphenated line breaks ("cons-⏎truir") → joined in passage text. Genuine hyphenated words that happen to end a line may be joined wrongly; accepted.
- Mixed pages (some text, some image-only) → import succeeds; image pages are unsearchable.
- Multi-column layouts → reading order is whatever PDFKit gives; correct handling deferred to ADR-002.
- Query with only whitespace → `idle`, not `noMatch`.
- Query differing only in case or accents → same matches.
- Game name differing only in case/accents/surrounding spaces → rejected as duplicate.
- Same file name, different bytes → different rulebooks.

## Reserved for after m4

- **Dispute** stores the query, the chosen passage's locator and a frozen copy of the cited text, so it outlives the rulebook. Showing a dispute whose rulebook is gone as "stale" is a later idea, not decided.
- **Cheat sheet entry** — locator + frozen text + note; added only by explicit action.
