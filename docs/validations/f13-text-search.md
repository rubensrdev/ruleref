# Validations: f13-text-search

## Validation 1 — accept — 2026-10-16
- Commit validated: 5106583 (code dfbf8e8, base main cfc729a)
- Checks rerun: `./init.sh` exit 0, all 11 checks PASS (101 tests = 92 + 9 new, 0 failed, 0 skipped, 0 expected failures); focused `xcodebuild test -only-testing:RuleRefTests/SearchIndexTests -only-testing:RuleRefTests/SearchFoldingTests -only-testing:RuleRefTests/SearchIndexRulebookTests` TEST SUCCEEDED (15 of 15 test-case runs); `git diff --stat main...HEAD` 15 files, the spec's list plus `feature_list.json` and `PROGRESS.md`; full `git diff main...HEAD` read, `RuleRef/Search/` imports Foundation only; `GameName.swift` read to confirm identical folding options and locale.
- Findings:
  - Low: `RuleRef/Persistence/Passage.swift` still calls `extractedPassage(rulebookID:)` "the one exception to 'only extraction builds locators'", while `docs/domain-model.md` now lists two; outside the spec's files, cosmetic.
  - Low: `ARCHITECTURE.md`'s `Search/` row lists `Persistence/` and `Domain/` but search uses `ExtractedPassage` from `Import/`; the spec requires it and the general layering rule allows it.
  - Low: ADR-003 says a new locator variant should not touch search, but `Match.pageNumber` switches over every `Locator` case; the approved spec asked for it; matters only if a second import source arrives after m4.
  - Info: `SearchFolding` repeats `GameName`'s options instead of sharing them (`GameName.swift` is not in the spec's files); `SearchFoldingTests` checks they agree.
  - Info: security checklist found nothing relevant.
- Not verified: scenario 9 (Taifa on the iPhone 16 in English and Spanish); where the search field appears on iOS 26.0 and 27; the previews (`GameContent` Empty, Importing, Ready, Matches, Import Failed; `MatchRow` "Match"; `GameView` "Game"); search speed on a device with the index rebuilt per body evaluation; iOS 26.0, a physical device, a Release build; rulebooks other than synthetic ones (no test searches Taifa); a fresh clone with clean DerivedData; the implementer's mutation check and `plutil` read of the `Page %lld` key (catalog-coverage is indirect evidence); the exact Xcode build number.
- User: confirmed
