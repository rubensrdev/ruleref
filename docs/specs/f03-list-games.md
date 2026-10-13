# Feature Implementation Spec: List games alphabetically

## Source Feature

- `id`: f03-list-games
- `area`: library
- `depends_on`: f02-create-game
- `status`: not_started
- `source`: `feature_list.json`

## Goal

The root screen becomes the library: it lists every game alphabetically by its folded name key (f02's `Game.nameKey`), so case, diacritics and width do not change the order. With no games it shows an empty state that invites the user to create one. One sorted `FetchDescriptor<Game>`, defined once, feeds both the list (`@Query`) and a `Library` operation, so the tests check the same query the screen shows. Tapping a row opens a minimal game screen, `GameView`, which shows the game's name and a "No Rulebook Yet" empty state.

## Non-Goals

- Renaming or deleting games (f04).
- Importing a rulebook, the `ready` state and anything shown for it (f08); `GameView` has no actions.
- Search (f13).
- Any custom visual design (`docs/build-brief.md`, Non-goals); standard SwiftUI controls only until m4.
- Sections, index bars, a secondary sort key or user-selectable sorting.

## Job Story

When I open RuleRef at the table,
I want to see my games in alphabetical order and open one,
so I can get to its rulebook quickly.

## Users And Permissions

- The single on-device user: views the library and opens a game. No accounts, no sharing.

## Acceptance Scenarios

Scenarios 1–3 are automated on `ModelConfiguration(isStoredInMemoryOnly: true)`, one container per test, as in f02. Games are created with f02's `Library.createGame(named:)`, never inserted by hand, so every `nameKey` is the real folded key. Scenario 4 is manual.

### Scenario 1: alphabetical order

Given a library where "Zombicide", "azul" and "Ábaco" were created in that order
When `Library.games()` runs
Then it returns the games named "Ábaco", "azul", "Zombicide", in that order.

### Scenario 2: empty library

Given an empty library
When `Library.games()` runs
Then it returns an empty array (the feature's "empty flag" is `isEmpty` on that result; there is no separate property). The list showing the empty state is checked by hand (scenario 4).

### Scenario 3: order after creating

Given a library holding "Zombicide" and "azul", and a first `Library.games()` returning "azul", "Zombicide"
When `Library.createGame(named: "Catán")` succeeds and `Library.games()` runs again
Then it returns "azul", "Catán", "Zombicide".

### Scenario 4: the screens (manual, not automated)

Given the app launched on the iPhone 16
When the library has games
Then the list shows them in the same order as scenario 1; tapping a row opens `GameView` with the game's name as its title and the "No Rulebook Yet" empty state; going back returns to the list.
When the library has no games
Then the empty state is shown, and "New Game" in the navigation bar opens the same `NewGameSheet` as f02; after creating a game the list replaces the empty state.

## Repository Research

### Files Inspected

- `docs/specs/f02-create-game.md` (approved) — promises `Game` (`@Model`: `name`, `nameKey`, folded with `[.caseInsensitive, .diacriticInsensitive, .widthInsensitive]` and `en_US_POSIX`), `Library` (MainActor struct over a `ModelContext`, `createGame(named:)` saves), `NewGameSheet`, a "New Game" button in `ContentView`, and `.modelContainer(for: Game.self)` in `RuleRefApp`. `nameKey` is unique because creation rejects duplicates.
- `docs/domain-model.md` — Game states `empty` (no rulebook; import offered) and `ready`; Library 1 — N Game.
- `CONTEXT.md` — terms **Library** (the list of all games on the device) and **Game**.
- `docs/build-brief.md` — F03 row ("order and empty flag"); screens: Library (list of games, empty state) and Game; Non-goals (custom design, F04).
- `AGENTS.md` — Localization (catalog keys by hand, `es` translated) and Tests (no UI tests; manual validation).
- `RuleRef/ContentView.swift` — still the Xcode template; `RuleRef/RuleRefApp.swift` — no model container; `RuleRef/Localizable.xcstrings` — only "Hello, world!".
- `RuleRefTests/RuleRefTests.swift` — smoke test only.
- `docs/specs/f05-rulebook-id.md`, `docs/specs/f06-extract-passages.md` — approved references for detail level.

### Existing Patterns To Follow

- Default isolation is `MainActor` in both targets; `Library` and the views stay MainActor.
- Synchronized folders: new files in `RuleRef/` and `RuleRefTests/` need no project change.
- Catalog keys are added by hand with a `translated` `es` value; `init.sh` checks it (`string-catalog`, `catalog-coverage`).

### Current Gaps

- f02 is approved but not implemented: `Game`, `Library`, `NewGameSheet`, `RuleRefApp`'s model container and f02's `ContentView` do not exist yet. This spec relies only on what f02's spec promises; f02 must be accepted before f03 starts (`depends_on`).
- If f02's implementation places the "New Game" button somewhere other than the navigation bar, f03 moves it there; the sheet itself is unchanged.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled May 2026):

- `Query.init(_ descriptor: FetchDescriptor<Element>, transaction: Transaction? = nil)` (iOS 17+, `@MainActor`): `@Query` accepts a `FetchDescriptor` directly.
- `SortDescriptor.init(_ keyPath: any KeyPath<Compared, String> & Sendable, comparator: String.StandardComparator = .localizedStandard, order: SortOrder)` (iOS 17+). The default comparator, `.localizedStandard`, is "a localized, numeric comparison in the current locale" (Finder order). `.lexical` "compares Strings lexically". `.localized` uses the current locale.
- `PersistentModel` inherits `Hashable` and `Identifiable`, so a `@Model` class is a valid value for `NavigationLink(value:)`.
- `navigationDestination(for:destination:)` (iOS 16+) requires `D: Hashable`. Apple says not to put it inside a lazy container such as `List`; it goes outside, on the stack's root content.
- `ContentUnavailableView.init(_ title: LocalizedStringKey, systemImage: String, description: Text? = nil)` (iOS 17+). Apple recommends it for "a list without items".
- `Text.init(_ content: some StringProtocol)` displays a stored string without localization; `navigationTitle(_:)` has a `StringProtocol` overload as well as `LocalizedStringKey`. Game names are user data and use these overloads, so they never become catalog keys.

Sorting decision: sort by `\Game.nameKey`, `.forward`, with the comparator passed explicitly as `.lexical`. The key is already folded with a fixed locale (f02), so a locale-independent comparison keeps the order the same on every device and in tests. For the scenario names the keys are "abaco", "azul", "zombicide", which sort as expected under either comparator. The scenarios also tell folded and raw names apart: sorting the raw `name` lexically would give "Zombicide", "azul", "Ábaco".

- Verified in the docs: the comparator options and their meaning, and the default.
- **Not verified** in the docs: how SwiftData's store applies a `String.StandardComparator` to a fetch. Apple does not document how it is translated to the store. Scenario 1 checks it on the real (in-memory) store for Latin names.
- **Not verified**: order for non-Latin names (Greek, Cyrillic, CJK) and for names starting with digits or punctuation. With `.lexical` these sort before letters.
- Accepted consequence: names with numbers sort lexically ("Catan 10" before "Catan 2"). Diacritic folding turns "ñ" into "n", so "Ñandú" sorts among the n's, not after them as Spanish collation would.

`nameKey` is unique (f02), so there are no ties and no tie-break key.

Pieces:

1. `Library` (extend f02's struct):
   - `static var alphabeticalGames: FetchDescriptor<Game>`, a computed property returning `FetchDescriptor<Game>(sortBy: [SortDescriptor(\.nameKey, comparator: .lexical, order: .forward)])` with no predicate. This is the only place the order is defined.
   - `func games() throws -> [Game]`, which returns `try context.fetch(Self.alphabeticalGames)`.
2. `ContentView` (the library screen) has a `NavigationStack`. Inside it:
   - `@Query(Library.alphabeticalGames) private var games: [Game]`.
   - If `games.isEmpty`, a `ContentUnavailableView("No Games", systemImage:, description: Text("Create a game to start your library."))`. Otherwise a `List` of `NavigationLink(value: game) { Text(game.name) }`.
   - `.navigationTitle("Library")`, f02's "New Game" toolbar button that presents `NewGameSheet`, and `.navigationDestination(for: Game.self) { GameView(game: $0) }` outside the `List`.
3. `GameView` (SwiftUI) takes `let game: Game` and shows `.navigationTitle(game.name)` (the `StringProtocol` overload) and `ContentUnavailableView("No Rulebook Yet", systemImage:)` with no actions. It does not branch on rulebook state: `Game` has no rulebook relationship until f08.

SF Symbol names (for example `books.vertical` and `book.closed`) are the implementer's choice. Their existence was **not verified** in the MCP, and the validator does not check them.

Expected new visible texts and their `es` values (the keys are the English text):

- "Library" → "Biblioteca"
- "No Games" → "No hay juegos"
- "Create a game to start your library." → "Crea un juego para empezar tu biblioteca."
- "No Rulebook Yet" → "Aún no hay reglamento"

"New Game" and the other sheet texts already come from f02. Game names are never keys.

## Expected File Changes

- `RuleRef/Library.swift` — modify; add `alphabeticalGames` and `games()`.
- `RuleRef/ContentView.swift` — modify; `NavigationStack`, `@Query`, list, empty state, title, navigation destination.
- `RuleRef/GameView.swift` — create; the minimal game screen.
- `RuleRef/Localizable.xcstrings` — modify; the four keys above with `translated` `es` values.
- `RuleRefTests/LibraryGamesTests.swift` — create; scenarios 1–3.

## Visual Design Impact

- UI involved: yes.
- Design source: Human Interface Guidelines with standard SwiftUI controls. The repo has no `DESIGN.md`, and custom design is out of scope until m4. This is not a planning gap.
- Screens or states affected: library with games, library empty, `GameView` in its empty (`No Rulebook Yet`) state.
- New design artifact required: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- Other docs: none. `docs/build-brief.md` already lists the Library and Game screens, and `docs/domain-model.md` already defines the `empty` state. That f03 owns the minimal game screen and f08 the import action is recorded by this spec and by the `PROGRESS.md` entry.

## Implementation Plan

1. Write failing `LibraryGamesTests` for scenarios 1–3 on an in-memory container.
2. Add `Library.alphabeticalGames` and `Library.games()`.
3. Rework `ContentView` (stack, `@Query` with the same descriptor, list, empty state, toolbar, destination), add `GameView`, and add the catalog keys.
4. Run `./init.sh`. Record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] `LibraryGamesTests`: the order for "Zombicide", "azul", "Ábaco"; an empty array on an empty library; "Catán" lands between "azul" and "Zombicide" after `createGame`. Assert on `name`, in order.
- [ ] `Library.swift`: `alphabeticalGames` (sort on `nameKey`, `.lexical`, `.forward`) and `games()`.
- [ ] `ContentView.swift`: `@Query(Library.alphabeticalGames)`, `ContentUnavailableView` when empty, `NavigationLink(value:)` rows, `navigationDestination(for: Game.self)` outside the `List`, "New Game" in the toolbar.
- [ ] `GameView.swift`: the name as title, "No Rulebook Yet", no actions.
- [ ] Catalog: four new keys with `es` values; no game name added as a key.
- [ ] `./init.sh` green; evidence and `PROGRESS.md` updated.

## Verification Plan

- `./init.sh` exits 0 with every check PASS. test-results shows the new tests, 0 failed, 0 skipped. `catalog-coverage` passes with the four new keys.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/LibraryGamesTests`.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests). The user checks scenario 4 by hand on the iPhone 16 at the end of T3.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–3.
- `not_verified`: the list, the empty state and `GameView` (scenario 4); non-Latin names and names starting with digits or punctuation; how the store applies the comparator beyond the tested names; iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–3 are covered by passing tests on an in-memory container, with games created through `Library.createGame(named:)`.
- [ ] The sort is defined once (`Library.alphabeticalGames`), on `nameKey`, forward. `Library.games()` and the view's `@Query` both use it, and no other sort is applied in the view.
- [ ] The empty state is a `ContentUnavailableView`; "New Game" stays in the navigation bar and opens f02's `NewGameSheet`.
- [ ] Navigation is by value (`NavigationLink(value:)` + `navigationDestination(for: Game.self)`, outside the `List`). `GameView` shows the name and "No Rulebook Yet", with no actions.
- [ ] Game names are displayed through the `StringProtocol` overloads; the four new keys have `translated` `es` values.
- [ ] No rename, delete, import, `ready` state, search or custom design was added.
- [ ] The interface is listed in `not_verified`; `feature_list.json` and `PROGRESS.md` were updated correctly.
