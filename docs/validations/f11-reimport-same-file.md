# Validations: f11-reimport-same-file

## Validation 1 — accept — 2026-10-15
- Commit validated: 7b133555a6e36d9c2f60592ac190ebe9b3bb4d43
- Checks rerun:
  - `./init.sh`: exit 0; all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=78, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/ReimportTests -only-testing:RuleRefTests/ImportTests -only-testing:RuleRefTests/NoTextLayerImportTests -only-testing:RuleRefTests/UnreadableFileImportTests -only-testing:RuleRefTests/TaifaImportTests`: `** TEST SUCCEEDED **`; 24 of 24 passed (Reimport 7, Import 7, NoTextLayer 4, Unreadable 5, Taifa 1).
  - Same project, scheme and destination, `-only-testing:` on `simultaneousImportsIntoTwoGames()` and `simultaneousImportsIntoTheSameGame()` with `-test-iterations 25`: `** TEST SUCCEEDED **`; 50 of 50 executions passed (27 green runs each in total).
  - `git diff 0c417ea..7b13355` reviewed in full: files match the spec's Expected File Changes plus `feature_list.json` and `PROGRESS.md`; existing tests changed only at 3 call sites (`ImportTests.swift:94`, `:113`, `TaifaImportTests.swift:30`, each appending `.rulebook`); no `#expect` or `#require` changed.
  - Cupertino MCP checked for `FetchDescriptor.includePendingChanges` (default `true`, so step (d) sees pending inserts).
  - Full diff reviewed against the spec's Validator Checklist (all items met). The f08 carry-over is closed: `store.write` runs only after the step-(d) check finds no rulebook with that ID, nothing awaits between that check and `save()`, and `removeFile` runs only after this call's own failed save.
- Findings:
  - Info: the doc comment on `ImportError.gameHasRulebook` now reads "nothing was extracted or written" (the old "nothing was read" became false after the reorder); disclosed, acceptable.
  - Info: the test-private `Summary` in scenarios 6–7 carries the rulebook's `PersistentIdentifier` to check "the same rulebook"; disclosed, strengthens the test, acceptable.
  - Info: names follow the implementation as the spec allows; disclosed, acceptable.
  - Low: scenario 1's unchanged modification date proves "no rewrite" only if every atomic rewrite changes the timestamp; the byte check and the no-op code path make it moot in practice; in `not_verified`.
  - Low: scenarios 6 and 7 do not prove whether step (d) or step (b) caught the loser (stated in the spec); 27 green runs each.
  - Info: a game with a rulebook given unreadable bytes now gets `.unreadable` instead of `.gameHasRulebook`; stated in the spec and `PROGRESS.md`; no earlier test depends on it.
- Not verified:
  - The implementer's step-(d) mutation run (validator is read-only); which check caught the loser in scenarios 6 and 7.
  - That every atomic rewrite changes the file's modification date.
  - The fetch-error → `.storage` and rulebook-without-game → `.storage` paths.
  - Imports from a second `ModelContext` or container over the same store (uniqueness relies on main-actor serialization over one context).
  - A persistent on-disk store across launches; a real file picked twice (f17).
  - iOS 26.0, a physical device, a fresh clone or clean DerivedData; the Xcode build number.
- User: confirmed
