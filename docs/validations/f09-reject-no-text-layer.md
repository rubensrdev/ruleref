# Validations: f09-reject-no-text-layer

## Validation 1 — accept — 2026-10-15
- Commit validated: cdc33addaa9f28043f638086428cc63a7ccfc9ba
- Checks rerun:
  - `./init.sh`: exit 0; all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=66, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/NoTextLayerImportTests -only-testing:RuleRefTests/ImportTests`: `** TEST SUCCEEDED **`.
  - `xcrun xcresulttool get test-results summary` on the focused run's default bundle: Passed; totalTestCount 11, passed 11, failed 0, skipped 0, no runtime warnings; iPhone 18 Pro, iOS 27.0 (24A434).
  - `git diff --stat 0309e36...cdc33ad` and `git diff 0309e36...cdc33ad -- RuleRef/ImportError.swift RuleRef/RulebookPreparer.swift`: only the `noTextLayer` case (with a doc comment), the `passages.isEmpty` check after extraction and before `PreparedRulebook`, its comment, the new test file and the evidence files.
  - Full diff reviewed against the spec's Validator Checklist (all items met).
- Findings:
  - Info: the one-line doc comment on `case noTextLayer` departs from "Nothing else changes" in the spec; judged acceptable (matches the other cases, no behavior change, disclosed in the evidence).
- Not verified:
  - Red-first behavior (confirmed by reading the code only).
  - Real scanned PDFs, including ones with an invisible OCR layer.
  - Encrypted PDFs (may fail as `.noTextLayer` until f10).
  - How the error reaches the user (f17).
  - iOS 26.0, a physical device, a fresh clone or clean DerivedData; the Xcode build number.
  - A repo-wide search for OCR/Vision/UIKit (relied on the feature diff and `init.sh`'s source rules).
