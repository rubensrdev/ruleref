# Validations: f06-extract-passages

## Validation 1 — accept — 2026-10-15
- Commit validated: 6669268f02618bde46e57c8f779c22210d6f9acc
- Checks rerun:
  - `./init.sh`: exit 0; all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=37, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/PassageSegmenterTests -only-testing:RuleRefTests/PassageExtractorTests`: `** TEST SUCCEEDED **`.
  - `xcrun xcresulttool get test-results summary` on the focused run's bundle: Passed; totalTestCount 18, passed 18, failed 0, skipped 0, expected failures 0, no runtime warnings; iPhone 18 Pro, iOS 27.0 (24A434).
  - Diff `37516f0..6669268` reviewed against the spec's Validator Checklist (all items met); scenario 3's adjusted layout reviewed and judged a faithful wrap (shift and narrowing `#require`d on PDFKit-measured bounds); Cupertino MCP checked for `PDFPage.selection(for: NSRange)` (raises on zero or out-of-range length; guarded).
- Findings:
  - Info, outside f06: `docs/risks-and-open-questions.md` still lists multi-column extraction as deferred to ADR-002 and geometry vs. Vision reading order as open, although ADR-002 is Accepted (db69cd1). Docs follow-up on `main`.
  - Info: the approved spec says ADR-002 is "not written yet"; it exists and keeps f06 as specified. No conflict.
  - Info: the implementer's evidence context records 04e4342, not 6669268; 6669268 only changes `feature_list.json` and `PROGRESS.md`.
  - Info: the `>=` mutation check was not rerun; the exact-threshold test was confirmed analytically to discriminate (5.0 exact in floating point).
- Not verified:
  - Real rulebooks and the Taifa calibration of the 0.5 ratio (f08).
  - A text wrap whose full-width lines do not span the narrow lines' x range (PDFKit reads it as two columns; implementer's finding).
  - Multi-column layouts; rotated pages; crop box different from the media box.
  - iOS 26 SDK isolation of `PDFDocument`, `PDFPage`, `PDFSelection`.
  - iOS 26.0, a physical device, a fresh clone or clean DerivedData.
  - The `>=` mutation check (analytical only).
