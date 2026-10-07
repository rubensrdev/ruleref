#!/bin/bash
# PostToolUse (Write|Edit) — checks the .swift file just written against the non-negotiables.
# It cannot undo the write; exit 2 sends the findings to Claude as immediate feedback.
# Grep-based: it flags suspects, it does not diagnose with certainty.

FILE_PATH=$(python3 -c '
import json, os, sys
try:
    ti = json.load(sys.stdin).get("tool_input", {}) or {}
except Exception:
    print(""); sys.exit(0)
for key in ("file_path", "path", "filePath", "filepath", "notebook_path"):
    v = ti.get(key)
    if isinstance(v, str) and v:
        if not os.path.isabs(v):
            v = os.path.join(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd(), v)
        print(v); break
else:
    print("")
')

case "$FILE_PATH" in *.swift) ;; *) exit 0 ;; esac
[ -f "$FILE_PATH" ] || exit 0
case "$FILE_PATH" in *Tests*|*Test.swift) IS_TEST=1 ;; *) IS_TEST=0 ;; esac

REPORT=""
flag() {
  local hits
  hits=$(grep -nE "$1" "$FILE_PATH" | head -3)
  [ -n "$hits" ] && REPORT="${REPORT}
[$2]
$hits"
}

flag 'try!'                                  'try! — use try/catch or try? with a real fallback'
flag 'as!'                                   'as! — use as? with guard let'
flag 'nonisolated\(unsafe\)'                 'nonisolated(unsafe) — forbidden, fix the isolation'
flag '@unchecked Sendable'                   '@unchecked Sendable — forbidden, fix the isolation'
flag '@preconcurrency'                       '@preconcurrency — forbidden, fix the isolation'
flag 'DispatchQueue|DispatchGroup|DispatchSemaphore' 'GCD — async/await only'
flag 'ObservableObject|@Published|@StateObject|@ObservedObject' 'legacy Observation — use @Observable'
flag 'NavigationView'                        'NavigationView — use NavigationStack'
flag '\.system\(size:'                       '.system(size:) — semantic text styles only'
flag 'AnyView'                               'AnyView — restructure instead'
flag 'JSONSerialization'                     'JSONSerialization — Codable only'
flag '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+UIKit\b' 'import UIKit — SwiftUI only (ADR-001)'
[ "$IS_TEST" -eq 0 ] && flag '(^|[^a-zA-Z])print\('  'print() — use Logger'
[ "$IS_TEST" -eq 1 ] && flag 'import XCTest' 'XCTest — Swift Testing only'

# Xcode 27: @State is a macro, so a custom init that assigns it before the other stored
# properties fails to compile. Flags the suspicious combination for manual review.
if grep -qE 'init\s*\(' "$FILE_PATH" && grep -qE '@State[^=]*=' "$FILE_PATH"; then
  hits=$(grep -nE '@State[^=]*=' "$FILE_PATH" | head -3)
  REPORT="${REPORT}
[@State with a default value + custom init — verify init doesn't assign to it before other stored properties (Xcode 27)]
$hits"
fi

# Xcode 27: a modified ShapeStyle passed directly to overlay/background becomes ambiguous.
flag '\.overlay\(.*\.(opacity|blendMode)\(|\.background\(.*\.(opacity|blendMode)\(' \
  'overlay/background with a modified ShapeStyle as a direct argument — use the trailing closure form (Xcode 27)'

if [ -n "$REPORT" ]; then
  echo "Constitution check on $(basename "$FILE_PATH") — review before continuing:$REPORT" >&2
  exit 2
fi

exit 0
