# Validations: f05-rulebook-id

## Validation 1 — accept — 2026-10-15
- Commit validated: e95c9d78ab588969234a533e03a05e2f6c1a37d3
- Checks rerun:
  - `./init.sh`: all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=19, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/RulebookIDTests`: `** TEST SUCCEEDED **`; 9 test runs passed (`sameBytesGiveTheSameID()`, `oneChangedByteGivesADifferentID()`, `knownVectorForABC()`, `emptyInputGivesTheKnownVector()`, `hexIs64LowercaseHexCharacters(bytes:)` ×5).
  - Diff `a89cb9e..e95c9d7` reviewed against the spec's Validator Checklist (all items met); Cupertino MCP checked for CryptoKit `SHA256.hash(data:)`.
- Findings:
  - Info: the implementer's uppercase-hex mutation check was not reproduced; the exact lowercase vectors and the `[0-9a-f]` assertions were confirmed in the tests.
  - Info: `PROGRESS.md` notes that `block-dangerous-commands.sh` blocks a shell write in any command that also mentions the Xcode project, even for a Swift file. Outside f05's scope; a possible harness follow-up for the user to decide.
- Not verified:
  - The mutation check (judged on inspection of the assertions only).
  - Hashing of real files and large inputs (f08); the largest tested input is 4096 bytes.
  - iOS 26.0 and a physical device.
  - A fresh clone or clean DerivedData.
  - Xcode and simulator runtime build numbers (not checked independently).
