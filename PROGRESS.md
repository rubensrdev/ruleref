# Progress

One entry per work session, oldest first. Each entry says what closed and what comes next.

## 2026-10-06 — T0: demo rulebook and device
- Rulebook: Taifa 3.0 (printandplay.games, 16 pp., Spanish), CC BY-NC-SA; imported on camera, never bundled.
- Layout: single-column body with a text layer; text wraps around images on pp. 3 and 12; line-break hyphenation present.
- Eval ground truth comes from the 3.0 PDF; the official FAQ covers v2.0 and is used only as a source of hard questions.
- Demo device: iPhone 16 (standard on-device model on iOS 27, not the 12 GB one).
- Next: P1, adapt the build-brief skill.

## 2026-10-06 — T1: build brief
- P1: build-brief skill adapted to the closed stack; installed in .agents/skills with a .claude/skills symlink.
- Brief written: CONTEXT.md, docs/build-brief.md, docs/domain-model.md, docs/risks-and-open-questions.md, ADR-003 (scope cut).
- All six open decisions closed; multi-column deferred to ADR-002 (T3). UI in Spanish and English via String Catalog. No UI tests: the user validates the interface manually at the end of each phase.
- Features by task: T2 F01; T3 F02, F03, F05–F11; T4 F13–F15; after m4 F04, F12, F16.
- Next: P2, hand-off for T2 (minimal harness).

## 2026-10-07 — P2, T2.0–T2.2
- P2 closed: the user creates and configures the Xcode project; the agent never edits project.pbxproj; the agent edits the String Catalog; no global hooks; T2 split into subtasks, one per commit.
- T2.0: hooks and permissions copied from the user's kit with patches (commits 4d4c7f9 and 08c2944); commit attribution disabled.
- T2.1: Xcode project created by hand with synchronized folders, shared scheme with an autocreated test plan, iPhone only in portrait, iOS 26.0, Swift 6 with complete concurrency checking, MainActor default isolation, English as development language and Spanish added.
- T2.2: .gitignore tracked again.
- Next: T2.3, init.sh and F01.
