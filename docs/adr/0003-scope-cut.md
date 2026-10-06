# ADR 0003: Scope cut — no web importer, no parallel worktrees

## Status
Accepted

## Context
Solo developer with fragmented time and three weeks to a graded harness. The harness is what gets graded; the app is its test bed. The idea included a second import source (web pages) and a module 4 loop running agents in parallel git worktrees. Both add surface without adding features the harness needs to prove itself.

## Decision
- The only import source in the MVP is a PDF file. The web importer is out of scope.
- The import contract is kept: after import, the app sees only passages with locators. The locator has a single `pdf` variant, and a new source adds a variant without touching search or the page viewer.
- The module 4 loop runs sequentially in a single working tree. Parallel worktrees are out of scope.

## Alternatives Considered
- **Keep the web importer** to prove the import contract with a second source: doubles the extraction work (HTML structure, locators for web content, offline snapshots) for a contract that one source already exercises.
- **Parallel worktrees in the m4 loop**: shows parallel agents, but adds merge conflicts, per-worktree simulators and build caches, and makes a CLI gate (ADR-001) harder to keep reliable alone.
- **Photographed pages instead of web**: same contract, kept as a week 6 / v2 candidate rather than replacing the cut.

## Consequences
- One source and one locator variant to test; feature slices stay small.
- The import contract is unverified by a second source until one is added; the locator is designed as an extensible variant to limit that risk.
- The harness demonstrates a sequential loop only; parallelism is not part of the graded deliverable.
- Reversing either cut later is additive: a new importer behind the contract, or worktrees on top of an already-stable gate.
