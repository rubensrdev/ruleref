---
name: build-brief
description: Discovery interview for the rulebook-referee iOS app before any spec or code. Use only when the user runs /build-brief to close MVP scope, domain model and open decisions. Not for specs, implementation or harness files.
disable-model-invocation: true
---

# Build Brief (rulebook referee, iOS)

Turn the project idea into four short, durable documents that any future session can reread instead of this chat. The stack is already closed; this skill decides product scope, domain and open decisions only.

All paths are relative to the repository root.

## Inputs (read before asking anything)

- `docs/idea.md` — the product idea, decided items, open decisions, risks.
- `docs/adr/0001-stack-and-build-doctrine.md` — the closed stack and the CLI build doctrine. Do not reopen it.
- `PROGRESS.md` — what is already settled (demo rulebook, demo device).

Never ask a question these files already answer. If two inputs disagree, ask which one wins before writing.

## Hard rules

- No code, no Xcode project, no specs.
- Do not create `AGENTS.md`, `CLAUDE.md`, `init.sh`, `feature_list.json`, hooks, settings or task plans. Do not edit `PROGRESS.md`. Those belong to the next phase.
- Interview in Spanish. Write every artifact in English. Do not ask about document language.
- One question at a time, always with a recommended answer and why. Use the structured question tool for bounded choices; plain text for open ones.
- Every document must remove a concrete ambiguity. No ceremony, no duplicated statements across documents.
- No design-system output. For UI, state the screens the MVP needs and defer visual rules to Apple's Human Interface Guidelines.

## Steering

- Aim for the smallest MVP that gives the development harness real features to run on. The harness is graded, not the app.
- Planning horizon: up to the end of module 4. Anything needing AI (Foundation Models, embeddings, evals) is listed as later, not sliced now.
- The app must be useful without AI at that horizon: import a PDF rulebook, search its text, jump to the cited page with the passage highlighted.
- Prefer cutting a feature to designing it half-way. Each cut goes to Non-goals with a one-line reason.

## Outputs (fixed paths)

1. `CONTEXT.md` — glossary only. Canonical terms the code and UI will use, plus rejected or ambiguous terms with the preferred one. Add a term only once it is stable.
2. `docs/build-brief.md` — Problem, Target user, Goals, Non-goals, MVP slice, Feature slices, Validation plan, Success criteria.
   - Feature slices: an ordered list with stable IDs (`F01`, `F02`…). Each has one sentence of behaviour and one line of observable evidence that a command or test can check. Keep it to what fits before module 4 ends.
3. `docs/domain-model.md` — Core concepts, Relationships, States and lifecycles, Important scenarios, Edge cases.
   - The locator is the central type: what it identifies, what makes two locators equal, what a valid one guarantees, and how it survives re-import of the same file.
   - Every entity with states gets its lifecycle: states, what triggers each transition, and the failure states (for example an import that finds no text layer).
4. `docs/risks-and-open-questions.md` — Blocking next phase, Implementation-time, Later (after m4), Assumptions, Risks.
5. `docs/adr/0003-scope-cut.md` — records the cut already decided in `docs/idea.md`: web importer and parallel worktrees out of scope, with context, alternatives and consequences. Further ADRs only for decisions that are hard to reverse, had real alternatives, and the user confirmed after a short preview.

## Stop condition

Stop when the documents answer, without needing this chat:

- What the MVP is and what is explicitly out.
- The core concepts, with the locator and every lifecycle defined.
- Every open decision listed in `docs/idea.md`, each marked **Decided** (and where it is written) or **Deferred** with a named owner: an ADR number or "after m4". Multi-column extraction is deferred to ADR-002 unless the user decides otherwise.
- The feature slices up to module 4, each with checkable evidence.
- What remains unknown, classified.

Before stopping, run a quality pass: remove duplicates, move resolved items out of open questions, and check that no section is left as "not yet defined" without a stance.

Then summarise in Spanish what was decided and what was deferred, and stop. Do not start the next phase.
