# RuleRef

An iPhone rulebook referee for board games: import a game's PDF rulebook, search it, and see the original rule on its page with the passage highlighted.

## Status

In development. Final project for DevExpert's AI Expert course. The project has two deliverables: the working app and the documented harness. The harness is the main one; the app is its test bed.

## MVP (up to m4)

- A library of games, each holding at most one rulebook imported from a single-column PDF with a text layer.
- Import once, then use it offline: the rulebook is frozen into ordered passages, each with a page locator.
- Text search inside one game's rulebook, case- and diacritic-insensitive, with an explicit no-match state instead of approximate results.
- Open a match in the page viewer with the passage highlighted.

No AI before m4. On-device AI comes later as a pluggable layer.

## Stack

iOS 26+, iPhone only, Swift 6, SwiftUI, SwiftData, Swift Testing, PDFKit and Vision, no third-party dependencies, built and tested via `xcodebuild`. See [ADR-001](docs/adr/0001-stack-and-build-doctrine.md).

## Build and test

`./init.sh` is the only command: it checks the toolchain and simulator, enforces the source rules (no JSONSerialization, UIKit, XCTest, third-party packages or bundled PDFs; Spanish translations complete), then builds with warnings as errors and runs the tests. Requires Xcode 27 and an iPhone 18 Pro simulator with iOS 27.0.

## Documentation

- [`docs/idea.md`](docs/idea.md): original idea, course context and initial decisions (Spanish).
- [`docs/build-brief.md`](docs/build-brief.md): problem, goals, non-goals and feature slices up to m4.
- [`docs/domain-model.md`](docs/domain-model.md): core concepts and rules.
- [`docs/risks-and-open-questions.md`](docs/risks-and-open-questions.md): status of open decisions, assumptions and risks.
- [`docs/adr/0001-stack-and-build-doctrine.md`](docs/adr/0001-stack-and-build-doctrine.md): stack and CLI build doctrine.
- [`docs/adr/0003-scope-cut.md`](docs/adr/0003-scope-cut.md): scope cut, with no web importer and no parallel worktrees.
- [`CONTEXT.md`](CONTEXT.md): glossary of canonical terms.
- [`PROGRESS.md`](PROGRESS.md): log of work sessions, recording what closed and what comes next.

## Demo rulebook

The demo uses Taifa 3.0 (CC BY-NC-SA). It is used only as a test fixture and is never bundled in the app.
