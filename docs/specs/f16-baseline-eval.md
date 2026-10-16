# Feature Implementation Spec: Baseline search evaluation

Approval: approved by the user on 2026-10-16

## Source Feature

- `id`: f16-baseline-eval
- `area`: evaluation
- `depends_on`: f13-text-search, f14-no-match-state, f18-paragraph-cut-calibration (all `accepted`)
- `status`: not_started
- `source`: `feature_list.json`

## Goal

Measure today's text search on the eval set, so AI retrieval after m4 has a number to beat. A test in the test target decodes `RuleRefTests/Fixtures/taifa-3.0-eval.json`, imports the Taifa fixture through the same path as the app into an in-memory store, runs each question's `query` through `SearchIndex`, and writes a Codable JSON report with hit@1, hit@3 and no-match accuracy, tagged with the iOS version. The report is attached to the test with Swift Testing `Attachment`; the implementer exports it from a focused run and commits it as `docs/eval/f16-baseline-taifa-3.0.json`.

The test measures; it never fails because of a low score. It fails only when an input is missing or the eval set is malformed.

## Non-Goals

- Any AI: Foundation Models, embeddings, answer generation.
- Changing search (`SearchIndex`, `SearchFolding`, ranking) or segmentation (`PassageSegmenter`, `PassageExtractor`).
- Adjusting queries: each `query` is searched exactly as written in the file; `question` is never searched.
- An interface for the report; any app code. Everything is in the test target.
- Changing `init.sh` or the eval set file.
- Refactoring the existing Taifa tests to use the new fixture helper.

## Job Story

When I add AI retrieval after m4,
I want a recorded baseline of text search on real questions,
so I can tell whether the AI finds the right page more often.

## Users And Permissions

- Not applicable: test-only code, no user-facing change.

## Acceptance Scenarios

### Scenario 1: the baseline runs and attaches the report

Given the Taifa fixture and the eval set in the test bundle, with the eval set's `fixtureSHA256` equal to the PDF's SHA-256
When `BaselineEvalTests` runs in a focused `xcodebuild test -only-testing:` run
Then the test passes and attaches one JSON report, `f16-baseline-taifa-3.0.json`, with 25 rows in file order, `hitAt1.total == 21`, `hitAt3.total == 21`, `noMatchAccuracy.total == 4`, the imported passage count, the fixture SHA-256 and the iOS version.

### Scenario 2: a low score does not fail

Given any search outcome, including `.noMatch` for every question
When the report is built
Then no expectation on hit@1, hit@3 or no-match accuracy is evaluated; only the inputs are checked.

### Scenario 3: scoring of a page question

Given a question of type `normal`, `table` or `falsePremise` with `expectedPage` 5
When its search state is `.matches` with pages [3, 5, 5, 7] in `SearchIndex` order
Then its row has `topPages` [3, 5, 5], `hitAt1` false, `hitAt3` true, and no `noMatchCorrect`.
And when its state is `.noMatch`, `topPages` is [], `hitAt1` and `hitAt3` are false.

### Scenario 4: scoring of an absent question

Given a question of type `absent`
When its state is `.noMatch`
Then `noMatchCorrect` is true; when its state is `.matches`, it is false and `topPages` holds up to its first three pages. The row has no `hitAt1`/`hitAt3`.

### Scenario 5: a malformed eval set fails

Given an eval set with any of: a repeated `id`; an unknown `type`; an unknown `overlap`; `expectedPage` null for a type other than `absent`, or non-null for `absent`; an `expectedPage` outside 1...page count of the PDF; a `query` with no non-whitespace character
When it is decoded and validated
Then decoding or validation throws, and the baseline test fails. Each case has its own unit test.

### Scenario 6: a missing or different fixture fails

Given the PDF or the eval set is not in the test bundle, or the PDF's SHA-256 differs from `fixtureSHA256`
When the baseline test runs
Then it fails with a message naming the missing resource or the SHA mismatch; it never skips.

## Repository Research

### Files Inspected

- `RuleRefTests/Fixtures/taifa-3.0-eval.json` — header `fixture` ("taifa-3.0.pdf"), `fixtureSHA256`, `scoring` ("page"), `questions`. Each question: `id`, `question`, `query`, `type`, `overlap`, `expectedPage` (Int or null), `fragment` (String or null), `note` (String or null). 25 questions: 13 `normal`, 4 `table`, 4 `falsePremise`, 4 `absent`; `overlap` is `low` (19) or `high` (6). The 4 `absent` have null `expectedPage` and `fragment`. Ids are not contiguous (q04, q09… are missing). `fixtureSHA256` equals `shasum -a 256` of the PDF today. The file is copied into `RuleRefTests.xctest` (synchronized folder), like the PDF.
- `RuleRef/Search/SearchIndex.swift` — `init(rulebook:)` (main actor, from the stored passages) and `search(_:) -> SearchState`; ranking by occurrences, then ordinal.
- `RuleRef/Search/SearchState.swift` — `.idle` (no terms), `.matches([Match])` (never empty), `.noMatch`; `matches` is empty for `.idle`/`.noMatch`.
- `RuleRef/Search/Match.swift` — `pageNumber`, 1-based.
- `RuleRef/Search/SearchFolding.swift` — folds case, diacritics and width only; a query with a non-whitespace character always has a term.
- `RuleRef/Persistence/Library.swift` — `createGame(named:)`, `importRulebook(fileAt:into:store:) async throws -> ImportOutcome`.
- `RuleRef/Domain/RulebookID.swift` — `RulebookID(bytes:).hex`: SHA-256 with CryptoKit, 64 lowercase hex.
- `RuleRefTests/Persistence/TaifaImportTests.swift` — the app import path in a test: in-memory `ModelContainer(for: Game.self, Rulebook.self, Passage.self, …isStoredInMemoryOnly: true)`, `Library(context:)`, `RulebookStore` in a temporary directory removed in a `defer`, `importRulebook(…).rulebook`; fixture via a private token class and `Bundle(for:)`; `Attachment.record(_:named:)`.
- `RuleRefTests/Search/SearchIndexRulebookTests.swift` — `SearchIndex(rulebook:)` over an imported rulebook.
- `.claude/hooks/validator-readonly-bash.sh` — the validator may run `xcodebuild test` with `-only-testing:` but without `-resultBundlePath`/`-derivedDataPath`, and `xcrun xcresulttool get` only: it cannot export attachments.
- `.claude/settings.json` — `xcodebuild test *` is allowed; `xcrun xcresulttool export …` is not on the allowlist.
- `ARCHITECTURE.md`, `CONTEXT.md` (Eval set, Baseline, Query vs question), `docs/build-brief.md` (F16), `docs/risks-and-open-questions.md`, `docs/specs/f18-paragraph-cut-calibration.md` (focused-run and export pattern).
- Cupertino: Swift Testing `Attachment.record(_:named:)` for encoded data; `ProcessInfo.operatingSystemVersion` (`majorVersion`, `minorVersion`, `patchVersion`).

### Existing Patterns To Follow

- Private token class per file for `Bundle(for:)`; missing fixture → failure, never skip.
- Pure logic `nonisolated`; Swift Testing only; Codable only (`JSONSerialization` is forbidden and `init.sh` checks it).

### Current Gaps

- No `docs/eval/` folder and no `RuleRefTests/Evaluation/` folder yet.
- The validator cannot re-extract the report; it relies on the committed copy and on its own focused run passing.

## Technical Approach

All new code is in the test target, in a new folder `RuleRefTests/Evaluation/`, plus one helper in `RuleRefTests/Support/`.

1. `TestFixture` (`Support/`): `static func url(forResource:withExtension:) throws -> URL` looks the resource up in the test bundle (private token class) and throws an error naming the file when it is missing.
2. `EvalSet` (`nonisolated`, `Decodable` is enough; `Codable` is allowed): properties `fixture`, `fixtureSHA256`, `scoring`, `questions`, named as in the file. Nested `Question` with every field of the file (`question`, `fragment`, `note` are decoded and unused). Nested `QuestionType: String, Codable` with `normal`, `table`, `falsePremise`, `absent`, and nested `Overlap: String, Codable` with `low`, `high`: an unknown value of either fails decoding. `func validate(pageCount: Int) throws` throws a nested error for: a repeated `id`; `expectedPage == nil` while `type != .absent`, or `!= nil` while `type == .absent`; `expectedPage` outside `1...pageCount`; `query` with no non-whitespace character. The error says which question and which rule.
3. `BaselineReport` (`nonisolated`, `Codable`): nested `Score { count, total, rate }` (`rate` is `count / total`, 0 when `total` is 0); `Summary { hitAt1, hitAt3, noMatchAccuracy, passageCount, fixtureSHA256, iOSVersion }`; `Row { id, type, overlap, expectedPage?, topPages, hitAt1?, hitAt3?, noMatchCorrect? }`. `Row.init(question:state:)` scores one question:
   - `topPages`: `pageNumber` of the first three matches in `SearchIndex` order, duplicates kept; `[]` for `.noMatch` or `.idle`.
   - Questions with `expectedPage` (`normal`, `table`, `falsePremise` alike): `hitAt1` = first page equals it; `hitAt3` = any of `topPages` equals it; `.noMatch` is a miss. `noMatchCorrect` is nil.
   - `absent`: `noMatchCorrect` = state is `.noMatch`; `hitAt1`/`hitAt3` are nil.
   - The summary counts rows: hit@1 and hit@3 over rows with `expectedPage`, no-match accuracy over `absent` rows. Optional fields left nil are omitted by synthesized encoding.
   - `func json() throws -> Data`: `JSONEncoder` with `.prettyPrinted`, `.sortedKeys`, `.withoutEscapingSlashes`.
4. `BaselineEvalTests.taifaBaseline()` (main actor, `async throws`):
   1. PDF and eval set URLs via `TestFixture` (`taifa-3.0.pdf`, `taifa-3.0-eval.json`); decode with `JSONDecoder`.
   2. `#expect`/`#require` that `RulebookID(bytes: Data(contentsOf: pdf)).hex == evalSet.fixtureSHA256`; on mismatch the test fails before measuring.
   3. Import as in `TaifaImportTests` (in-memory container, temporary `RulebookStore`, `createGame`, `importRulebook`), removing the temporary directory in a `defer`.
   4. `try evalSet.validate(pageCount: rulebook.pageCount)`.
   5. `let index = SearchIndex(rulebook: rulebook)`; one `Row` per question from `index.search(question.query)`, in file order.
   6. Summary with `rulebook.passages.count`, the SHA from step 2, and `iOSVersion` as `"\(major).\(minor).\(patch)"` from `ProcessInfo.processInfo.operatingSystemVersion` (no UIKit).
   7. `Attachment.record(try report.json(), named: "f16-baseline-taifa-3.0.json")`. No expectation on any score.

## Expected File Changes

- `RuleRefTests/Support/TestFixture.swift` — create.
- `RuleRefTests/Evaluation/EvalSet.swift`, `BaselineReport.swift` — create.
- `RuleRefTests/Evaluation/BaselineEvalTests.swift` — create; the baseline run.
- `RuleRefTests/Evaluation/EvalSetTests.swift` — create; scenario 5 (each malformed case built from small JSON strings, plus the real file validating clean with page count 16) and the missing-fixture case of `TestFixture`.
- `RuleRefTests/Evaluation/BaselineReportTests.swift` — create; scenarios 3–4 and the summary counts, on hand-built `Match` values.
- `docs/eval/f16-baseline-taifa-3.0.json` — create; the exported report, byte-identical.
- `ARCHITECTURE.md`, `README.md`, `docs/risks-and-open-questions.md` — see below.
- No app file, no `init.sh`, no catalog, no project change.

## Visual Design Impact

- UI involved: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`: update — the `RuleRefTests/` section lists `Evaluation/` (eval set model, scoring and the baseline run) and `TestFixture` in `Support/`.
- `CONSTRAINTS.md`: not needed — the repo has none.
- `AGENTS.md`, `DESIGN.md`: not needed.
- `README.md`: update — one docs-map line for `docs/eval/` (baseline reports).
- `docs/risks-and-open-questions.md`: update — the assumption "Text search alone answers enough eval questions…" gets the measured hit@1, hit@3 and no-match accuracy and a link to the report.

## Implementation Plan

1. Check that f13, f14 and f18 are `accepted`; otherwise stop.
2. `TestFixture`, `EvalSet` with validation, and their tests.
3. `BaselineReport` with scoring and its tests.
4. `BaselineEvalTests`; `./init.sh` green; commit the code.
5. Focused run with a result bundle, export, save the report; docs; commit.
6. Evidence and `PROGRESS.md`; commit.

## Implementation Tasks

- [ ] Preconditions checked.
- [ ] `TestFixture` and `EvalSet` (decode + validate), with scenario 5 and missing-fixture tests.
- [ ] `BaselineReport` and `Row` scoring, with scenarios 3–4 and summary tests.
- [ ] `BaselineEvalTests.taifaBaseline` with the SHA check, import, search and attachment.
- [ ] Report exported and saved to `docs/eval/f16-baseline-taifa-3.0.json`.
- [ ] `ARCHITECTURE.md`, `README.md`, risks assumption updated.
- [ ] `./init.sh` green; evidence; `PROGRESS.md`.

## Verification Plan

- `./init.sh` exits 0, all checks PASS, 0 failed, 0 skipped; the test count rises only by the new tests. `init.sh` is not modified.
- Implementer, focused run with a known bundle (scratch directory, never inside the repo):
  `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/BaselineEvalTests -resultBundlePath <scratch>/f16.xcresult` → `** TEST SUCCEEDED **`; then
  `xcrun xcresulttool export attachments --path <scratch>/f16.xcresult --output-path <scratch>/f16-attachments`; find the report through the exported `manifest.json` and copy it unchanged to `docs/eval/f16-baseline-taifa-3.0.json`. If a permission prompt or rule blocks any of these commands, stop and report which command; do not look for a workaround.
- Validator: `./init.sh`; `xcodebuild test -project RuleRef.xcodeproj -scheme RuleRef -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" -only-testing:RuleRefTests/BaselineEvalTests -only-testing:RuleRefTests/EvalSetTests -only-testing:RuleRefTests/BaselineReportTests` → `** TEST SUCCEEDED **`, optionally `xcrun xcresulttool get test-results summary` on that run's bundle in DerivedData. It does not export; it reads the committed report.
- `git diff main...HEAD --stat` lists only the files above plus `feature_list.json` and `PROGRESS.md`; `git diff main...HEAD -- RuleRef/ init.sh RuleRefTests/Fixtures/` is empty.
- No UI tests; no E2E (no user-facing flow).

## Evidence To Capture

- `./init.sh` summary and counts, with date, code commit, Xcode and simulator.
- The focused run's command and result; the export command; the `shasum -a 256` of the exported file and of the committed copy (equal).
- From the report: hit@1, hit@3 and no-match accuracy with their counts, passage count, iOS version.
- `not_verified`: iOS 26.0 and a device (iOS 27.0 simulator only); other rulebooks; the validator's re-extraction of the attachment; that later runs give the same report (search is deterministic, but not re-checked).

## Validator Checklist

- [ ] Only test files, `docs/eval/`, the declared docs, `feature_list.json` and `PROGRESS.md` changed; no app code, `init.sh`, fixture or eval set change.
- [ ] The eval set is decoded with Codable using the file's field names; `query` is searched as written; `question` is never searched.
- [ ] Import uses `Library.importRulebook` with an in-memory container; the SHA check uses CryptoKit (`RulebookID`) and fails on mismatch.
- [ ] Scoring follows scenarios 3–4: `SearchIndex` order, `Match.pageNumber`, `falsePremise` scored like `normal`, `.noMatch` a miss for page questions and the only success for `absent`.
- [ ] No expectation depends on a score; every scenario 5 case and the missing fixture have a test.
- [ ] The committed report has 25 rows in file order; its summary counts equal the counts from its rows; totals 21, 21 and 4; `fixtureSHA256` matches the eval set; `iOSVersion` is present.
- [ ] Report encoded with `JSONEncoder`; no `JSONSerialization`, UIKit or XCTest.
- [ ] `ARCHITECTURE.md`, `README.md` and the risks assumption updated; `feature_list.json` and `PROGRESS.md` correct.
