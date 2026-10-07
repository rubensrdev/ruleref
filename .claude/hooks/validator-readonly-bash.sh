#!/bin/bash
# PreToolUse (Bash) for the validator subagent only: an allowlist of read-only commands. exit 2 = block.
# Fails closed: anything not explicitly allowed, or any error, is blocked.
# Wired in the validator's frontmatter, never in settings.json (it would also block the main session).

if python3 -c '
import json, shlex, sys

GIT_SUBCOMMANDS = ("status", "diff", "log", "show", "ls-files", "rev-parse")

def allowed(cmd):
    # Conservative on purpose: these are rejected even inside quotes.
    if any(c in cmd for c in (";", "&", "|", ">", "<", "`", "$(", "\n")):
        return False
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return False
    if not tokens:
        return False
    head, args = tokens[0], tokens[1:]
    if head == "./init.sh":
        return not args
    if head == "git":
        # Global options before the subcommand (-c, -C, --git-dir...) can run code.
        if not args or args[0] not in GIT_SUBCOMMANDS:
            return False
        return not any(t.startswith("--output") or t == "--ext-diff" for t in args)
    if head == "xcrun":
        return args[:2] == ["xcresulttool", "get"]
    if head == "xcodebuild":
        return (args[:1] == ["test"]
                and any(t.startswith("-only-testing:") for t in args)
                and not any(t.startswith(("-resultBundlePath", "-derivedDataPath")) for t in args))
    return False

try:
    data = json.load(sys.stdin)
    cmd = data["tool_input"]["command"]
except Exception:
    sys.exit(2)
if not isinstance(cmd, str):
    sys.exit(2)
if data.get("tool_name", "Bash") != "Bash":
    sys.exit(0)
sys.exit(0 if allowed(cmd) else 2)
'; then
  exit 0
fi

echo "BLOCKED: the validator is read-only. Allowed Bash commands: ./init.sh; git status|diff|log|show|ls-files|rev-parse; xcrun xcresulttool get; xcodebuild test with -only-testing:. Run them from the repository root, without cd, pipes or redirection. Read files with Read, Grep and Glob. If you need another command, say so in your report." >&2
exit 2
