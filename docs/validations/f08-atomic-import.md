# Validations: f08-atomic-import

## Validation 1 — accept — 2026-10-15
- Commit validated: fc770abee3103a4229b7b896006463365b0de9a9
- Checks rerun:
  - `./init.sh`: exit 0; all 11 checks PASS (`no-pdf-in-app` included); `init.sh: PASS`; test-results `totalTestCount=62, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/RulebookStoreTests -only-testing:RuleRefTests/ImportTests -only-testing:RuleRefTests/TaifaImportTests -quiet`: exit 0; 17 tests (26 test-case runs) passed.
  - `git diff 7b644af...fc770ab -- RuleRef/Game.swift RuleRef/RulebookID.swift RuleRef/RuleRefApp.swift`: only the declared changes; `PassageSegmenter.swift`, `PassageExtractor.swift`, the f02/f03 test files, `ContentView.swift` and `GameView.swift` unchanged.
  - Full diff `7b644af..fc770ab` reviewed against the spec's Validator Checklist (all items met); Cupertino MCP checked for `FetchDescriptor.includePendingChanges` (default `true`).
- Findings:
  - Info, carry into f11: when the same PDF is in two games, a failed save's `removeFile` deletes the file the first game uses; f11 must refuse with `.alreadyImported` before `store.write`.
  - Low: `saveFailureRollsBackAndRemovesTheFile()` does not assert that the file was written before it was removed (`storedFiles()` is `[]` for a missing or empty directory); optional fix: assert `store.baseDirectory` exists.
  - Info: the `game.rulebook` re-check after the `await` has no test (code only).
  - Info: cascade delete rules are declared but untested (deletion is f04/f12).
  - Info: scenario 4 asserts the source PDF is the only `.pdf` in the temporary directory; a reasonable reading.
  - Not a defect: `ContentView`'s `#Preview` keeps `.modelContainer(for: Game.self, inMemory: true)`; `ContentView` is outside the declared changes and the unchanged `for: Game.self` test containers pass. Align it in f17.
  - Workarounds judged sound: `fetch(...).count` (with `includePendingChanges` true) is at least as strong as `fetchCount`; `#expect(throws:)` still asserts the exact error.
- Not verified:
  - The `game.rulebook` re-check after the `await`; runtime cascade deletes.
  - Save failures other than a read-only store; `removeFile` failing during rollback; that the file was written before removal in the save-failure test.
  - Taifa's per-page passage counts (attachment not exported by the validator); only `pageCount == 16`, non-empty passages and stored bytes are asserted.
  - `ContentView` preview rendering.
  - Import from a picked file with security-scoped access (f17); persistence across launches with the on-disk store and `RulebookStore.app` in the real sandbox.
  - iOS 26.0, a physical device, a fresh clone or clean DerivedData; the Xcode build number.
