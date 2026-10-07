#!/bin/bash
# PreToolUse (Bash) — on `git commit`, scans the staged diff for secrets. exit 2 = block.
# The repo is public: a committed key is a leaked key, even if removed later.
# Case-insensitive. Catches quoted and unquoted (.env style) assignments, well-known key
# prefixes, private keys, and staged .env or credential files.

CMD=$(python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    print("")
')

echo "$CMD" | grep -qE '(^|[;&|]\s*)git\s+([^;&|]*\s)?commit\b' || exit 0

deny() { echo "BLOCKED: $1" >&2; exit 2; }

FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
BAD_FILES=$(printf '%s\n' "$FILES" | grep -E '(^|/)\.env($|\.)|credentials|\.(pem|p8|p12|mobileprovision)$' | grep -vE '\.env\.(example|sample|template)$')
[ -n "$BAD_FILES" ] && deny "secret or credential files are staged. Unstage them and make sure .gitignore covers them:
$BAD_FILES"

STAGED=$(git diff --cached --unified=0 2>/dev/null | grep '^+' | grep -v '^+++')
[ -z "$STAGED" ] && exit 0

NAME='[a-z0-9_.-]*(api[_-]?key|secret|token|password|passwd|auth)[a-z0-9_]*'
QUOTED="${NAME}\s*[:=]\s*[\"'][^\"']{8,}"
UNQUOTED="${NAME}\s*[:=]\s*[a-z0-9_./+-]*[0-9][a-z0-9_./+-]{11,}\s*$"
PREFIXES='sk-[a-z0-9_-]{20,}|sk_(live|test)_[a-z0-9]{10,}|AIza[0-9a-z_-]{30,}|gh[pousr]_[a-z0-9]{30,}|github_pat_[a-z0-9_]{30,}|AKIA[0-9a-z]{16}|-----BEGIN ([a-z]+ )?PRIVATE KEY'

FOUND=$(printf '%s\n' "$STAGED" | grep -niE "${QUOTED}|${UNQUOTED}|${PREFIXES}" \
  | grep -viE 'placeholder|example|your[_-]?key|<[^>]+>|\$\{|\$\(|ProcessInfo|environment')

if [ -n "$FOUND" ]; then
  deny "possible secrets in the staged diff. Keep keys out of the repo (Keychain, or a git-ignored file read at runtime):
$(printf '%s\n' "$FOUND" | head -10)"
fi

exit 0
