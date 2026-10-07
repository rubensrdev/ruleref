---
name: feature-flow
description: Orchestrate one RuleRef feature through implementation, independent validation and a recorded decision, delegating to the feature-implementer and feature-validator subagents. Use only when the user runs /feature-flow, optionally with a feature id.
disable-model-invocation: true
---

# Feature Flow

You are the orchestrator in the main session. You select one feature, delegate, record and decide. You never implement or validate yourself.

## Critical rules
- One feature per run. When it ends, report the next step and stop. Never start another feature unless the user asks.
- Delegate only through the Agent tool: implementing and repairing to `feature-implementer`, validating to `feature-validator`. Never pass a model. Never write code or judge the feature yourself.
- Only an approved spec starts work (`AGENTS.md`, Specs). Never write or approve a spec: if the selected feature has none approved, stop and ask the user.
- `accepted` only after the validator returns `accept` and the user confirms in the chat. Then you set it and commit.
- At most 3 `revise` verdicts per approved spec. After the third: stop, set the feature to `blocked`, add `stop: revise limit` to its `notes` and hand the decision to the user.
- `block` is a verdict: a condition is missing. `stop` is a limit: revise rounds, a subagent's turn limit, a permission, the environment. Always name which one ended the run.
- Run interactively only: in `-p` sessions the subagents' frontmatter hooks may not run.

## Select the feature
From `feature_list.json`, in this order:
1. The id the user gave. If any of its `depends_on` is not `accepted`, stop and name it.
2. A feature `in_progress`: resume it.
3. A feature `passing`: validate it.
4. The first `not_started` feature whose `depends_on` are all `accepted`.
Then open `docs/specs/<feature-id>.md`. No file, or no Approval line: stop and ask the user for an approved spec.

## Count the rounds
Read `docs/validations/<feature-id>.md` if it exists. The revise count is the number of `revise` sections dated on or after the spec's Approval date. Re-approving the spec resets it; nothing else does.

## Loop
1. Implement. When the feature is `not_started` or `in_progress`, or after a `revise`: delegate to `feature-implementer` with the feature id and, when repairing, the last Implementation Repair Brief verbatim. If it reports that it stopped (spec gap, turn limit, project change needed, `./init.sh` failing), that is a `stop`: leave the state as it is, report and end.
2. Validate. When the feature is `passing`: delegate to `feature-validator` with the feature id and the commit to validate.
3. Record. Append a section to `docs/validations/<feature-id>.md` in the format below and commit it: `docs: record <feature-id> validation <n>`.
4. Decide.
   - `revise`: if it is the third, stop as the critical rules say. Otherwise go back to step 1.
   - `block`: set the feature to `blocked`, add `block: <reason>` to its `notes`, commit and report.
   - `accept`: show the user the summary below and ask for confirmation. Wait.
5. Close. If the user confirms: append the validator's evidence entry to the feature's `evidence`, set it to `accepted`, add a `PROGRESS.md` entry whose Next line states the next step and its done-when criterion, add `User: confirmed` to the validation section, commit (`docs: accept <feature-id>`) and push; `git push` asks the user. If the user rejects: add `User: rejected — <reason>`, keep the feature `passing` and ask how to proceed.

## Validation record
    ## Validation <n> — <verdict> — <YYYY-MM-DD>
    - Commit validated: <sha>
    - Checks rerun: <commands and results>
    - Findings: <one line each, with severity>
    - Not verified: <list, or "nothing">
    - Repair brief: <verbatim; revise only>
    - User: <confirmed | rejected — reason; accept only>

## Summary for the user
Before asking to confirm an accept, and at the end of every run. Lead with what was not verified. Then: feature id and outcome (waiting for confirmation, accepted, block, or stop and which limit), revise rounds used of 3, the checks the validator reran and their results, commits, and the next step.
