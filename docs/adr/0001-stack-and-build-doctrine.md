# ADR 0001: Stack and build doctrine

## Status
Accepted

## Context
Solo developer, three weeks to a graded harness, recorded as a video. Agents must build, test and be gated without anyone driving Xcode. The app must stay maintainable alone and publishable on the App Store later.

## Decision
- iOS app, deployment target iOS 27, built with Xcode 27.
- Swift 6 language mode with strict concurrency; async/await wherever an API offers it.
- SwiftUI only (no UIKit), SwiftData for persistence, Swift Testing for tests.
- Codable only for serialization; JSONSerialization is forbidden.
- Zero third-party dependencies. No deprecated APIs.
- Ingestion with PDFKit and Vision. AI with Foundation Models on-device; without Apple Intelligence the app offers text search only.
- Build and test through the CLI (`xcodebuild`) on one fixed simulator, named in `init.sh`. Hooks and the agent loop never need Xcode in the foreground.

## Alternatives Considered
- Xcode-driven builds (Xcode MCP, IDE agents): not scriptable from hooks or a Stop gate; rejected for the gate path.
- Swift Package-only targets: faster tests, but no app target for PDFKit views and on-device AI; rejected for the MVP.
- Remote AI backend as the main path: conflicts with privacy and later App Store release; kept only as a module 5 fallback, decided by evals in its own ADR.

## Consequences
- `init.sh` is the single source of truth for "builds and passes"; hooks and validators call it.
- The simulator name and OS are pinned; changing them is an explicit edit, not drift.
- Foundation Models behaviour can change with iOS updates; evals must record the OS version.
