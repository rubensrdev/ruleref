# Feature Implementation Spec: Create a game

Approval: approved by the user on 2026-10-08

## Source Feature

- `id`: f02-create-game
- `area`: library
- `depends_on`: f01-cli-build-and-tests
- `status`: not_started
- `source`: `feature_list.json`

## Goal

The user creates a game by name. A name is trimmed, must not be blank, and must be unique across the library, ignoring case and diacritics. The game is persisted with SwiftData. A minimal sheet from the root screen makes the operation reachable; the root screen stops being the Xcode template.

## Non-Goals

- Listing games (f03); the root screen shows no list.
- Navigating to a game screen.
- Renaming or deleting games (f04).
- Importing rulebooks (f08); `Game` gets no rulebook relationship yet.
- Any custom visual design (`docs/build-brief.md`, Non-goals).

## Job Story

When I sit down to play a game whose rulebook I want on hand,
I want to add that game to my library by name,
so I can later import its rulebook and search it.

## Users And Permissions

- The single on-device user: creates games. No accounts, no sharing.

## Acceptance Scenarios

### Scenario 1: a blank name is rejected

Given an empty library
When the user creates a game named "" or "   "
Then creation fails with the blank-name error and the library still holds 0 games.

### Scenario 2: surrounding spaces and case do not make a new name

Given a library holding "Taifa"
When the user creates a game named " taifa "
Then creation fails with the duplicate-name error and the library still holds 1 game.

### Scenario 3: diacritics do not make a new name

Given a library holding "Catán"
When the user creates a game named "catan"
Then creation fails with the duplicate-name error and the library still holds 1 game.

### Scenario 4: a valid name creates a persisted, trimmed game

Given an empty library
When the user creates a game named "  Taifa  "
Then one game exists, its name is "Taifa", and a fetch through a new `ModelContext` on the same container returns it.

### Scenario 5: the sheet (manual, not automated)

Given the app launched on the iPhone 16
When the user taps "New Game", leaves the name blank or repeats an existing one, and confirms
Then the sheet stays open with an inline error; with a valid name it closes.

## Repository Research

### Files Inspected

- `RuleRef/RuleRefApp.swift` — `WindowGroup { ContentView() }`; no model container yet.
- `RuleRef/ContentView.swift` — Xcode template ("Hello, world!" with a globe image).
- `RuleRef/Localizable.xcstrings` — one key, "Hello, world!", with its `es` value.
- `RuleRefTests/RuleRefTests.swift` — Swift Testing smoke test; keep it.
- `CONTEXT.md`, `docs/domain-model.md` (Game: name unique, case- and diacritic-insensitive), `docs/build-brief.md` (F02 row, Non-goals), ADR-001, `AGENTS.md`, `docs/specs/f01-cli-build-and-tests.md`.

### Existing Patterns To Follow

- Default isolation is `MainActor`; pure domain logic is `nonisolated` explicitly.
- Synchronized folders: new files in `RuleRef/` and `RuleRefTests/` need no project change.
- Catalog keys are added by hand with a `translated` `es` value; `init.sh` enforces it.

### Current Gaps

- No SwiftData model or container exists yet; f02 introduces both.

## Technical Approach

APIs, checked in the Cupertino MCP on 2026-10-08:

- **Name key**: `String.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))` on the trimmed name (`trimmingCharacters(in: .whitespacesAndNewlines)`). Apple recommends folding once and storing the result when strings are compared repeatedly. The fixed locale keeps the key deterministic (the docs note case folding varies by locale, e.g. Turkish "I"). Folding is not available inside `#Predicate`, so the key is stored.
- **Uniqueness**: the creation operation fetches by key (`FetchDescriptor<Game>` with `#Predicate { $0.nameKey == key }`, `fetchCount`) and throws the duplicate-name error before inserting. No `#Unique`: on a collision SwiftData upserts, updating the existing game instead of failing (WWDC24 "What's new in SwiftData"), which would silently rename it rather than reject the duplicate.

Pieces:

1. `GameName` (`nonisolated struct`, `Sendable`, `Equatable`): built from raw input, throws `GameNameError.blank`; exposes `value` (trimmed) and `key` (folded).
2. `GameNameError` (`nonisolated enum`, `Error`, `Equatable`): `blank`, `duplicate`.
3. `Game` (`@Model final class`): `name: String`, `nameKey: String`.
4. `Library` (MainActor struct over a `ModelContext`): `createGame(named:) throws -> Game` builds a `GameName`, checks the key, inserts and saves.
5. `NewGameSheet` (SwiftUI): a `Form` with a name `TextField`, Cancel and Create toolbar buttons, and an inline error text for `blank` and `duplicate`. It calls `Library` with the environment's `modelContext`.
6. `ContentView`: a "New Game" button that presents `NewGameSheet`. `RuleRefApp` adds `.modelContainer(for: Game.self)`.

## Expected File Changes

- `RuleRef/GameName.swift` — create; name rule and key.
- `RuleRef/GameNameError.swift` — create; the two errors.
- `RuleRef/Game.swift` — create; SwiftData model.
- `RuleRef/Library.swift` — create; create-game operation.
- `RuleRef/NewGameSheet.swift` — create; the sheet.
- `RuleRef/ContentView.swift` — modify; template removed, "New Game" button.
- `RuleRef/RuleRefApp.swift` — modify; model container.
- `RuleRef/Localizable.xcstrings` — modify; remove "Hello, world!"; add every new visible text with its `es` value (expected: "New Game", "Name", "Cancel", "Create", the two error messages).
- `RuleRefTests/GameNameTests.swift`, `RuleRefTests/LibraryTests.swift` — create.

## Visual Design Impact

- UI involved: yes.
- Design source: Human Interface Guidelines with standard SwiftUI controls. The repo has no `DESIGN.md`; custom design is out of scope until m4. Not a planning gap.
- Screens or states affected: root screen (button only); sheet in empty, blank-error and duplicate-error states.
- New design artifact required: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- Other docs: none; `docs/domain-model.md` already states the name rule.

## Implementation Plan

1. Write failing tests for `GameName` (blank, trim, key equality for case and diacritics).
2. Add `GameNameError` and `GameName`.
3. Write failing `Library` tests on an in-memory container (scenarios 1–4).
4. Add `Game` and `Library`.
5. Add `NewGameSheet`, rework `ContentView`, wire the container in `RuleRefApp`, update the catalog.
6. Run `./init.sh`; record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] `GameNameTests`: "" and "   " throw `.blank`; "  Taifa  " → value "Taifa"; keys of "Taifa"/" taifa " and "Catán"/"catan" are equal; "Taifa"/"Catan" differ.
- [ ] `GameNameError.swift`, `GameName.swift` (`nonisolated`).
- [ ] `LibraryTests` with `ModelConfiguration(isStoredInMemoryOnly: true)`, one container per test.
- [ ] `Game.swift`, `Library.swift`.
- [ ] `NewGameSheet.swift`, `ContentView.swift`, `RuleRefApp.swift`.
- [ ] Catalog: drop "Hello, world!", add new keys with `es` values.
- [ ] `./init.sh` green; evidence and `PROGRESS.md` updated.

## Verification Plan

- `./init.sh` exits 0 with every check PASS; test-results shows the new tests, 0 failed, 0 skipped.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/GameNameTests -only-testing:RuleRefTests/LibraryTests`.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests). The user validates the sheet by hand at the end of T3 (scenario 5).

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–4.
- `not_verified`: the sheet and root screen (scenario 5), iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–4 are covered by passing tests on an in-memory container.
- [ ] `GameName` and `GameNameError` are `nonisolated`; no UIKit, XCTest or JSONSerialization.
- [ ] Uniqueness is enforced only by the pre-insert check; `Game` has no `#Unique`.
- [ ] Every new visible text is in the catalog with a translated `es` value; "Hello, world!" is gone.
- [ ] No list, navigation, rename, delete or import was added.
- [ ] The interface is listed in `not_verified`.
- [ ] `feature_list.json` and `PROGRESS.md` were updated correctly.
