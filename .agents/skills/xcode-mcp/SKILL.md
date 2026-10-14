---
name: xcode-mcp
description: How to use the Xcode 27 MCP server (mcp__xcode__ tools) in RuleRef: opening the workspace, project paths, which tools are allowed, ask or denied, and what they never replace. Use before calling any mcp__xcode__ tool, or when deciding whether one fits a task.
---

# Xcode MCP (RuleRef)

The Xcode 27 MCP server is declared in `.mcp.json` as `xcode` (`xcrun mcpbridge`) and runs headless: no Xcode window is needed. It is an interactive aid for the main session. Decision and reasons: `docs/adr/0001-stack-and-build-doctrine.md`, revision 2026-10-14.

## Never the gate

- `./init.sh` is the only definition of "builds and passes". A result from `BuildProject`, `RunAllTests` or `RunSomeTests` is never evidence in `feature_list.json` or in a validation.
- Those tools build the workspace's active scheme and run destination, not the pinned simulator, and skip the source rules, `feature-list`, `xcresulttool` and `catalog-coverage` checks.
- `./init.sh` uses the default DerivedData, like Xcode. Never run an Xcode MCP build or test while `./init.sh` is running.

## Who uses it

- Main session only. The implementer has none of its tools (`disallowedTools: mcp__xcode`) and the validator has none (explicit `tools` list).
- Apple documentation: Cupertino first (`AGENTS.md`); `DocumentationSearch` is a complement.

## Workflow

1. `XcodeOpenWorkspace` with the absolute path of `RuleRef.xcodeproj` at the repo root. It returns a `workspaceIdentifier`.
2. Pass that `workspaceIdentifier` to every other call.
3. Paths are Xcode project paths, not filesystem paths: `RuleRef/RuleRef/ContentView.swift`, `RuleRef/RuleRefTests/RuleRefTests.swift`.
4. `XcodeCloseWorkspace` when done.

## Allowed (no prompt)

- Workspace: `XcodeListWorkspaces`, `XcodeOpenWorkspace`, `XcodeCloseWorkspace`.
- Files, read only: `XcodeRead`, `XcodeGlob`, `XcodeGrep`, `XcodeLS`.
- Project state, read only: `XcodeListSchemes`, `XcodeListTargets`, `XcodeListRunDestinations`, `XcodeListTestPlans`, `XcodeListTemplates`, `GetTargetBuildSettings`, `GetFileCompilerFlags`.
- Diagnostics: `XcodeRefreshCodeIssuesInFile` (compiler diagnostics for one file, without a full build), `GetBuildLog`, `GetTestList`, `GetConsoleOutput`.
- Docs: `DocumentationSearch`.

## Ask (the user approves each call)

- Build and test: `BuildProject`, `RunAllTests`, `RunSomeTests`.
- Previews: `RenderPreview`. A visual check in the main session; never validation evidence, because the user validates the interface by hand.
- Run and debug: `RunProject`, `StopProject`, `RunCodeSnippet`, `InvokeDebuggerCommand`. `RunCodeSnippet` suits probing how an Apple API behaves before writing the test that pins it.
- Simulator and devices: `DeviceInteractionStartSession`, `DeviceInteractionStartWorkspaceSession`, `DeviceInteractionInstallAndRun`, `DeviceInteractionSynthesize`, `DeviceInteractionEndSession`. Always end the session.
- IDE state: `XcodeSwitchScheme`, `XcodeSwitchRunDestination`, `XcodeSwitchTestPlan`.
- String Catalog: `StringCatalogRead`, `StringCatalogContext`. They require Apple's `xcode-integration` skills, which this repo does not have; read `RuleRef/Localizable.xcstrings` instead.
- App Store data: `GetTopCrashIssues`, `GetCrashIssueLogs`, `GetTopFieldPerformanceIssues`, `GetFieldPerformanceIssueLogs`. Not applicable until the app is published.

## Denied

`XcodeWrite`, `XcodeUpdate`, `XcodeMakeDir`, `XcodeMV`, `XcodeRM`, `XcodeNewProject`, `XcodeNewTarget`, `AddEntitlement`, `AddInfoPlist`, `UpdateTargetBuildSetting`, `UpdateFileCompilerFlags`, `StringCatalogEdit`, `LocalizationPlanner`.

They are denied in `.claude/settings.json` and blocked again by `.claude/hooks/xcode-mcp-write-guard.sh`. Edit sources with Edit or Write, so the file hooks and `./init.sh` check them. Project, target, Info.plist, entitlement and localization changes are made only by the user, in Xcode.

## When the tool list changes

The server exposed 54 tools on 2026-10-14 (41 visible plus the 13 denied). If the visible count is not 41, or after any Xcode update, stop and tell the user: every new tool must be classified in `.claude/settings.json`, and every new write tool also added to the hook's `WRITE_TOOLS` with a test case.

## Machine setup (the user, by hand)

Headless mode enabled, Claude Code a permitted agent and this repo a permitted folder (`xcrun mcp-server status`). Never run `xcrun mcp-server` commands that need `sudo`, and never pass `--unsafe-always-allow-all-agents`.
