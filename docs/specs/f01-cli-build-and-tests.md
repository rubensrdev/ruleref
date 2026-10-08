# Feature Implementation Spec: Build and test from the CLI

Approval: approved by the user on 2026-10-08

## Source Feature

- `id`: f01-cli-build-and-tests
- `area`: harness
- `depends_on`: none
- `status`: passing (retroactive spec: it describes what exists at HEAD; no new work is planned)
- `source`: `feature_list.json`

## Goal

The empty app target and its test target build and run their tests from the command line through `./init.sh`, the single gate for "builds and passes" (ADR-001). Every later feature is verified through this gate.

## Non-Goals

- Any product feature (f02 onwards).
- The gate's failure path: the T2.6 exit criterion already proved it (recorded in `PROGRESS.md`).
- The Xcode MCP integration (P3.8).
- CI.
- Running on iOS 26.0 or on a physical device.

## Job Story

When an agent or the user changes the repo,
I want one command that checks the toolchain, enforces the source rules, builds and runs the tests,
so I can tell whether the repo builds and passes without opening Xcode.

## Users And Permissions

- Agents and the user: run `./init.sh` at any time without asking. The validator may run only `./init.sh`, read-only git, `xcrun xcresulttool get` and focused `xcodebuild test` with `-only-testing:` (`validator-readonly-bash.sh`).

## Acceptance Scenarios

### Scenario 1: the gate is green at HEAD

Given a checkout of HEAD on a Mac with Xcode 27 and the iPhone 18 Pro / iOS 27.0 simulator
When the validator runs `./init.sh`
Then it exits 0, the summary lists every check as PASS (xcode-version, simulator, no-jsonserialization, no-uikit-xctest, no-third-party-deps, no-pdf-in-app, string-catalog, feature-list, xcodebuild-test, test-results, catalog-coverage), with no FAIL or SKIP, and the last line is `init.sh: PASS`.

### Scenario 2: tests ran and none failed or were skipped

Given the same run
When the validator reads the line the test-results check prints before the summary
Then it reports `totalTestCount` of at least 1 and `failedTests=0`, `skippedTests=0`, `expectedFailures=0`.

## Repository Research

### Files Inspected

- `init.sh` — the gate: preflight, rules, `xcodebuild test` with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, xcresult summary, catalog coverage, one-line summary per check.
- `RuleRefTests/RuleRefTests.swift` — one Swift Testing test: the hosted app bundle is `dev.ruben.RuleRef` and ships the `es` localization.
- `RuleRef/RuleRefApp.swift`, `RuleRef/ContentView.swift` — Xcode template app; no product behavior.
- `RuleRef/Localizable.xcstrings` — the catalog that string-catalog and catalog-coverage check.
- `feature_list.json` — f01 entry and its recorded evidence.
- `docs/adr/0001-stack-and-build-doctrine.md`, `docs/build-brief.md` (F01 row), `AGENTS.md`, `PROGRESS.md`.

### Existing Patterns To Follow

- The scheme `RuleRef`, the project and the destination are fixed at the top of `init.sh`; the Xcode project is configured by the user, never by agents.
- `init.sh` keeps its log and result bundle only on failure, so after a green run the summary output is the evidence.

### Current Gaps

- None blocking. The only test is a smoke test; the gate's behavior on a machine without Xcode 27 or the simulator was never exercised.

## Technical Approach

Already implemented: a Bash gate that runs checks in phases (preflight, rules, build and tests, summary), skips build and tests when preflight or rules fail, and ends with one PASS/FAIL/SKIP line per check. `init.sh` executes non-blocking checks only and starts no long-running process.

## Expected File Changes

- None. Existing files: `init.sh`, `RuleRefTests/RuleRefTests.swift`, `RuleRef/Localizable.xcstrings`.

## Visual Design Impact

- UI involved: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — it already describes `init.sh` as the single command.
- Other docs: none.

## Implementation Plan

1. [x] Add the gate with its preflight, rules, build, test and summary phases, plus the F01 smoke test (76f55aa).
2. [x] Add catalog-coverage, failing on code strings missing from the catalog (80e5c04), and on stale keys used again without a translation (a77be40).
3. [x] Declare the Cupertino MCP (cd45432) and write `AGENTS.md` and `CLAUDE.md` (5b76d93).

## Implementation Tasks

- [x] `init.sh` with xcode-version, simulator, source-rule and string-catalog checks, `xcodebuild test` and test-results (76f55aa).
- [x] Smoke test in `RuleRefTests/RuleRefTests.swift` and the first catalog key with its Spanish value (76f55aa).
- [x] catalog-coverage check (80e5c04, a77be40).
- [x] `.mcp.json`, `AGENTS.md`, `CLAUDE.md` (cd45432, 5b76d93).

## Verification Plan

- Run `./init.sh`; expect scenarios 1 and 2.
- No E2E and no UI tests, by the project's design (`AGENTS.md`, Tests): the user validates the interface by hand.

## Evidence To Capture

- The validator's own `./init.sh` run: exit code, the summary lines, the test-results counts, and the date, commit, Xcode and simulator.
- Recorded evidence the validator cannot re-run: the clean-clone run at aaf46dd in `feature_list.json`. The validator lists it in `not_verified`.

## Validator Checklist

- [ ] Scenarios 1 and 2 pass on the validator's own run.
- [ ] No product behavior beyond the template app was added.
- [ ] `feature_list.json` f01 evidence is complete and its `not_verified` list is honest.
- [ ] The clean-clone evidence is listed in `not_verified` as not re-run.
