# Feature Implementation Spec: Text search in a rulebook

## Source Feature

- `id`: f13-text-search
- `area`: search
- `depends_on`: f08-atomic-import, f19-interface-conventions (added by this spec with the user's authorization on 2026-10-16)
- `status`: not_started
- `source`: `feature_list.json`

## Goal

On the screen of a game that has a rulebook, the user types a query and sees the passages that contain every term, with their page number and an excerpt. Matching folds case, diacritics and width the way `GameName` does, so "construccion" finds "construcción". Matches are ranked by how many times the terms occur, then by reading order. An empty or whitespace-only query is the `idle` state. The search logic is pure, in `RuleRef/Search/`, and runs in memory over the rulebook's ordered passages; it never reads the stored file ("import means freeze").

## Non-Goals

- The no-match state (f14). Until f14, a query with zero matches yields `.matches([])` and an empty list. No f13 test pins that case, so f14 changes no f13 test.
- Opening a match in the page viewer (f15): match rows are not tappable in f13.
- Fuzzy, stemmed, partial-term or approximate matching; highlighting terms in the excerpt; a snippet window around the term.
- Search across games, query history or logging (`CONTEXT.md`: queries are never logged), a persistent index.

## Job Story

When a rule is argued at the table,
I want to type a few words and see the passages that contain them, with their page,
so I can find the rule in seconds.

## Users And Permissions

- One on-device user; search reads only the passages of the open game's rulebook.

## Acceptance Scenarios

Scenarios 1–7 use a synthetic rulebook: `ExtractedPassage` values built in the test (tests may build locators by hand). Scenario 8 imports a synthetic PDF. Scenario 9 is manual.

### Scenario 1: AND semantics

Given passages 0 "A road ends at a city.", 1 "A road crosses a field.", 2 "The city scores two points."
When the query is "road city"
Then the state is `.matches` with exactly passage 0.

### Scenario 2: case, diacritics and width are folded

Given a passage "Fase de construcción"
When the query is "construccion", "CONSTRUCCIÓN" or "ｃｏｎｓｔｒｕｃｃｉｏｎ" (full-width)
Then each yields that passage.

### Scenario 3: a term matches inside a word

Given the passage of scenario 2
When the query is "constru"
Then it yields that passage.

### Scenario 4: ranking by occurrences, then by ordinal

Given passages 0 "carta y mano", 1 "carta, otra carta", 2 "una carta" and 3 "mano"
When the query is "carta"
Then the matches are in ordinals 1, 0, 2 with occurrence counts 2, 1, 1; the same order comes back on a second call and when the input passages are given in reverse order.
When the query is "carta mano"
Then the matches are 0 (count 2) only.

### Scenario 5: repeated terms count once

Given the passages of scenario 4
When the query is "carta carta"
Then the result equals the result for "carta".

### Scenario 6: an empty query is idle

Given any passages
When the query is "", "   " or "\n\t"
Then the state is `.idle`.

### Scenario 7: a match carries its passage unchanged

Given the passages of scenario 1 with page indexes 0, 0, 3
When the query is "city"
Then each match's `passage` equals the input passage (text, ordinal, locator) and `pageNumber` is `pageIndex + 1` (1 and 4).

### Scenario 8: search over an imported rulebook

Given a game with a two-page synthetic PDF imported through `Library.importRulebook(fileAt:into:store:)` (in-memory container and temporary `RulebookStore`, as in f17's tests), page 2 holding "or at another road"
When `SearchIndex(rulebook:)` searches "another"
Then there is one match with `pageNumber` 2 whose `passage` equals that `Passage`'s `extractedPassage(rulebookID:)`.

### Scenario 9: the screen (manual)

Given Taifa imported on the iPhone 16
When the user types "carretera ciudad" (or another query) in the search field
Then the list shows the matching passages, each with "Page N" and up to three lines of text; clearing the field shows the "Pages" row again.

## Repository Research

### Files Inspected

- `RuleRef/Domain/GameName.swift` — folding: `[.caseInsensitive, .diacriticInsensitive, .widthInsensitive]`, `Locale(identifier: "en_US_POSIX")`.
- `RuleRef/Persistence/Rulebook.swift` (`orderedPassages`), `Passage.swift` (`extractedPassage(rulebookID:)`), `RuleRef/Import/ExtractedPassage.swift`, `RuleRef/Domain/Locator.swift`, `RulebookID.swift` (`init?(hex:)`).
- `RuleRef/Features/Game/GameView.swift`, `GameScreenState.swift`; f19's spec for `GameContent` and the previews.
- `docs/domain-model.md` (Search states, "Search reads passages only", the locator convention), `CONTEXT.md` (Query, Match), `ARCHITECTURE.md` (`Search/` may use `Persistence/` and `Domain/`), `DESIGN.md`.
- `RuleRefTests/Features/Game/GameScreenStateTests.swift` — the in-memory import pattern.

### Existing Patterns To Follow

- Pure types are `nonisolated`, `Equatable`, `Sendable`; anything that reads a `@Model` stays on the main actor.
- User data (passage text) is never a catalog key: `Text` with a `String` value.

### Current Gaps

- f19 is not implemented yet. This spec relies on its `GameContent`/`GameView` split; if names differ, f13 follows the implementation and says so in its evidence.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-16:

- `folding(options:locale:)` (iOS 2+). `searchable(text:placement:prompt:)` with a `LocalizedStringKey` prompt (iOS 15+). `NavigationLink(destination:label:)` is not needed in f13.
- **Not verified**: the catalog key the compiler generates for `Text("Page \(pageNumber)")` with an `Int`; expected `Page %lld`. `catalog-coverage` checks it; if it differs, use the compiler's key and record it. Where the search field appears on iOS 26.0 and 27 (navigation bar or bottom toolbar): manual.

Types in `RuleRef/Search/`, all `nonisolated` unless stated:

1. `SearchFolding.folded(_ text: String) -> String`: the `GameName` options and locale.
2. `Match: Equatable, Sendable, Identifiable`: `passage: ExtractedPassage`, `occurrences: Int`; `id` is `passage.ordinal`; `pageNumber` is the locator's `pageIndex + 1`.
3. `SearchState: Equatable, Sendable`: `idle`, `matches([Match])`.
4. `SearchIndex: Sendable`:
   - `init(passages: [ExtractedPassage])`: sorts by ordinal and folds each text once.
   - `func search(_ query: String) -> SearchState`: fold the query, split on whitespace (`split(whereSeparator: \.isWhitespace)`), drop repeated terms keeping the first. No terms → `.idle`. For each passage and term, count non-overlapping occurrences left to right with `range(of:options: .literal, range:)` on the folded strings; a passage matches only if every term occurs. `occurrences` is the sum over terms. Sort by `occurrences` descending, then `ordinal` ascending.
   - `@MainActor extension SearchIndex { init(rulebook: Rulebook) }`: `rulebook.orderedPassages.map { $0.extractedPassage(rulebookID:) }` with `RulebookID(hex: rulebook.rulebookID)`; if that is `nil` (impossible for an imported rulebook; a comment says so) the index is empty.

Interface (`RuleRef/Features/Game/`):

- `GameContent` gains `query: Binding<String>` and `searchState: SearchState`. In `.ready`: `List` showing, for `.idle`, the existing `LabeledContent("Pages", …)`; for `.matches`, one `MatchRow` per match. `.searchable(text: query, prompt: "Search the rulebook")` is applied only in `.ready`, so a game without a rulebook offers no search (domain model).
- `MatchRow(match: Match)`: a `VStack(alignment: .leading)` with `Text("Page \(match.pageNumber)")` in `.subheadline` and `.secondary`, and the passage text with `.lineLimit(3)`.
- `GameView` (wrapper) gains `@State private var query = ""`. `searchState` is `.idle` without a rulebook, otherwise `SearchIndex(rulebook:).search(query)`, computed in `body`. The index is rebuilt per change; for a rulebook of Taifa's size that is accepted, and caching is out of scope.
- Previews (`#if DEBUG`): `GameContent` adds "Matches" (sample matches). `MatchRow` has "Match". Sample data: `RuleRef/Shared/SampleSearch.swift` (`#if DEBUG`) with three invented English passages (never Taifa text: Taifa lives only in the test target) and their matches.
- Sample passages need hand-built locators. `docs/domain-model.md` gains this as a second exception to "only extraction builds locators": preview sample data inside `#if DEBUG`.

Texts (key → `es`, state `translated`): `Search the rulebook` → `Buscar en el reglamento`; `Page %lld` → `Página %lld`.

## Expected File Changes

- `RuleRef/Search/SearchFolding.swift`, `Match.swift`, `SearchState.swift`, `SearchIndex.swift` — create.
- `RuleRef/Features/Game/MatchRow.swift` — create; `GameContent.swift`, `GameView.swift` — modify.
- `RuleRef/Shared/SampleSearch.swift` — create.
- `RuleRef/Localizable.xcstrings` — modify; two keys.
- `RuleRefTests/Search/SearchIndexTests.swift` (scenarios 1–7), `SearchFoldingTests.swift`, `SearchIndexRulebookTests.swift` (scenario 8) — create.
- `docs/domain-model.md` — modify; the locator exception.
- `feature_list.json` — f19 added to f13's `depends_on` (committed with this spec).

## Visual Design Impact

- UI involved: yes. Design source: `DESIGN.md` (standard search field, list rows, previews per state).
- States: ready idle (Pages row) and ready with matches. No new buttons.
- New design artifact required: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`: not needed — `Search/` is already defined, "arrives with f13".
- `DESIGN.md`, `AGENTS.md`, `CONSTRAINTS.md`: not needed.
- `docs/domain-model.md`: update — the preview exception to the locator convention.

## Implementation Plan

1. Confirm f08 and f19 are accepted; otherwise stop.
2. Write scenarios 1–8 as failing tests; add the `Search/` types.
3. Add `MatchRow`, extend `GameContent` and `GameView`, add `SampleSearch` and the previews, the two keys and the domain-model sentence.
4. `./init.sh`; commit; record evidence and `PROGRESS.md`; commit.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] `SearchFoldingTests` (folded equals `GameName(x).key` for "  Catán " trimmed, "ＣＡＴＡＮ" and "catan"), `SearchIndexTests`, `SearchIndexRulebookTests`.
- [ ] `SearchFolding`, `Match`, `SearchState`, `SearchIndex` and `init(rulebook:)`.
- [ ] `MatchRow`, `GameContent`/`GameView` changes, `SampleSearch`, previews.
- [ ] Two catalog keys with `es`; domain-model sentence; `./init.sh` green; evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0, all checks PASS (`catalog-coverage` with the two keys), 0 failed, 0 skipped.
- Focused run: `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/SearchIndexTests -only-testing:RuleRefTests/SearchFoldingTests -only-testing:RuleRefTests/SearchIndexRulebookTests` → `** TEST SUCCEEDED **`.
- The implementer commits code first and evidence later; the validator reviews the branch: `git diff main...HEAD --stat` lists only the files above plus `feature_list.json` and `PROGRESS.md`; `git diff main...HEAD -- RuleRef/Search/` imports only Foundation, SwiftData where needed, and no SwiftUI or PDFKit (`ARCHITECTURE.md`).
- No UI tests and no E2E. The user checks scenario 9 and the previews.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, code commit, Xcode and simulator; the generated `Page …` key.
- `not_verified`: the interface (scenario 9, search field placement, previews); search speed on a real device; iOS 26.0; rulebooks other than synthetic ones and Taifa.

## Validator Checklist

- [ ] Scenarios 1–8 pass; folding uses exactly `GameName`'s options and locale.
- [ ] AND over whitespace-separated terms, substring match, repeated terms once, rank by occurrences then ordinal; empty query `.idle`.
- [ ] Search reads passages only; no file access, no fuzzy or partial-term fallback, no logging.
- [ ] Search appears only when the game has a rulebook; match rows show page and excerpt, not tappable.
- [ ] Two keys with `es`; previews per `DESIGN.md` with invented sample text; domain-model updated.
- [ ] `feature_list.json` and `PROGRESS.md` updated correctly; the interface is in `not_verified`.
