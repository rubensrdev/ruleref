# Feature Implementation Spec: Import action in the game screen

## Source Feature

- `id`: f17-import-action
- `area`: import
- `depends_on`: f03-list-games, f11-reimport-same-file
- `status`: not_started
- `source`: `feature_list.json`

## Goal

A game without a rulebook can import one from its screen. f03's `GameView` empty state ("No Rulebook Yet") gains an "Import Rulebook" button. It opens the system file picker, limited to one PDF. The picked file goes through f11's `Library.importRulebook(fileAt:into:store:)` inside security-scoped access. While it runs, a progress indicator replaces the button. When the game has a rulebook, `GameView` shows its page count instead of the empty state. Every `ImportError` becomes a plain-language message in an alert, and the game stays empty. Two pure pieces drive the screen, so tests cover its logic without UI tests: the screen state (`empty` or `ready(pageCount:)`) and the error-to-message mapping.

## Non-Goals

- Search (f13), the page viewer (f15), deleting or replacing the rulebook (f12).
- Drag and drop, "Open in" from other apps, a progress percentage, cancelling an import.
- Any custom visual design; standard SwiftUI controls only (`docs/build-brief.md`, Non-goals).
- Any change to the import pipeline or `ImportError` (f08–f11).

## Job Story

When I open a game that has no rulebook yet,
I want to pick its PDF from Files and import it right there,
so I can see the rulebook is ready, or learn plainly why it was refused.

## Users And Permissions

- The single on-device user picks a file through the system picker. The app reads only the picked file, through security-scoped access.

## Acceptance Scenarios

Scenarios 1–3 are automated. As in f08, each uses its own in-memory container (`ModelConfiguration(isStoredInMemoryOnly: true)`) and its own `RulebookStore` over a unique temporary directory, removed at the end of the test. Games are created with f02's `Library.createGame(named:)`, and PDFs are built with f06's `SyntheticPDF` and written to temporary files. Scenario 4 is manual.

### Scenario 1: screen state from empty to ready

Given a newly created game "Taifa"
When `GameScreenState(game:)` is computed
Then it is `.empty`.
When a two-page synthetic PDF is imported with `library.importPickedFile(at:into:store:)`
Then the result is `.success(.imported(_))` and `GameScreenState(game:)` is `.ready(pageCount: 2)`.
When the same file is imported again
Then the result is `.success(.alreadyPresent(_))` and the state is still `.ready(pageCount: 2)`.
When the bytes "not a pdf" are imported into a second new game
Then the result is `.failure(.unreadable)` and that game's state is still `.empty`.

### Scenario 2: one distinct message per error

Given the six `ImportError` cases: `.unreadable`, `.locked`, `.noTextLayer`, `.alreadyImported(gameName: "Taifa")`, `.storage`, `.gameHasRulebook`
When `ImportErrorMessage.message(for:)` maps each one
Then the six `key`s are pairwise distinct. The key for `.alreadyImported` is exactly `This rulebook is already in “%@”.`, and it is the same for `gameName: "Taifa"` and `gameName: "Catán"`. Resolved with `locale` set to `en`, the `"Catán"` message reads `This rulebook is already in “Catán”.`; with `es`, it reads `Este reglamento ya está en «Catán».`. The game name is an argument, not part of the key.

### Scenario 3: successful outcomes produce no message

Given a rulebook `r` from an import in the test
When `ImportErrorMessage.message(for: .success(.imported(r)))` and `ImportErrorMessage.message(for: .success(.alreadyPresent(r)))` run
Then both are `nil`. For `.failure(e)`, the result equals `message(for: e)` for every case in scenario 2.

### Scenario 4: the screen on the iPhone 16 (manual, not automated)

Given the app on the iPhone 16 and a game without a rulebook
When the user taps "Import Rulebook" and picks Taifa 3.0 in Files
Then a progress indicator replaces the button; afterwards the screen shows "Pages" with 16 and no alert.
When the user picks a scanned PDF, a password-protected PDF, or a file that is not a PDF (if the picker allows selecting it)
Then the "Import Failed" alert shows that file's message, "OK" closes it, and the game stays empty.
When the user imports, into another game, the Taifa file already imported
Then the alert names the first game.

## Repository Research

### Files Inspected

- `docs/specs/f03-list-games.md` (approved) — `GameView(game:)`: `navigationTitle(game.name)` and `ContentUnavailableView("No Rulebook Yet", systemImage:)` with no actions; f03 left import and the `ready` state to a later feature.
- `docs/specs/f08-atomic-import.md` (approved) — `RulebookStore.app` (`applicationSupportDirectory/Rulebooks`), `Rulebook.pageCount`, `Game.rulebook`, `ImportError`; the f08 non-goals hand the picker and security-scoped access to f17.
- `docs/specs/f09-reject-no-text-layer.md`, `docs/specs/f10-reject-unreadable-file.md` (approved) — `.noTextLayer`, `.locked`, and `.unreadable` for files that cannot be read or opened; how each error is shown belongs to f17.
- `docs/specs/f11-reimport-same-file.md` (approved) — `importRulebook(fileAt:into:store:) async throws -> ImportOutcome` (`imported`, `alreadyPresent`, `var rulebook`); `ImportError.alreadyImported(gameName:)` carries the stored `name`. All six error cases.
- `docs/domain-model.md` — Game `empty` (import offered) and `ready` (import not offered); the Import state machine.
- `CONTEXT.md` — Game, Rulebook, Import, Text layer; avoid "document" or "PDF" for the entity.
- `docs/build-brief.md` — Game screen (rulebook status, import action); F17 row; File picker (system).
- `AGENTS.md` — Localization (keys added by hand with `es` translated), Tests (no UI tests; manual validation).
- `feature_list.json` — f17 entry (verification, `depends_on` f03 and f11).
- `RuleRef/` — app shell and the catalog with only "Hello, world!"; `RuleRefTests/` — smoke test.

### Existing Patterns To Follow

- Default isolation is `MainActor`; pure domain logic is `nonisolated` explicitly; no `@Model` type is `nonisolated` (f08).
- Game names are shown through `StringProtocol` overloads and are never catalog keys (f03).
- Errors are `nonisolated` `Equatable` `Sendable` enums (f08).

### Current Gaps

- f02, f03 and f05–f11 are approved but not implemented. `Game`, `Library`, `GameView`, `Rulebook`, `RulebookStore`, `ImportError`, `ImportOutcome` and `SyntheticPDF` do not exist yet. This spec relies only on what their specs promise. If an implementation differs in a name used here, f17 follows the implementation and says so in its evidence.
- How f02's `ContentView` builds a `Library` from the environment is f02's choice; `GameView` builds it the same way.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled May 2026):

- `fileImporter(isPresented:allowedContentTypes:onCompletion:)` (iOS 14+, not deprecated): the single-file variant, with `onCompletion: (Result<URL, any Error>) -> Void`. `isPresented` is set to `false` before `onCompletion`; on cancel, `onCompletion` is not called. The returned URLs are security-scoped. The variants with `allowsMultipleSelection` return `[URL]`, and only the multiple-selection one has `onCancellation` (iOS 17+). f17 needs neither.
- `UTType.pdf` (iOS 14+): `com.adobe.pdf`.
- `URL.startAccessingSecurityScopedResource() -> Bool` and `stopAccessingSecurityScopedResource()`: every successful start must be balanced by a stop, and a missed stop leaks kernel resources. Calling stop without access does nothing.
- `ContentUnavailableView.init(label:description:actions:)` (iOS 17+): carries a call to action.
- `ProgressView.init(_:)` with a localized title (iOS 14+): indeterminate progress.
- `LabeledContent.init(_ titleKey: LocalizedStringKey, value: F.FormatInput, format: F)` (iOS 16+). The `value:` overloads take only `StringProtocol`, so an `Int` page count uses `format: .number`. There is no plural variant.
- `alert(_:isPresented:presenting:actions:message:)` with a `LocalizedStringResource` or `LocalizedStringKey` title (iOS 15+/16+, not deprecated; `Alert` and `alert(isPresented:content:)` are deprecated). It appears only while `isPresented` is `true` and the data is non-nil. On iOS, alert actions must have `Text` labels.
- `LocalizedStringResource` (iOS 16+, `Sendable`, `Equatable`, `ExpressibleByStringInterpolation`): `key: String`, `var locale`. It is resolved later with `String(localized:)`; changing `locale` before resolving picks the language. `Text.init(_ resource: LocalizedStringResource)` (iOS 16+).
- **Not verified**: that the key generated for a `String` interpolation uses the `%@` placeholder. Scenario 2 and `catalog-coverage` check it. If the compiler generates another placeholder, use the compiler's, keep the catalog in line, and record it in evidence.
- **Not verified**: whether `startAccessingSecurityScopedResource()` returns `true` or `false` for a plain temporary file URL. Scenario 1 passes either way, because the import is attempted regardless.
- **Not verified**: which executor runs `onCompletion`. It is created in a `MainActor` view and starts a `Task` that inherits the main actor.

Pieces:

1. `GameScreenState` (`nonisolated enum`, `Equatable`, `Sendable`): `empty`, `ready(pageCount: Int)`. An extension adds `init(game: Game)`, which stays on the main actor because it reads a `@Model`: `game.rulebook.map { .ready(pageCount: $0.pageCount) } ?? .empty`. `GameView` decides what to show only from this value.
2. `ImportErrorMessage` (`nonisolated enum`), with two pure functions:
   - `static func message(for error: ImportError) -> LocalizedStringResource`: one literal per case, below. `.alreadyImported(let gameName)` interpolates `gameName`.
   - `static func message(for result: Result<ImportOutcome, ImportError>) -> LocalizedStringResource?`: `nil` for success, `message(for: error)` for failure. It never reads the rulebook.
3. `Library.importPickedFile(at url: URL, into game: Game, store: RulebookStore) async -> Result<ImportOutcome, ImportError>` (f02's file, declared change):
   - `let didStart = url.startAccessingSecurityScopedResource()`, then `defer { if didStart { url.stopAccessingSecurityScopedResource() } }`. Access is released on success and on error. A `false` start does not stop the import.
   - `try await importRulebook(fileAt: url, into: game, store: store)` becomes `.success`; a caught `ImportError` becomes `.failure`. Any other error becomes `.failure(.storage)`, because f08–f11 throw only `ImportError`; a comment says so.
4. `GameView` (f03's file, declared change):
   - `switch GameScreenState(game: game)`:
     - `.empty`: `ContentUnavailableView` with the label "No Rulebook Yet" (unchanged) and, as its action, `Button("Import Rulebook")`. While `isImporting` is `true`, the action is `ProgressView("Importing…")` instead.
     - `.ready(let pageCount)`: `List { LabeledContent("Pages", value: pageCount, format: .number) }` and nothing else.
   - `.fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.pdf])`. On `.success(url)`: set `isImporting = true`; in `Task`, `await library.importPickedFile(at: url, into: game, store: .app)`; set `errorMessage = ImportErrorMessage.message(for: result)`, then `isImporting = false`. On `.failure`: `errorMessage` is the `.unreadable` message (the picker could not hand over a file). Cancel does nothing.
   - `.alert("Import Failed", isPresented: <errorMessage != nil>, presenting: errorMessage) { _ in Button("OK") {} } message: { Text($0) }`. Dismissing it sets `errorMessage` to `nil`.
   - With the button hidden while importing, a second import cannot start. Leaving the screen does not cancel the `Task`.

Texts (the key is the English text; `es` value with state `translated`):

| Key | `es` |
|---|---|
| Import Rulebook | Importar reglamento |
| Importing… | Importando… |
| Pages | Páginas |
| Import Failed | No se pudo importar |
| OK | Aceptar |
| This file could not be opened as a PDF. It may be damaged or not be a PDF. (`.unreadable`) | Este archivo no se ha podido abrir como PDF. Puede que esté dañado o que no sea un PDF. |
| This PDF asks for a password. Import a copy without a password. (`.locked`) | Este PDF pide una contraseña. Importa una copia sin contraseña. |
| This PDF has no selectable text. Scanned rulebooks are not supported. (`.noTextLayer`) | Este PDF no tiene texto seleccionable. No se admiten reglamentos escaneados. |
| This rulebook is already in “%@”. (`.alreadyImported`) | Este reglamento ya está en «%@». |
| The rulebook could not be saved. Try again. (`.storage`) | No se ha podido guardar el reglamento. Inténtalo de nuevo. |
| This game already has a rulebook. (`.gameHasRulebook`) | Este juego ya tiene un reglamento. |

The parenthesised case names are not part of the keys. Game names are never keys.

## Expected File Changes

- `RuleRef/GameScreenState.swift`, `RuleRef/ImportErrorMessage.swift` — create.
- `RuleRef/Library.swift` — modify (declared); `importPickedFile(at:into:store:)`.
- `RuleRef/GameView.swift` — modify (declared, f03's file); state switch, button, picker, progress, alert, ready row.
- `RuleRef/Localizable.xcstrings` — modify; the 11 keys above with `translated` `es` values.
- `RuleRefTests/GameScreenStateTests.swift` (scenario 1), `RuleRefTests/ImportErrorMessageTests.swift` (scenarios 2–3) — create.

## Visual Design Impact

- UI involved: yes.
- Design source: Human Interface Guidelines with standard SwiftUI controls. The repo has no `DESIGN.md`, and custom design is out of scope until m4. This is not a planning gap.
- Screens or states affected: `GameView` empty (with the button), importing (progress), ready (page count), and the error alert.
- New design artifact required: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- Other docs: none. `docs/domain-model.md` already defines `empty` and `ready`, and `docs/build-brief.md` already lists the Game screen and the system file picker.

## Implementation Plan

1. Confirm f03 and f11 are accepted; otherwise stop and report.
2. Write failing `GameScreenStateTests` and `ImportErrorMessageTests`.
3. Add `GameScreenState`, `ImportErrorMessage` and `Library.importPickedFile`.
4. Rework `GameView` and add the 11 catalog keys.
5. Run `./init.sh`; record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] `GameScreenStateTests`: scenario 1, on its own container and temporary directory.
- [ ] `ImportErrorMessageTests`: scenarios 2 and 3; distinct keys, the exact `alreadyImported` key, `en` and `es` resolution with "Catán".
- [ ] `GameScreenState` and `ImportErrorMessage` (`nonisolated`, pure); `Library.importPickedFile` with balanced access and the error mapping.
- [ ] `GameView`: switch on `GameScreenState`, button or progress, `fileImporter` for one PDF with `RulebookStore.app`, alert with one "OK", ready row.
- [ ] Catalog: 11 keys with `es` values; `./init.sh` green; evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0 with every check PASS. test-results shows the new tests, 0 failed, 0 skipped. `string-catalog` and `catalog-coverage` pass with the 11 keys.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/GameScreenStateTests -only-testing:RuleRefTests/ImportErrorMessageTests`.
- `git diff main...HEAD -- RuleRef/GameView.swift RuleRef/Library.swift` shows only the declared changes.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests). The user checks scenario 4 by hand on the iPhone 16 at the end of T3.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–3, and the generated `alreadyImported` key.
- `not_verified`: the interface (button, picker limited to PDF, progress, alert and ready state; scenario 4); a real security-scoped URL from Files and its access balance; the picker's `.failure` path; leaving the screen during an import; iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–3 pass on in-memory containers with their own temporary directories.
- [ ] `GameView` chooses what to show only from `GameScreenState(game:)`; the ready state shows only `LabeledContent("Pages", …)`.
- [ ] The picker is `fileImporter` with `[.pdf]` and single selection. Every successful start is balanced by a stop on success and on error, and a failed start does not prevent the import.
- [ ] While importing, a `ProgressView` replaces the button; there is no cancel and no second import.
- [ ] Errors go through `ImportErrorMessage` into one alert with a common title and a single "OK". Successful outcomes show no alert. Game names are arguments, never keys.
- [ ] The 11 keys have `translated` `es` values. No search, viewer, deletion, drag and drop or custom design was added.
- [ ] The interface is listed in `not_verified`; `feature_list.json` and `PROGRESS.md` were updated correctly.
