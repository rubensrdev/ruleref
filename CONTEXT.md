# Context — glossary

Canonical terms for code, UI copy, specs and tests. Definitions and rules live in `docs/domain-model.md`; this file only fixes the words.

## Canonical terms

| Term | Meaning |
|---|---|
| **RuleRef** | The app's name (final). |
| **Game** | A board game in the library. Holds at most one rulebook. |
| **Library** | The list of all games on the device. |
| **Rulebook** | The imported, frozen content of one PDF file: its passages plus a stored copy of the file for display. |
| **Rulebook ID** | SHA-256 of the imported file's bytes. Identity of a rulebook. |
| **Passage** | One paragraph-sized unit of rulebook text, in reading order, with exactly one locator. |
| **Locator** | Where a passage lives in its source. In the MVP: rulebook ID + page index + rectangle. |
| **Import** | Turning a picked file into a rulebook. Happens once; the original is never re-read at search time. |
| **Text layer** | The selectable text embedded in a PDF. Required for import in the MVP. |
| **Query** | What the user types into search. |
| **Match** | A passage returned by a query, shown with its page number. |
| **No-match state** | The explicit result when a query returns zero matches ("the rulebook doesn't mention it"). Never replaced by approximate results. |
| **Page viewer** | The screen that shows a rulebook page with one passage highlighted. |
| **Eval set** | The ~25 real questions with their expected page (or expected "not in rulebook"), used to measure search. |
| **Baseline** | The measured score of text search on the eval set. AI retrieval is compared against it after m4. |

## Reserved (defined, built after m4)

| Term | Meaning |
|---|---|
| **Dispute** | A question argued at the table plus the passage that settles it, with a frozen copy of the cited text. The only form of history. |
| **Cheat sheet** | Passages the user saves with a personal note. Filled only by explicit action, never automatically. |

## Rejected or ambiguous terms

| Avoid | Use instead | Why |
|---|---|---|
| chunk, fragment, snippet | **Passage** | One word across extraction, search and UI. |
| document, manual, rules file, PDF (as an entity) | **Rulebook** | "PDF" is the source format, not the domain object. |
| location, anchor, reference, citation (as a type) | **Locator** | "Citation" is the act of showing a passage, not the type. |
| question (for search input) | **Query** | "Question" belongs to the eval set and to AI answering. |
| search history, query log | **Dispute** | History stores disputes only; queries are never logged. |
| replace / update rulebook | delete the rulebook, then import | There is no replace operation. |
| result (for search hits) | **Match** | "Result" is ambiguous with import results. |
