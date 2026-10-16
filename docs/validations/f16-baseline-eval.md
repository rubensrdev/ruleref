# Validations: f16-baseline-eval

## Validation 1 — accept — 2026-10-16
- Commit validated: 31b1521 (code 8cf7ec8, report 675ea11, base main 35f85c9)
- Checks rerun: `./init.sh` exit 0, all 11 checks PASS (130 tests, 0 failed, 0 skipped, 0 expected failures); focused `xcodebuild test -only-testing:RuleRefTests/BaselineEvalTests -only-testing:RuleRefTests/EvalSetTests -only-testing:RuleRefTests/BaselineReportTests` TEST SUCCEEDED (21 tests, 31 runs, `taifaBaseline()` 0.110 s); `xcrun xcresulttool get test-results activities` shows exactly one attachment `f16-baseline-taifa-3.0.json`; its payload printed with `xcresulttool get object --legacy` equals the committed `docs/eval/f16-baseline-taifa-3.0.json` field by field; summary recomputed from the 25 rows: hit@1 3/21, hit@3 4/21, no-match 3/4; `git diff main...HEAD -- RuleRef/ init.sh RuleRefTests/Fixtures/ RuleRef.xcodeproj` empty.
- Findings:
  - Note: no test exercises the SHA-mismatch path; it is a `#require` with a message, listed in `not_verified`. No change required.
  - Note: the implementer's evidence entry names commit 675ea11; HEAD 31b1521 only adds evidence and `PROGRESS.md`.
  - Note: the spec's task checkboxes stay unchecked because the approved spec must not be edited.
  - Info: security checklist found nothing relevant; test-only change, temporary files removed in a `defer`.
- Not verified: byte-for-byte identity of the attachment and the committed report (no hash or export allowed to the validator; compared field by field); the SHA-mismatch failure path; a missing PDF or eval set during the actual baseline run; iOS 26.0 and a physical device; rulebooks other than Taifa 3.0; a fresh clone with clean DerivedData; search determinism beyond two runs.
- User: confirmed
