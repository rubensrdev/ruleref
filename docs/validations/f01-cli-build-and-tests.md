# Validations: f01-cli-build-and-tests

## Validation 1 — accept — 2026-10-14
- Commit validated: a687994162d07b7f71ff667431f7468d31235e1c
- Checks rerun:
  - `./init.sh`: exit 0; all 11 checks PASS (xcode-version: Xcode 27.0, simulator: iPhone 18 Pro, iOS 27.0, no-jsonserialization, no-uikit-xctest, no-third-party-deps, no-pdf-in-app, string-catalog, feature-list, xcodebuild-test, test-results, catalog-coverage); last line `init.sh: PASS`; test-results `totalTestCount=1, failedTests=0, skippedTests=0, expectedFailures=0`.
  - `git log --oneline --no-walk 76f55aa 80e5c04 a77be40 cd45432 5b76d93 aaf46dd`: all six commits the spec cites exist and match their tasks.
  - `git diff --stat aaf46dd a687994 -- RuleRef RuleRefTests init.sh`: the only change since the clean-clone evidence is the test-only Taifa fixture (ebde3ec).
  - `git ls-files RuleRef RuleRefTests`: template app only; one smoke test plus the fixture.
- Findings:
  - Info: `init.sh` uses `python3` in several checks, but preflight does not check that it is installed.
  - Info: a green `init.sh` deletes its result bundle by design, so `xcresulttool` could not inspect it; counts come from `init.sh` output.
  - Info: `validator-readonly-bash.sh` blocked a compound read-only git command; this only partly covers the planned live check that a validator write attempt is blocked.
- Not verified:
  - The clean-clone run at aaf46dd (the validator cannot clone; it ran in the existing checkout).
  - Exact Xcode build and simulator runtime build (`init.sh` prints only marketing versions).
  - Time of day of the run.
  - The result bundle via `xcresulttool` (deleted on a green run).
  - The gate's failure paths (preflight or rules failing; no Xcode 27, simulator or `python3`).
  - iOS 26.0 and a physical device.
  - The interface (no UI tests by design).
