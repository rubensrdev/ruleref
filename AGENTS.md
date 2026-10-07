# AGENTS.md

RuleRef is an iPhone rulebook referee for board games, plus the harness that builds it.
The harness is the main deliverable; the app is its test bed.

## Start of every session

1. Read `PROGRESS.md` first, then `feature_list.json` once it exists.
2. Read the docs the task needs, using the map in `README.md`.
3. If the auto memory and the repo disagree, the repo wins. Anything durable you learn about the project goes into the repo (`AGENTS.md`, `docs/` or `PROGRESS.md`); the auto memory is only a cache.

## Non-negotiable rules

- Never edit `RuleRef.xcodeproj`. The user configures it in Xcode. If a target, setting, scheme or file membership change is needed, stop and tell the user exactly what to change.
- New files go in the synchronized folders `RuleRef/` and `RuleRefTests/`; they need no project change.
- Swift 6 with complete strict concurrency.
- SwiftUI, no UIKit. Pending exception: the PDFKit page viewer (F15), which gets its own ADR.
- SwiftData for persistence.
- Swift Testing only; no XCTest.
- Codable only; `JSONSerialization` is forbidden.
- Zero third-party dependencies.
- Never use deprecated APIs.
- Deployment target iOS 26.0. Any iOS 27-only API goes behind `#available` with an iOS 26 path.
- Default actor isolation is `MainActor` in both targets. Pure domain logic is marked `nonisolated` explicitly.

## Apple documentation

Before using an Apple API, and whenever a platform question comes up, query the Cupertino MCP (declared in `.mcp.json`) for the most modern API and Apple's recommended practice. If it is unavailable, search developer.apple.com on the web. Never improvise or assume how an API behaves.

## The single command

`./init.sh` is the only definition of "builds and passes". Run it any time without asking.
It checks Xcode 27 and the iPhone 18 Pro / iOS 27.0 simulator, enforces the source rules (no JSONSerialization, UIKit, XCTest, third-party packages or bundled PDFs; complete Spanish translations), builds with warnings as errors, runs the tests and checks that every string the compiler extracts from the app is in the catalog.
The Stop hook runs it automatically at the end of each turn when the code changed.

## Tests

- Test business logic and everything that is not interface. Never UI tests (no XCUITest); the user validates the interface by hand at the end of each phase.
- PDFs for tests are synthetic, generated inside the test with PDFKit.
- No test is ever skipped: if an input is missing, the test fails.
- Taifa 3.0 lives only in the test target, with its attribution file; never in the app.

## Localization

- English is the development language; Spanish is the second language.
- Every visible text is a localizable literal (the key is the English text).
- `xcodebuild` compiles `RuleRef/Localizable.xcstrings` but never adds keys to it; only the Xcode IDE syncs the catalog. Add every new key by hand, with a `translated` Spanish (`es`) value, in the same change as the code.
- `init.sh` enforces it. `string-catalog` requires a translated `es` value for every key that is not stale. `catalog-coverage` replays `xcrun xcstringstool sync` on a temporary copy of the catalog with the current build's `.stringsdata` and fails on any key in code missing from the catalog, or marked stale but used again without a translation. On failure, add the listed keys; the real catalog is never modified by `init.sh`.

## Languages

Speak Spanish with the user. Code, comments, files and commit messages are in English. Comments are brief and only where the decision is not evident.

## Naming

- UPPERCASE only for `AGENTS.md`, `CLAUDE.md`, `PROGRESS.md`, `CONTEXT.md` and `SKILL.md`; lowercase-kebab for everything else.
- Swift files are named after their type.
- Domain terms are the ones in `CONTEXT.md`.

## Git

- The agent does all git operations.
- Conventional Commits; one commit per subtask, on `main`.
- Push asks for permission.
- No attribution lines.
- Never force push or `reset --hard`.

## Documents

- Edit documents with Edit/Write, never with shell heredocs: the commands hook blocks any shell write whose text mentions the Xcode project.
- Update `README.md` only when what it says changes (scope, stack, how to build and test, or the docs map), and keep it short.
- Decisions with consequences go in an ADR in `docs/adr/`.

## Hooks (`.claude/hooks/`)

- `protect-files.sh` (before Write/Edit): blocks edits to the Xcode project, secrets and credentials, `.git` internals, and DerivedData or `.build`.
- `block-dangerous-commands.sh` (before Bash): blocks `rm -rf`, `find -delete`, `chmod 777`, force push, `reset --hard`, `git clean -f`, writes to `.env`, piping downloads into a shell, and any write, copy, move or restore whose command text mentions `pbxproj` or `.xcodeproj`.
- `secrets-commit-guard.sh` (before Bash): on `git commit`, blocks staged secret files and diffs that look like keys or passwords.
- `constitution-lint.sh` (after Write/Edit of `.swift`): warns about `try!`, `as!`, unsafe isolation escapes, GCD, legacy Observation, `NavigationView`, `AnyView`, `JSONSerialization`, UIKit/XCTest, `print()` outside tests and two Xcode 27 pitfalls.
- `stop-build-gate.sh` (on Stop): runs `./init.sh` when non-Markdown files changed since the last green run, and keeps the turn going if it fails.

## Definition of Done

- [ ] `./init.sh` ends in PASS.
- [ ] Tests cover all new logic.
- [ ] New visible texts are in the catalog with their Spanish translation.
- [ ] Docs and `README.md` are up to date if what they say changed.
- [ ] `PROGRESS.md` has an entry with what closed and what comes next.
- [ ] Commits are made.
