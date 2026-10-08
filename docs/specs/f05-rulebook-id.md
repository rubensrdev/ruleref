# Feature Implementation Spec: Rulebook ID from file bytes

## Source Feature

- `id`: f05-rulebook-id
- `area`: import
- `depends_on`: f01-cli-build-and-tests
- `status`: not_started
- `source`: `feature_list.json`

## Goal

A `RulebookID` value type is the SHA-256 of a given sequence of bytes, as 64 lowercase hexadecimal characters (`docs/domain-model.md`, The locator). Identity comes from the bytes alone, never from a file name or path. It is pure domain logic, marked `nonisolated`.

## Non-Goals

- Reading the file the user picks, the `Rulebook` model, and persisting anything (f08).
- Detecting re-imports (f11).
- Any interface.

## Job Story

When the app imports a rulebook,
I want its identity to come from its exact bytes,
so I can tell the same file from a different one regardless of its name.

## Users And Permissions

- None: internal domain type.

## Acceptance Scenarios

### Scenario 1: same bytes, same ID

Given two separate `Data` values with identical bytes
When a `RulebookID` is computed from each
Then the two IDs are equal.

### Scenario 2: one changed byte, different ID

Given a byte sequence and a copy with exactly one byte changed
When a `RulebookID` is computed from each
Then the two IDs differ.

### Scenario 3: known vector

Given the UTF-8 bytes of "abc"
When its `RulebookID` is computed
Then its hex is `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`.

### Scenario 4: format

Given the IDs of several inputs, including empty bytes
When their hex strings are inspected
Then each has 64 characters, all in `[0-9a-f]`; the empty input gives `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Repository Research

### Files Inspected

- `docs/domain-model.md` — rulebook ID: "SHA-256 hex of the imported file's bytes"; identity from bytes, not name or path.
- `CONTEXT.md` — canonical term **Rulebook ID**.
- `docs/build-brief.md` — F05 row; ADR-001 — Apple frameworks only.
- `RuleRef/`, `RuleRefTests/` — no hashing or rulebook code exists yet.
- `docs/specs/f02-create-game.md` — approved reference for detail level.

### Existing Patterns To Follow

- Default isolation is `MainActor`; pure domain logic is `nonisolated` explicitly (`AGENTS.md`).
- Swift Testing only; new files in the synchronized folders need no project change.

### Current Gaps

- None.

## Technical Approach

API checked in the Cupertino MCP on 2026-10-08: CryptoKit `SHA256.hash(data:)` (iOS 13+), which returns a `SHA256Digest` (a `Sequence` of `UInt8`, `Sendable`). Apple's CryptoKit overview says to prefer CryptoKit over lower-level interfaces. It is an Apple framework, so there is no third-party dependency.

- `RulebookID`: `nonisolated struct`, `Hashable`, `Sendable`, with `let hex: String` and `init(bytes: some DataProtocol)`.
- The hex string is built from the digest bytes, two lowercase hex digits per byte. Do not derive it from `SHA256Digest.description`, whose format is undocumented.
- One-shot hashing is enough here. Hashing large files incrementally (`update(data:)` / `finalize()`) is f08's concern, which reads the file.

## Expected File Changes

- `RuleRef/RulebookID.swift` — create; the value type.
- `RuleRefTests/RulebookIDTests.swift` — create; scenarios 1–4.

## Visual Design Impact

- UI involved: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- Other docs: none; `docs/domain-model.md` already defines the rulebook ID.

## Implementation Plan

1. Write failing tests for scenarios 1–4.
2. Add `RulebookID` with CryptoKit.
3. Run `./init.sh`; record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] `RulebookIDTests`: equality for equal bytes; inequality after flipping one byte; "abc" and empty-input vectors; 64-char lowercase hex for several inputs.
- [ ] `RulebookID.swift` (`nonisolated`, `import CryptoKit`).
- [ ] `./init.sh` green; evidence and `PROGRESS.md` updated.

## Verification Plan

- `./init.sh` exits 0 with every check PASS; test-results shows the new tests, 0 failed, 0 skipped.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/RulebookIDTests`.
- Swift Testing only; no UI tests and no E2E, by design (`AGENTS.md`, Tests).

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–4.
- `not_verified`: hashing of real files and large inputs (f08), iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–4 are covered by passing tests.
- [ ] `RulebookID` is `nonisolated` and uses CryptoKit only; hex is not parsed from `description`.
- [ ] No file reading, persistence, re-import logic or UI was added.
- [ ] `feature_list.json` and `PROGRESS.md` were updated correctly.
