# Feature Implementation Spec: Explicit no-match state

## Source Feature

- `id`: f14-no-match-state
- `area`: search
- `depends_on`: f13-text-search
- `status`: not_started
- `source`: `feature_list.json`

## Goal

When no passage contains every term of a non-empty query, search returns the explicit no-match state instead of an empty list of matches, and the game screen shows the standard search-unavailable view naming the query. Nothing approximate replaces it: no partial-term, fuzzy or "did you mean" results. This is how RuleRef says "the rulebook doesn't mention it" (`CONTEXT.md`, No-match state).

## Non-Goals

- Any change to how matches are found or ranked (f13).
- Suggestions, spelling correction, partial-term fallback, AI answers or abstention (after m4).
- Opening matches (f15); the baseline measurement of no-match accuracy (f16).

## Job Story

When I search for something the rulebook does not cover,
I want to be told plainly that nothing matches,
so I can stop looking and settle the dispute another way.

## Users And Permissions

- Unchanged: one on-device user.

## Acceptance Scenarios

Scenarios 1–4 use the synthetic passages of f13's `SearchIndexTests` (0 "A road ends at a city.", 1 "A road crosses a field.", 2 "The city scores two points."). Scenario 5 is manual.

### Scenario 1: an absent term

Given the passages
When the query is "dragon"
Then the state is `.noMatch` and its `matches` is empty.

### Scenario 2: one term present, one absent

Given the passages
When the query is "road dragon"
Then the state is `.noMatch`: passages with only "road" are never returned.

### Scenario 3: no approximate matching

Given the passages
When the query is "roads" or "citty"
Then the state is `.noMatch` (no stemming, no fuzzy match).

### Scenario 4: idle and matches are unchanged

Given the passages
When the query is "   "
Then the state is `.idle`, not `.noMatch`, and `matches` is empty.
When the query is "road"
Then the state is `.matches` with passages 0 and 1, as in f13.

### Scenario 5: the screen (manual)

Given Taifa imported on the iPhone 16
When the user searches a term that is not in the rulebook
Then the screen shows the system "no results" view with the query, and no list rows.

## Repository Research

### Files Inspected

- f13's spec: `SearchState` (`idle`, `matches([Match])`), `SearchIndex.search(_:)` returning `.matches([])` for zero hits until f14, `GameContent` with `query`/`searchState`, `MatchRow`, the "Matches" preview, `SampleSearch`.
- `docs/domain-model.md` (Search: `idle` → `matches` or `noMatch`; whitespace-only query is `idle`), `CONTEXT.md` (No-match state), `DESIGN.md` (empty states are `ContentUnavailableView` with a symbol; a named preview per state).
- `docs/build-brief.md` (F14 row).

### Existing Patterns To Follow

- `ContentUnavailableView` for empty states (`LibraryView`, `GameContent`).
- State enums are `nonisolated`, `Equatable`, `Sendable`.

### Current Gaps

- f13 is not implemented yet; this spec relies on the names its spec defines. If they differ, f14 follows the implementation and says so in its evidence.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-16:

- `ContentUnavailableView.search(text:)` (iOS 17.0+): "Creates a `ContentUnavailableView` instance that conveys a search state", with the query. `ContentUnavailableView.search` (iOS 17.0+) is the variant without text. Their texts and symbol are the system's, so they add no catalog keys.
- **Not verified**: the exact wording and symbol the system shows, in English and Spanish, on iOS 26.0 and 27 (manual).

Changes:

1. `SearchState` gains `case noMatch` and `var matches: [Match]` (the list for `.matches`, empty for `.idle` and `.noMatch`).
2. `SearchIndex.search(_:)`: with at least one term and zero matching passages, return `.noMatch` instead of `.matches([])`. `.matches` is never empty after this change. Nothing else in the algorithm changes.
3. `GameContent`, `.ready`: for `.noMatch`, show `ContentUnavailableView.search(text: query.wrappedValue)` instead of the list rows, keeping `.searchable` so the user can edit the query.
4. Preview "No Match" on `GameContent` (`#if DEBUG`), with `.noMatch` and a sample query.

Test files: scenarios 1–4 go in a new `RuleRefTests/Search/NoMatchTests.swift`. No f13 test changes (f13 does not test the zero-match case).

## Expected File Changes

- `RuleRef/Search/SearchState.swift`, `SearchIndex.swift` — modify.
- `RuleRef/Features/Game/GameContent.swift` — modify; the `.noMatch` branch and the preview.
- `RuleRefTests/Search/NoMatchTests.swift` — create.
- No catalog change.

## Visual Design Impact

- UI involved: yes. Design source: `DESIGN.md`; the system search-unavailable view.
- States: ready with no match.
- New design artifact required: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `DESIGN.md`, `AGENTS.md`, `CONSTRAINTS.md`: not needed.
- Other docs: none; the domain model already defines `noMatch`.

## Implementation Plan

1. Confirm f13 is accepted; otherwise stop.
2. Write `NoMatchTests` (scenarios 1–4), failing.
3. Add `.noMatch` and `matches`; return it from `search(_:)`.
4. Add the `GameContent` branch and preview; `./init.sh`; commit; evidence and `PROGRESS.md`; commit.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] `NoMatchTests` for scenarios 1–4.
- [ ] `SearchState.noMatch`, `SearchState.matches`, `search(_:)` change.
- [ ] `GameContent` `.noMatch` branch with `ContentUnavailableView.search(text:)`; "No Match" preview.
- [ ] `./init.sh` green; evidence and `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0, all checks PASS, 0 failed, 0 skipped.
- Focused run: `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/NoMatchTests -only-testing:RuleRefTests/SearchIndexTests -only-testing:RuleRefTests/SearchIndexRulebookTests` → `** TEST SUCCEEDED **`.
- The implementer commits code first and evidence later; the validator reviews the branch: `git diff main...HEAD --stat` lists only the files above plus `feature_list.json` and `PROGRESS.md`; `git diff main...HEAD -- RuleRefTests/` adds only `NoMatchTests.swift`; `git diff main...HEAD -- RuleRef/Search/SearchIndex.swift` changes only the zero-match return.
- No UI tests and no E2E. The user checks scenario 5 and the preview.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, code commit, Xcode and simulator.
- `not_verified`: the interface (scenario 5 and the "No Match" preview), the system texts in Spanish, iOS 26.0.

## Validator Checklist

- [ ] Scenarios 1–4 pass; `.noMatch` only for a non-empty query with zero matches; whitespace stays `.idle`.
- [ ] No approximate, partial-term or fuzzy fallback anywhere.
- [ ] The screen uses `ContentUnavailableView.search(text:)`; no custom empty view, no new keys.
- [ ] f13 tests unchanged; `feature_list.json` and `PROGRESS.md` updated correctly; the interface is in `not_verified`.
