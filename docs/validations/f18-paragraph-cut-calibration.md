# Validations: f18-paragraph-cut-calibration

## Validation 1 — accept — 2026-10-16
- Commit validated: 8f68b61 (code 072c1ad, spec revision 0b07d84, base main c001c18)
- Checks rerun: `./init.sh` exit 0, all 11 checks PASS (91 tests = 85 + 6 new, 0 failed, 0 skipped); focused `xcodebuild test -only-testing:RuleRefTests/TaifaSegmentationTests -only-testing:RuleRefTests/PassageSegmenterTests -only-testing:RuleRefTests/PassageExtractorTests -only-testing:RuleRefTests/HyphenationExtractionTests` TEST SUCCEEDED (26 passed, 0 failed, 0 skipped); `git diff main...HEAD` stat, `RuleRef/` (only `PassageSegmenter.swift`) and the changed tests read; `git diff 4c22ea6 8f68b61` on `TaifaSegmentationTests.swift` leaves `taifaGapMeasurement` unchanged; `git show --stat` per commit (code and evidence in separate commits, spec only in 0b07d84).
- Findings:
  - Note: the two exact-threshold tests use line height 25 instead of 10 so that 0.03 × height is exact; the spec allows changing the height, and the guard is kept.
  - Note: `bulletLineStartsANewPassage` adds a check that a bullet after leading whitespace cuts; an extra assertion of the spec's own rule.
  - Note: table rows on pages 2 and 11 (gaps 0.279, header 0.462) were left out of maxInside, so each row is now its own passage; the spec does not classify table rows, the re-approved stop measurement already left them out, and it is in `not_verified`. For the user to know.
  - Note: the spec file appears in the branch diff from the orchestrator's revision 0b07d84; expected.
  - Note: in `ignoredLinesWhitespaceLineDoesNotAffectTheMedian` the blank line's `minY` became `second.bounds.maxY - 20`, a follow-on of the declared gap change; no assertion changed.
  - Info: security checklist found nothing relevant.
- Not verified: the measured values in `taifa-gaps.txt` and `taifa-passages.txt` (maxInside −0.017, minBetween 0.069, 221 passages, pages 3, 5 and 12, the 20 bullet lines), only checked through the scenario tests since the validator cannot export attachments; that leaving out table rows and page 16 is the right classification; the implementer's mutation checks; iOS 26.0 and a physical device; other rulebooks; how matches look in the app (no search yet); rulebooks imported before f18 keep their old passages; a fresh clone with clean DerivedData; the exact Xcode build number; a separate `TaifaImportTests` run.
- User: confirmed
