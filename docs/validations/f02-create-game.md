# Validations: f02-create-game

## Validation 1 — accept — 2026-10-14
- Commit validated: 0fa26f41025fa4354da86a2f9d3ad5ac85888dbe
- Checks rerun:
  - `./init.sh`: exit 0, no retry; all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=10, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/GameNameTests -only-testing:RuleRefTests/LibraryTests`: `** TEST SUCCEEDED **`.
  - `xcrun xcresulttool get test-results summary` on the focused run's bundle: Passed; totalTestCount 9, 12 test runs passed, 0 failed, 0 skipped, 0 expected failures, no runtime warnings; iPhone 18 Pro, iOS 27.0 (24A434).
  - Diff `6983f83..0fa26f4` reviewed; Cupertino MCP checked for `FetchDescriptor.includePendingChanges` (default `true`).
- Findings:
  - Info: the extra save-failure message in `NewGameSheet` ("The game could not be saved.", translated) is acceptable under the spec.
  - Low, not blocking: F1, if `save()` throws, `Library` leaves the inserted `Game` unsaved in the context, so a retry reports a duplicate and autosave may store it later; follow-up: remove or roll back the insert before rethrowing.
  - Info: scenarios 1–3 count games in the store, not unsaved inserts, so they would not catch a regression that inserts and then throws.
  - Info: the rest of the code is clean (`en_US_POSIX` folding, no deprecated or iOS 27-only APIs, in-memory previews, glossary terms).
- Not verified:
  - Scenario 5: root screen and sheet (manual by design).
  - The save-failure path and F1 (no test forces `save()` to fail).
  - Spanish rendering on screen.
  - Persistence across launches with the on-disk store.
  - iOS 26.0 and a physical device.
  - A fresh clone or clean DerivedData.
  - `init.sh`'s own result bundle (deleted on a green run).
  - Exact Xcode build number and time of day.
  - That the tests failed before the implementation existed.
