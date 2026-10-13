# Feature Implementation Spec: Import a rulebook atomically

## Source Feature

- `id`: f08-atomic-import
- `area`: import
- `depends_on`: f02-create-game, f05-rulebook-id, f06-extract-passages
- `status`: not_started
- `source`: `feature_list.json`

## Goal

Importing a readable PDF into a game without a rulebook stores three things together or not at all: a copy of the file, a `Rulebook` and its `Passage`s. Reading, hashing (f05) and extraction (f06 + f07) run off the main actor in one `@concurrent` function that returns a `Sendable` value. Storing then runs on the main actor in one `Library` operation: an atomic file write, then a single `save()` of the usual context. Any failure leaves zero `Rulebook` and `Passage` rows, no stored file, and `game.rulebook == nil`. This feature has no interface; the import action and the ready state are f17.

## Non-Goals

- f09 (`.noTextLayer`), f10 (`.locked`, and telling it apart from `.unreadable`) and f11 (re-import). f08 only marks where they plug in (Technical Approach); it implements none of their behaviour. In f08, a PDF that yields zero passages still imports.
- Deleting games or rulebooks, and deleting the stored file when that happens (f04, f12).
- Search (f13); any interface: button, file picker, security-scoped access, ready state (f17).
- Recalibrating f06's `paragraphGapRatio`. If Taifa yields odd passages, record it as a finding for ADR-002; do not change it here.

## Job Story

When I pick my game's rulebook PDF,
I want its text, its passages and a copy of the file stored together,
so I can search it later, offline, without a half-imported rulebook.

## Users And Permissions

- None: internal domain logic. The single on-device user triggers it through f17.

## Acceptance Scenarios

Every scenario uses its own in-memory container (`ModelConfiguration(isStoredInMemoryOnly: true)`) and its own `RulebookStore` over a unique temporary directory, which is removed at the end of the test. Games are created with f02's `Library.createGame(named:)`.

### Scenario 1: successful import of a synthetic PDF

Given a game "Taifa" without a rulebook, and the `Data` of a two-page synthetic PDF (f06's `SyntheticPDF`) written to a temporary file
When it is imported
Then `game.rulebook` has `rulebookID == RulebookID(bytes: data).hex` and `pageCount == 2`; its passages, read in ordinal order and turned back into `ExtractedPassage`s, are equal (`==`) to `PassageExtractor.extract(from: PDFDocument(data: data)!, rulebookID:)` run in the test; and `<base>/<hex>.pdf` exists with bytes equal to `data`.

### Scenario 2: persistence

Given the import of scenario 1
When a new `ModelContext` on the same container fetches the game by name
Then its rulebook, page count and passages (in ordinal order, with equal texts, ordinals and locators) are the same as in scenario 1.

### Scenario 3: Taifa fixture

Given the fixture `taifa-3.0.pdf` from the test bundle (missing → the test fails, never skips)
When it is imported into a new game
Then `pageCount == 16`, at least one passage exists, and the stored file exists with the fixture's bytes.

### Scenario 4: storage failure

Given a game without a rulebook and a `RulebookStore` whose base URL is an existing regular file (so no directory can be created and nothing can be written beneath it)
When a valid synthetic PDF is imported
Then the error is `.storage`; the context holds 0 `Rulebook` and 0 `Passage` rows (also through a new context); no `.pdf` file exists under the temporary directory; `game.rulebook == nil`.

### Scenario 5: bytes that are not a PDF

Given a temporary file containing the UTF-8 bytes of "not a pdf"
When it is imported
Then the error is `.unreadable`, nothing is persisted, the store directory holds no file, and `game.rulebook == nil`.

### Scenario 6: game that already has a rulebook

Given a game with a rulebook imported from synthetic PDF A
When a different synthetic PDF B is imported into the same game
Then the error is `.gameHasRulebook`; the `Rulebook` and `Passage` counts and the set of stored files are unchanged; `game.rulebook` still has A's ID.

## Repository Research

### Files Inspected

- `docs/domain-model.md` — Rulebook, Passage, Locator and its guarantees; Game 1 — 0..1 Rulebook, Rulebook 1 — N Passage, deletion cascades; Import state machine (`fingerprinting` → `extracting` → `storing`, every failure leaves no rows and no file); "import means freeze".
- `CONTEXT.md` — terms Rulebook, Rulebook ID, Passage, Locator, Import, Text layer.
- `feature_list.json` — f08 (verification), f17 (action and ready state, split from f08 on 2026-10-13), f09–f11 (later errors).
- `docs/risks-and-open-questions.md` — risk 4: SwiftData under strict concurrency; keep extraction pure and persist in one step.
- `AGENTS.md` — Tests: Taifa only in the test target, with its attribution file; no test is skipped.
- `init.sh` — `no-pdf-in-app` scans only `APP_DIR="RuleRef"`, so a PDF under `RuleRefTests/` passes the gate.
- `RuleRef/RuleRefApp.swift`, `RuleRef/ContentView.swift`, `RuleRefTests/RuleRefTests.swift` — app shell; the smoke test notes hosted tests (`Bundle.main` is the app).
- Approved specs: `f02-create-game.md` (`Game`, `Library` as a MainActor struct over a `ModelContext`, model container, no `#Unique`), `f05-rulebook-id.md` (`RulebookID`, `hex`, `init(bytes:)`), `f06-extract-passages.md` (`Locator`, `ExtractedPassage`, `PassageExtractor.extract(from:rulebookID:)`, `SyntheticPDF`; where extraction runs is f08's decision), `f07-join-hyphenation.md` (normalized text, empty segments skipped).

### Existing Patterns To Follow

- Default isolation is `MainActor`; pure domain logic is `nonisolated` explicitly. `Library` stays MainActor.
- Errors are `nonisolated` `Equatable` enums (f02's `GameNameError`); no `#Unique` (f02: SwiftData upserts on collision).
- Swift Testing only; synchronized folders need no project change.

### Current Gaps

- f02, f05, f06 and f07 are approved but not implemented: `Game`, `Library`, `RulebookID`, `Locator`, `ExtractedPassage`, `PassageExtractor`, `PassageText` and `SyntheticPDF` do not exist yet. This spec relies only on what their specs promise; they must be accepted before f08 starts. If an implementation differs in a name used here, f08 follows the implementation and says so in its evidence.
- f07 is not in f08's `depends_on`, yet f08 expects normalized text. The next-feature rule starts f07 before f08 (list order); if f07 is not accepted when f08 starts, stop and report.
- The Taifa fixture and its attribution file are not in the repo. The user adds them by hand before f08 starts; if they are missing, the implementer stops and says so.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled May 2026; SE-0461):

- `@concurrent` (SE-0461, Swift 6.2): an `async` function that always switches off the caller's actor to the generic executor; it implies `nonisolated`. Arguments and results crossing from the main actor must be `Sendable` (or disconnected). `#isolation` is `nil` inside.
- `@Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)` (iOS 17+): default rule `.nullify`; `.cascade` "deletes any related models". To-many relationships are arrays; SwiftData does not document an order for them.
- `ModelContext`: inserting a graph's root inserts its related models; `save() throws` writes pending inserts; `rollback()` "discards pending inserts and deletes, restores changed models to their most recent committed state".
- `Data.write(to:options:)` with `.atomic`: writes to an auxiliary file, then replaces the destination. `Data(contentsOf:options:)` throws if the URL cannot be read.
- `URL.applicationSupportDirectory` (iOS 16+): inside the app's sandbox. `FileManager.createDirectory(at:withIntermediateDirectories:attributes:)`, `removeItem(at:)`.
- `Bundle(for: AnyClass)`: returns the bundle that loaded the class, so a class declared in the test target locates the test bundle even though tests are hosted. `url(forResource:withExtension:)`.
- **Not verified**: that a PDF placed in the `RuleRefTests/` synchronized folder is copied into the test bundle as a resource. The implementer checks it with scenario 3. If it is not copied, stop and tell the user what to change in Xcode; never edit the project.
- **Not verified**: whether SwiftData discovers related models from `Game` alone; f08 lists all three model types explicitly, so it does not rely on that.
- **Not verified**: that a `save()` failure can be triggered in a test.

Types:

1. `ImportError` (`nonisolated enum`, `Error`, `Equatable`, `Sendable`): `unreadable`, `storage`, `gameHasRulebook`.
2. `PreparedRulebook` (`nonisolated struct`, `Sendable`): `rulebookID: RulebookID`, `pageCount: Int`, `bytes: Data`, `passages: [ExtractedPassage]`.
3. `RulebookPreparer` (`nonisolated enum`): `@concurrent static func prepare(fileAt url: URL) async throws -> PreparedRulebook`. In order: read the bytes once (`Data(contentsOf:)`; failure → `.unreadable`); `RulebookID(bytes:)` once (fingerprinting); `PDFDocument(data:)` (`nil` → `.unreadable`); `PassageExtractor.extract`. The `PDFDocument` is a local and never leaves this function. Only `URL` goes in and only `PreparedRulebook` comes out.
4. `RulebookStore` (`nonisolated struct`, `Sendable`): `baseDirectory: URL`; `static var app` = `URL.applicationSupportDirectory/Rulebooks`; `fileURL(for: RulebookID)` = `<base>/<hex>.pdf`; `write(_:for:) throws` creates the base directory with intermediates, then writes with `.atomic`; `removeFile(for:)` removes it and ignores a missing file.
5. `Rulebook` (`@Model final class`): `rulebookID: String` (hex), `pageCount: Int`, `importDate: Date`, `game: Game?` (inverse), `@Relationship(deleteRule: .cascade, inverse: \Passage.rulebook) passages: [Passage]`. `orderedPassages` sorts by `ordinal`; it is the only read order.
6. `Passage` (`@Model final class`): `text`, `ordinal`, `pageIndex`, `minX`, `minY`, `width`, `height` (`Double`), `rulebook: Rulebook?`. `extractedPassage(rulebookID: RulebookID) -> ExtractedPassage` rebuilds the locator from those values (on 64-bit, `CGFloat` is `Double`, so the round trip is exact). This is the one needed exception to "only extraction builds locators": a locator rebuilt from what extraction stored. `docs/domain-model.md` records it.
7. `RulebookID` (f05, declared change): add `init?(hex:)`, which accepts exactly 64 characters in `[0-9a-f]`, so a stored hex becomes a `RulebookID` again.
8. `Game` (f02, declared change): `@Relationship(deleteRule: .cascade, inverse: \Rulebook.game) var rulebook: Rulebook?`.
9. `Library` (f02, extended): `func importRulebook(fileAt url: URL, into game: Game, store: RulebookStore) async throws -> Rulebook`:
   - `game.rulebook != nil` → `.gameHasRulebook`, before any reading;
   - `try await RulebookPreparer.prepare(fileAt:)`;
   - check `game.rulebook` again, because the main actor may have run other work during the `await`;
   - `store.write(prepared.bytes, for: id)`; failure → `.storage`, nothing inserted;
   - build the `Rulebook` with its `Passage`s, set `game.rulebook`, `try context.save()`; failure → `context.rollback()`, `store.removeFile(for: id)`, `.storage`.
10. `RuleRefApp` (declared change): `.modelContainer(for: [Game.self, Rulebook.self, Passage.self])`. No other change.

Plug-in points, documented in code comments, with no behaviour in f08:

- f11: after fingerprinting, before extraction (the state machine's `duplicateNoOp` and `.alreadyImported`). f11 decides whether to split `prepare`.
- f10: right after `PDFDocument` opens (`.locked`; distinguishing a corrupt file from `.unreadable`).
- f09: after extraction (zero passages → `.noTextLayer`).

Uniqueness of `rulebookID` across games is f11's; no `#Unique` (f02's reason). Writing the file happens on the main actor; a 16-page rulebook is small, and this was the decided trade-off.

Fixture: `RuleRefTests/Fixtures/taifa-3.0.pdf` and `RuleRefTests/Fixtures/taifa-3.0-attribution.md` (CC BY-NC-SA; title, authors, source, license), placed by the user. Never under `RuleRef/`. The test resolves the PDF with `Bundle(for:)` on a test-target class and `#require`s a non-nil URL.

## Expected File Changes

- `RuleRef/ImportError.swift`, `RuleRef/PreparedRulebook.swift`, `RuleRef/RulebookPreparer.swift`, `RuleRef/RulebookStore.swift`, `RuleRef/Rulebook.swift`, `RuleRef/Passage.swift` — create.
- `RuleRef/Library.swift` — modify; `importRulebook(fileAt:into:store:)`.
- `RuleRef/Game.swift` — modify (declared, f02's file); `rulebook` relationship.
- `RuleRef/RulebookID.swift` — modify (declared, f05's file); `init?(hex:)`.
- `RuleRef/RuleRefApp.swift` — modify; three model types.
- `RuleRefTests/RulebookStoreTests.swift` — create; path, atomic write, missing-file removal, `init?(hex:)` round trip and rejects.
- `RuleRefTests/ImportTests.swift` — create; scenarios 1, 2, 4, 5, 6.
- `RuleRefTests/TaifaImportTests.swift` — create; scenario 3.
- `RuleRefTests/Fixtures/` — user-provided; not created by the implementer.
- `docs/domain-model.md` — modify; one line on the rebuilt-locator exception.

## Visual Design Impact

- UI involved: no (f17).

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change; the Taifa rule is already there.
- `docs/domain-model.md`: update — a locator rebuilt from persisted passage values is the one exception to "only extraction builds locators".
- `docs/risks-and-open-questions.md`: not needed unless Taifa shows a segmentation problem; then add it as an ADR-002 finding.

## Implementation Plan

1. Confirm f02, f05, f06 and f07 are accepted and the fixture and attribution file exist; otherwise stop and report.
2. Write failing `RulebookStoreTests`; add `RulebookID.init?(hex:)` and `RulebookStore`.
3. Write failing `ImportTests`; add `ImportError`, `PreparedRulebook`, `RulebookPreparer`, `Rulebook`, `Passage`, the `Game` relationship and `Library.importRulebook`.
4. Write `TaifaImportTests`; confirm the fixture reaches the test bundle.
5. Update `RuleRefApp` and `docs/domain-model.md`; run `./init.sh`; record evidence and a `PROGRESS.md` entry.

## Implementation Tasks

- [ ] Preconditions checked (dependencies accepted, fixture present).
- [ ] `RulebookID.init?(hex:)`, `RulebookStore`, `RulebookStoreTests`.
- [ ] `ImportError`, `PreparedRulebook`, `RulebookPreparer` (`@concurrent`, PDFDocument local only).
- [ ] `Rulebook`, `Passage`, `Game.rulebook`; `Library.importRulebook` with the re-check after `await`, write before save, rollback and file removal on save failure.
- [ ] `ImportTests` (scenarios 1, 2, 4, 5, 6), `TaifaImportTests` (scenario 3), each with its own temporary directory, removed afterwards.
- [ ] `RuleRefApp` container; `docs/domain-model.md` line; `./init.sh` green; evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0 with every check PASS, `no-pdf-in-app` included; test-results shows the new tests, 0 failed, 0 skipped.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/RulebookStoreTests -only-testing:RuleRefTests/ImportTests -only-testing:RuleRefTests/TaifaImportTests`.
- `git diff main...HEAD -- RuleRef/Game.swift RuleRef/RulebookID.swift RuleRef/RuleRefApp.swift` shows only the declared changes.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests); f08 has no interface.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–6; Taifa's page and passage counts.
- `not_verified`: the `save()` failure path (rollback and file removal), unless a test provokes it; that the fixture is bundled by the synchronized folder, if confirmed only indirectly; import from a real picked file (f17); iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–6 pass, each on an in-memory container and its own temporary directory; scenario 3 fails rather than skips if the fixture is missing.
- [ ] `RulebookPreparer.prepare` is `@concurrent`, reads and hashes once, and no `PDFDocument` leaves it; only `Sendable` values cross isolation.
- [ ] No `@Model` type is `nonisolated`; all SwiftData work is on the main actor; no isolation escapes.
- [ ] The file is written atomically before the single `save()`; a write failure inserts nothing; a save failure rolls back and removes the file; every failure ends in `.storage`, `.unreadable` or `.gameHasRulebook` with no rows and no file.
- [ ] `Rulebook.passages` and `Game.rulebook` cascade; passages are read through `orderedPassages`.
- [ ] Changes to `Game`, `RulebookID` and `RuleRefApp` are only the declared ones; no f09–f11 behaviour, deletion, search or UI was added; `paragraphGapRatio` is unchanged.
- [ ] Taifa is only under `RuleRefTests/Fixtures/`, with its attribution file.
- [ ] `docs/domain-model.md`, `feature_list.json` and `PROGRESS.md` were updated correctly.
