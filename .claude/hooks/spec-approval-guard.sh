#!/bin/bash
# PreToolUse (Write|Edit|Bash), session-wide: only the user approves a spec, and no agent edits an approved one. exit 2 = block.
# Fails closed: unparseable input or any error is blocked.

if python3 -c '
import json, os, re, shlex, sys

APPROVAL = re.compile(r"^Approval: approved by the user on \d{4}-\d{2}-\d{2}\s*$", re.MULTILINE)
GIT_SUBCOMMANDS = ("add", "commit", "diff", "show", "log", "status")
WRITE_MSG = ("BLOCKED: only the user approves a spec, and an approved spec is never edited by an agent. "
             "To change it, ask the user to remove its Approval line first.")
BASH_MSG = ("BLOCKED: edit specs only with Edit or Write. "
            "In Bash you may only git add, commit, diff, show, log or status them.")

def block(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)

def check_file_edit(name, tool_input):
    path = tool_input["file_path"]
    if not os.path.isabs(path):
        path = os.path.join(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd(), path)
    if "/docs/specs/" not in path or not path.endswith(".md"):
        return
    try:
        with open(path, encoding="utf-8") as f:
            current = f.read()
    except OSError:
        current = ""

    if name == "Write":
        new = tool_input["content"]
    else:
        old_string, new_string = tool_input["old_string"], tool_input["new_string"]
        if old_string not in current:
            return  # The Edit tool fails on its own.
        count = -1 if tool_input.get("replace_all") else 1
        new = current.replace(old_string, new_string, count)

    if APPROVAL.search(current) or APPROVAL.search(new):
        block(WRITE_MSG)

def check_bash(cmd):
    if "docs/specs" not in cmd:
        return
    if ">" in cmd or re.search(r"\btee\b", cmd):
        block(BASH_MSG)
    # Command substitution would run inside an allowed git segment.
    if "$(" in cmd or "`" in cmd:
        block(BASH_MSG)
    # Newlines and a single & also separate commands.
    for segment in re.split(r"&&|\|\||;|\||&|\n", cmd):
        if "docs/specs" not in segment:
            continue
        try:
            tokens = shlex.split(segment)
        except ValueError:
            block(BASH_MSG)
        if len(tokens) < 2 or tokens[0] != "git" or tokens[1] not in GIT_SUBCOMMANDS:
            block(BASH_MSG)
        if any(t.startswith("--output") for t in tokens):
            block(BASH_MSG)

try:
    data = json.load(sys.stdin)
    name = data["tool_name"]
    tool_input = data["tool_input"]
except Exception:
    block("BLOCKED: spec-approval-guard could not parse the hook input.")

if name in ("Write", "Edit"):
    check_file_edit(name, tool_input)
elif name == "Bash":
    check_bash(tool_input["command"])
sys.exit(0)
'; then
  exit 0
fi
exit 2
