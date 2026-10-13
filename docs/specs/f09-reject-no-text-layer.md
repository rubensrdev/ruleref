# Feature Implementation Spec: Reject PDFs without a text layer

Approval: approved by the user on 2026-10-13

## Source Feature

- `id`: f09-reject-no-text-layer
- `area`: import
- `depends_on`: f08-atomic-import
- `status`: not_started
- `source`: `feature_list.json`

## Goal

Importing a PDF that has no usable text layer fails with `ImportError.noTextLayer` and persists nothing. The rule is: if extracting the whole document, after f07's normalization, yields zero passages, the import fails. Any document with at least one passage imports, even if some of its pages have no text. The check runs in `RulebookPreparer.prepare(fileAt:)` (f08), right after extraction and before the `PreparedRulebook` is returned. That is f08's plug-in point for f09. Because of where it runs, a rejected file is never written to the store and SwiftData is never touched. This feature has no interface; how the error is shown to the user belongs to f17.

## Non-Goals

- OCR, Vision or any other text recognition for scanned PDFs (`docs/build-brief.md`, Non-goals).
- Detecting encrypted or corrupt PDFs, and telling them apart (`.locked`, `.unreadable`; f10).
- Re-import of the same file (f11).
- Any interface: alert, message, import action or game screen state (f17).
- Any change to f06's cut rule or to f07's normalization; a per-page or a character-count threshold.

## Job Story

When I pick a scanned rulebook that only has page images,
I want the import to fail clearly instead of creating an empty rulebook,
so I don't search a rulebook that can never match anything.

## Users And Permissions

- None: internal domain logic. The single on-device user triggers it through f17.

## Acceptance Scenarios

As in f08, every scenario uses its own in-memory container (`ModelConfiguration(isStoredInMemoryOnly: true)`) and its own `RulebookStore` over a unique temporary directory, removed at the end of the test. Games are created with f02's `Library.createGame(named:)`. PDFs are built with f06's `SyntheticPDF`, written to a temporary file and imported with f08's `Library.importRulebook(fileAt:into:store:)`. "Nothing persisted" means all of these: the error is exactly `.noTextLayer`; the context holds 0 `Rulebook` and 0 `Passage` rows, also through a new `ModelContext` on the same container; no file exists at `store.fileURL(for: RulebookID(bytes: data))`, and the store's base directory is either absent or holds no file; and `game.rulebook == nil`.

### Scenario 1: image-only PDF

Given a game without a rulebook and a one-page synthetic PDF whose page holds only a filled rectangle and no text
And the test first `#require`s that `PDFDocument(data:)` of that `Data` has `pageCount == 1` and that its page has `numberOfCharacters == 0`
When it is imported
Then nothing is persisted.

### Scenario 2: blank pages

Given a game without a rulebook and a two-page synthetic PDF with no content on either page
And the test first `#require`s `pageCount == 2` and `numberOfCharacters == 0` on both pages
When it is imported
Then nothing is persisted.

### Scenario 3: mixed PDF imports

Given a game without a rulebook and a two-page synthetic PDF whose page 0 holds one paragraph of text and whose page 1 holds only a filled rectangle
And the test first `#require`s `numberOfCharacters > 0` on page 0 and `numberOfCharacters == 0` on page 1
When it is imported
Then the import succeeds; `game.rulebook` has `pageCount == 2` and at least one passage; every passage has `pageIndex == 0`; and the stored file exists.

### Scenario 4: the game can import after a rejection

Given a game whose import of the image-only PDF of scenario 1 has just failed with `.noTextLayer`
When a synthetic PDF with text is imported into the same game, with the same store
Then the import succeeds; `game.rulebook` has the text PDF's `RulebookID`; the context holds exactly 1 `Rulebook`, and its passages equal (`==`, via f08's `orderedPassages` and `extractedPassage(rulebookID:)`) `PassageExtractor.extract` run in the test on that PDF; and the store holds exactly one file, the text PDF's.

## Repository Research

### Files Inspected

- `docs/specs/f08-atomic-import.md` (approved) — `ImportError` (`unreadable`, `storage`, `gameHasRulebook`), `RulebookPreparer.prepare(fileAt:)` (`@concurrent`; read, hash, open, extract; `PDFDocument` stays local), `RulebookStore` (`fileURL(for:)`, `write` creates the base directory), `Library.importRulebook` (`.gameHasRulebook` first, prepare, write, single `save()`), test setup (in-memory container, temporary store directory), and plug-in point "f09: after extraction (zero passages → `.noTextLayer`)". Its non-goals say that in f08 a PDF with zero passages still imports.
- `docs/specs/f06-extract-passages.md` (approved) — `SyntheticPDF` with filled rectangles and blank pages; `lines(on:)` skips pages with `numberOfCharacters == 0`; a page without text yields no passages; extraction has no errors of its own.
- `docs/specs/f07-join-hyphenation.md` (approved) — segments whose normalized text is empty are skipped before ordinals are assigned, so no passage has empty text.
- `docs/domain-model.md` — Import state machine: `extracting` → `failed(.noTextLayer)` if zero passages; every failure leaves zero rows and no stored file; edge cases: image-only PDF → `.noTextLayer`, nothing stored; mixed pages → import succeeds, image pages are unsearchable.
- `CONTEXT.md` — **Text layer**: the selectable text embedded in a PDF, required for import in the MVP.
- `feature_list.json` — f09 entry and verification; f10 and f11 also plug into `prepare`; f17 shows import errors.
- `docs/build-brief.md` — F09 row; non-goal "PDFs without a text layer (OCR): import fails explicitly instead".
- `docs/risks-and-open-questions.md` — no item on text-layer detection.
- `RuleRef/`, `RuleRefTests/` — only the app shell and a smoke test.

### Existing Patterns To Follow

- Errors are `nonisolated` `Equatable` `Sendable` enums without associated values where none are needed (f08's `ImportError`).
- Failures are thrown from `prepare`, before anything is written or inserted (f08's `.unreadable`).
- Swift Testing only; synchronized folders need no project change; no test is skipped.

### Current Gaps

- f06, f07 and f08 are approved but not implemented: `SyntheticPDF`, `PassageExtractor`, `PassageText`, `ImportError`, `RulebookPreparer`, `RulebookStore`, `Rulebook`, `Passage` and `Library.importRulebook` do not exist yet. This spec relies only on what their specs promise; f08 must be accepted before f09 starts (`depends_on`). If an implementation differs in a name used here, f09 follows the implementation and says so in its evidence.
- f08's test helpers (container and temporary store) may be private to its test files. f09 writes its own private helpers rather than editing f08's tests.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled May 2026):

- `PDFPage.numberOfCharacters: Int` (iOS 11+): "the number of characters on the page, including whitespace characters". Used only in the tests' preconditions; f06 already uses it to skip pages.
- `PDFDocument.init?(data:)` (returns `nil` when the data is not PDF data), `pageCount: Int`, `page(at:)` (iOS 11+).
- `FileManager.fileExists(atPath:)` and `contentsOfDirectory(at:includingPropertiesForKeys:options:)` (a shallow listing; iOS 4+), for the "no stored file" checks. The base directory may not exist after a rejection, because `RulebookStore.write` is what creates it; the test treats a missing directory as empty.
- **Not verified**: that a page drawn by `SyntheticPDF` with only a filled rectangle, or with no content, reports `numberOfCharacters == 0`. Each scenario `#require`s it, so a surprise fails loudly instead of testing something else.
- **Not verified**: what PDFKit reports for real scanned PDFs (an invisible OCR layer added by a scanner app would count as a text layer and import). No real scanned PDF is in the repo.

Changes, both in f08's files, declared:

1. `RuleRef/ImportError.swift`: add the case `noTextLayer`. Nothing else changes.
2. `RuleRef/RulebookPreparer.swift`: in `prepare(fileAt:)`, right after `PassageExtractor.extract` returns and before the `PreparedRulebook` is built, `if passages.isEmpty { throw ImportError.noTextLayer }`. The f09 plug-in comment becomes a one-line comment on the check. The `@concurrent` signature, the order of the other steps, and the f10 and f11 plug-in comments do not change.

Why `passages.isEmpty` and nothing else: f06 drops pages with zero characters and whitespace-only lines, and f07 drops segments whose normalized text is empty. So "zero passages" already means "no searchable text in the whole document". A page made only of whitespace or soft hyphens counts as having no text; that case is covered by f06's and f07's own tests and is not tested again here.

Resulting error order for one import (none of it new except the last line):

- `.gameHasRulebook` before any reading (f08, `Library`).
- `.unreadable` when the bytes can't be read or `PDFDocument(data:)` is `nil` (f08). Non-PDF bytes stay `.unreadable`, never `.noTextLayer`.
- `.noTextLayer` when the extraction is empty (f09).

Interim consequence, accepted: until f10 adds `.locked` right after the document opens, an encrypted PDF that opens but exposes no text may fail as `.noTextLayer`. f10's check runs earlier in `prepare`, so it takes precedence once it lands.

## Expected File Changes

- `RuleRef/ImportError.swift` — modify (declared, f08's file); add `noTextLayer`.
- `RuleRef/RulebookPreparer.swift` — modify (declared, f08's file); empty-extraction check after extraction.
- `RuleRefTests/NoTextLayerImportTests.swift` — create; scenarios 1–4, with private helpers for the container, the temporary store and the persisted-nothing assertions.
- No other file changes: f08's sources and tests, `SyntheticPDF`, `PassageExtractor` and `PassageText` stay as they are. If an existing test fails because it imports a PDF with zero passages, stop and report it instead of editing that test.

## Visual Design Impact

- UI involved: no (f17 shows the error).

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- `docs/domain-model.md`: not needed — the state machine and edge cases already say zero passages → `.noTextLayer`, and mixed pages import.
- `CONTEXT.md`, `docs/build-brief.md`, `docs/risks-and-open-questions.md`: not needed — terms and scope are unchanged.

## Implementation Plan

1. Confirm f08 is accepted; otherwise stop and report.
2. Write `NoTextLayerImportTests` (scenarios 1–4) with their `#require` preconditions; scenarios 1, 2 and 4 fail against f08 as it stands.
3. Add `ImportError.noTextLayer` and the check in `RulebookPreparer.prepare`.
4. Run `./init.sh`; check that the diff against f08's files has only the declared lines; record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] Precondition: f08 accepted.
- [ ] `NoTextLayerImportTests`: scenarios 1–4, each with its own in-memory container and temporary directory, removed afterwards; preconditions `#require`d before the import.
- [ ] `ImportError.noTextLayer`.
- [ ] `RulebookPreparer.prepare`: throw on empty extraction, after extraction and before building `PreparedRulebook`.
- [ ] `./init.sh` green; evidence and `PROGRESS.md` updated.

## Verification Plan

- `./init.sh` exits 0 with every check PASS; test-results shows the new tests, 0 failed, 0 skipped, and f08's tests still passing unchanged.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/NoTextLayerImportTests -only-testing:RuleRefTests/ImportTests`.
- `git diff main...HEAD -- RuleRef/ImportError.swift RuleRef/RulebookPreparer.swift` shows only the new case, the check and its comment; `git diff --stat main...HEAD` lists no other existing file except `feature_list.json` and `PROGRESS.md` (the evidence commit).
- No UI tests and no E2E, by design (`AGENTS.md`, Tests); f09 has no interface.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–4, and the diff summary above.
- `not_verified`: real scanned PDFs, including ones with an invisible OCR layer; encrypted PDFs (f10); how the error reaches the user (f17); iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–4 pass, each on an in-memory container and its own temporary directory; every `numberOfCharacters` precondition is `#require`d before the import.
- [ ] The only rule is "zero passages after extraction"; there is no per-page check, threshold or character count in app code.
- [ ] The check is inside `RulebookPreparer.prepare`, after `PassageExtractor.extract` and before `PreparedRulebook` is built, so a rejected file is never written and nothing is inserted.
- [ ] `ImportError` gains only `noTextLayer`; `RulebookPreparer` gains only the check and its comment; no other f08 file and no f06, f07 or f08 test changed.
- [ ] Non-PDF bytes still fail as `.unreadable` (f08's scenario 5 still passes).
- [ ] No OCR, Vision, `.locked` handling, re-import logic or UI was added.
- [ ] `feature_list.json` and `PROGRESS.md` were updated correctly.
