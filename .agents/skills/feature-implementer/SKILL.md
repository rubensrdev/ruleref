---
name: feature-implementer
description: Implement one RuleRef feature from its approved spec in docs/specs, or apply a validator repair brief to it, and leave it passing with evidence. Use when asked to implement, resume or repair a feature by id. Not for writing specs, validating or accepting features.
---

# Feature Implementer

## Critical rules
- One feature per run: the id you were given. Never start another feature, never set `accepted`, never edit `docs/specs/`.
- The spec at `docs/specs/<feature-id>.md` is the contract. If it is missing, contradicts itself or does not cover a decision the code needs, stop and report the gap; never decide it yourself.
- `AGENTS.md` rules apply in full: non-negotiables, tests, localization, Definition of Done. Never edit `RuleRef.xcodeproj`.
- Done means `./init.sh` passes. Never weaken, skip or delete a test to get there.
- Do not push. The orchestrator decides what is published.
- Report what you could not verify.

## Inputs
Read first: `AGENTS.md`, `PROGRESS.md`, the feature's entry in `feature_list.json`, its spec and, when repairing, the Implementation Repair Brief you were given. Then the code the spec names.

## Workflow
1. Check the state. `not_started` with every `depends_on` accepted: set it to `in_progress`. `in_progress`: resume from `git status` and `git diff`; never start over. `passing` with a repair brief: set it back to `in_progress`. Any other case: stop and report.
2. Write or update a Swift Testing test for each Acceptance Scenario, named after it, then implement the Implementation Tasks inside the spec's scope and Non-Goals.
3. Run `./init.sh` until it passes. Fix the cause, never the check.
4. Commit the code (Conventional Commits).
5. Run `./init.sh` again on that commit and record one evidence entry in `feature_list.json`, following the spec's Evidence To Capture: `command`, `expected`, `observed`, `context` (date, commit, Xcode, simulator) and `not_verified`. Set the status to `passing`.
6. Add a `PROGRESS.md` entry: what closed, what is left and a Next line with its done-when criterion. Commit both files.

## Applying a repair brief
- Change only what the brief lists. Anything else you notice goes in your report, not in the code.
- For a behaviour bug: first add a test that reproduces it and fails, then fix it.
- If a finding conflicts with the spec, stop and report it. The spec wins until the user changes it.

## Output
A short report: feature id and final status, commits, the last `init.sh` summary line, the evidence entry, what was not verified, any deviation from the spec and open questions.
