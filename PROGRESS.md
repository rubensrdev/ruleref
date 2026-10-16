# Progress

One entry per work session, oldest first. Each entry says what closed and what comes next.

## 2026-10-06 — T0: demo rulebook and device
- Rulebook: Taifa 3.0 (printandplay.games, 16 pp., Spanish), CC BY-NC-SA; imported on camera, never bundled.
- Layout: single-column body with a text layer; text wraps around images on pp. 3 and 12; line-break hyphenation present.
- Eval ground truth comes from the 3.0 PDF; the official FAQ covers v2.0 and is used only as a source of hard questions.
- Demo device: iPhone 16 (standard on-device model on iOS 27, not the 12 GB one).
- Next: P1, adapt the build-brief skill.

## 2026-10-06 — T1: build brief
- P1: build-brief skill adapted to the closed stack; installed in .agents/skills with a .claude/skills symlink.
- Brief written: CONTEXT.md, docs/build-brief.md, docs/domain-model.md, docs/risks-and-open-questions.md, ADR-003 (scope cut).
- All six open decisions closed; multi-column deferred to ADR-002 (T3). UI in Spanish and English via String Catalog. No UI tests: the user validates the interface manually at the end of each phase.
- Features by task: T2 F01; T3 F02, F03, F05–F11; T4 F13–F15; after m4 F04, F12, F16.
- Next: P2, hand-off for T2 (minimal harness).

## 2026-10-07 — P2, T2.0–T2.2
- P2 closed: the user creates and configures the Xcode project; the agent never edits project.pbxproj; the agent edits the String Catalog; no global hooks; T2 split into subtasks, one per commit.
- T2.0: hooks and permissions copied from the user's kit with patches (commits 4d4c7f9 and 08c2944); commit attribution disabled.
- T2.1: Xcode project created by hand with synchronized folders, shared scheme with an autocreated test plan, iPhone only in portrait, iOS 26.0, Swift 6 with complete concurrency checking, MainActor default isolation, English as development language and Spanish added.
- T2.2: .gitignore tracked again.
- Next: T2.3, init.sh and F01.

## 2026-10-07 — T2.3–T2.4
- `init.sh` is the single gate. Checks: Xcode 27, simulator, no JSONSerialization, no UIKit/XCTest imports, no third-party dependencies, no PDFs in the app, string catalog (exists, with Spanish translations), `xcodebuild test` with warnings as errors, test results, catalog-coverage.
- F01 delivered: app and tests build and pass by CLI. `./init.sh` is green in a clean clone.
- Finding: the CLI build never extracts keys into `Localizable.xcstrings`. catalog-coverage replays `xcstringstool sync` on a copy with the current build's `.stringsdata`. It fails on code strings missing from the catalog, and on stale keys used again without a translation.
- The auto memory is kept as a cache only; the repo is the source of truth.
- Cupertino MCP declared in `.mcp.json` and allowed; pencil denied for this project.
- `AGENTS.md` and `CLAUDE.md` created.
- Next: T2.5, `feature_list.json`.

## 2026-10-07 — T2.5
- `feature_list.json` adopts the course format (harness-starter), with richer evidence: each entry has `command`, `expected`, `observed`, `context` (date, commit, Xcode, simulator) and `not_verified`.
- The 16 features of the build brief, in order, with their dependencies: f02, f05 and f06 depend on f01; f03 on f02; f07 on f06; f08 on f02, f05 and f06; f04 on f02 and f08; f09–f13 on f08; f14 and f15 on f13; f16 on f13 and f14.
- New `feature-list` check in `init.sh` (rules phase): fields, id format, unique ids, allowed status, at most one `in_progress`, known dependencies without self-references or cycles, dependencies `accepted` before work starts, complete evidence for `passing` and `accepted`.
- `AGENTS.md` gains the scope and feature-list sections.
- f01 is `passing` with evidence from a clean clone at aaf46dd, awaiting the T3 validator.
- Next: T2.6, T2 exit criteria and tag `m3`.

## 2026-10-07 — T2.6, T2 closed
- Exit criterion 1 met: a new session with the auto memory disabled (`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`) rebuilt the project state from the repo alone. It found that the T2 exit criteria were not written down, so `AGENTS.md` now requires every "Next" line to state what comes next and its "done when" criterion.
- Exit criterion 2 met: a `JSONSerialization` call planted in `RuleRef/GateProbe.swift` was flagged by constitution-lint on write, and the Stop hook blocked the end of the turn because `./init.sh` failed in the rules phase, before building. After the file was deleted, `./init.sh` was green.
- Known gate limitation: after a block, Claude Code does not run the Stop hooks again in the same turn (`stop_hook_active`), so a failed fix could end that turn. The gate records green only when it runs `init.sh` itself, so the next turn checks again. Worst case: one turn of delay.
- Tag `m3`: minimal harness.
- Next: T3, install the loop (feature-flow skill, implementer and validator subagents, Xcode MCP integration) and run it on the T3 features. Done when: ADR-002 (multi-column extraction) exists; a write attempt by the validator is blocked; the validator accepts f01 with evidence; the loop is launched on the T3 features.

## 2026-10-07 — P3.1–P3.7a: the feature loop
- Only the orchestrating main session sets `accepted`, after the validator returns `accept` and the user confirms in the chat. At most 3 `revise` verdicts per approved spec, counted from its Approval date; after the third, `stop` and `blocked`. A `blocked` note says whether it came from a `block` verdict or a `stop`.
- feature-validator: course skill vendored verbatim from harness-starter at 18b19e6 with its MIT license. Read-only subagent (no Edit, Write or NotebookEdit; opus; 40 turns); its Bash goes through `validator-readonly-bash.sh`.
- feature-implementer: own skill (repair brief: reproducing test first, then the fix; two commits per feature, code then evidence). Subagent without Agent or Skill (opus; 100 turns); `implementer-no-accept.sh` blocks setting `accepted`.
- Specs are approved only by the user, by hand, with the `Approval:` line. `spec-approval-guard.sh` blocks any agent from adding it or editing an approved spec, and blocks non-git Bash on `docs/specs/`.
- feature-flow: orchestrator skill, run only with `/feature-flow [feature-id]` and only interactively. It delegates through the Agent tool without passing a model and records each verdict in `docs/validations/<feature-id>.md`.
- feature-spec: course skill vendored verbatim at 18b19e6 with its license.
- Hook tests: `.claude/hooks/tests/run-cases.sh`, one cases file per hook; 75 cases (37 + 21 + 17), all passing.
- `AGENTS.md` and `README.md` document the loop. Commits 1959d1f to 7c7c487.
- Not run yet: `.claude/agents/` is a new folder, so the subagents load only after a session restart; the live checks belong to T3.
- Next: P3.7b, fix the next-feature rule in `AGENTS.md` and write the specs for f01 (retroactive) and every T3 feature, reviewed in batches; then P3.8, Xcode MCP read-only integration and the ADR-001 revision. Done when: every T3 spec plus f01's exists in `docs/specs/` and carries the user's Approval line, and P3.8's tools are registered with their hook tests passing.

## 2026-10-08 — P3.7b, part 1: specs for f01, f02 and f05
- `AGENTS.md`: the next feature to start is the first `not_started` feature whose `depends_on` are all `accepted`, as in feature-flow.
- Specs approved by the user: f01 (retroactive; the validator can only rerun `./init.sh`, so the clean-clone evidence goes to `not_verified`), f02 (minimal "New Game" sheet; uniqueness by a stored folded name key checked before insert, no `#Unique` because SwiftData upserts on collision) and f05 (CryptoKit SHA-256).
- Decided: each feature carries its minimal interface; the user validates it by hand at the end of each phase and the validator lists it in `not_verified`. Which features own the game screen and the import action is settled in the f03 and f08 specs.
- Decided: P3 stays on `main`. In T3, right after f01 is accepted and before f02 starts, features move to one branch and one PR each, run one at a time, merged by the user, with no issues.
- Next: P3.7b, specs for f06, then f03, f07, f08, f09, f10 and f11 (f11 with the idempotency scenario); then P3.8, Xcode MCP read-only integration and the ADR-001 revision. Done when: every T3 spec exists in `docs/specs/` and carries the user's Approval line, and P3.8's tools are registered with their hook tests passing.

## 2026-10-13 — P3.7b, part 2: the remaining T3 specs
- Thursday answers from the module 4 Q&A: Foundation Models with the course API as a fallback is valid; adapting the harness is fine; parallel worktrees are not required, so the loop stays sequential (ADR-003) and a worktree trial is left for after m4. The spec-approval and feature-flow questions were settled in the project: the `Approval:` line plays the role of the course planner's `block` until the spec is approved.
- Specs approved by the user: f06 (a new passage on a vertical gap above 0.5 × the page's median line height or on a line above the previous one; a page break always cuts), f03 (sorted on `nameKey` with `.localizedStandard`; f03 owns the minimal game screen), f07 (hyphen and whitespace rules applied inside extraction), f08 (heavy work in a `@concurrent` function, one `save()` on the main actor), f09 (zero passages → `.noTextLayer`), f10 (`.locked` only when the document stays locked after opening), f11 (fingerprint, checks, prepare, checks again, store; `ImportOutcome`) and f17.
- f08 was split: the import action, the file picker and the ready state are the new feature f17-import-action, placed after f11 so every import outcome exists.
- Dependencies tightened in `feature_list.json`: f06 on f05, f08 on f07, f11 on f09 and f10, f17 on f03 and f11.
- f04, f12 and f16 are `blocked` with a `deferred` note until m4, so the next-feature rule never selects them.
- `AGENTS.md`: the Approval line is added only with the user's explicit approval; a `blocked` note can say `deferred`.
- Found: `spec-approval-guard.sh` blocks a command that touches a spec and uses `$(…)`, as a heredoc commit message does; spec commits use an inline message.
- Before T3: the user places `RuleRefTests/Fixtures/taifa-3.0.pdf` and `taifa-3.0-attribution.md`.
- Commits 249c71d to 1ee6186.
- Next: P3.8, Xcode MCP read-only integration and the ADR-001 revision. Done when: its tools are registered at project scope, the hook matchers for its write tools have passing test cases, and ADR-001 records the change.

## 2026-10-14 — P3.8: Xcode MCP, read-only integration
- Xcode 27 serves its MCP server headless (`xcrun mcp-server`; `xcrun mcpbridge` is the stdio bridge). Registered at project scope in `.mcp.json`. The user enabled headless mode and permitted only this repo's folder, by hand.
- The server exposes 54 tools. `.claude/settings.json` classifies all of them: 19 allowed, 22 ask, 13 denied. `xcode-mcp-write-guard.sh` blocks the 13 write tools again, with 25 test cases. Live check: the 13 are not visible to the agent; opening, listing and closing the workspace work without a window.
- The implementer has no Xcode MCP tools; the validator has none. `RenderPreview` is not validation evidence.
- `xcode-mcp` skill added. ADR-001 revised: the gate stays in `./init.sh`. The hook list moved from `AGENTS.md` to `.claude/hooks/README.md`.
- Hook tests: 100 cases (37 + 17 + 21 + 25), all passing.
- Planning assumption: delivery on 2026-10-22, to be confirmed. The 8 Oct git decision stands: from f02 on, one branch and one PR per feature, run one at a time, merged by the user, with no issues and no worktrees (ADR-003). T4 specs are written and reviewed in one round.
- Commits 1a86988 to 7a485f2, plus this one.
- Next: T3. The user places `RuleRefTests/Fixtures/taifa-3.0.pdf` and `taifa-3.0-attribution.md`; a new session loads the subagents; live checks (a validator write is blocked, the implementer cannot set `accepted`); `/feature-flow` on f01 on `main`; then the branch-and-PR step is added to the loop, and each later T3 feature runs on its own branch. Done when: ADR-002 records the multi-column extraction decision after a ~10-minute layout check of the fixture, a validator write attempt is blocked live, f01 is `accepted` with evidence, and every later T3 feature reaches `main` through a PR the user merged.

## 2026-10-14 — T3: f01 accepted
- First live `/feature-flow` run, on branch `feat/f01-cli-build-and-tests`. The validator reran `./init.sh` at a687994 (exit 0, 11 checks PASS, 1 test, none failed or skipped) and returned `accept`; the user confirmed. Record: `docs/validations/f01-cli-build-and-tests.md`. 0 of 3 revise rounds used.
- The validator's evidence entry is appended to f01 in `feature_list.json`; the clean-clone run at aaf46dd stays the only fresh-clone evidence.
- Validator findings (info): `init.sh` uses `python3` without a preflight check; `validator-readonly-bash.sh` blocked a compound read-only git command, which only partly covers the planned live check that a validator write is blocked.
- Still open from the T3 done-when: a validator write attempt blocked live.
- Next: the user merges the f01 PR; then `/feature-flow` on f02-create-game, on its own branch. Done when: f02 is `accepted` and its PR is merged into `main`.

## 2026-10-14 — T3: f02 implemented
- f02-create-game is `passing` on branch `feat/f02-create-game` (code commit 6b0ced1): `GameName` and `GameNameError` (`nonisolated`; trimmed value, key folded for case, diacritics and width with the `en_US_POSIX` locale), `Game` (`@Model`, `name` and `nameKey`, no `#Unique`), `Library.createGame(named:)` (fetch count by key before insert, then save), `NewGameSheet`, a "New Game" button on the root screen and the app's model container.
- `./init.sh` green: 10 tests, 0 failed, 0 skipped. Scenarios 1-4 are covered by `LibraryTests` on one in-memory container per test.
- Beyond the spec's expected keys: the sheet shows "The game could not be saved." when `save()` throws, so a save error is never silent.
- Left: scenario 5 (the sheet) is validated by hand at the end of T3.
- Next: the validator reviews f02 through `/feature-flow`. Done when: f02 is `accepted` and its PR is merged into `main`.

## 2026-10-14 — T3: f02 revise round 1 stopped
- The user rejected the validator's accept and asked to fix F1 (a retry after a failed save reports a duplicate). Round 1 of 3.
- Done (commit 9015b3a): scenarios 1-3 now also count unsaved inserts in the library's context; a mutation that inserts before the duplicate check fails scenarios 2 and 3. `./init.sh` green, 10 tests.
- Reproduced F1 with a real save failure: a store created on disk, then reopened with `ModelConfiguration(url:allowsSave: false)`, makes `save()` throw (Cocoa error 513). An in-memory store cannot be opened read-only.
- Found: the brief's fix (`rollback()` after a failed save, or `delete(game)`) is not enough. After a failed save, the next `fetchCount` that includes pending changes returns a stale 1, and only the following calls return 0. `fetch`, and `fetchCount` with `includePendingChanges = false`, return 0. Without a failed save, rollback and `fetchCount` agree.
- Two fixes pass the reproducing test, both with `rollback()`: (a) the duplicate check sets `includePendingChanges = false`; (b) it uses `fetch` with `fetchLimit = 1` instead of `fetchCount`. Both change the spec's Technical Approach, so the implementer stopped. The red test and the rollback are in git stash "f02 F1 WIP (red)"; f02 is `in_progress`.
- Next: the user picks (a), (b) or another option, and an approved spec revision if needed; then the implementer applies the stash, adds the chosen check and finishes round 1. Done when: `failedSaveLeavesNothingBehind` passes, `./init.sh` is green and f02 is back to `passing` with new evidence.

## 2026-10-14 — T3: f02 revise round 1 finished
- The user picked fix (b) and re-approved the f02 spec (a3ab8fd): the duplicate check uses `fetch` with `fetchLimit = 1`, `createGame(named:)` calls `rollback()` when `save()` throws, and the new scenario 6 says a failed save leaves nothing behind.
- Done (commit 327f27a): the stash "f02 F1 WIP (red)" was applied and dropped; `Library` gets the `fetch` check. `LibraryTests.failedSaveLeavesNothingBehind()` covers scenario 6 on an on-disk store reopened with `allowsSave: false`; it also checks that both attempts throw the same save error, and removes its temporary store.
- Mutation check, not committed: with the old `fetchCount` guard, only scenario 6 fails.
- `./init.sh` green at 327f27a: 11 tests, 0 failed, 0 skipped. f02 is `passing` again.
- Found: when a test fails, `xcodebuild` runs `simctl diagnose`, which can take up to 600 s before the run ends.
- Left: scenario 5 (the sheet) is validated by hand at the end of T3.
- Next: the validator reviews f02 again through `/feature-flow` (revise round 1 of 3 used). Done when: f02 is `accepted` and its PR is merged into `main`.

## 2026-10-14 — T3: f02 accepted
- Validation 2 at f6fb9e6 returned `accept` and the user confirmed. `./init.sh` green (11 tests, 0 failed, 0 skipped); the focused GameNameTests/LibraryTests run passed. F1 resolved. Record: `docs/validations/f02-create-game.md`.
- Process: the user rejected validation 1's accept to fix F1 first; the repair round stopped on a spec decision, the user revised and re-approved the spec, and the next implementation passed. A spec gap is a `stop`, not a verdict.
- Follow-up for f04: `rollback()` after a failed save discards every pending change in the shared main context; revisit when rename leaves unsaved edits.
- Gate notes: the Stop hook's `./init.sh` failed several times while a subagent was mid-change or running its own `xcodebuild` (once with `Terminated: 15`); those runs say nothing about the result. When `xcodebuild` dies without a result bundle, test-results prints a Python traceback instead of a clean FAIL (harness fix pending on `main`).
- Left: scenario 5 (the sheet) is validated by hand at the end of T3.
- Next: the user merges the f02 PR; then the harness fix for the test-results traceback on `main`; then `/feature-flow` on f03-list-games. Done when: f03 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — Harness: test-results fails cleanly; B2b recorded
- Recorded late (B2b, 6983f83, 2026-10-14): `./init.sh` retries `xcodebuild test` once, only when the log shows a simulator launch failure and no `.swift:line:column` location, because two runs that day failed while launching the test host and passed on rerun. Dry-run in five scenarios. A second failure in a row is not retried; if that happens, reset the simulator before the retry (dry-run first).
- Recorded late (B2b): live write probe inside the validator subagent; `echo` and `touch .probe-validator-write` were blocked by `validator-readonly-bash.sh` and no file was created. This closes the T3 done-when item "a validator write attempt blocked live".
- `init.sh`: when `xcodebuild` dies before the result bundle is complete, test-results prints one clear line and fails, instead of a Python `JSONDecodeError` traceback. The exit status is unchanged.
- Next: `/feature-flow` on f03-list-games, on its own branch. Done when: f03 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f03 implemented
- f03-list-games is `passing` on branch `feat/f03-list-games` (code commit cd953e1): `Library.alphabeticalGames` (the one sorted `FetchDescriptor<Game>`, on `nameKey`, `.localizedStandard`, forward) and `Library.games()`; the root screen is the library (`NavigationStack`, `@Query(Library.alphabeticalGames)`, `ContentUnavailableView` when empty, "New Game" moved to the toolbar, navigation by value); `GameView` shows the name and "No Rulebook Yet" with no actions. Four new catalog keys with Spanish values.
- `./init.sh` green: 14 tests, 0 failed, 0 skipped. Scenarios 1-3 are covered by `LibraryGamesTests`; a no-sort mutation fails scenarios 1 and 3.
- f03 owns the minimal game screen; the import action and the ready state stay with f17.
- Left: scenario 4 (list, empty state, game screen) is validated by hand at the end of T3.
- Next: the validator reviews f03 through `/feature-flow`. Done when: f03 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f03 accepted
- Validation 1 at dc7809d returned `accept` and the user confirmed. `./init.sh` green (14 tests, 0 failed, 0 skipped); the focused LibraryGamesTests run passed. Record: `docs/validations/f03-list-games.md`.
- Spec drift for the user: the approved spec's Non-Goals give import and the `ready` state to f08; since the 2026-10-13 split they belong to f17. Behavior is unaffected; only the user can update the spec.
- Left: scenario 4 (list, empty state, game screen) is validated by hand at the end of T3.
- Next: the user merges the f03 PR; then `/feature-flow` on the next dependency-ready feature, f05-rulebook-id. Done when: f05 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f05 implemented
- f05-rulebook-id is `passing` on branch `feat/f05-rulebook-id` (code commit be1109f): `RulebookID` (`nonisolated`, `Hashable`, `Sendable`; `hex` built from the CryptoKit `SHA256.hash(data:)` digest bytes, two lowercase digits per byte, never from `description`).
- `./init.sh` green: 19 tests, 0 failed, 0 skipped. Scenarios 1-4 are covered by `RulebookIDTests`; an uppercase-hex mutation fails scenarios 3 and 4.
- Found: `block-dangerous-commands.sh` blocks a shell write (`sed -i`) in any command that also mentions the Xcode project, even when the file written is a Swift source; mutation checks use Edit, then a separate `xcodebuild` call.
- Left: reading the file and incremental hashing of large files belong to f08.
- Next: the validator reviews f05 through `/feature-flow`. Done when: f05 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f05 accepted
- Validation 1 at e95c9d7 returned `accept` and the user confirmed. `./init.sh` green (19 tests, 0 failed, 0 skipped); the focused RulebookIDTests run passed (9 test runs). Record: `docs/validations/f05-rulebook-id.md`.
- Open for the user: whether `block-dangerous-commands.sh` should stop blocking shell writes to Swift sources in commands that also mention the Xcode project (harness follow-up on `main`, outside f05).
- Next: the user merges the f05 PR; then `/feature-flow` on the next dependency-ready feature, f06-extract-passages. Done when: f06 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f06 implemented
- f06-extract-passages is `passing` on branch `feat/f06-extract-passages` (code commits 13e01ac, 6c8556a; docs 04e4342): `Locator` (one case, `pdf(rulebookID:pageIndex:bounds:)`), `ExtractedPassage`, `PageLine`, `PassageSegmenter` (cut on a gap > 0.5 × the page's median line height or a line above the previous one; whitespace lines ignored; bounds clipped to the crop box) and `PassageExtractor` (skips pages with zero characters before `selection(for:)`; ordinals consecutive across the rulebook). All `nonisolated`; PDFKit model classes compile without isolation escapes on the iOS 27.0 SDK.
- `./init.sh` green: 37 tests, 0 failed, 0 skipped. Scenarios 1-7 on synthetic PDFs (`RuleRefTests/SyntheticPDF.swift`, Core Graphics and Core Text, no UIKit), 8-9 on `PageLine` values; a `>=` mutation fails the exact-threshold test.
- Found: PDFKit reads text wrapped around an image as a second column when the full-width lines do not reach the narrow lines' x range; the scenario 3 layout uses full-width lines that span it. Worth checking on Taifa pp. 3 and 12 in f08.
- Docs: the segmentation rule is decided in `docs/risks-and-open-questions.md`; `docs/domain-model.md` says "only extraction builds locators" is a convention.
- Left: Taifa calibration (f08); iOS 26 SDK isolation of PDFKit classes not checked.
- Next: the validator reviews f06 through `/feature-flow`. Done when: f06 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f06 accepted
- Validation 1 at 6669268 returned `accept` and the user confirmed. `./init.sh` green (37 tests, 0 failed, 0 skipped); the focused PassageSegmenterTests/PassageExtractorTests run passed (18). Record: `docs/validations/f06-extract-passages.md`.
- Open for the user: `docs/risks-and-open-questions.md` still lists multi-column extraction as deferred and geometry vs. Vision reading order as open, although ADR-002 is Accepted (docs follow-up on `main`); the approved f06 spec says ADR-002 is not written yet (wording only, no conflict).
- Next: the user merges the f06 PR; then `/feature-flow` on the next dependency-ready feature, f07-join-hyphenation. Done when: f07 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f07 stopped on a spec gap
- f07-join-hyphenation is `in_progress` on branch `feat/f07-join-hyphenation`. Done (commit 0c1087d): `PassageText.normalized(_:)` (`nonisolated` enum, no Foundation, rules a → b → c) and `PassageTextTests` for scenarios 2-8; `./init.sh` green, 44 tests, 0 failed, 0 skipped.
- Gap: f06's `PassageExtractorTests.boundsAreNonEmptyInsideTheCropBoxAndContainTheirLines()` (scenario 4) counts each passage's lines with `passage.text.split(separator: "\n")`. Normalized text has no "\n", so every passage counts as one line and the test fails. The approved f07 spec allows only expected-text-literal changes in that file, so the test cannot be fixed without a spec decision.
- Seen in a focused run with the full change: every other test passes, including scenario 1 (PDFKit returns "cons-" and "truir" as drawn) and the three updated expected texts.
- Stashed: the extractor change, `HyphenationExtractionTests` and the expected-text updates, in git stash "f07 step 2 WIP (scenario 4 red)".
- Next: the user decides how scenario 4 counts lines (for example from the layout's known line counts, or by consuming lines until their normalized join equals the passage text) and re-approves the f07 spec; then the implementer applies the stash and finishes. Done when: `./init.sh` is green with the extractor change and f07 is `passing` with evidence.

## 2026-10-15 — T3: f07 implemented
- The user re-approved the f07 spec (585abfe): scenario 4 takes each passage's line count from its layout. f07-join-hyphenation is `passing` on branch `feat/f07-join-hyphenation` (code commits 0c1087d, b00d743).
- `PassageExtractor.extract(from:rulebookID:)` runs each segment's text through `PassageText.normalized(_:)` and skips empty results before taking the ordinal. `HyphenationExtractionTests` covers scenario 1 on a synthetic PDF; f06's `PassageExtractorTests` changed only in its three expected texts and in scenario 4's line counts (stash applied and dropped).
- `./init.sh` green: 45 tests, 0 failed, 0 skipped; focused run of the four passage suites passed (26).
- Left: Taifa's real hyphenation, U+2011 and PDFKit's handling of drawn U+00AD (f08); iOS 26.0 and device runs.
- Next: the validator reviews f07 through `/feature-flow`. Done when: f07 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f07 accepted
- Validation 1 at bfad103 returned `accept` and the user confirmed. `./init.sh` green (45 tests, 0 failed, 0 skipped); the focused run of the four passage suites passed (26). Record: `docs/validations/f07-join-hyphenation.md`.
- Process: the first implementation run stopped on a spec gap (f06's scenario 4 counted lines by splitting on "\n"); the user re-approved the spec with layout-based line counts and the resumed run passed. A spec gap is a `stop`, not a verdict.
- Found: the validator hook blocks `-resultBundlePath`, so focused runs use the default DerivedData bundle.
- Left for f08: Taifa's real hyphenation, U+2011 and how PDFKit reports a drawn U+00AD.
- Next: the user merges the f07 PR; then `/feature-flow` on the next dependency-ready feature, f08-atomic-import. Done when: f08 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f08 implemented
- f08-atomic-import is `passing` on branch `feat/f08-atomic-import` (code commits c38cba0, a0d8488; docs b9a61b1): `RulebookStore` (`<base>/<hex>.pdf`, atomic write, missing file ignored on removal), `RulebookID.init?(hex:)`, `ImportError`, `PreparedRulebook`, `RulebookPreparer.prepare(fileAt:)` (`@concurrent`; reads and hashes once; the `PDFDocument` stays local), the `Rulebook` and `Passage` models (cascades; `orderedPassages`; `Passage.extractedPassage(rulebookID:)` rebuilds the locator), `Game.rulebook` and `Library.importRulebook(fileAt:into:store:)` (checks before and after the await, writes the file before the single `save()`, rolls back and removes the file if the save fails). The app container lists the three model types.
- `./init.sh` green: 62 tests, 0 failed, 0 skipped. Scenarios 1, 2, 4, 5 and 6 in `ImportTests`, scenario 3 in `TaifaImportTests`; a read-only store also covers the save-failure path. The f02 and f03 test containers did not need changes.
- Taifa: the fixture reaches the test bundle through the synchronized folder; 16 pages, 40 passages. Finding for ADR-002 (in `docs/risks-and-open-questions.md`): most passages are a whole page body, because Taifa's paragraph gaps are not above 0.5 × the median line height, and each printed page number is its own passage. No line-break hyphen is left inside a passage. The ratio is unchanged.
- Found: `#expect(throws:)` with an async closure needs a `sending` result, so a closure returning a main-actor `@Model` must discard it. As in f02, `fetchCount` returns a stale count right after a failed save and rollback; the tests count with `fetch`. `block-dangerous-commands.sh` also blocks `mkdir` in a command that mentions the Xcode project.
- Left: the import action and ready state (f17); Taifa's segmentation decision (ADR-002 or a later spec, measured by f16).
- Next: the validator reviews f08 through `/feature-flow`. Done when: f08 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f08 accepted
- Validation 1 at fc770ab returned `accept` and the user confirmed. `./init.sh` green (62 tests, 0 failed, 0 skipped); the focused RulebookStoreTests/ImportTests/TaifaImportTests run passed (17). Record: `docs/validations/f08-atomic-import.md`.
- Carry into f11: with the same PDF in two games, a failed save's `removeFile` deletes the file the first game uses; f11 must refuse with `.alreadyImported` before `store.write`.
- Open for the user: Taifa's coarse segmentation (40 passages for 16 pages) should be decided before f13 (ADR-002 finding). Align `ContentView`'s `#Preview` container in f17.
- Next: the user merges the f08 PR; then `/feature-flow` on the next dependency-ready feature, f09-reject-no-text-layer. Done when: f09 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f09 implemented
- f09-reject-no-text-layer is `passing` on branch `feat/f09-reject-no-text-layer` (code commit 01f9afc): `ImportError.noTextLayer`, thrown by `RulebookPreparer.prepare(fileAt:)` when extraction yields zero passages, before anything is written or inserted. A document with at least one passage imports, even with pages that have no text.
- `NoTextLayerImportTests` covers scenarios 1-4 (image-only, blank pages, mixed PDF imports, the game imports after a rejection). Red first: without the check, scenarios 1, 2 and 4 failed and 3 passed. PDFKit reports 0 characters for synthetic pages holding only a filled rectangle or nothing.
- `./init.sh` green: 66 tests, 0 failed, 0 skipped; the focused NoTextLayerImportTests/ImportTests run passed (11). No existing test imported a zero-passage PDF.
- Left: real scanned PDFs (an invisible OCR layer would import); encrypted PDFs may fail as `.noTextLayer` until f10; the error's presentation (f17).
- Next: the validator reviews f09 through `/feature-flow`. Done when: f09 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f09 accepted
- Validation 1 at cdc33ad returned `accept` and the user confirmed. `./init.sh` green (66 tests, 0 failed, 0 skipped); the focused NoTextLayerImportTests/ImportTests run passed (11). Record: `docs/validations/f09-reject-no-text-layer.md`.
- The doc comment on `case noTextLayer` was judged acceptable despite the spec's "Nothing else changes".
- Next: the user merges the f09 PR; then `/feature-flow` on the next dependency-ready feature, f10-reject-unreadable-file. Done when: f10 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f10 implemented
- f10-reject-unreadable-file is `passing` on branch `feat/f10-reject-unreadable-file` (code commit a45587c): `ImportError.locked`, thrown by `RulebookPreparer.prepare(fileAt:)` when the opened `PDFDocument` is locked, after opening and before extraction. An encrypted PDF that opens unlocked (owner password only) imports normally; bytes PDFKit cannot open stay `.unreadable`. `docs/domain-model.md` now says "locked (needs a password to open)".
- `SyntheticPDF.data(pages:encryption:)` gains an optional `Encryption` (owner password, optional user password) passed through Core Graphics' auxiliary dictionary; existing calls are unchanged.
- `UnreadableFileImportTests` covers scenarios 1-5. All PDFKit preconditions held on the iOS 27.0 simulator: a user-password PDF opens locked, an owner-only PDF opens unlocked and extracts its text, the corrupt bytes give `nil`. Red first: without the check, scenarios 1, 4 and 5 failed with `.noTextLayer`; 2 and 3 passed.
- `./init.sh` green: 71 tests, 0 failed, 0 skipped; the focused run (UnreadableFileImportTests, ImportTests, PassageExtractorTests, NoTextLayerImportTests) passed (24).
- Left: real encrypted or damaged rulebooks, other key lengths and permission sets; the error's presentation (f17).
- Next: the validator reviews f10 through `/feature-flow`. Done when: f10 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f10 accepted
- Validation 1 at 973726d returned `accept` and the user confirmed. `./init.sh` green (71 tests, 0 failed, 0 skipped); the focused UnreadableFileImportTests/ImportTests/PassageExtractorTests/NoTextLayerImportTests run passed (24). Record: `docs/validations/f10-reject-unreadable-file.md`.
- f09's interim consequence is resolved: a locked PDF now fails as `.locked` and never reaches extraction.
- The doc comment on `case locked` was judged acceptable, as in f09. The red-first claim was not reproduced by the read-only validator.
- Next: the user merges the f10 PR; then `/feature-flow` on the next dependency-ready feature, f11-reimport-same-file (it must refuse `.alreadyImported` before `store.write`). Done when: f11 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f11 implemented
- f11-reimport-same-file is `passing` on branch `feat/f11-reimport-same-file` (code commit 9a3a5ca): `FingerprintedFile`, `ImportOutcome` (`imported` / `alreadyPresent`), `ImportError.alreadyImported(gameName:)`. `RulebookPreparer` is split into `fingerprint(fileAt:)` and `prepare(_:)`, both `@concurrent`. `Library.importRulebook` now fingerprints, checks, prepares, checks again and then runs f08's store step, returning `ImportOutcome`. The check looks up the ID first (`FetchDescriptor<Rulebook>`, `fetchLimit` 1): if this game holds it, the call is a no-op; if another game does, the call fails naming that game's stored name. After that comes `.gameHasRulebook`.
- f08 carry-over closed: `store.write` runs only after the step-(d) check, so no path writes or removes a file another game holds.
- `./init.sh` green: 78 tests, 0 failed, 0 skipped. `ReimportTests` covers scenarios 1-7. Existing tests changed only at three call sites (`.rulebook`). Mutation check: without the step-(d) check, scenarios 6 and 7 fail.
- Change from f08-f10: `.gameHasRulebook` no longer comes before reading; a game with a rulebook given unreadable bytes now gets `.unreadable`.
- Left: what the user sees for each outcome (f17).
- Next: the validator reviews f11 through `/feature-flow`. Done when: f11 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f11 accepted
- Validation 1 at 7b13355 returned `accept` and the user confirmed. `./init.sh` green (78 tests, 0 failed, 0 skipped); the focused Reimport/Import/NoTextLayer/UnreadableFile/Taifa run passed (24); the two concurrent scenarios passed 50 of 50 with `-test-iterations 25`. Record: `docs/validations/f11-reimport-same-file.md`.
- The f08 carry-over is closed: no path writes or removes the file of a rulebook another game holds.
- Uniqueness relies on main-actor serialization over one `ModelContext`; imports from a second context or container are not covered.
- Next: the user merges the f11 PR; then `/feature-flow` on the next dependency-ready feature, f17-import-action (spec approved 2026-10-13; it shows each `ImportOutcome` and `ImportError` and aligns `ContentView`'s `#Preview` container). Done when: f17 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f17 implemented
- f17-import-action is `passing` on branch `feat/f17-import-action` (code commit 8133a9f): `GameScreenState` (`empty` / `ready(pageCount:)`, `init(game:)` on the main actor), `ImportErrorMessage` (one `LocalizedStringResource` per `ImportError`, `nil` for a successful outcome), `Library.importPickedFile(at:into:store:)` (security-scoped access released on every path; a failed start does not stop the import) and the reworked `GameView` (Import Rulebook button or progress, `fileImporter` for one PDF into `RulebookStore.app`, one "Import Failed" alert with "OK", a "Pages" row when ready). 11 catalog keys with Spanish values.
- `./init.sh` green: 84 tests, 0 failed, 0 skipped. Scenario 1 in `GameScreenStateTests`, scenarios 2-3 in `ImportErrorMessageTests`. The compiler's key for `.alreadyImported` is `This rulebook is already in “%@”.`, as the spec assumed.
- Not done: `ContentView`'s `#Preview` container still lists only `Game.self`; the spec does not declare that file and the build does not need it.
- Left: scenario 4 (the screen, the picker, the alert; Taifa shows 16 pages) is validated by hand on the iPhone 16 at the end of T3.
- Next: the validator reviews f17 through `/feature-flow`. Done when: f17 is `accepted` and its PR is merged into `main`.

## 2026-10-15 — T3: f17 accepted
- Validation 1 at aacf0e1 returned `accept` and the user confirmed. `./init.sh` green (84 tests, 0 failed, 0 skipped); the focused GameScreenStateTests/ImportErrorMessageTests run passed (6 tests, 11 runs). Record: `docs/validations/f17-import-action.md`.
- Open item for the user: `ContentView`'s and `NewGameSheet`'s `#Preview` containers list only `Game.self`; outside f17's spec. Align them in a small chore on `main` or a later spec.
- Left: scenario 4 (the screen, picker, alert; Taifa shows 16 pages) is checked by hand on the iPhone 16 at the end of T3.
- Next: the user merges the f17 PR; then the next dependency-ready feature, f13-text-search, which has no spec yet: write it with `feature-spec` and get the user's approval, then `/feature-flow`. Done when: f13's spec carries the Approval line and f13 is `accepted` with its PR merged into `main`.

## 2026-10-15 — T3 closed: manual checks on the iPhone 16
- f03 (checked 2026-10-15, main at 0c417ea): empty state (`books.vertical`), "Nuevo juego" toolbar button and sheet, list order "7 Wonders, Ábaco, Catan, Taifa", duplicate refused for "abaco", games persist after killing the app, game screen (`book.closed`) and back, Spanish texts. Also covers f02 scenario 5.
- f17 (checked 2026-10-15, main at 42a9793, PR #11 merged): picker limited to PDF; Taifa imports and shows "Páginas 16"; the ready state offers no import button (re-import needs f12); the same file into another game is refused naming "Taifa"; an image-only PDF is refused as having no selectable text; a user-password PDF is refused as asking for a password; cancelling the picker leaves the game untouched; the rulebook survives killing the app; all texts in Spanish. "Importando…" was not observed (import finished at once); not a failure.
- T3 closed: f02, f03, f05–f11 and f17 accepted and merged; 84 tests on main. f04 and f12 stay deferred (ADR-003).
- Next: B4 spec round on `main`: f13, f14, f15, f16 and the new f18 (paragraph-cut calibration) written with `feature-spec`, plus ADR-004 (page viewer) and the docs alignment patch; each spec needs the user's Approval line before `/feature-flow`.

## 2026-10-16 — T4 prep: ADR-004, f18 and docs alignment
- ADR-004 accepted: the page viewer wraps PDFKit's `PDFView` in one `UIViewRepresentable` whose file imports `SwiftUI` and `PDFKit` only; `init.sh` does not change; if it needs `import UIKit`, f15 stops. ADR-001 gets a revision note (the UIKit exception; no Vision in the MVP) and `AGENTS.md` points to ADR-004.
- ADR-002 revised: the second Taifa table is on page 11, not 10; the f08 segmentation finding leads to f18. `docs/risks-and-open-questions.md`, `docs/domain-model.md` and `README.md` aligned with ADR-002 and ADR-004.
- New feature f18-paragraph-cut-calibration (T4), after f12 and before f13, depending on f08: the paragraph ratio is measured on Taifa with PDFKit and recalibrated. Added to `feature_list.json` and `docs/build-brief.md`.
- f16 verification changed by the user's decision: the report is attached to the result bundle of a focused test run and extracted with `xcresulttool`, instead of `./init.sh` producing it; the gate does not change. f16 stays `blocked` until m4.
- Known stale wording, left untouched on purpose because the specs are approved and accepted: `docs/specs/f03-list-games.md` attributes the import action to f08 (now f17), and `docs/specs/f06-extract-passages.md` says ADR-002 is not written.
- Next: write the specs of f18, f13, f14, f15 and f16 with `feature-spec` on `main`. Done when: each of the five has `docs/specs/<id>.md` with the user's Approval line.

## 2026-10-16 — Harness: interface and folder rules after the user's code review
- The user reviewed the code in Xcode: every file sits in the root of `RuleRef/`, `GameView` has no preview and the other two show only an empty container, and buttons are text only. None of this was a rule: `AGENTS.md`, the skills and the specs never asked for folders, previews or SF Symbols, and the f02, f03 and f17 specs named text buttons. The vendored `feature-spec` and `feature-validator` skills already read `DESIGN.md` and `ARCHITECTURE.md`; the repo had neither.
- New `DESIGN.md` (SF Symbols through `Label`, standard button roles, a named preview per state with sample data, views that receive plain values) and `ARCHITECTURE.md` (folders as boundaries and what each may use). `AGENTS.md`, the `feature-implementer` skill, `README.md` and `docs/build-brief.md` point to them; both names join the UPPERCASE list.
- New feature f19-interface-conventions (T4), after f18 and before f13, depending on f17: the three existing screens follow `DESIGN.md`. It absorbs the open `#Preview` container item from f17.
- Not yet enforced by `init.sh`: a check that every view has a `#Preview` waits for the post-m4 harness batch; until then the spec and the validator's review cover it.
- Next: move the existing files into the folders `ARCHITECTURE.md` defines, on `main`, renames only. Done when: `./init.sh` passes after the move with the same 84 tests and no `.swift` file is left in the root of `RuleRef/` or `RuleRefTests/`.
