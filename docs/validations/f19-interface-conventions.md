# Validations: f19-interface-conventions

## Validation 1 — accept — 2026-10-16
- Commit validated: d34d5a4 (code 8d1eda6, base main ae8aa0f)
- Checks rerun: `./init.sh` exit 0, all 11 checks PASS (92 tests = 91 + 1 new, 0 failed, 0 skipped); focused `xcodebuild test -only-testing:RuleRefTests/NewGameFailureTests -only-testing:RuleRefTests/GameScreenStateTests -only-testing:RuleRefTests/LibraryTests` TEST SUCCEEDED (8 test-case runs, including `sheetFailureMappingIsUnchanged()`); `git diff -M --stat main...HEAD` limited to the spec's files plus `feature_list.json` and `PROGRESS.md`, `ContentView.swift` → `LibraryView.swift` (R078), only test change the new `NewGameFailureTests.swift`; `git ls-files RuleRef RuleRefTests`; `git log -S` for `ContentView`, `"Cancel"`, `"Create"` (none left); every changed view read against `DESIGN.md` and `ARCHITECTURE.md`; Cupertino MCP for `Button.init(role:action:)` (iOS 26.0+) and `PreviewModifier`.
- Findings:
  - Low: `EmptyLibraryPreview` shares one cached in-memory container between "Sheet" and LibraryView "Empty", so a game created in a live "Sheet" preview may show in "Empty" until previews reload; previews only, follows the spec.
  - Info: the GameView "Game" preview can start a real import into the preview sandbox if tapped in a live preview; rendering touches nothing.
  - Info: `NewGameForm` and `GameContent` previews write plain values inline; the spec prescribes them and `DESIGN.md` allows plain values.
  - Info: the footer keeps `.foregroundStyle(.red)` and `LibraryView` is not split, both as the spec decided.
  - Info: the implementer's declared deviations hold (`RuleRefApp.swift` changes one line and keeps its template header; untitled role buttons as the spec says).
  - Info: security checklist found nothing relevant.
- Not verified: scenario 5 (the three screens on the iPhone 16 in English and Spanish); every Xcode preview opened and rendered; how the `.cancel` and `.confirm` role buttons render on iOS 26.0 and 27; whether the alert shows in the "Import Failed" preview; how `plus` and `square.and.arrow.down` render on iOS 26.0; the shared-preview-container effect; a Release build; iOS 26.0 and a physical device; a fresh clone with clean DerivedData; the exact Xcode build number; a plain-text grep for `ContentView` (git pickaxe used instead); the xcresult bundle.
- User: confirmed
