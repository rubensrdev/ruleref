#!/bin/bash
# The single gate for "builds and passes" (ADR-001): preflight, source rules, build and tests.
# Exits 0 only when every check passes. Ends with one PASS/FAIL/SKIP line per check,
# because the Stop hook only shows the last 30 lines.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

SCHEME="RuleRef"
PROJECT="RuleRef.xcodeproj"
DESTINATION="platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0"
XCODE_MAJOR="27"

SOURCE_DIRS=(RuleRef RuleRefTests)
APP_DIR="RuleRef"

SUMMARY=()
FAILED=0

pass() { SUMMARY+=("PASS  $1"); }
fail() { SUMMARY+=("FAIL  $1"); FAILED=1; }
skip() { SUMMARY+=("SKIP  $1 ($2)"); }
section() { echo "== $1"; }

swift_grep() {
  grep -rnE --include='*.swift' "$1" "${SOURCE_DIRS[@]}" 2>/dev/null
}

# --- a) Preflight --------------------------------------------------------------

section "Preflight"
PREFLIGHT_OK=1

XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)
if [[ "$XCODE_VERSION" =~ ^Xcode\ ${XCODE_MAJOR}(\.|$) ]]; then
  pass "xcode-version: $XCODE_VERSION"
else
  echo "Xcode $XCODE_MAJOR is required; xcodebuild reports: '${XCODE_VERSION:-nothing}'."
  echo "Install Xcode $XCODE_MAJOR and select it: sudo xcode-select -s /Applications/Xcode.app"
  fail "xcode-version: Xcode $XCODE_MAJOR required"
  PREFLIGHT_OK=0
fi

SIM_NAME=$(sed -E 's/.*name=([^,]+).*/\1/' <<< "$DESTINATION")
SIM_OS=$(sed -E 's/.*OS=([^,]+).*/\1/' <<< "$DESTINATION")
if xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, sys
name, os_version = sys.argv[1], sys.argv[2]
runtime = "com.apple.CoreSimulator.SimRuntime.iOS-" + os_version.replace(".", "-")
devices = json.load(sys.stdin).get("devices", {}).get(runtime, [])
sys.exit(0 if any(d.get("name") == name for d in devices) else 1)
' "$SIM_NAME" "$SIM_OS"; then
  pass "simulator: $SIM_NAME, iOS $SIM_OS"
else
  echo "Simulator '$SIM_NAME' with iOS $SIM_OS is not available."
  echo "Install the iOS $SIM_OS runtime (Xcode > Settings > Components) and create the device"
  echo "in Xcode > Window > Devices and Simulators. List what exists: xcrun simctl list devices"
  fail "simulator: $SIM_NAME, iOS $SIM_OS not found"
  PREFLIGHT_OK=0
fi

# --- b) Rules ------------------------------------------------------------------

section "Rules"
RULES_OK=1

HITS=$(swift_grep '\bJSONSerialization\b')
if [ -z "$HITS" ]; then
  pass "no-jsonserialization"
else
  echo "JSONSerialization is forbidden; use Codable:"; echo "$HITS" | head -10
  fail "no-jsonserialization"; RULES_OK=0
fi

# Covers attributes (@preconcurrency, @_exported), access levels and kind/submodule imports.
IMPORT_RE='^[[:space:]]*(@[A-Za-z_]+(\([^)]*\))?[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?(UIKit|XCTest)\b'
HITS=$(swift_grep "$IMPORT_RE")
if [ -z "$HITS" ]; then
  pass "no-uikit-xctest"
else
  echo "UIKit and XCTest imports are forbidden (SwiftUI and Swift Testing only):"; echo "$HITS" | head -10
  fail "no-uikit-xctest"; RULES_OK=0
fi

DEP_HITS=$(grep -n 'XCRemoteSwiftPackageReference' "$PROJECT/project.pbxproj" 2>/dev/null | head -5)
RESOLVED=$(find . -path ./.git -prune -o -name Package.resolved -print 2>/dev/null)
if [ -z "$DEP_HITS" ] && [ -z "$RESOLVED" ]; then
  pass "no-third-party-deps"
else
  echo "Third-party dependencies are forbidden:"
  [ -n "$DEP_HITS" ] && echo "$PROJECT/project.pbxproj: $DEP_HITS"
  [ -n "$RESOLVED" ] && echo "$RESOLVED"
  fail "no-third-party-deps"; RULES_OK=0
fi

# Rulebook PDFs are test fixtures, never bundled; vector icons inside asset catalogs are fine.
PDFS=$(find "$APP_DIR" -name '*.xcassets' -prune -o -type f -iname '*.pdf' -print 2>/dev/null)
if [ -z "$PDFS" ]; then
  pass "no-pdf-in-app"
else
  echo "PDFs must not ship in the app bundle:"; echo "$PDFS" | head -10
  fail "no-pdf-in-app"; RULES_OK=0
fi

python3 - "${SOURCE_DIRS[@]}" <<'PY'
import json, os, sys

# English is the development language: the key is the English text, so only "es" is required.
def string_units(node):
    if isinstance(node, dict):
        if "stringUnit" in node:
            yield node["stringUnit"]
        for value in node.values():
            if isinstance(value, (dict, list)):
                yield from string_units(value)
    elif isinstance(node, list):
        for value in node:
            yield from string_units(value)

paths = sorted(
    os.path.join(root, name)
    for top in sys.argv[1:]
    for root, _, names in os.walk(top)
    for name in names
    if name.endswith(".xcstrings")
)
if not paths:
    sys.exit(3)

ok = True
for path in paths:
    try:
        with open(path, encoding="utf-8") as f:
            catalog = json.load(f)
    except (OSError, ValueError) as error:
        print(f"{path}: invalid JSON: {error}")
        ok = False
        continue
    missing = []
    for key, entry in catalog.get("strings", {}).items():
        if entry.get("extractionState") == "stale" or entry.get("shouldTranslate") is False:
            continue
        es = entry.get("localizations", {}).get("es")
        # Plural, device and substitution variations nest their own stringUnits; all must be translated.
        units = list(string_units(es)) if es else []
        if not units or any(u.get("state") != "translated" for u in units):
            missing.append(key)
    if missing:
        ok = False
        print(f"{path}: {len(missing)} key(s) without a translated 'es' value:")
        for key in missing[:10]:
            print(f"  {key!r}")
sys.exit(0 if ok else 1)
PY
case $? in
  0) pass "string-catalog" ;;
  3) skip "string-catalog" "no .xcstrings found" ;;
  *) fail "string-catalog"; RULES_OK=0 ;;
esac

# --- c) Build and tests --------------------------------------------------------

if [ "$PREFLIGHT_OK" -eq 1 ] && [ "$RULES_OK" -eq 1 ]; then
  section "Build and tests"
  TMP_ROOT="${TMPDIR:-/tmp}"
  WORK_DIR=$(mktemp -d "${TMP_ROOT%/}/ruleref-init.XXXXXX")
  RESULT_BUNDLE="$WORK_DIR/Test.xcresult"
  LOG="$WORK_DIR/xcodebuild.log"

  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -resultBundlePath "$RESULT_BUNDLE" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    > "$LOG" 2>&1
  if [ $? -eq 0 ]; then
    pass "xcodebuild-test"
  else
    echo "xcodebuild test failed. Relevant lines (full log: $LOG):"
    grep -E 'error:|✘|\*\* [A-Z ]+ FAILED \*\*' "$LOG" | awk '!seen[$0]++' | head -20
    fail "xcodebuild-test"
  fi

  if [ -d "$RESULT_BUNDLE" ] && xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE" 2>/dev/null | python3 -c '
import json, sys
summary = json.load(sys.stdin)
fields = ("totalTestCount", "failedTests", "skippedTests", "expectedFailures")
missing = [f for f in fields if f not in summary]
if missing:
    print("xcresulttool summary lacks: " + ", ".join(missing)); sys.exit(1)
counts = {f: summary[f] for f in fields}
print(", ".join(f"{k}={v}" for k, v in counts.items()))
ok = counts["totalTestCount"] > 0 and all(counts[f] == 0 for f in fields[1:])
sys.exit(0 if ok else 1)
'; then
    pass "test-results"
  else
    [ -d "$RESULT_BUNDLE" ] || echo "No result bundle at $RESULT_BUNDLE."
    fail "test-results"
  fi

  # Keep the log and result bundle only when something failed.
  [ "$FAILED" -eq 0 ] && rm -r "$WORK_DIR"
else
  skip "xcodebuild-test" "preflight or rules failed"
  skip "test-results" "preflight or rules failed"
fi

# --- d) Summary ----------------------------------------------------------------

section "Summary"
printf '%s\n' "${SUMMARY[@]}"
if [ "$FAILED" -eq 0 ]; then
  echo "init.sh: PASS"
  exit 0
fi
echo "init.sh: FAIL"
exit 1
