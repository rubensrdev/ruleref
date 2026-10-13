# Feature Implementation Spec: Re-import of the same file

Approval: approved by the user on 2026-10-13

## Source Feature

- `id`: f11-reimport-same-file
- `area`: import
- `depends_on`: f08-atomic-import, f09-reject-no-text-layer, f10-reject-unreadable-file
- `status`: not_started
- `source`: `feature_list.json`

## Goal

A rulebook's identity is its `RulebookID`, so the same file is held by at most one game. Re-importing a file into the game that already holds it is a no-op that returns the existing rulebook untouched. Importing it into any other game fails with `ImportError.alreadyImported(gameName:)`, naming the game that holds it. To decide that before extracting, f11 reorders f08's pipeline to follow the domain model's state machine: fingerprint → checks → prepare → checks again and store. `Library.importRulebook` returns an `ImportOutcome` (`imported` or `alreadyPresent`) instead of a `Rulebook`, so f17 never shows a false success. Uniqueness is enforced by the checks alone, with no `#Unique` (f02's reason). This feature has no interface; what the user sees in each case belongs to f17.

## Non-Goals

- Replacing one rulebook with another (`docs/build-brief.md`, Non-goals); `.gameHasRulebook` stays as in f08.
- Deleting games or rulebooks (f04, f12).
- Any interface: alert, message, import action or game screen state (f17).
- Merging or comparing the contents of different files; identity is the file bytes only.
- Any change to the rules of f09 (`.noTextLayer`) or f10 (`.locked`), or to f06's and f07's extraction.

## Job Story

When I pick a rulebook PDF I may already have imported,
I want the app to recognise the file instead of storing it twice,
so my searches and citations keep pointing at the one rulebook I already have.

## Users And Permissions

- None: internal domain logic. The single on-device user triggers it through f17.

## Acceptance Scenarios

As in f08, every scenario uses its own in-memory container (`ModelConfiguration(isStoredInMemoryOnly: true)`) and its own `RulebookStore` over a unique temporary directory, removed at the end of the test. Games are created with f02's `Library.createGame(named:)`. PDFs A and B are two different text PDFs built with f06's `SyntheticPDF` and written to temporary files. "Nothing changed" means: the `Rulebook` and `Passage` counts (`fetchCount`), the list of files in the store directory and their bytes, and each game's `rulebook` are equal to what they were before the import.

### Scenario 1: idempotent re-import into the same game

Given A imported into "Taifa", and saved before the re-import: its locators in ordinal order (via f08's `orderedPassages` and `extractedPassage(rulebookID:)`), the `Rulebook` and `Passage` counts, its `importDate`, and the stored file's bytes and modification date
When A is imported into "Taifa" again
Then the result is `.alreadyPresent` holding the same rulebook (equal `persistentModelID`); the locators are equal (`==`) to the saved ones, in the same order; the counts and `importDate` are unchanged; and the store holds exactly one file, with the same bytes and modification date.

### Scenario 2: same file, another game

Given A imported into "Taifa" and a game "Catan" without a rulebook
When A is imported into "Catan"
Then the error is `.alreadyImported(gameName: "Taifa")`; `catan.rulebook == nil`; nothing changed.

### Scenario 3: the stored name is returned

Given A imported into a game created as "Catán" and another game "Taifa"
When A is imported into "Taifa"
Then the error is `.alreadyImported(gameName: "Catán")`, with the accent (the stored `name`, never `nameKey`).

### Scenario 4: another file, same game

Given A imported into "Taifa"
When B is imported into "Taifa"
Then the error is `.gameHasRulebook` and nothing changed. f08's scenario 6 still passes with unchanged assertions.

### Scenario 5: the ID check comes before the game check

Given A imported into "Taifa" and B imported into "Catan"
When A is imported into "Catan"
Then the error is `.alreadyImported(gameName: "Taifa")`, not `.gameHasRulebook`; nothing changed.

### Scenario 6: simultaneous imports into two games

Given games "Taifa" and "Catan" without a rulebook
When A is imported into both at the same time, in two `Task { @MainActor in … }` started from the main actor (see Technical Approach)
Then the context holds exactly 1 `Rulebook` and the store exactly one file (A's); exactly one import returned `.imported`, the other failed with `.alreadyImported(gameName:)` naming the winner, which is the game whose `rulebook` is non-nil; the other game's `rulebook` is nil.

### Scenario 7: simultaneous imports into the same game

Given "Taifa" without a rulebook
When A is imported into "Taifa" twice at the same time
Then one import returns `.imported` and the other `.alreadyPresent` with the same rulebook; 1 `Rulebook` and one stored file.

### Scenario 8: earlier features still pass

Given f08's, f09's and f10's tests, adapted only to the new return type
When `./init.sh` runs
Then all of them pass with their assertions unchanged.

## Repository Research

### Files Inspected

- `docs/specs/f08-atomic-import.md` (approved) — `ImportError`, `PreparedRulebook`, `RulebookPreparer.prepare(fileAt:)` (`@concurrent`; read once, hash once, open, extract), `RulebookStore`, `Rulebook` (`rulebookID: String` hex, `game: Game?`), `Library.importRulebook(fileAt:into:store:) -> Rulebook` (`.gameHasRulebook` before reading, re-check after `await`, write, single `save()`); plug-in point "f11: after fingerprinting, before extraction … f11 decides whether to split `prepare`"; scenario 6.
- `docs/specs/f09-reject-no-text-layer.md`, `docs/specs/f10-reject-unreadable-file.md` (approved) — `.noTextLayer` after extraction and `.locked` after opening, both inside `prepare`; their error order starts with `.gameHasRulebook` "before any reading".
- `docs/specs/f02-create-game.md` (approved) — `Game.name` (trimmed, as typed) and `nameKey` (folded); no `#Unique`, because SwiftData upserts on collision; uniqueness by a fetch before insert.
- `docs/domain-model.md` — Import: `fingerprinting` → `duplicateNoOp` · `failed(.alreadyImported(gameName))` · `extracting`; important scenarios 4 (idempotent re-import, locators equal) and 5 (refused, naming "Taifa"); "Survival across re-import".
- `feature_list.json` (f11 entry), `docs/build-brief.md` (F11 row), `docs/risks-and-open-questions.md` (risk 4: SwiftData under strict concurrency), `AGENTS.md`.
- `RuleRef/`, `RuleRefTests/` — only the app shell and a smoke test.

### Existing Patterns To Follow

- Off-main work in `@concurrent` functions that take and return `Sendable` values; all SwiftData work on the main actor (f08).
- Errors are `nonisolated` `Equatable` `Sendable` enums (f08); uniqueness by a fetch before insert, no `#Unique` (f02).
- No suspension point between the first insert and the single `save()` (f08).

### Current Gaps

- f02, f05–f10 are approved but not implemented; none of the types named here exist yet. This spec relies only on what their specs promise. If an implementation differs in a name used here, f11 follows the implementation and says so in its evidence.
- f11 reorganises code that f09 and f10 add to, so f09 and f10 were added to its `depends_on` on 2026-10-13; the feature-list rules enforce that both are accepted before f11 starts.
- Test helpers of f08–f10 may be private; f11 writes its own.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled May 2026):

- `FetchDescriptor<T>` (iOS 17+, `Sendable`): `init(predicate:sortBy:)`; `fetchLimit: Int?` ("the maximum number of models the fetch can return"; `nil` means all); `includePendingChanges` defaults to `true`. Apple's sample builds a `#Predicate` that captures a local `String`, so the hex is bound to a local constant first.
- `TaskGroup.addTask(priority:operation:)`: `operation` is `sending @escaping @isolated(any) () async -> ChildTaskResult`, with `ChildTaskResult: Sendable`; `withThrowingTaskGroup(of:returning:isolation:body:)` takes `isolation: isolated (any Actor)? = #isolation`.
- **Not verified**: whether a child task may capture a `Game` or a `Library` (it holds a `ModelContext`, which is not `Sendable`) under complete checking. The test avoids it: each import runs in its own `Task { @MainActor in … }` created on the main actor, whose closure captures only `Sendable` values (the `ModelContainer`, the file URL, the store, the game name); inside it builds a `Library` over `container.mainContext`, fetches its game by name and returns a test-private `Sendable` summary (`imported`, `alreadyPresent`, `failed(ImportError)`), because `ImportOutcome` holds a `Rulebook` and is not `Sendable`. The test awaits both tasks' values; the test's own `Library` uses the same `container.mainContext`.
- **Not verified**: that the two imports in scenarios 6 and 7 interleave so that both pass the first checks before either stores. The test proves the outcome, not which check caught the loser.

Types:

1. `FingerprintedFile` (`nonisolated struct`, `Sendable`): `rulebookID: RulebookID`, `bytes: Data`.
2. `RulebookPreparer` (f08's file) becomes two `@concurrent static` functions:
   - `fingerprint(fileAt url: URL) async throws -> FingerprintedFile`: reads the bytes once (`.unreadable` on failure) and computes `RulebookID(bytes:)` once.
   - `prepare(_ file: FingerprintedFile) async throws -> PreparedRulebook`: `PDFDocument(data:)` (`nil` → `.unreadable`), f10's `.locked` check, `PassageExtractor.extract`, f09's `.noTextLayer` check, in that order. The `PDFDocument` never leaves it, and the bytes are not read or hashed again.
3. `ImportError` (f08's file): add `alreadyImported(gameName: String)`; it stays `Equatable` and `Sendable`.
4. `ImportOutcome` (`nonisolated enum`): `imported(Rulebook)`, `alreadyPresent(Rulebook)`, and `var rulebook: Rulebook` returning the rulebook of either case. Not `Sendable`; it never leaves the main actor.
5. `Library` (f08's method, reworked), on the main actor:
   - `private func rulebook(withID id: RulebookID) throws -> Rulebook?`: `let hex = id.hex`; `FetchDescriptor<Rulebook>(predicate: #Predicate { $0.rulebookID == hex })` with `fetchLimit = 1`. A fetch error maps to `.storage`.
   - `private func check(_ id: RulebookID, for game: Game) throws -> Rulebook?`, in this order: if a rulebook with `id` exists and its `game` is `game` (equal `persistentModelID`), return it (no-op); if it belongs to another game, throw `.alreadyImported(gameName: thatGame.name)`; if it has no game, throw `.storage` (f08's invariants make that impossible); if `game.rulebook != nil`, throw `.gameHasRulebook`; else return `nil`.
   - `importRulebook(fileAt:into:store:) async throws -> ImportOutcome`: (a) `try await RulebookPreparer.fingerprint(fileAt:)`; (b) `check`, and a returned rulebook gives `.alreadyPresent`; (c) `try await RulebookPreparer.prepare(file)`; (d) `check` again, because the main actor may have finished another import during the waits, and a returned rulebook gives `.alreadyPresent`; otherwise f08's store step unchanged (write the file, insert, single `save()`, rollback and file removal on failure) and `.imported`. No `await` between the step-d check and the `save()`.
   - The no-op path writes no file, inserts and deletes nothing, and does not touch the existing rulebook.

Resulting error order: `.unreadable` (bytes unreadable) → no-op or `.alreadyImported` → `.gameHasRulebook` → `.unreadable` (`PDFDocument` is `nil`) → `.locked` → `.noTextLayer` → `.storage`. Change from f08–f10: `.gameHasRulebook` no longer comes before reading; a game with a rulebook given unreadable bytes now gets `.unreadable`. No f08–f10 scenario depends on that.

## Expected File Changes

- `RuleRef/FingerprintedFile.swift`, `RuleRef/ImportOutcome.swift` — create.
- `RuleRef/RulebookPreparer.swift` — modify (declared, f08's file, with f09's and f10's checks); split into `fingerprint` and `prepare`; the checks keep their relative order; the f11 plug-in comment goes.
- `RuleRef/ImportError.swift` — modify (declared); add `alreadyImported(gameName:)`.
- `RuleRef/Library.swift` — modify (declared); the pipeline above and the new return type; f08's post-`await` re-check is replaced by step (d).
- `RuleRefTests/ImportTests.swift`, `TaifaImportTests.swift`, `NoTextLayerImportTests.swift`, `UnreadableFileImportTests.swift` — modify only where a call needs the new return type (append `.rulebook` or discard the result); no assertion changes.
- `RuleRefTests/ReimportTests.swift` — create; scenarios 1–7.
- No other file changes.

## Visual Design Impact

- UI involved: no (f17 shows each outcome).

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- `docs/domain-model.md`: not needed — its Import state machine and scenarios 4 and 5 already describe this behaviour; f11 implements them.
- `CONTEXT.md`, `docs/build-brief.md`, `docs/risks-and-open-questions.md`: not needed — terms and scope are unchanged.

## Implementation Plan

1. Confirm f08, f09 and f10 are accepted; otherwise stop and report.
2. Write `ReimportTests` (scenarios 1–7); they fail to compile or fail against f08.
3. Add `FingerprintedFile`, `ImportOutcome` and `ImportError.alreadyImported`; split `RulebookPreparer`.
4. Rework `Library.importRulebook`; adapt the existing test calls to the new return type only.
5. Run `./init.sh`; check the diff of the existing tests; record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] `ReimportTests`: scenarios 1–7, own container and temporary directory each; the concurrent imports run in `Task { @MainActor in … }` closures that capture only `Sendable` values.
- [ ] `FingerprintedFile`, `ImportOutcome`, `ImportError.alreadyImported(gameName:)`.
- [ ] `RulebookPreparer.fingerprint` and `prepare`, both `@concurrent`; checks in order.
- [ ] `Library`: fetch by ID with `fetchLimit` 1, `check` before and after `prepare`, `ImportOutcome`.
- [ ] Existing test calls adapted; `./init.sh` green; evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0 with every check PASS; test-results shows the new tests, 0 failed, 0 skipped, and every f08–f10 test still passing.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/ReimportTests -only-testing:RuleRefTests/ImportTests -only-testing:RuleRefTests/NoTextLayerImportTests -only-testing:RuleRefTests/UnreadableFileImportTests`.
- `git diff main...HEAD -- RuleRefTests/` shows, in existing files, only changed call sites (`.rulebook` or a discarded result), no changed `#expect` or `#require`.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests); f11 has no interface.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–7, and the test diff summary above.
- `not_verified`: that scenarios 6 and 7 exercised the step-(d) re-check rather than step (b); that every rewrite of the file changes its modification date; re-import of a real file picked twice (f17); a persistent store across launches; iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–7 pass, each on an in-memory container and its own temporary directory.
- [ ] The bytes are read and hashed once, in `fingerprint`; `prepare` takes the `FingerprintedFile`; both are `@concurrent`; no `PDFDocument` or `@Model` crosses isolation.
- [ ] The checks run before `prepare` and again after it, in the stated order; the look-up is a `FetchDescriptor<Rulebook>` on `rulebookID` with `fetchLimit` 1; no `#Unique`; no `await` between the last check and the `save()`.
- [ ] The no-op writes no file and inserts or deletes nothing; `.alreadyImported` carries the stored `name`.
- [ ] `.locked` still precedes `.noTextLayer`; in existing tests only call sites changed; no replace, delete or UI was added.
- [ ] `feature_list.json` and `PROGRESS.md` were updated correctly.
