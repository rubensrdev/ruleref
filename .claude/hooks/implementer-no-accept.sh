#!/bin/bash
# PreToolUse (Write|Edit|Bash) for the implementer subagent only: it never sets a feature to accepted. exit 2 = block.
# Fails closed: unparseable input or any error is blocked.
# Wired in the implementer's frontmatter, never in settings.json (the main session does set accepted).

if python3 -c '
import json, os, re, shlex, sys

ACCEPTED = re.compile(r"\"status\"\s*:\s*\"accepted\"")
GIT_SUBCOMMANDS = ("add", "commit", "diff", "show", "log", "status")
WRITE_MSG = ("BLOCKED: the implementer never sets a feature to accepted. Leave it passing; "
             "acceptance belongs to the orchestrating main session after the validator and the user (see AGENTS.md).")
BASH_MSG = ("BLOCKED: edit feature_list.json only with Edit or Write. "
            "In Bash you may only git add, commit, diff, show, log or status it.")

def block(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)

def accepted_ids(text):
    try:
        features = json.loads(text)
    except ValueError:
        return None
    if not isinstance(features, list):
        return set()
    return {f.get("id") for f in features if isinstance(f, dict) and f.get("status") == "accepted"}

def check_file_edit(name, tool_input):
    path = tool_input["file_path"]
    if os.path.basename(path) != "feature_list.json":
        return
    if not os.path.isabs(path):
        path = os.path.join(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd(), path)
    try:
        with open(path, encoding="utf-8") as f:
            current = f.read()
    except OSError:
        current = ""
    old_ids = accepted_ids(current)
    # A missing or unparseable file counts as having no accepted features.
    old_count = 0 if old_ids is None else len(ACCEPTED.findall(current))
    old_ids = old_ids or set()

    if name == "Write":
        new = tool_input["content"]
    else:
        old_string, new_string = tool_input["old_string"], tool_input["new_string"]
        if old_string not in current:
            return  # The Edit tool fails on its own.
        count = -1 if tool_input.get("replace_all") else 1
        new = current.replace(old_string, new_string, count)

    if len(ACCEPTED.findall(new)) > old_count:
        block(WRITE_MSG)
    new_ids = accepted_ids(new)
    if new_ids and new_ids - old_ids:
        block(WRITE_MSG)

def check_bash(cmd):
    if "feature_list.json" not in cmd:
        return
    if ">" in cmd or re.search(r"\btee\b", cmd):
        block(BASH_MSG)
    # Command substitution would run inside an allowed git segment.
    if "$(" in cmd or "`" in cmd:
        block(BASH_MSG)
    # Newlines and a single & also separate commands.
    for segment in re.split(r"&&|\|\||;|\||&|\n", cmd):
        if "feature_list.json" not in segment:
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
    block("BLOCKED: implementer-no-accept could not parse the hook input.")

if name in ("Write", "Edit"):
    check_file_edit(name, tool_input)
elif name == "Bash":
    check_bash(tool_input["command"])
sys.exit(0)
'; then
  exit 0
fi
exit 2
