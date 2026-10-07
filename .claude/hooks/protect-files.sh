#!/bin/bash
# PreToolUse (Write|Edit) — blocks files the agent never edits. exit 2 = block; stderr goes
# back to Claude as feedback. Only destination keys are read, never the content: a test may
# mention a protected path without being blocked.
#
# The Xcode project belongs to the user, who edits it in Xcode. Bash writes to it are
# blocked in block-dangerous-commands.sh.

FILE_PATH=$(python3 -c '
import json, sys
try:
    ti = json.load(sys.stdin).get("tool_input", {}) or {}
except Exception:
    print(""); raise SystemExit
for key in ("file_path", "path", "filePath", "filepath", "notebook_path", "destination"):
    v = ti.get(key)
    if isinstance(v, str) and v:
        print(v); raise SystemExit
print("")
')

[ -z "$FILE_PATH" ] && exit 0

deny() { echo "$1" >&2; exit 2; }

case "$FILE_PATH" in
  *project.pbxproj*|*.xcodeproj/*|*.xcworkspace/*)
    deny "BLOCKED: the Xcode project is edited only by the user, in Xcode. Source folders are synchronized, so new files inside them need no project change. If you need a target, setting, scheme or file membership change, stop and tell the user exactly what to change." ;;
  *.env.example|*.env.sample|*.env.template)
    ;;
  *.env|*.env.*|*credentials*|*.pem|*.p8|*.p12|*.mobileprovision)
    deny "BLOCKED: secrets and credential files are never edited by the agent. Ask the user." ;;
  */.git/*)
    deny "BLOCKED: .git internals are off-limits. Use git commands instead." ;;
  */DerivedData/*|*/.build/*)
    deny "BLOCKED: generated or cached content. Edit the source, not the cache." ;;
esac

exit 0
