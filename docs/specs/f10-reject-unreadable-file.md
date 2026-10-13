# Feature Implementation Spec: Reject locked or unreadable files

## Source Feature

- `id`: f10-reject-unreadable-file
- `area`: import
- `depends_on`: f08-atomic-import
- `status`: not_started
- `source`: `feature_list.json`

## Goal

Importing a PDF that PDFKit opens but that is locked fails with `ImportError.locked` and persists nothing. The rule is: after `PDFDocument(data:)` opens the document, if `isLocked` is `true`, the import fails. An encrypted PDF that opens unlocked (`isEncrypted == true`, `isLocked == false`, for example one with only an owner password) takes the normal path: it imports if it yields passages, or f09 rejects it if it yields none. A file that cannot be read, or whose bytes `PDFDocument(data:)` cannot open, stays `.unreadable` exactly as in f08; f10 proves the two errors are distinct. The check runs in `RulebookPreparer.prepare(fileAt:)` (f08) at f08's f10 plug-in point, right after the document opens and before extraction, so a rejected file is never written to the store and SwiftData is never touched. This feature has no interface; how the error is shown to the user belongs to f17.

## Non-Goals

- Asking for a password or unlocking a document; app code never calls `unlock(withPassword:)`.
- Honouring or checking permissions (`allowsCopying` and similar, `permissionsStatus`).
- Repairing damaged PDFs, or any new way of detecting corruption beyond f08's `.unreadable`.
- Re-import of the same file (f11).
- Any interface: alert, message, import action or game screen state (f17).
- Any change to f06's extraction, f08's other steps or f09's check.

## Job Story

When I pick a rulebook PDF that is password-protected or damaged,
I want the import to fail with a reason that matches the problem,
so I know whether to find an unprotected copy or a working file.

## Users And Permissions

- None: internal domain logic. The single on-device user triggers it through f17.

## Acceptance Scenarios

As in f08 and f09, every scenario uses its own in-memory container (`ModelConfiguration(isStoredInMemoryOnly: true)`) and its own `RulebookStore` over a unique temporary directory, removed at the end of the test. Games are created with f02's `Library.createGame(named:)`. PDFs are built with f06's `SyntheticPDF` (with the `encryption` parameter below where stated), written to a temporary file and imported with f08's `Library.importRulebook(fileAt:into:store:)`. "Nothing persisted" means the same as in f09, with the scenario's error: the error is exactly the stated one; the context holds 0 `Rulebook` and 0 `Passage` rows, also through a new `ModelContext` on the same container; no file exists at `store.fileURL(for: RulebookID(bytes: data))`, and the store's base directory is either absent or holds no file; and `game.rulebook == nil`.

### Scenario 1: user password, locked

Given a game without a rulebook and a one-page synthetic PDF with one paragraph of text, encrypted with an owner password and a different user password
And the test first `#require`s that `PDFDocument(data:)` of that `Data` is not `nil`, and that it has `isEncrypted == true` and `isLocked == true`
When it is imported
Then the error is `.locked` and nothing is persisted.

### Scenario 2: owner password only, imports

Given a game without a rulebook and a one-page synthetic PDF with one paragraph of text, encrypted with an owner password and no user password
And the test first `#require`s that `PDFDocument(data:)` of that `Data` is not `nil`, and that it has `isEncrypted == true` and `isLocked == false`
When it is imported
Then the import succeeds; `game.rulebook` has `rulebookID == RulebookID(bytes: data).hex`, `pageCount == 1` and at least one passage; and `<base>/<hex>.pdf` exists with bytes equal to `data`.

### Scenario 3: corrupt file, unreadable

Given a game without a rulebook and a temporary file holding the ASCII bytes of `"%PDF-1.7\n"` followed by a fixed block of 1,024 bytes with values `0x00, 0x01, …, 0xFF` repeated four times
And the test first `#require`s that `PDFDocument(data:)` of those bytes is `nil`
When it is imported
Then the error is `.unreadable` and nothing is persisted.

### Scenario 4: distinct errors

Given one game without a rulebook, the locked PDF of scenario 1 and the corrupt file of scenario 3
When each is imported into that game, with the same store
Then the errors are `.locked` and `.unreadable` respectively, and they are not equal; after both, nothing is persisted.

### Scenario 5: the game can import after a rejection

Given a game whose import of the locked PDF of scenario 1 has just failed with `.locked`
When an unencrypted synthetic PDF with text is imported into the same game, with the same store
Then the import succeeds; `game.rulebook` has that PDF's `RulebookID`; the context holds exactly 1 `Rulebook`, and its passages equal (`==`, via f08's `orderedPassages` and `extractedPassage(rulebookID:)`) `PassageExtractor.extract` run in the test on that PDF; and the store holds exactly one file, that PDF's.

## Repository Research

### Files Inspected

- `docs/specs/f08-atomic-import.md` (approved) — `ImportError` (`unreadable`, `storage`, `gameHasRulebook`); `RulebookPreparer.prepare(fileAt:)` (`@concurrent`; read once, hash once, `PDFDocument(data:)` with `nil` → `.unreadable`, extract; the document never leaves the function); plug-in point "f10: right after `PDFDocument` opens (`.locked`; distinguishing a corrupt file from `.unreadable`)"; scenario 5 ("not a pdf" → `.unreadable`); test setup.
- `docs/specs/f09-reject-no-text-layer.md` (approved) — `noTextLayer` thrown after extraction; the definition of "nothing persisted"; the error order; the interim consequence that an encrypted PDF may fail as `.noTextLayer` until f10 lands.
- `docs/specs/f06-extract-passages.md` (approved) — `SyntheticPDF` in `RuleRefTests/`: Core Graphics PDF context via `CGContext(consumer:mediaBox:_:)`, Helvetica text through Core Text, rectangles, blank pages; it fails the test if `PDFDocument(data:)` is `nil`.
- `docs/domain-model.md` — Import state machine: `extracting` → `failed(.unreadable)` if the file can't be opened, `failed(.locked)` "if encrypted", `failed(.noTextLayer)`; every failure leaves no rows and no file; edge case "Encrypted or corrupt file → `.locked` / `.unreadable`, nothing stored".
- `feature_list.json` — f10 entry: "an encrypted file and a corrupt file: distinct errors", nothing persisted.
- `docs/build-brief.md` — F10 row; same evidence.
- `CONTEXT.md`, `docs/risks-and-open-questions.md`, `docs/adr/` — no mention of locked or encrypted files.
- `RuleRef/`, `RuleRefTests/` — only the app shell and a smoke test.

### Existing Patterns To Follow

- Errors are `nonisolated` `Equatable` `Sendable` enums without associated values where none are needed (f08's `ImportError`).
- Failures are thrown from `prepare`, before anything is written or inserted (f08's `.unreadable`, f09's `.noTextLayer`).
- Preconditions on synthetic PDFs are `#require`d before the import, so a PDFKit surprise fails loudly (f06, f09).
- Swift Testing only; synchronized folders need no project change; no test is skipped.

### Current Gaps

- f06, f08 and f09 are approved but not implemented: `SyntheticPDF`, `PassageExtractor`, `ImportError`, `RulebookPreparer`, `RulebookStore`, `Rulebook`, `Passage`, `Library.importRulebook` and `.noTextLayer` do not exist yet. This spec relies only on what their specs promise; f08 must be accepted before f10 starts (`depends_on`). If an implementation differs in a name used here, f10 follows the implementation and says so in its evidence.
- f10 does not depend on f09. If f09 is not implemented when f10 lands, the error order below still holds for the parts that exist, and f09's check, when it lands, goes after f10's.
- `SyntheticPDF`'s exact signature is f06's to define. f10 adds its parameter to whatever entry point produces the PDF `Data`, without changing existing call sites.
- f08's and f09's test helpers may be private to their test files. f10 writes its own private helpers rather than editing their tests.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled December 2025 to May 2026):

- `PDFDocument.isLocked: Bool` (iOS 11+): "Only encrypted documents can be locked. Encrypted documents whose password is the empty string are unlocked automatically upon opening, because PDF Kit tries the empty string as a password if none is supplied."
- `PDFDocument.isEncrypted: Bool` (iOS 11+): `true` "whether it is locked or unlocked".
- `PDFDocument.unlock(withPassword:) -> Bool` (iOS 11+): unlocks with a password; a document unlocked with only user permissions may gain owner permissions. Not used by f10 (non-goal); listed only to state why it is absent.
- `kCGPDFContextOwnerPassword` (iOS 2+): "If this key is specified, the document is encrypted using the value as the owner password; otherwise, the document will not be encrypted." ASCII only, first 32 bytes used; a non-ASCII value makes context creation return `NULL`.
- `kCGPDFContextUserPassword` (iOS 2+): the user password of an encrypted document; "If not specified, the user password is the empty string." Same ASCII and 32-byte rules.
- `CGContext(consumer:mediaBox:_:)` (iOS 2+): the third argument is the auxiliary info dictionary that takes these keys.
- Consequence: a user password alone does not encrypt; the owner password is what turns encryption on. A document with only an owner password has an empty user password, so PDFKit opens it unlocked.
- **Not verified**: that `PDFDocument(data:)` returns a non-`nil`, locked document for a PDF with a user password. Scenario 1 `#require`s it; if it is `nil`, the import is `.unreadable` and the implementer stops and reports.
- **Not verified**: that PDFKit returns the text of a PDF opened unlocked under owner-only restrictions. If scenario 2 fails because extraction yields no passages, the implementer stops and reports; the rule is not changed to work around it.
- **Not verified**: that `PDFDocument(data:)` returns `nil` for scenario 3's bytes, rather than repairing them. Scenario 3 `#require`s it; if PDFKit opens them, the implementer stops and reports.
- **Not verified**: the default encryption algorithm and key length (`kCGPDFContextEncryptionKeyLength` is not set), and how real-world encrypted rulebooks behave.

Changes, declared:

1. `RuleRef/ImportError.swift` (f08's file): add the case `locked`. Nothing else changes.
2. `RuleRef/RulebookPreparer.swift` (f08's file): in `prepare(fileAt:)`, right after `PDFDocument(data:)` succeeds and before `PassageExtractor.extract`, `if document.isLocked { throw ImportError.locked }`. The f10 plug-in comment becomes a one-line comment on the check. The `@concurrent` signature, the order of the other steps, f08's `.unreadable` paths, f09's check and the f11 plug-in comment do not change. The check uses `isLocked` only; `isEncrypted` is never consulted in app code.
3. `RuleRefTests/SyntheticPDF.swift` (f06's test file): add an optional parameter `encryption: SyntheticPDF.Encryption? = nil` to the entry point that produces the PDF `Data`. `Encryption` is a `nonisolated struct` with `ownerPassword: String` (required, because only it turns encryption on) and `userPassword: String?`. When it is non-`nil`, the auxiliary dictionary passed to `CGContext(consumer:mediaBox:_:)` gets `kCGPDFContextOwnerPassword` and, if set, `kCGPDFContextUserPassword`; when it is `nil`, the dictionary is exactly what f06 passes. Tests use ASCII passwords of at most 32 characters, owner and user different. Existing calls compile and behave unchanged.

Nothing else in f06, f08 or f09 changes.

Resulting error order for one import:

- `.gameHasRulebook` before any reading (f08, `Library`).
- `.unreadable` when the bytes can't be read or `PDFDocument(data:)` is `nil` (f08). Corrupt bytes stay `.unreadable`, never `.locked`.
- `.locked` when the opened document is locked (f10).
- `.noTextLayer` when the extraction of an unlocked document is empty (f09).

f09's interim consequence is resolved: a locked PDF fails as `.locked` and never reaches extraction, so it can no longer fail as `.noTextLayer`. An encrypted but unlocked PDF with no text still fails as `.noTextLayer`, which is correct under the rule.

## Expected File Changes

- `RuleRef/ImportError.swift` — modify (declared, f08's file); add `locked`.
- `RuleRef/RulebookPreparer.swift` — modify (declared, f08's file); the `isLocked` check after opening and before extraction.
- `RuleRefTests/SyntheticPDF.swift` — modify (declared, f06's file); additive `encryption` parameter and `Encryption` type.
- `RuleRefTests/UnreadableFileImportTests.swift` — create; scenarios 1–5, with private helpers for the container, the temporary store, the corrupt bytes and the persisted-nothing assertions.
- `docs/domain-model.md` — modify; see Durable Documentation Impact.
- No other file changes. If an existing test fails because of the new check, stop and report it instead of editing that test.

## Visual Design Impact

- UI involved: no (f17 shows the error).

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- `docs/domain-model.md`: update — the state machine says `failed(.locked)` "if encrypted" and the edge case says "Encrypted or corrupt file"; under the decided rule only a locked document fails. Change both to "locked (needs a password to open)" and add that an encrypted PDF that opens unlocked follows the normal path.
- `CONTEXT.md`, `docs/build-brief.md`, `docs/risks-and-open-questions.md`: not needed — the F10 row's "encrypted file" is met by the user-password PDF; terms and scope are unchanged.

## Implementation Plan

1. Confirm f08 is accepted; otherwise stop and report.
2. Add `SyntheticPDF`'s `encryption` parameter; confirm f06's tests still pass unchanged.
3. Write `UnreadableFileImportTests` (scenarios 1–5) with their `#require` preconditions; scenarios 1, 4 and 5 fail against f08 as it stands.
4. Add `ImportError.locked` and the check in `RulebookPreparer.prepare`.
5. Update `docs/domain-model.md`; run `./init.sh`; check that the diff against f06's and f08's files has only the declared lines; record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] Precondition: f08 accepted.
- [ ] `SyntheticPDF.Encryption` and the optional `encryption` parameter; existing call sites untouched.
- [ ] `UnreadableFileImportTests`: scenarios 1–5, each with its own in-memory container and temporary directory, removed afterwards; preconditions `#require`d before the import.
- [ ] `ImportError.locked`.
- [ ] `RulebookPreparer.prepare`: throw on `isLocked`, after opening and before extraction.
- [ ] `docs/domain-model.md` lines; `./init.sh` green; evidence and `PROGRESS.md` updated.

## Verification Plan

- `./init.sh` exits 0 with every check PASS; test-results shows the new tests, 0 failed, 0 skipped, and f06's, f08's and f09's tests (where present) still passing unchanged.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/UnreadableFileImportTests -only-testing:RuleRefTests/ImportTests -only-testing:RuleRefTests/PassageExtractorTests`.
- `git diff main...HEAD -- RuleRef/ImportError.swift RuleRef/RulebookPreparer.swift RuleRefTests/SyntheticPDF.swift` shows only the new case, the check and its comment, and the additive parameter; `git diff --stat main...HEAD` lists no other existing file except `docs/domain-model.md`, `feature_list.json` and `PROGRESS.md`.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests); f10 has no interface.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–5, and the diff summary above.
- `not_verified`: real-world encrypted and damaged rulebooks; encryption algorithms and key lengths other than Core Graphics' default; PDFs with restrictive permissions beyond owner-only encryption; how the error reaches the user (f17); iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–5 pass, each on an in-memory container and its own temporary directory; every `isEncrypted`, `isLocked` and `PDFDocument(data:)` precondition is `#require`d before the import.
- [ ] The only new rule is `isLocked` after opening; app code does not read `isEncrypted`, call `unlock(withPassword:)` or check permissions.
- [ ] The check is inside `RulebookPreparer.prepare`, after `PDFDocument(data:)` and before `PassageExtractor.extract`, so a locked file is never written and nothing is inserted, and it fails as `.locked`, never `.noTextLayer`.
- [ ] `ImportError` gains only `locked`; `RulebookPreparer` gains only the check and its comment; `SyntheticPDF` gains only the additive parameter; no other f06, f08 or f09 file or test changed.
- [ ] Non-PDF and corrupt bytes still fail as `.unreadable` (f08's scenario 5 and scenario 3 here).
- [ ] No password prompt, unlocking, permission handling, repair, re-import logic or UI was added.
- [ ] `docs/domain-model.md`, `feature_list.json` and `PROGRESS.md` were updated correctly.
