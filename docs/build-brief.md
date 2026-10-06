# Build brief — RuleRef

Planning horizon: end of module 4 (tag `m4`). Stack and build doctrine are closed in ADR-001. Terms follow `CONTEXT.md`.

## Problem

Board game arguments stall because nobody can find the exact rule fast, and a paraphrase from memory settles nothing. Players need the original sentence on its page, quickly and offline.

## Target user

A player at the table, on an iPhone, with the game's PDF rulebook already on the device, usually without reliable coverage.

## Goals (by m4)

1. Import a PDF rulebook once and use it offline from then on.
2. Find a rule by text search and see it on its original page, highlighted.
3. Say clearly when the rulebook doesn't mention something.
4. Give the harness many small, independent features with checkable evidence.

## Non-goals (until m4)

- **Any AI** (Foundation Models, @Generable answers, embeddings, RAG): enters after m4 as a pluggable layer; the app must stand without it.
- **Disputes / history**: decided as dispute-based, built after m4.
- **Cheat sheet**: cut to keep the slice small; after m4.
- **Sharing a resolution**: first candidate after m4 (plain text via ShareLink: question, cited passage, game, page; no verdict).
- **Web importer and parallel worktrees**: cut, see ADR-003.
- **Photographed paper pages**: fits the import contract; week 6 or v2.
- **Multi-column layout handling**: deferred to ADR-002; MVP supports single-column PDFs.
- **PDFs without a text layer (OCR)**: import fails explicitly instead.
- **Several PDFs per game** (expansions, FAQs): one rulebook per game keeps identity and search simple.
- **Replacing a rulebook**: delete and import instead; avoids versioning.
- **Search across games**: search runs inside one game's rulebook.
- **Custom visual design**: screens follow Apple's Human Interface Guidelines.
- **Baseline measurement (F16)**: moves to module 5, next to the AI it is compared against.
- **Deleting games and rulebooks (F04, F12)**: not needed for the demo flow; after m4.

## MVP slice

A library of games. Each game can hold one rulebook imported from a single-column PDF with a text layer. Inside a game the user types a query, gets matches with page numbers or an explicit no-match state, and opens a match in the page viewer with the passage highlighted. Everything works offline after import.

Screens: Library (list of games, empty state) · Game (rulebook status, import action, search field, matches) · Page viewer · File picker (system).

## Feature slices

Ordered. IDs are stable; never renumber.

| ID | Task | Behaviour | Evidence |
|---|---|---|---|
| F01 | T2 | Empty app target and test target build and run tests from the CLI. | `./init.sh` exits 0 on a clean clone. |
| F02 | T3 | User creates a game with a name; names are trimmed, non-empty and unique case- and diacritic-insensitively. | Tests: blank name rejected; "Taifa" vs " taifa " rejected as duplicate. |
| F03 | T3 | Library lists games alphabetically, with an empty state when there are none. | Test on the library query: order and empty flag. |
| F04 | after m4 | User renames or deletes a game; deleting removes its rulebook, passages and stored file. | Test: after delete, passage count and stored-file count for that rulebook ID are 0. |
| F05 | T3 | A rulebook ID is the SHA-256 of the file bytes. | Test: same bytes → same ID; one changed byte → different ID. |
| F06 | T3 | Extraction turns a text-layer PDF into ordered passages, each with a valid locator. | Test with a synthetic PDF (built in-test with PDFKit): expected texts, order, page indices, rects inside page bounds. |
| F07 | T3 | Extraction joins line-break hyphenation and normalises whitespace. | Test: synthetic "cons-⏎truir" yields passage text containing "construir". |
| F08 | T3 | Importing into a game without a rulebook stores the file copy, the rulebook and its passages atomically. | Test: after import, passage count equals extraction output and the stored file exists; Taifa fixture imports with 16 pages. |
| F09 | T3 | Import of a PDF with no text layer fails with an explicit error and persists nothing. | Test with an image-only synthetic PDF: error `.noTextLayer`, zero rulebooks and passages. |
| F10 | T3 | Import of a locked or unreadable file fails with an explicit error and persists nothing. | Test with an encrypted and a corrupt file: distinct errors, nothing persisted. |
| F11 | T3 | Re-importing the same file into the same game is a no-op; the same file into another game is refused, naming that game. | Test: locators before and after are equal and counts unchanged; second game gets `.alreadyImported(gameName)`. |
| F12 | after m4 | User deletes a game's rulebook; the game stays and can import again. | Test: game remains, rulebook/passages/file gone, import is offered again. |
| F13 | T4 | Text search returns passages of the game's rulebook containing all query terms, case- and diacritic-insensitively, ranked by term frequency then reading order. | Tests on a synthetic rulebook: AND semantics, "construccion" matches "construcción", ranking stable. |
| F14 | T4 | A query with zero matches shows the no-match state, never approximate matches. | Test: search state is `.noMatch` with an empty list for an absent term. |
| F15 | T4 | Opening a match shows its page in the page viewer with the passage rectangle highlighted. | Test: locator → page index and highlight bounds passed to the viewer equal the locator's. |
| F16 | after m4 | Baseline run: the eval set (Codable JSON) is evaluated against search over the Taifa fixture and a report with hit@1, hit@3 and no-match accuracy is written, tagged with OS version. | `./init.sh` produces the report file; the test fails if the eval set is malformed or the fixture missing. |

## Validation plan

- Tests cover business logic and everything that is not interface. There are no interface tests (no XCUITest).
- Every slice lands with Swift Testing tests run by `init.sh` through `xcodebuild` on the pinned simulator (ADR-001).
- Unit tests use synthetic PDFs generated in the test with PDFKit. No test is skipped: missing inputs fail.
- Taifa 3.0 is versioned only in the test target with a CC BY-NC-SA attribution file next to it; never in the app target.
- The interface is validated manually by the user at the end of each phase, on the iPhone 16. Before `m4` this includes: import Taifa from Files, search a real table question, open the match, see the highlight, airplane mode on.

## Success criteria (at m4)

- Every T2–T4 feature is accepted, with `./init.sh` green on a clean clone.
- The user's manual validation on the iPhone 16 passes.
