# Validations: f10-reject-unreadable-file

## Validation 1 — accept — 2026-10-15
- Commit validated: 973726dd490a3c468cb3f5855e0aa8753a888261
- Checks rerun:
  - `./init.sh`: exit 0; all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=71, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/UnreadableFileImportTests -only-testing:RuleRefTests/ImportTests -only-testing:RuleRefTests/PassageExtractorTests -only-testing:RuleRefTests/NoTextLayerImportTests`: `** TEST SUCCEEDED **`.
  - `xcrun xcresulttool get test-results summary` on the focused run's default bundle: Passed; totalTestCount 24, passed 24, failed 0, skipped 0, no runtime warnings; iPhone 18 Pro, iOS 27.0 (24A434). Scenarios 1–5 (`userPasswordLocked`, `ownerPasswordOnlyImports`, `corruptFileUnreadable`, `distinctErrors`, `gameCanImportAfterARejection`) and f08's `bytesThatAreNotAPDF` and `missingFileIsUnreadable` passed.
  - `git diff --stat c071af7..973726d` and `git diff c071af7..973726d -- RuleRef/ImportError.swift RuleRef/RulebookPreparer.swift RuleRefTests/SyntheticPDF.swift docs/domain-model.md`: only the declared files; only the `locked` case, the `isLocked` check after `PDFDocument(data:)` and before `PassageExtractor.extract` with its comment, and the additive `encryption` parameter.
  - App code touching PDFKit (`RulebookPreparer.swift`, `PassageExtractor.swift`, `Library.swift`) read: no `isEncrypted`, `unlock(withPassword:)` or permission checks. Cupertino MCP checked for `PDFDocument.isLocked`.
  - Full diff reviewed against the spec's Validator Checklist (all items met).
- Findings:
  - Info: the implementer's handoff said scenario 4 checks nothing persisted after each import; the test checks only after both, which is what the spec requires. The recorded evidence does not make the claim. No change needed.
  - Info: the one-line doc comment on `case locked` departs from "Nothing else changes"; judged acceptable (matches the other cases and the f09 precedent).
  - Info: names follow the implementation as the spec allows (`SyntheticPDF.data(pages:)`, `Rulebook.rulebookID` storing the hex); disclosed in the evidence.
- Not verified:
  - Red-first behavior (scenarios 1, 4 and 5 failing without the check); not reproduced by the read-only validator.
  - The exact Xcode build number.
  - Real-world encrypted and damaged rulebooks.
  - Encryption algorithms and key lengths other than Core Graphics' default.
  - PDFs with restrictive permissions beyond owner-only encryption.
  - How the error reaches the user (f17).
  - iOS 26.0, a physical device, a fresh clone or clean DerivedData.
- User: confirmed
