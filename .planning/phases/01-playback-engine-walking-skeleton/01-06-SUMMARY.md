---
phase: 01-playback-engine-walking-skeleton
plan: 06
subsystem: playback
tags: [flutter, dart, icy, now-playing, cp1251, windows-1251, sanitise, bidi, freezed, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "IcyCharset enum (lib/core/text/icy_charset.dart), Station/StationStream.icyCharset, freezed setup with committed generated files (D-17)"
provides:
  - "repairCp1251(String, {IcyCharset hint}): windows-1251 mojibake repair with the 128-entry table and the cp1252 reverse map (lib/core/text/cp1251.dart)"
  - "sanitizeIcyText(String, {int maxCodePoints = 200}): control/bidi strip, whitespace collapse, rune-safe clamp (lib/core/text/sanitize.dart)"
  - "NowPlaying freezed value type (artist, title, text) with value equality (lib/features/playback/domain/now_playing.dart)"
  - "parseIcyTitle(String?, {required Station station, required IcyCharset charset}): repair -> sanitise -> junk filter -> first ' - ' split (lib/features/playback/engine/icy/now_playing_parser.dart)"
affects: [01-08, phase-3-now-playing-screen, v1.1-song-history, v1.1-android-auto]

# Actuals (#2632)
actuals:
  tokens: 7000
  tasks: 2
  commits: 4
plan_head_before: 4a267fba62fea6128b4ccf47aad0bf5d446d7eec

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ICY text pipeline order: repairCp1251 first, then sanitizeIcyText; sanitising first would delete the U+0080-U+009F characters that carry cp1251 punctuation"
    - "Pure text functions live in lib/core/text/ with no engine or Flutter dependency; tests are plain goldens"
    - "Test sources write control and bidi characters as \\uXXXX escapes, never literally (the analyzer's text_direction_code_point_in_literal warning)"

key-files:
  created:
    - lib/core/text/cp1251.dart
    - lib/core/text/sanitize.dart
    - lib/features/playback/domain/now_playing.dart
    - lib/features/playback/domain/now_playing.freezed.dart
    - lib/features/playback/engine/icy/now_playing_parser.dart
    - test/core/text/cp1251_test.dart
    - test/core/text/sanitize_test.dart
    - test/features/playback/engine/icy/now_playing_parser_test.dart
  modified: []

key-decisions:
  - "parseIcyTitle runs repairCp1251 before sanitizeIcyText (the reverse of RESEARCH Pattern 5's listed order), so cp1251 punctuation „ “ – survives"
  - "sanitizeIcyText turns tab/LF/VT/FF/CR into a space before collapsing, so 'Artist\\nTitle' reads 'Artist Title' rather than 'ArtistTitle'; every other C0/DEL/C1 control is removed"
  - "A dangling separator ('Artist - ' or ' - Title') yields a title-only NowPlaying with the separator dropped, instead of showing 'Artist -'"
  - "Station-name junk matching is case-insensitive for both name and nameLatin, and it runs after the repair, so a station name sent as cp1251 mojibake is also dropped"

patterns-established:
  - "NowPlaying equality is the change detector: 01-08 republishes the MediaItem only when parseIcyTitle returns a different value"
  - "The caller passes the icyCharset of the stream that is currently playing; the parser never looks it up itself"

requirements-completed: [STRM-05, PLAY-02]

coverage:
  - id: D1
    description: "windows-1251 mojibake becomes Cyrillic ('Àðòèñò - Ïåñåí' -> 'Артист - Песен', the whole 0xC0..0xFF letter range, Ё/ё); „ “ ” – are kept whether they arrive as C1 characters or double-encoded through cp1252; Mötley Crüe, Beyoncé, Björk, Sigur Rós, ASCII, real Cyrillic and non-Latin-1 Unicode are unchanged; utf8 hint is a no-op and cp1251 hint forces a two-letter repair that auto skips"
    requirement: STRM-05
    verification:
      - kind: unit
        ref: "test/core/text/cp1251_test.dart (19 tests)"
        status: pass
      - kind: other
        ref: "Python cp1251/cp1252 codec cross-check of _cp1251High (128/128) and _cp1252Reverse (27/27)"
        status: pass
    human_judgment: false
  - id: D2
    description: "sanitizeIcyText strips C0, DEL, C1, U+202A-U+202E and U+2066-U+2069, collapses whitespace and trims, and clamps to 200 code points without leaving a lone surrogate (199 chars + emoji)"
    requirement: PLAY-02
    verification:
      - kind: unit
        ref: "test/core/text/sanitize_test.dart (15 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "parseIcyTitle: 'Artist - Title' split, title only, first-separator split, dangling separators, junk (null, empty, whitespace, '-', station name and Latin name in any case, www./:// URLs, control-only, mojibake station name) -> null, cp1251 repair and punctuation through the parser, bidi and newline stripping, clamp, value equality"
    requirement: PLAY-02
    verification:
      - kind: unit
        ref: "test/features/playback/engine/icy/now_playing_parser_test.dart (28 tests)"
        status: pass
      - kind: other
        ref: "flutter analyze + dart analyze (No issues found!); full suite 163 tests pass"
        status: pass
    human_judgment: false
  - id: D4
    description: "Real Bulgarian stations' ICY titles (windows-1251 and UTF-8 senders) show correct Cyrillic in the notification, lock screen and mini-player"
    requirement: STRM-05
    verification: []
    human_judgment: true
    rationale: "The parser is pure and unit-tested, but it is wired into the handler and UI only in 01-08, and real station encodings can only be checked on the owner's phone (ARCHITECTURE Pattern 7 marks the Media3 decoder assumption VERIFY)."

# Metrics
duration: 6min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 06: Station titles become clean Cyrillic now-playing values Summary

**`parseIcyTitle` turns a raw ICY `StreamTitle` into a `NowPlaying` value (artist, title, text), or into nothing. It repairs windows-1251 mojibake using the RESEARCH-generated 128-entry table, then strips controls and bidi overrides and clamps the text to 200 code points without splitting surrogates, then drops junk titles and splits on the first " - ".**

## Performance

- **Duration:** about 6 min
- **Started:** 2026-09-25T15:13:40Z
- **Completed:** 2026-09-25T15:19:20Z
- **Tasks:** 2 of 2. Both were TDD (RED, then GREEN); neither needed a refactor.
- **Files modified:** 8, all new.

## Accomplishments

- **STRM-05, text half:** `repairCp1251` turns `Àðòèñò - Ïåñåí` into `Артист - Песен`.
  - The table and the reverse map were copied verbatim from 01-RESEARCH.md; a diff shows them identical. They were also checked against Python's `cp1251` and `cp1252` codecs: 128 of 128 table entries and 27 of 27 map entries match.
  - `IcyCharset` is imported from `icy_charset.dart`, not declared a second time.
  - Punctuation („ “ ” –) is kept whether it arrives as U+0084/U+0093/U+0094/U+0096 or double-encoded through cp1252.
  - Western accented titles, ASCII, real Cyrillic and any non-Latin-1 text are left alone.
- **PLAY-02, text half:** `sanitizeIcyText` removes C0, DEL, C1, U+202A–U+202E and U+2066–U+2069. It collapses whitespace, trims, and clamps by runes to 200 code points, so an emoji at the limit is never split.
- **`NowPlaying`** is a freezed value type. Its equality lets 01-08 publish a new notification only when the value changes.
- **`parseIcyTitle`** runs repair, then sanitising, then the junk filter, then the split.
  - The junk filter drops empty text, `-`, the station name or Latin name in any case, and anything URL-like.
  - A dangling separator becomes a title only.
- **Tests:** 62 in the plan's scope (cp1251 19, sanitize 15, parser 28) and 163 in the whole suite. `flutter analyze` and `dart analyze` report no issues, and no test touches the network.

## Task Commits

1. **Task 1: Mojibake from windows-1251 stations turns back into Cyrillic, and hostile or oversized text is cleaned.** RED `f3326a0` (test), GREEN `80bf768` (feat)
2. **Task 2: A raw ICY title becomes an artist/title value, and junk titles become nothing.** RED `80c7185` (test), GREEN `e007e5d` (feat)

**Plan metadata:** see the `docs(01-06): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `f3326a0`: 18 of 34 tests failed, all on assertions. The 16 that passed are the "unchanged" goldens (Western accents, ASCII, Cyrillic, the utf8 hint, the auto skip) and two clamp cases that an identity stub satisfies. | `80bf768` | not needed | `check tdd-red-evidence` returned RED_EVIDENCE_OK for 3 targets: the mojibake golden, the emoji clamp, and the bidi-override strip |
| 2 | `80c7185`: 12 of 28 tests failed, all on assertions. The 16 that passed are the junk cases and the equality case, which a stub returning null satisfies. | `e007e5d` | not needed | RED_EVIDENCE_OK for 3 targets: the 'Artist - Title' split, punctuation through the pipeline, and the bidi/newline strip |

As in 01-03 and 01-04, each RED run used `flutter test --reporter json`, converted line for line into TAP for the checker. Each RED commit holds only compile scaffolding. The stubs return the input (or null), and in Task 2 the `NowPlaying` type and its generated file are included, so every failure is an assertion rather than a compile error.

## Files Created/Modified

- `lib/core/text/cp1251.dart`: `_cp1251High`, `_cp1252Reverse` and `repairCp1251`, verbatim from RESEARCH.
- `lib/core/text/sanitize.dart`: `sanitizeIcyText`.
- `lib/features/playback/domain/now_playing.dart` and `now_playing.freezed.dart`: the `NowPlaying` value type (the generated file is committed, D-17).
- `lib/features/playback/engine/icy/now_playing_parser.dart`: `parseIcyTitle`.
- `test/core/text/cp1251_test.dart`, `test/core/text/sanitize_test.dart` and `test/features/playback/engine/icy/now_playing_parser_test.dart`: the golden tests.

## Decisions Made

- **Repair runs before sanitising.** The plan requires this order. It reverses RESEARCH Pattern 5's list, because sanitising first would delete the cp1251 punctuation.
- **Whitespace controls become spaces.** See deviation 1.
- **Dangling separators are dropped.** See deviation 2.
- **Station-name matching happens after repair.** A station name that arrives as mojibake (`ÁÃ Ðàäèî`) is still recognised as junk.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tab and newline between words would have glued the words together**
- **Found during:** Task 1 (tests)
- **Issue:** Read literally, "strip U+0000–U+001F, then collapse whitespace" deletes a tab or newline before the collapse can see it. `Artist\nTitle` would then become `ArtistTitle`.
- **Fix:** U+0009–U+000D are turned into a space first. Every other C0 control, DEL and C1 control (U+0085 NEL included) is removed as planned.
- **Files modified:** lib/core/text/sanitize.dart
- **Verification:** the tests "a tab or newline between words becomes a space, not a join", "removing a control does not leave a double space" and "DEL and C1 controls U+007F..U+009F are removed" pass.
- **Committed in:** 80bf768

**2. [Rule 2 - Missing Critical] A dangling separator no longer shows as 'Artist -'**
- **Found during:** Task 2 (tests)
- **Issue:** PITFALLS Pitfall 6 names `Artist - ` with an empty title as common junk. After trimming it is `Artist -`, which contains no ` - `, so the planned split would have shown the literal `Artist -`. The plan's must-have forbids a "junk line".
- **Fix:** A trailing ` -` or leading `- ` is dropped before the junk filter and the split, so what remains becomes the title.
- **Files modified:** lib/features/playback/engine/icy/now_playing_parser.dart
- **Verification:** the tests "a dangling 'Artist - ' becomes a title only", "a dangling ' - Title' becomes a title only" and "a lone separator produces no now-playing value" pass.
- **Committed in:** e007e5d

**3. [Note] Test-authoring detail**
- The file-writing tool put the bidi characters into the test sources literally instead of as `‪` escapes, and the analyzer flagged them (`text_direction_code_point_in_literal`). They were rewritten as `\uXXXX` escapes before the RED commit, and the committed tests contain no literal control or bidi characters.
- The table and function in `cp1251.dart` keep RESEARCH's compact layout rather than `dart format` output, so the "copy verbatim" instruction can be checked with a diff. `flutter analyze` is clean.

---

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 2 missing-critical), plus 1 note.
**Impact on plan:** Both fixes serve the plan's own must-haves: clean text and no junk line. There is no scope creep. Rate limiting and distinct-until-changed stay in 01-08.

## Issues Encountered

None beyond the escape issue in deviation 3, which was caught by `flutter analyze` before the first commit.

## Known Stubs

None. The RED stubs were fully replaced in the GREEN commits.

## Threat Flags

None. The plan's threat register covers all of this plan's surface: T-06-01 (bidi and controls), T-06-02 (the clamp) and T-06-03 (the table, checked against Python's codecs). All three are mitigated and unit-tested.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- 01-08 can call `parseIcyTitle(icy.title, station: current, charset: currentStream.icyCharset)` on each `icyMetadataStream` event and publish only when the returned `NowPlaying` differs from the last one. It should also clear the value on every load and on Paused/Idle/Error (RESEARCH Pattern 5).
- For end-of-phase UAT (D4): on the owner's phone, check real Bulgarian stations' titles in the notification and the mini-player. If a station's titles come out wrong, set that station's `icyCharset` to `cp1251` or `utf8` in the catalogue.
- The STRM-05 edge assumption, from the plan's Edge Coverage table, still needs a manual review. It assumes no station sends UTF-8 bytes of cp1251-decoded text.
- 01-02 and 01-05 are still open in this phase.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED

All 8 created files exist. Commits f3326a0, 80bf768, 80c7185 and e007e5d are in git. No tracked files were deleted. Both tasks' acceptance criteria and grep gates were re-run and pass. The full suite (163 tests), `flutter analyze` and `dart analyze` are clean.
