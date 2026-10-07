#!/bin/bash
# Stop — green before finishing: runs ./init.sh when the code changed since the last green run.
# exit 2 = Claude keeps working. Without an executable init.sh the gate is inactive.
#
# The fingerprint covers tracked and untracked files, so committing before stopping or adding
# a new folder does not skip the gate. Markdown-only changes are ignored.
# The last green fingerprint lives inside .git, never in the working tree.

INPUT=$(cat)
STOP_ACTIVE=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("stop_hook_active", False))
except Exception:
    print(False)
')
[ "$STOP_ACTIVE" = "True" ] && exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT" 2>/dev/null || exit 0
[ -x ./init.sh ] || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Content only: a commit of an already green tree does not trigger another run.
fingerprint() {
  git ls-files --cached --others --exclude-standard -- . ':(exclude)*.md' | LC_ALL=C sort -u |
    while IFS= read -r f; do
      [ -f "$f" ] && [ ! -L "$f" ] && printf '%s %s\n' "$f" "$(git hash-object -- "$f")"
    done | git hash-object --stdin
}

MARKER=$(git rev-parse --git-path ruleref-last-green)
[ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$(fingerprint)" ] && exit 0

LOG=$(./init.sh 2>&1)
if [ $? -ne 0 ]; then
  echo "BLOCKED (definition of done): ./init.sh failed. Fix the cause before finishing. Last lines:" >&2
  printf '%s\n' "$LOG" | tail -30 >&2
  exit 2
fi

# Taken after the run: anything init.sh regenerates is part of the green state.
fingerprint > "$MARKER"
exit 0
