# Feature Implementation Spec: Library and game screens follow DESIGN.md

## Source Feature

- `id`: f19-interface-conventions
- `area`: interface
- `depends_on`: f17-import-action
- `status`: not_started
- `source`: `feature_list.json`

## Goal

The three existing screens (library, new game, game) follow `DESIGN.md` without changing what they do: buttons outside alerts are `Label`s with an SF Symbol or use a standard role, and every state each view can show has a named `#Preview` with sample data. Views whose states are reachable only at run time are split into a content view that takes plain values and a thin wrapper that owns `@Query`, `@State`, the environment and the actions. `ContentView` becomes `LibraryView`. The existing tests pass untouched.

## Non-Goals

- Any behavior change: same flows, same messages, same import pipeline, same order of games.
- Search (f13), the no-match state (f14), the page viewer (f15), deleting games or rulebooks (f04, f12).
- Custom colors, fonts, materials or components (`DESIGN.md`, Source).
- An `init.sh` check for previews (post-m4 harness batch, `PROGRESS.md`).

## Job Story

When I review the app in Xcode or on the iPhone,
I want standard symbols and roles and a preview for every state,
so I can check each screen without reaching its states by hand.

## Users And Permissions

- Unchanged: one on-device user.

## Acceptance Scenarios

Scenario 1 is automated; scenarios 2–4 are reviewed by the validator in the diff; scenario 5 is manual.

### Scenario 1: the sheet's failure mapping is unchanged

Given the errors `GameNameError.blank`, `GameNameError.duplicate` and any other error (for example `CocoaError(.fileWriteUnknown)`)
When `NewGameFailure(error:)` maps each one
Then they are `.blank`, `.duplicate` and `.saveFailed`, the mapping `NewGameSheet.create()` used before f19.

### Scenario 2: buttons follow DESIGN.md

Given the diff of `RuleRef/Features/`
Then "New Game" is `Button("New Game", systemImage: "plus")` with `.labelStyle(.iconOnly)` in the library toolbar; the sheet's buttons are `Button(role: .cancel)` and `Button(role: .confirm)` with no title; "Import Rulebook" is `Button("Import Rulebook", systemImage: "square.and.arrow.down")`; the alert keeps `Button("OK")` as text.

### Scenario 3: one named preview per state, sample data only

Given every file under `RuleRef/Features/`
Then each file that declares a view has at least one `#Preview`, and the content views have these named previews: `LibraryView` "Empty" and "Games"; `NewGameForm` "Empty", "Blank Name", "Duplicate" and "Save Failed"; `GameContent` "Empty", "Importing", "Ready" and "Import Failed". No preview touches the persistent store, `RulebookStore.app`, a stored file or the network.

### Scenario 4: LibraryView replaces ContentView

Given the diff
Then `ContentView.swift` is renamed to `LibraryView.swift`, the type is `LibraryView`, `RuleRefApp` shows `LibraryView()`, and no `ContentView` remains in `RuleRef/` or `RuleRefTests/`.

### Scenario 5: the screens on the iPhone 16 (manual)

Given the app on the iPhone 16 and every preview in Xcode
Then the library shows a "+" button; the new-game sheet shows the system cancel and confirm buttons, Create still validates blank and duplicate names; the game screen's import button shows its symbol and title; behavior is as before f19, in English and Spanish.

## Repository Research

### Files Inspected

- `RuleRef/Features/Library/ContentView.swift` — `@Query(Library.alphabeticalGames)`, `@State isCreatingGame`, `NavigationStack`, empty `ContentUnavailableView("No Games", systemImage: "books.vertical", …)`, toolbar `Button("New Game")`, `navigationDestination(for: Game.self)`, sheet; Xcode template header; one unnamed preview with `.modelContainer(for: Game.self, inMemory: true)`.
- `RuleRef/Features/Library/NewGameSheet.swift` — private `Failure` (`blank`, `duplicate`, `saveFailed`), `TextField("Name")` with `.onSubmit(create)`, footer message in red, `Button("Cancel")` and `Button("Create")` in `.cancellationAction` / `.confirmationAction`; one unnamed preview.
- `RuleRef/Features/Game/GameView.swift` — `switch GameScreenState(game:)`, `ContentUnavailableView` with `Button("Import Rulebook")` or `ProgressView("Importing…")`, `List { LabeledContent("Pages", …) }`, `.fileImporter`, `.alert("Import Failed", …)` with `Button("OK")`; no preview.
- `RuleRef/Features/Game/GameScreenState.swift`, `ImportErrorMessage.swift`; `RuleRef/App/RuleRefApp.swift`; `RuleRef/Localizable.xcstrings` (22 keys).
- `DESIGN.md`, `ARCHITECTURE.md`, `AGENTS.md`; `docs/validations/f17-import-action.md` (open item: preview containers list only `Game.self`).
- Build settings in the project file (read only): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`, `ENABLE_PREVIEWS = YES`.

### Existing Patterns To Follow

- Game names go through `StringProtocol` overloads, never keys; `GameScreenState` decides what `GameView` shows.
- Errors and small state enums are `nonisolated`, `Equatable`, `Sendable`.

### Current Gaps

- `.claude/agents/feature-validator.md` still says the repo has no `DESIGN.md` or `ARCHITECTURE.md`. Until that line is fixed (a harness change outside this spec), the validator may skip the `DESIGN.md` review this feature depends on.
- No `RuleRef/Shared/` folder yet; this feature creates it (`ARCHITECTURE.md`).

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-16:

- `ButtonRole.cancel` (iOS 15+); `ButtonRole.close` and `.confirm` (iOS 26.0+). Apple: "Unlike a cancel operation, a close operation doesn't lose progress." The sheet discards the typed name, so Cancel is `.cancel`; Create is `.confirm`.
- `Button.init(role:action:)` (iOS 26.0+): a button with the role's default label. `Button.init(_:systemImage:action:)` with a `LocalizedStringKey` (iOS 14+) builds a `Label`. `LabelStyle.iconOnly` (iOS 14+).
- `PreviewModifier` (iOS 18+): `static func makeSharedContext() async throws -> Context`, cached and shared across previews; `body(content:context:)` applies it, for example with `.modelContainer(context)`. Attached with the `.modifier(_:)` preview trait. `#Preview(_ name: String? = nil, traits:…)`: the name is a `String`, not a catalog key.
- `ContentUnavailableView`, `ProgressView`, `LabeledContent`, `alert(_:isPresented:presenting:actions:message:)`, `fileImporter`: as checked in f17.
- **Not verified**: how `Button(role: .cancel)` and `Button(role: .confirm)` render in a sheet toolbar on iOS 26.0 and 27 (symbol or title); whether an alert shows in an Xcode preview; whether `#Preview` blocks compile in a Release build without `#if DEBUG` (this spec puts them inside `#if DEBUG`, so it does not matter). SF Symbol names `plus` and `square.and.arrow.down` were checked to exist with `NSImage(systemSymbolName:)` on macOS 27, not in the SF Symbols app for iOS 26.0; the user confirms them in the previews.

Pieces:

1. `RuleRef/Shared/SampleLibrary.swift`, all inside `#if DEBUG`:
   - `enum SampleLibrary { static let gameNames = ["Taifa", "Catán", "Carcassonne"]; static func container(gameNames: [String]) throws -> ModelContainer }`: a `ModelContainer(for: Game.self, Rulebook.self, Passage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))`, with each name created through `Library(context:).createGame(named:)`. No rulebook, no file.
   - `struct GamesPreview: PreviewModifier` (context: the container with `gameNames`) and `struct EmptyLibraryPreview: PreviewModifier` (no games); both `body` apply `.modelContainer(context)`.
2. `RuleRef/Features/Library/LibraryView.swift` (renamed from `ContentView.swift`, template header removed): same body; the toolbar button as in scenario 2. Its data comes from `@Query`, so it is not split. Previews "Empty" (`EmptyLibraryPreview`) and "Games" (`GamesPreview`).
3. `RuleRef/Features/Library/NewGameFailure.swift`: `nonisolated enum NewGameFailure: Equatable, Sendable { case blank, duplicate, saveFailed; init(error: any Error) }`, mapping as scenario 1.
4. `RuleRef/Features/Library/NewGameForm.swift`: content view `NewGameForm(name: Binding<String>, failure: NewGameFailure?, create: () -> Void, cancel: () -> Void)`. It holds the `NavigationStack`, `Form`, `TextField("Name")` with `.onSubmit(create)`, the footer messages (same keys, same red style), title "New Game", inline display mode and the toolbar: `.cancellationAction` → `Button(role: .cancel, action: cancel)`, `.confirmationAction` → `Button(role: .confirm, action: create)`. Previews "Empty" (`.constant("")`, `nil`), "Blank Name" (`""`, `.blank`), "Duplicate" (`"Taifa"`, `.duplicate`), "Save Failed" (`"Taifa"`, `.saveFailed`).
5. `RuleRef/Features/Library/NewGameSheet.swift`: wrapper with `@Environment(\.modelContext)`, `@Environment(\.dismiss)`, `@State name`, `@State failure: NewGameFailure?`; `create()` calls `Library.createGame(named:)`, dismisses on success, otherwise `failure = NewGameFailure(error:)`. One preview "Sheet" with `EmptyLibraryPreview`.
6. `RuleRef/Features/Game/GameContent.swift`: content view `GameContent(title: String, state: GameScreenState, isImporting: Bool, errorMessage: LocalizedStringResource?, importRulebook: () -> Void, dismissError: () -> Void)`. It holds the state switch, the import button as in scenario 2 or the progress view, the ready list, `navigationTitle(title)` (StringProtocol overload) and the alert, whose `isPresented` binding reads `errorMessage != nil` and calls `dismissError()` on dismissal. Previews, each in a `NavigationStack`, title "Taifa": "Empty", "Importing" (`isImporting: true`), "Ready" (`.ready(pageCount: 16)`), "Import Failed" (`.empty`, `ImportErrorMessage.message(for: .noTextLayer)`).
7. `RuleRef/Features/Game/GameView.swift`: wrapper with `game`, the environment, `@State isPickingFile`, `isImporting`, `errorMessage`, the `.fileImporter` and `importRulebook(at:)` unchanged; its body is `GameContent(…)` plus `.fileImporter`. One preview "Game" with `GamesPreview`, showing the first game from `@Previewable @Query(Library.alphabeticalGames)` in a `NavigationStack`.
8. `RuleRef/App/RuleRefApp.swift`: `LibraryView()`.
9. Every `#Preview` in these files sits inside `#if DEBUG`.

Catalog: no new keys. "Cancel" and "Create" are no longer used: delete both entries from `Localizable.xcstrings` by hand, so the catalog holds no dead keys (Xcode would only mark them stale). All other keys stay.

## Expected File Changes

- `RuleRef/Shared/SampleLibrary.swift` — create.
- `RuleRef/Features/Library/ContentView.swift` → `LibraryView.swift` — rename (`git mv`) and modify.
- `RuleRef/Features/Library/NewGameFailure.swift`, `NewGameForm.swift` — create; `NewGameSheet.swift` — modify.
- `RuleRef/Features/Game/GameContent.swift` — create; `GameView.swift` — modify.
- `RuleRef/App/RuleRefApp.swift` — modify (one line).
- `RuleRef/Localizable.xcstrings` — modify; remove "Cancel" and "Create".
- `RuleRefTests/Features/Library/NewGameFailureTests.swift` — create (scenario 1).
- No existing test file changes.

## Visual Design Impact

- UI involved: yes. Design source: `DESIGN.md`.
- Screens or states: library empty and with games; new-game sheet empty, blank, duplicate, save failed; game empty, importing, ready, import failed.
- New design artifact required: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`: not needed — `Shared/` is already defined there; it appears with its first file.
- `DESIGN.md`, `AGENTS.md`, `CONSTRAINTS.md`: not needed.
- Other docs: none. `.claude/agents/feature-validator.md` is stale (Current Gaps) but out of this feature's scope.

## Implementation Plan

1. Confirm f17 is accepted; otherwise stop.
2. Write `NewGameFailureTests` (scenario 1), then `NewGameFailure`.
3. Add `SampleLibrary`; rename `ContentView` to `LibraryView`; split the sheet and the game screen; update `RuleRefApp`.
4. Remove the two catalog keys; `./init.sh`; commit; record evidence and `PROGRESS.md`; commit.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] `NewGameFailure` and its test.
- [ ] `SampleLibrary` with `GamesPreview` and `EmptyLibraryPreview`, in `#if DEBUG`.
- [ ] `LibraryView` (rename), `NewGameForm` + `NewGameSheet`, `GameContent` + `GameView`, `RuleRefApp`.
- [ ] Buttons and previews exactly as scenarios 2 and 3.
- [ ] Catalog keys removed; `./init.sh` green; evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0, all checks PASS (`string-catalog` and `catalog-coverage` included), 0 failed, 0 skipped; the count is the previous 84 plus the new tests (more if f18 is merged first).
- Focused run: `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/NewGameFailureTests -only-testing:RuleRefTests/GameScreenStateTests -only-testing:RuleRefTests/LibraryTests` → `** TEST SUCCEEDED **`.
- The implementer commits code first and evidence later; the validator reviews the branch: `git diff main...HEAD --stat` lists only the files above plus `feature_list.json` and `PROGRESS.md`; `git diff main...HEAD -- RuleRefTests/` adds only `NewGameFailureTests.swift`; `git diff -M main...HEAD -- RuleRef/Features/` shows the rename and scenarios 2–3; `git ls-files RuleRef/Features RuleRef/Shared` lists the expected files.
- No UI tests and no E2E, by design. The user checks scenario 5 and every preview by hand.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, code commit, Xcode and simulator.
- The list of previews per file, and the two removed catalog keys.
- `not_verified`: the interface and every preview (scenario 5); how the role buttons render on iOS 26.0 and 27; the alert in the "Import Failed" preview; SF Symbol rendering; a Release build.

## Validator Checklist

- [ ] Existing tests unchanged and passing; `NewGameFailure` matches the old mapping.
- [ ] Buttons, symbols and roles exactly as scenario 2; the alert's OK is text.
- [ ] Named previews exactly as scenario 3, inside `#if DEBUG`, sample data only, from `RuleRef/Shared/`.
- [ ] Wrappers own `@Query`, `@State`, environment and actions; content views take plain values.
- [ ] `ContentView` is gone; "Cancel" and "Create" are gone from the catalog; no new keys.
- [ ] No behavior, search, viewer or custom design added; `feature_list.json` and `PROGRESS.md` updated correctly; the interface is in `not_verified`.
