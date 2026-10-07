#!/bin/bash
# PreToolUse (Bash) — blocks destructive commands before they run. exit 2 = block.
# Conservative patterns: better a rare manual override by the user than an unrecoverable loss.

CMD=$(python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    print("")
')

[ -z "$CMD" ] && exit 0

deny() { echo "BLOCKED: $1" >&2; exit 2; }

# Destructive filesystem commands, flags joined or split
echo "$CMD" | grep -qE '(^|[;&|(]\s*)rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)' && \
  deny "rm -rf is not allowed. Delete specific files explicitly, or ask the user."
echo "$CMD" | grep -qE '(^|[;&|(]\s*)rm\s+([^;&|]*\s)?(-[a-zA-Z]*r|--recursive)\b' && \
  echo "$CMD" | grep -qE '(^|[;&|(]\s*)rm\s+([^;&|]*\s)?(-[a-zA-Z]*f|--force)\b' && \
  deny "recursive forced rm is not allowed. Delete specific files explicitly, or ask the user."
echo "$CMD" | grep -qE '\bfind\b[^;&|]*\s-delete\b' && \
  deny "find -delete is not allowed. List the files first and ask the user."
echo "$CMD" | grep -qE '(^|[;&|(]\s*)sudo\s+rm' && \
  deny "sudo rm is never allowed."
echo "$CMD" | grep -qE 'chmod\s+(-R\s+)?777' && \
  deny "chmod 777 is never allowed. Use the minimum permissions needed."

# Destructive git
echo "$CMD" | grep -qE 'git\s+push\s+[^|;&]*(--force([^-]|$)|-f(\s|$))' && \
  deny "git push --force is not allowed. Use --force-with-lease only with explicit user approval."
echo "$CMD" | grep -qE 'git\s+reset\s+--hard' && \
  deny "git reset --hard discards work. Ask the user first."
echo "$CMD" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f' && \
  deny "git clean -f deletes untracked files. Ask the user first."

# The Xcode project is the user's, also through the shell
if echo "$CMD" | grep -qE 'pbxproj|\.xcodeproj'; then
  echo "$CMD" | grep -qE '>\s*[^&[:space:]]*(pbxproj|\.xcodeproj)|\bsed\s+[^;&|]*-i|\bperl\s+[^;&|]*-[a-zA-Z]*i|\btee\b|\b(mv|cp|rm|truncate|plutil|python3?|ruby|xcodegen)\b|git\s+(checkout|restore)\b' && \
    deny "the Xcode project is edited only by the user, in Xcode. Tell the user what to change."
fi

# Secrets via shell
echo "$CMD" | grep -qE '(>>?|tee)\s*[^ ]*\.env' && \
  deny "writing to .env files via shell is not allowed."

# Piping remote code into a shell
echo "$CMD" | grep -qE '(curl|wget)[^|;&]*\|\s*(ba|z)?sh' && \
  deny "piping downloaded content into a shell is not allowed. Download, review, then run."

exit 0
