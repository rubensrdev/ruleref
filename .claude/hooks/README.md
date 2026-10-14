# Hooks

Wired in `.claude/settings.json`, except the two subagent hooks, which are wired in their subagent's frontmatter. Exit code 2 blocks the tool call.

- `protect-files.sh` (before Write/Edit): blocks edits to the Xcode project, secrets and credentials, `.git` internals, and DerivedData or `.build`.
- `block-dangerous-commands.sh` (before Bash): blocks `rm -rf`, `find -delete`, `chmod 777`, force push, `reset --hard`, `git clean -f`, writes to `.env`, piping downloads into a shell, and any write, copy, move or restore whose command text mentions `pbxproj` or `.xcodeproj`.
- `secrets-commit-guard.sh` (before Bash): on `git commit`, blocks staged secret files and diffs that look like keys or passwords.
- `constitution-lint.sh` (after Write/Edit of `.swift`): warns about `try!`, `as!`, unsafe isolation escapes, GCD, legacy Observation, `NavigationView`, `AnyView`, `JSONSerialization`, UIKit/XCTest, `print()` outside tests and two Xcode 27 pitfalls.
- `stop-build-gate.sh` (on Stop): runs `./init.sh` when non-Markdown files changed since the last green run, and keeps the turn going if it fails.
- `spec-approval-guard.sh` (before Write/Edit and Bash): blocks any agent from approving a spec or editing an approved one.
- `validator-readonly-bash.sh` (validator subagent only, before Bash): allows only `./init.sh`, read-only git, `xcrun xcresulttool get` and focused `xcodebuild test`.
- `implementer-no-accept.sh` (implementer subagent only, before Write/Edit and Bash): blocks setting any feature to `accepted`.
- `xcode-mcp-write-guard.sh` (before any `mcp__xcode__` tool): blocks by name the Xcode MCP tools that write files or change the project. They are also denied in `settings.json`; this is the second layer.

## Tests

`.claude/hooks/tests/run-cases.sh <hook> <cases.json>` runs one cases file per hook and compares exit codes. Run every cases file after changing a hook.
