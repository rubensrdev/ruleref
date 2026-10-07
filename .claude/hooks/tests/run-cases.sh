#!/bin/bash
# Runs a PreToolUse Bash hook against a JSON array of cases and compares exit codes.
# Usage: run-cases.sh <hook> <cases.json>
# Each case has name, expected_exit and one of: command (wrapped as a Bash tool call),
# input (a full hook input object, sent as JSON) or raw_stdin (sent as is).

if [ $# -ne 2 ]; then
  echo "usage: $0 <hook> <cases.json>" >&2
  exit 64
fi

python3 -c '
import json, os, subprocess, sys

hook = os.path.abspath(sys.argv[1])
with open(sys.argv[2]) as f:
    cases = json.load(f)

failed = 0
for case in cases:
    if "raw_stdin" in case:
        stdin = case["raw_stdin"]
    elif "input" in case:
        stdin = json.dumps(case["input"])
    else:
        stdin = json.dumps({"tool_name": "Bash", "tool_input": {"command": case["command"]}})
    result = subprocess.run([hook], input=stdin, capture_output=True, text=True)
    expected = case["expected_exit"]
    if result.returncode == expected:
        print("PASS  " + case["name"] + " (exit " + str(result.returncode) + ")")
    else:
        failed += 1
        print("FAIL  " + case["name"] + " (expected " + str(expected) + ", got " + str(result.returncode) + ")")

print(str(len(cases) - failed) + " passed, " + str(failed) + " failed")
sys.exit(1 if failed else 0)
' "$1" "$2"
