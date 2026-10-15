# Validations: f03-list-games

## Validation 1 — accept — 2026-10-15
- Commit validated: dc7809d4fc2a71329f621be9cab0dbb039468bc1
- Checks rerun:
  - `./init.sh`: exit 0, no retry; all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=14, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/LibraryGamesTests`: `** TEST SUCCEEDED **`; `alphabeticalOrder()`, `emptyLibrary()` and `orderAfterCreating()` passed.
  - `xcrun xcresulttool get test-results summary` on the focused run's bundle: Passed; totalTestCount 3, passed 3, failed 0, skipped 0, expected failures 0, no runtime warnings; iPhone 18 Pro, iOS 27.0 (24A434).
  - Diff `331fa2a..dc7809d` reviewed against the spec's Validator Checklist (all items met); Cupertino MCP checked for `Query.init(_:transaction:)` and `ToolbarItemPlacement.primaryAction` (current, not deprecated).
- Findings:
  - Info: the approved spec's Non-Goals assign import and the `ready` state to f08; `GameView`'s comment and `PROGRESS.md` assign them to f17, following the f08/f17 split recorded in `feature_list.json` on 2026-10-13. Behavior is the same; only the spec's wording is out of date, and only the user can change it.
  - Info: the implementer's mutation check (no sort fails scenarios 1 and 3) was not reproduced; the `nameKey` key path was confirmed in code.
- Not verified:
  - Scenario 4: list, empty state, "New Game" toolbar button opening `NewGameSheet`, `GameView` and navigating back (manual by design).
  - The mutation check; the `nameKey` key path is checked in code only, since the scenario names sort the same way by `name`.
  - Order for non-Latin names and names starting with digits or punctuation; how the store applies `.localizedStandard` beyond the tested names.
  - That the SF Symbols `books.vertical` and `book.closed` exist.
  - Spanish rendering on screen.
  - `init.sh`'s own result bundle (deleted on a green run); exact Xcode build number.
  - iOS 26.0, a physical device, a fresh clone or clean DerivedData.
