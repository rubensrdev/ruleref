# Validations: f07-join-hyphenation

Spec re-approved on 2026-10-15 (585abfe) after a spec-gap stop on the first implementation run; no earlier validations.

## Validation 1 — accept — 2026-10-15
- Commit validated: bfad10383411354754e6107fd57329b9ba7b1747
- Checks rerun:
  - `./init.sh`: exit 0; all 11 checks PASS; `init.sh: PASS`; test-results `totalTestCount=45, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/PassageTextTests -only-testing:RuleRefTests/HyphenationExtractionTests -only-testing:RuleRefTests/PassageExtractorTests -only-testing:RuleRefTests/PassageSegmenterTests`: `** TEST SUCCEEDED **`.
  - `xcrun xcresulttool get test-results summary` on the focused run's default bundle: Passed; totalTestCount 26, passed 26, failed 0, skipped 0, no runtime warnings; 43 test runs.
  - `git diff e6daeb6...bfad103 -- RuleRefTests/PassageExtractorTests.swift RuleRefTests/PassageSegmenterTests.swift RuleRefTests/SyntheticPDF.swift RuleRef/PassageSegmenter.swift`: only `PassageExtractorTests` changed (three expected texts; scenario 4's line counts from the layouts, plus an index guard).
  - Full diff `e6daeb6..bfad103` reviewed against the spec's Validator Checklist (all items met). The added `#require(passages.count == lineCounts.count)` and the hand-typed `[2, 2]` judged within the spec's allowed change.
- Findings:
  - Info N1: `[2, 2]` is a literal for the inline continued layout; a drift fails loudly.
  - Info N2: idempotence is not guaranteed for whitespace followed by a combining mark with no base letter (SE-0221 leaves it undefined); outside the spec's inputs, reasoned only.
  - Info N3: scenario 1's `#require` on `lines[1]`/`lines[2]` repeats the full-equality check; harmless.
  - Info N4: the implementer's evidence context records b00d743; bfad103 only changes `feature_list.json` and `PROGRESS.md`.
- Not verified:
  - How PDFKit reports a drawn U+00AD, U+2010 or U+2011 (string literals only).
  - Real rulebooks and Taifa's hyphenation (f08).
  - Continuation lines starting with whitespace.
  - Idempotence with an orphan combining mark after whitespace (N2).
  - iOS 26.0, a physical device, a fresh clone or clean DerivedData.
  - The implementer's red-first order and the stash apply/drop (validator cannot run `git stash list`).
  - No result bundle at a validator-chosen path (the hook blocks `-resultBundlePath`).
