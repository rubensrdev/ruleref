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
APP_TARGET="RuleRef"
FEATURE_LIST="feature_list.json"

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
    print("No .xcstrings found; the app is bilingual (en, es) and needs RuleRef/Localizable.xcstrings.")
    sys.exit(1)

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
if [ $? -eq 0 ]; then
  pass "string-catalog"
else
  fail "string-catalog"; RULES_OK=0
fi

python3 - "$FEATURE_LIST" <<'PY'
import json, re, sys

path = sys.argv[1]
FIELDS = ("id", "area", "title", "user_visible_behavior", "depends_on", "status",
          "verification", "evidence", "notes")
STATUSES = ("not_started", "in_progress", "blocked", "passing", "accepted")
CONTEXT_FIELDS = ("date", "commit", "xcode", "simulator")
ID_RE = re.compile(r"f\d{2}(-[a-z0-9]+)+")

try:
    with open(path, encoding="utf-8") as f:
        features = json.load(f)
except (OSError, ValueError) as error:
    print(f"{path}: {error}")
    sys.exit(1)
if not isinstance(features, list) or not all(isinstance(f, dict) for f in features):
    print(f"{path}: must be a JSON array of feature objects.")
    sys.exit(1)

def filled(value):
    return isinstance(value, str) and value.strip() != ""

def complete(item):
    if not isinstance(item, dict):
        return False
    context = item.get("context")
    return (
        all(filled(item.get(k)) for k in ("command", "expected", "observed"))
        and isinstance(context, dict) and all(filled(context.get(k)) for k in CONTEXT_FIELDS)
        and isinstance(item.get("not_verified"), list)
        and all(filled(v) for v in item["not_verified"])
    )

errors = []
by_id = {}
for index, feature in enumerate(features):
    fid = feature.get("id")
    name = fid if filled(fid) else f"feature #{index}"
    missing = [k for k in FIELDS if k not in feature]
    if missing:
        errors.append(f"{name}: missing {', '.join(missing)}")
    if not isinstance(fid, str) or not ID_RE.fullmatch(fid):
        errors.append(f"{name}: id must be fNN-lowercase-kebab")
    elif fid in by_id:
        errors.append(f"{name}: duplicate id")
    else:
        by_id[fid] = feature
    for key in ("area", "title", "user_visible_behavior", "notes"):
        if key in feature and not filled(feature[key]):
            errors.append(f"{name}: {key} must be a non-empty string")
    if "status" in feature and feature["status"] not in STATUSES:
        errors.append(f"{name}: status {feature['status']!r} not in {', '.join(STATUSES)}")
    for key in ("depends_on", "verification", "evidence"):
        if key in feature and not isinstance(feature[key], list):
            errors.append(f"{name}: {key} must be a list")
    steps = feature.get("verification")
    if isinstance(steps, list) and not (steps and all(filled(v) for v in steps)):
        errors.append(f"{name}: verification must list non-empty steps")
    evidence = feature.get("evidence") if isinstance(feature.get("evidence"), list) else []
    for n, item in enumerate(evidence, 1):
        if not complete(item):
            errors.append(f"{name}: evidence #{n} needs non-empty command, expected, observed, "
                          f"context ({', '.join(CONTEXT_FIELDS)}) and a not_verified list")
    if feature.get("status") in ("passing", "accepted") and not any(complete(e) for e in evidence):
        errors.append(f"{name}: {feature['status']} needs at least one complete evidence entry")

in_progress = [f["id"] for f in by_id.values() if f.get("status") == "in_progress"]
if len(in_progress) > 1:
    errors.append(f"at most one feature may be in_progress, found {len(in_progress)}: {', '.join(in_progress)}")

graph = {}
for fid, feature in by_id.items():
    deps = feature.get("depends_on") if isinstance(feature.get("depends_on"), list) else []
    graph[fid] = []
    for dep in deps:
        if not isinstance(dep, str):
            errors.append(f"{fid}: depends_on must hold id strings")
        elif dep == fid:
            errors.append(f"{fid}: depends on itself")
        elif dep not in by_id:
            errors.append(f"{fid}: depends on unknown id {dep!r}")
        else:
            graph[fid].append(dep)
            if feature.get("status") in ("in_progress", "passing", "accepted") and by_id[dep].get("status") != "accepted":
                errors.append(f"{fid}: is {feature['status']} but dependency {dep} is "
                              f"{by_id[dep].get('status')}, not accepted")

state = {}
def visit(fid, path):
    state[fid] = "visiting"
    for dep in graph[fid]:
        if state.get(dep) == "visiting":
            cycle = path[path.index(dep):] + [dep]
            errors.append("dependency cycle: " + " -> ".join(cycle))
        elif dep not in state:
            visit(dep, path + [dep])
    state[fid] = "done"
for fid in graph:
    if fid not in state:
        visit(fid, [fid])

if errors:
    print(f"{path}: {len(errors)} problem(s):")
    print("\n".join(f"  {e}" for e in errors[:20]))
sys.exit(1 if errors else 0)
PY
if [ $? -eq 0 ]; then
  pass "feature-list"
else
  fail "feature-list"; RULES_OK=0
fi

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
  BUILD_STATUS=$?
  if [ "$BUILD_STATUS" -eq 0 ]; then
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

  # The CLI never syncs the catalog (only the IDE does), so replay that sync on a copy
  # and fail on any key the copy gains. Runs only after a clean build, so the
  # .stringsdata files of every compiled source are current.
  if [ "$BUILD_STATUS" -eq 0 ]; then
    OBJ_DIR=$(xcodebuild -showBuildSettings -json -project "$PROJECT" -scheme "$SCHEME" \
      -destination "$DESTINATION" 2>/dev/null | python3 -c '
import json, sys
for entry in json.load(sys.stdin):
    if entry.get("target") == sys.argv[1]:
        print(entry["buildSettings"].get("OBJECT_FILE_DIR_normal", ""))
' "$APP_TARGET")
    if python3 - "$OBJ_DIR" "$APP_TARGET" "$APP_DIR" "$WORK_DIR/catalog-sync" <<'PY'
import glob, json, os, shutil, subprocess, sys

obj_dir, target, app_dir, sync_dir = sys.argv[1:5]

file_lists = glob.glob(os.path.join(obj_dir, "*", target + ".SwiftFileList")) if obj_dir else []
if len(file_lists) != 1:
    print(f"Expected one {target}.SwiftFileList under '{obj_dir}', found {len(file_lists)}.")
    sys.exit(1)
arch_dir = os.path.dirname(file_lists[0])
with open(file_lists[0], encoding="utf-8") as f:
    sources = {line.strip() for line in f if line.strip()}

# A source deleted from the app leaves its .stringsdata behind; keep only those of
# sources compiled in this build.
stringsdata, tables = {}, set()
for path in glob.glob(os.path.join(arch_dir, "*.stringsdata")):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if data.get("source") in sources:
        stringsdata[data["source"]] = path
        tables.update(t for t, keys in data.get("tables", {}).items() if keys)
unextracted = sorted(sources - stringsdata.keys())
if unextracted:
    print("No .stringsdata for these sources (is SWIFT_EMIT_LOC_STRINGS on?):")
    print("\n".join(f"  {s}" for s in unextracted[:10]))
    sys.exit(1)

catalogs = sorted(
    os.path.join(root, name)
    for root, _, names in os.walk(app_dir)
    for name in names
    if name.endswith(".xcstrings")
)
# sync matches tables by file name, so each copy keeps its name in its own folder.
copies = []
for index, original in enumerate(catalogs):
    copy = os.path.join(sync_dir, str(index), os.path.basename(original))
    os.makedirs(os.path.dirname(copy))
    shutil.copyfile(original, copy)
    copies.append((original, copy))

command = ["xcrun", "xcstringstool", "sync", *[c for _, c in copies], "--skip-marking-strings-stale"]
for path in sorted(stringsdata.values()):
    command += ["--stringsdata", path]
result = subprocess.run(command, capture_output=True, text=True)
if result.returncode != 0:
    print("xcstringstool sync failed:", result.stderr.strip() or result.stdout.strip())
    sys.exit(1)

def strings(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f).get("strings", {})

def string_units(node):
    if isinstance(node, dict):
        if "stringUnit" in node:
            yield node["stringUnit"]
        for value in node.values():
            yield from string_units(value)
    elif isinstance(node, list):
        for value in node:
            yield from string_units(value)

def translated(entry):
    units = list(string_units(entry.get("localizations", {}).get("es", {})))
    return bool(units) and all(u.get("state") == "translated" for u in units)

ok = True
for original, copy in copies:
    before, after = strings(original), strings(copy)
    missing = sorted(after.keys() - before.keys())
    if missing:
        ok = False
        print(f"{original}: {len(missing)} string(s) in code but not in the catalog (add each with its 'es' translation):")
        print("\n".join(f"  {k!r}" for k in missing[:10]))
    # string-catalog skips stale keys; sync clears "stale" on the ones the code uses again.
    revived = sorted(
        k for k, entry in before.items()
        if entry.get("extractionState") == "stale" and k in after
        and after[k].get("extractionState") != "stale"
        and entry.get("shouldTranslate") is not False and not translated(entry)
    )
    if revived:
        ok = False
        print(f"{original}: {len(revived)} key(s) marked stale but used in code, without a translated 'es' value:")
        print("\n".join(f"  {k!r}" for k in revived[:10]))
orphan_tables = sorted(tables - {os.path.splitext(os.path.basename(c))[0] for c in catalogs})
if orphan_tables:
    ok = False
    print("Strings in code use tables with no catalog: " + ", ".join(orphan_tables))
sys.exit(0 if ok else 1)
PY
    then
      pass "catalog-coverage"
    else
      fail "catalog-coverage"
    fi
  else
    skip "catalog-coverage" "build failed"
  fi

  # Keep the log and result bundle only when something failed.
  [ "$FAILED" -eq 0 ] && rm -r "$WORK_DIR"
else
  skip "xcodebuild-test" "preflight or rules failed"
  skip "test-results" "preflight or rules failed"
  skip "catalog-coverage" "preflight or rules failed"
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
