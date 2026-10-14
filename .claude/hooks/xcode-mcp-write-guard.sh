#!/bin/bash
# PreToolUse (mcp__xcode__.*): second layer behind the mcp__xcode__ deny rules in settings.json. exit 2 = block.
# Blocks by tool name the Xcode MCP tools that write files or change the project: they take Xcode project
# paths, which protect-files.sh and spec-approval-guard.sh cannot match. Fails closed.
# Keep WRITE_TOOLS equal to the mcp__xcode__ entries under permissions.deny.

if python3 -c '
import json, sys

PREFIX = "mcp__xcode__"
WRITE_TOOLS = {
    "XcodeWrite", "XcodeUpdate", "XcodeMakeDir", "XcodeMV", "XcodeRM",
    "XcodeNewProject", "XcodeNewTarget",
    "AddEntitlement", "AddInfoPlist", "UpdateTargetBuildSetting", "UpdateFileCompilerFlags",
    "StringCatalogEdit", "LocalizationPlanner",
}
MSG = ("BLOCKED: {} writes files or changes the Xcode project. Edit sources with Edit or Write, "
       "so the file hooks and init.sh check them. Project, target, Info.plist, entitlement and "
       "localization changes are made only by the user, in Xcode.")

def block(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)

try:
    name = json.load(sys.stdin)["tool_name"]
except Exception:
    block("BLOCKED: xcode-mcp-write-guard could not parse the hook input.")
if not isinstance(name, str):
    block("BLOCKED: xcode-mcp-write-guard could not parse the hook input.")

if name.startswith(PREFIX) and name[len(PREFIX):] in WRITE_TOOLS:
    block(MSG.format(name))
sys.exit(0)
'; then
  exit 0
fi
exit 2
