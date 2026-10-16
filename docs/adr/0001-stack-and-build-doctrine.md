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

## Revision 2026-10-14
- Changed: the Xcode 27 MCP server is registered at project scope (`xcode` in `.mcp.json`, `xcrun mcpbridge`) as an interactive aid for the main session: reading, diagnostics, previews and docs. Xcode 27 serves it headless (`xcrun mcp-server`), so no Xcode window is needed.
- The gate does not move: `./init.sh` stays the only definition of "builds and passes". The Alternatives line above rejected Xcode-driven builds because they need Xcode in the foreground; headless mode removes that reason, not these:
  - its build and test tools skip the source rules, `feature-list`, `xcresulttool` and `catalog-coverage` checks;
  - they use the workspace's active scheme and run destination, not the pinned simulator;
  - they depend on a permitted agent and folder granted with `sudo` on each machine, which a Stop hook, a validator rerun or CI cannot rely on;
  - one test tool reported cached results as passing on Xcode 26.3, by a secondary source.
- Permissions: all 54 tools are classified in `.claude/settings.json`: 19 allowed (read only, diagnostics, workspace, docs), 22 ask (build, test, previews, run, debug, simulator, IDE state, String Catalog reads, App Store data) and 13 denied (every tool that writes files or changes the project, targets, Info.plist, entitlements or localizations). `xcode-mcp-write-guard.sh` blocks the 13 again by name, because they take Xcode project paths that the file hooks cannot match. Live check on 2026-10-14: none of the 13 is visible to the agent, so the hook's evidence is its test cases.
- Scope: the implementer has none of its tools (`disallowedTools: mcp__xcode`) and the validator has none (explicit `tools` list). `RenderPreview` is not validation evidence: the user validates the interface by hand.
- Consequences: the server's tool list drifts (53 tools in the morning and 54 in the afternoon of 2026-10-14), so it is listed again after every Xcode update and each new tool is classified. Machine setup (headless mode, permitted agent, permitted folder) is done by the user, by hand. Auto mode refused an agent edit that widened its own allow list; permission widenings are made in Manual mode with the user's approval.
- How to use it: the `xcode-mcp` skill.

## Revision 2026-10-16
- Changed: "SwiftUI only (no UIKit)" has one exception, the page viewer, which wraps PDFKit's `PDFView` in a `UIViewRepresentable`. See ADR-004. Its file imports `SwiftUI` and `PDFKit` only, so `init.sh`'s UIKit rule does not change.
- Changed: ingestion uses PDFKit only. Vision is not used in the MVP (ADR-002).
