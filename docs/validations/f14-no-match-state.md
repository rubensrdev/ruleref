# Validations: f14-no-match-state

## Validation 1 — accept — 2026-10-16
- Commit validated: babe1cc (code 449ef36, base main 9d1eadd)
- Checks rerun: `./init.sh` exit 0, all 11 checks PASS (105 tests = 101 + 4 new, 0 failed, 0 skipped, 0 expected failures); focused `xcodebuild test -only-testing:RuleRefTests/NoMatchTests -only-testing:RuleRefTests/SearchIndexTests -only-testing:RuleRefTests/SearchIndexRulebookTests` TEST SUCCEEDED (17 of 17 test-case runs); `git diff main...HEAD --stat` only `SearchState.swift`, `SearchIndex.swift`, `GameContent.swift`, `NoMatchTests.swift` (new), `feature_list.json`, `PROGRESS.md`; `git diff main...HEAD -- RuleRefTests/` adds only `NoMatchTests.swift`; `SearchIndex.swift` diff is the single zero-match return; no catalog or doc changes; `git diff 449ef36 babe1cc --stat` only `PROGRESS.md` and `feature_list.json`.
- Findings:
  - Info: deviation accepted: `ContentUnavailableView.search(text:)` is an `.overlay` on the `List` (no rows for `.noMatch`, `.searchable` kept) instead of replacing the list; it meets item 3 and scenario 5 and is the pattern Apple's `ContentUnavailableView` documentation shows (Cupertino MCP).
  - Info: `.noMatch` is handled in two places in `GameContent` (the switch's `EmptyView()` and the overlay); correct, no change required.
  - Info: security checklist found nothing relevant.
- Not verified: scenario 5 (Taifa on the iPhone 16, a term not in the rulebook); the "No Match" preview opened in Xcode; the system wording and symbol in English and Spanish; search-field focus and the overlay while typing moves between matches and no match; the implementer's mutation check (not rerun; reasoned from the assertions); iOS 26.0, a physical device, a Release build; a fresh clone with clean DerivedData.
