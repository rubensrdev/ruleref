# ADR 0001: Stack and build doctrine

## Status
Accepted

## Context
Solo developer, three weeks to a graded harness, recorded as a video. Agents must build, test and be gated without anyone driving Xcode. The app must stay maintainable alone and publishable on the App Store later.

## Decision
- iOS app, iPhone only, portrait only. Deployment target iOS 26.0, built with Xcode 27.
- Swift 6 language mode with strict concurrency; async/await wherever an API offers it.
- Default actor isolation is MainActor in both targets (app and tests).
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

## Revision 2026-10-07
- Changed: the deployment target drops from iOS 27 to iOS 26.0; the app is still built with Xcode 27 and the iOS 27 SDK. The app is declared iPhone only and portrait only, and default actor isolation is MainActor in both targets.
- Why: App Store reach. Requiring iOS 27 would exclude every device still on iOS 26 at release time; iOS 26.0 covers them at no cost to the MVP.
- Consequence: any API that exists only in iOS 27 must be guarded with `#available` and have an iOS 26 path.
