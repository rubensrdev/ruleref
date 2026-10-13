# Feature Implementation Spec: Join hyphenation and normalise whitespace

Approval: approved by the user on 2026-10-13

## Source Feature

- `id`: f07-join-hyphenation
- `area`: extraction
- `depends_on`: f06-extract-passages
- `status`: not_started
- `source`: `feature_list.json`

## Goal

Passage text reads as continuous prose. A word split by a hyphen at a line break is joined ("cons-⏎truir" → "construir"), soft hyphens disappear, and every run of whitespace, including the "\n" that f06 puts between lines, becomes a single space with no leading or trailing space. A new pure function, `PassageText.normalized(_:)`, does this, and `PassageExtractor` (f06) applies it to each segment's text before it builds the `ExtractedPassage`. `PassageSegmenter` does not change. This is the text the domain model promises for a Passage ("hyphenation joined, whitespace normalised"); search (f13) will match against it.

## Non-Goals

- Unicode normalization (NFC/NFD), ligature expansion, typographic quotes or any other character mapping.
- Any change to f06's cut rule, to `PassageSegmenter` or to its tests (f06 scenarios 8–9).
- Search and query folding (f13), persistence of passages (f08), any interface.
- Detecting genuine compound words: no dictionary, no language model.

## Job Story

When the app turns a rulebook into passages,
I want words split across lines joined back and spacing cleaned up,
so a search for "construir" finds the paragraph where the PDF printed "cons-" and "truir" on two lines.

## Users And Permissions

- None: internal domain logic.

## Acceptance Scenarios

Scenario 1 uses a synthetic PDF built with f06's `SyntheticPDF` helper. Scenarios 2–8 call `PassageText.normalized(_:)` on Swift string literals ("\n" is U+000A).

### Scenario 1: feature verification on a PDF

Given a one-page synthetic PDF with one paragraph whose consecutive lines are "cons-" and "truir", with in-paragraph spacing
When it is extracted with `PassageExtractor.extract(from:rulebookID:)`
Then the test first `#require`s that `PassageExtractor.lines(on:)` returns exactly "cons-" and "truir" for those two lines, and then the passage's text contains "construir" and does not contain "cons-".

### Scenario 2: line-break hyphen before a lowercase letter

Given "cons-\ntruir" and "con\u{2010}\nstruir"
When each is normalized
Then both give "construir".

### Scenario 3: line-break hyphen before anything else

Given "Norte-\nSur" and "nivel-\n2"
When each is normalized
Then they give "Norte-Sur" and "nivel-2": the hyphen stays and only the line break goes.

### Scenario 4: soft hyphen

Given "cons\u{00AD}\ntruir", "a\u{00AD}b" and "\u{00AD}"
When each is normalized
Then they give "construir", "ab" and "".

### Scenario 5: not a word hyphen

Given "x -\ny", "fin —\nsigue" and "fin—\nsigue"
When each is normalized
Then they give "x - y", "fin — sigue" and "fin— sigue". A hyphen not preceded by a letter is not joined, and dashes (U+2013, U+2014) are never hyphens.

### Scenario 6: whitespace

Given "  uno \n\t dos\u{00A0}tres  "
When it is normalized
Then it gives "uno dos tres".

### Scenario 7: idempotence

Given every input of scenarios 2–6 and 8
When each is normalized twice
Then the second result equals the first.

### Scenario 8: accepted wrong join of a genuine compound

Given "franco-\nalemán"
When it is normalized
Then it gives "francoalemán". This is the expected behaviour, accepted in `docs/domain-model.md` (Edge cases): a genuine hyphenated word that ends a line with a lowercase continuation is joined.

## Repository Research

### Files Inspected

- `docs/specs/f06-extract-passages.md` (approved) — promises `PageLine`, `PassageSegmenter.segments(of:pageBounds:)` with segment text joined by "\n", `ExtractedPassage(text:ordinal:locator:)`, `PassageExtractor.lines(on:)` (trailing newlines removed) and `extract(from:rulebookID:)` (ordinals consecutive from 0), `SyntheticPDF` (Helvetica 12 pt, explicit line specs, spacing precondition), and `PassageExtractorTests` (scenarios 1–7) asserting texts joined with "\n". Its non-goals hand hyphen joining and whitespace normalising to f07.
- `docs/domain-model.md` — Passage text is "hyphenation joined, whitespace normalised"; edge case: genuine hyphenated words at a line end may be joined wrongly, accepted.
- `CONTEXT.md` — term **Passage**; "chunk" and "fragment" are rejected.
- `feature_list.json` — f07 entry and its verification test; f08 and f13 consume passage text.
- `docs/build-brief.md` — F07 row; `docs/risks-and-open-questions.md` — no hyphenation item.
- `RuleRef/`, `RuleRefTests/` — only the app shell and a smoke test.
- `docs/specs/f03-list-games.md` — approved reference for detail level.

### Existing Patterns To Follow

- Default isolation is `MainActor`; pure domain logic is `nonisolated` explicitly. f06's `PassageSegmenter` is a pure `enum` with static functions and no PDFKit; `PassageText` follows it.
- Swift Testing only; synchronized folders need no project change.

### Current Gaps

- f06 is approved but not implemented: `PageLine`, `PassageSegmenter`, `ExtractedPassage`, `PassageExtractor`, `SyntheticPDF` and their tests do not exist yet. This spec relies only on what f06's spec promises; f06 must be accepted before f07 starts (`depends_on`).
- If f06's implementation differs in a name used here (for example `Segment.text`), f07 follows the implementation and says so in its evidence.

## Technical Approach

APIs checked in the Cupertino MCP on 2026-10-13 (Apple docs crawled May 2026; SE-0221):

- `Character.isLetter` (iOS 8+): permissive, it looks at the first scalar only, so "é" written as e + U+0301 is a letter.
- `Character.isLowercase` (iOS 8+): restrictive, it looks at the whole grapheme; a lowercase character changes when uppercased but not when lowercased. Digits, punctuation and spaces are not lowercase.
- `Character.isWhitespace` (iOS 8+): "whitespace, including newlines"; the docs list tab, space, U+2029 and U+3000. `Unicode.Scalar.Properties.isWhitespace` "corresponds to the White_Space property". SE-0221 leaves whitespace followed by combining scalars unspecified.
- `String.unicodeScalars` / `String.UnicodeScalarView` and `String.init(_: String.UnicodeScalarView)`.
- **Not verified** in Apple's docs: that U+00A0 counts as whitespace. It has the Unicode White_Space property, so it should; scenario 6 checks it.
- **Not verified**: how U+00AD clusters into `Character`s. Rule b therefore works on Unicode scalars, so it holds either way.

`PassageText`: `nonisolated enum`, pure, no PDFKit and no Foundation, with `static func normalized(_ text: String) -> String`. Three passes, in this order; each pass reads the previous pass's output, and its conditions are evaluated on its own input:

- a. **Line-break hyphen.** A hyphen is U+002D or U+2010. When a hyphen is immediately preceded by a `Character` with `isLetter` and immediately followed by "\n": if the `Character` after the "\n" `isLowercase`, remove the hyphen and the "\n" ("cons-\ntruir" → "construir"); otherwise remove only the "\n" ("Norte-\nSur" → "Norte-Sur"). Anything else is left for rule c, so in "x -\ny" the "\n" stays.
- b. **Soft hyphen** (on `unicodeScalars`). Remove every U+00AD followed by U+000A together with that U+000A, then remove every remaining U+00AD.
- c. **Whitespace.** Replace each maximal run of `Character`s with `isWhitespace` by one U+0020, then drop a leading and a trailing U+0020.

Only "\n" (U+000A) is a line break for rules a and b; f06 joins lines with exactly that. U+2011, U+2013, U+2014 and U+2212 are not hyphens.

Idempotence follows from the order: after rule c no "\n" and no U+00AD are left, so a second pass of rules a and b changes nothing, and rule c is idempotent on its own output. Scenario 7 tests it rather than relying on this argument.

`PassageExtractor.extract(from:rulebookID:)` changes in one place: each segment's text goes through `PassageText.normalized(_:)` before the `ExtractedPassage` is built. A segment whose normalized text is empty (only soft hyphens and whitespace) is skipped before ordinals are assigned, so ordinals stay consecutive and no passage has empty text. `lines(on:)`, locators and bounds do not change.

Declared change outside f07's own files: the expected texts in `RuleRefTests/PassageExtractorTests.swift` (f06) become the normalized texts, for example "line one line two" instead of "line one\nline two". That is the only change allowed in f06's tests. `PassageSegmenterTests` and `SyntheticPDF` are not touched. The approved f06 spec is not edited; it stays as the record of f06's version.

Risks:

- PDFKit may hand back the drawn "-" as another character, an already joined word, or a line with trailing spaces. Scenario 1 `#require`s the raw line texts first, so a surprise fails loudly instead of passing by accident.
- If a continuation line starts with whitespace, the hyphen is kept ("cons- truir"). f06 does not trim leading whitespace, and PDFKit is not expected to produce it. **Not verified.**
- Real rulebooks (Taifa) may use U+00AD, U+2010 or U+2011 at line ends; only synthetic text is tested here. Taifa is checked in f08.

## Expected File Changes

- `RuleRef/PassageText.swift` — create; the three passes.
- `RuleRef/PassageExtractor.swift` — modify; normalize each segment's text and skip empty results before assigning ordinals.
- `RuleRefTests/PassageTextTests.swift` — create; scenarios 2–8.
- `RuleRefTests/HyphenationExtractionTests.swift` — create; scenario 1, with `SyntheticPDF`.
- `RuleRefTests/PassageExtractorTests.swift` — modify; expected texts only (declared above).

## Visual Design Impact

- UI involved: no.

## Durable Documentation Impact

- `ARCHITECTURE.md`, `CONSTRAINTS.md`, `DESIGN.md`: not needed — this repo has none; its rules live in `AGENTS.md` and `docs/adr/`.
- `AGENTS.md`: not needed — no workflow change.
- `docs/domain-model.md`: not needed — it already says passage text has hyphenation joined and whitespace normalised, and accepts wrong joins of genuine compounds. The exact rule lives in this spec and in `PassageText`.
- Other docs: none.

## Implementation Plan

1. Write failing `PassageTextTests` for scenarios 2–8; add `PassageText`.
2. Write failing `HyphenationExtractionTests` for scenario 1; apply `PassageText.normalized(_:)` in `PassageExtractor.extract(from:rulebookID:)`, with the empty-text skip.
3. Update the expected texts in `PassageExtractorTests` to the normalized texts, and nothing else there.
4. Run `./init.sh`. Record evidence in `feature_list.json` and an entry in `PROGRESS.md`.

## Implementation Tasks

- [ ] `PassageTextTests`: one parameterized test per scenario (2–6, 8) with input and expected output; scenario 7 runs `normalized` twice on all those inputs.
- [ ] `PassageText.swift` (`nonisolated enum`, rules a → b → c, no Foundation).
- [ ] `HyphenationExtractionTests`: `#require` on the raw lines, then "construir" in the passage text.
- [ ] `PassageExtractor.swift`: normalize, skip empty, then assign ordinals.
- [ ] `PassageExtractorTests`: expected texts updated, no other change.
- [ ] `./init.sh` green; evidence and `PROGRESS.md` updated.

## Verification Plan

- `./init.sh` exits 0 with every check PASS; test-results shows the new tests, 0 failed, 0 skipped.
- Focused run: `xcodebuild test ... -only-testing:RuleRefTests/PassageTextTests -only-testing:RuleRefTests/HyphenationExtractionTests -only-testing:RuleRefTests/PassageExtractorTests -only-testing:RuleRefTests/PassageSegmenterTests`.
- `git diff main...HEAD -- RuleRefTests/PassageExtractorTests.swift RuleRefTests/PassageSegmenterTests.swift RuleRefTests/SyntheticPDF.swift RuleRef/PassageSegmenter.swift` (f07 runs on its own branch from `main`, as decided for T3) shows changes only to expected text literals in `PassageExtractorTests`.
- No UI tests and no E2E, by design (`AGENTS.md`, Tests); f07 has no interface.

## Evidence To Capture

- `./init.sh` summary and test-results counts, with date, commit, Xcode and simulator.
- Names of the tests covering scenarios 1–8.
- The `git diff` above, summarised.
- `not_verified`: real rulebooks and Taifa's hyphenation (f08); hyphen characters other than U+002D, U+2010 and U+00AD; continuation lines starting with whitespace; how PDFKit reports U+00AD; iOS 26.0 and physical device runs.

## Validator Checklist

- [ ] Scenarios 1–8 are covered by passing tests; scenario 1 `#require`s the raw lines "cons-" and "truir" before asserting "construir".
- [ ] `PassageText` is a `nonisolated` pure `enum` with no PDFKit and no Foundation; the passes run in the order a → b → c as specified, with exactly U+002D and U+2010 as hyphens.
- [ ] `PassageExtractor` normalizes every segment's text, skips empty results before assigning ordinals, and changes nothing else.
- [ ] `PassageSegmenter`, `PassageSegmenterTests` and `SyntheticPDF` are unchanged; in `PassageExtractorTests` only expected texts changed.
- [ ] No Unicode normalization, ligature or quote mapping, search, persistence or UI was added.
- [ ] `feature_list.json` and `PROGRESS.md` were updated correctly.
