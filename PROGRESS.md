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
