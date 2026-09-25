---
phase: 01-playback-engine-walking-skeleton
plan: 08
subsystem: playback
tags: [flutter, audio_service, icy, now-playing, cp1251, media-session, riverpod, mini-player, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "StreamPlayer.icyTitles with generation stamps, stop-before-load in JustAudioStreamPlayer, RadioAudioHandler generations and _lastStation resume"
  - phase: 01-playback-engine-walking-skeleton (plan 06)
    provides: "parseIcyTitle (repair, sanitise, junk filter, split) and the NowPlaying value type"
  - phase: 01-playback-engine-walking-skeleton (plan 07)
    provides: "mediaItemFor with EngineStrings, sameMediaItem field-wise dedupe, _setStatus/_publishMediaItem"
provides:
  - "AudioEngine.nowPlaying (Stream<NowPlaying?>, replays the latest value); AudioServiceEngine and FakeEngine implement it"
  - "RadioAudioHandler ICY subscription: current generation only, after the load's first ready snapshot (_readySeenForGeneration), parseIcyTitle with the playing stream's icyCharset, distinct by NowPlaying value"
  - "Now-playing clear on every start/switch, pause, stop and failure"
  - "mediaItemFor(station, status, strings, {NowPlaying? nowPlaying}): while Playing, artist = artist ?? text and displaySubtitle = text; title always the station name"
  - "nowPlayingProvider (keepAlive StreamProvider mirror) and the mini-player's now-playing line"
affects: [01-09, 01-11, phase-3-now-playing-screen, v1.1-song-history, v1.1-android-auto]

# Actuals (#2632)
actuals:
  tokens: 6694
  tasks: 3
  commits: 6
plan_head_before: 83e70ccf1fc0d20ff27b968403c89860f78e77bb

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_setNowPlaying(value) is the single write path for now-playing: it dedupes by NowPlaying value, emits on the handler stream and republishes the MediaItem through the sameMediaItem dedupe; _setNowPlaying(null) is the clear"
    - "_nextGeneration() is the only way to supersede a load: it bumps the generation and resets _readySeenForGeneration"
    - "In pause, stop and _fail the clear runs after _setStatus, so the MediaItem is not redrawn twice; in _start it runs first, before the old transport is stopped"
    - "The mini-player's second line is one live region: the state label, or while Playing the now-playing text, or nothing"

key-files:
  created:
    - .planning/phases/01-playback-engine-walking-skeleton/01-08-SUMMARY.md
  modified:
    - lib/features/playback/domain/audio_engine.dart
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/features/playback/engine/audio_service_engine.dart
    - lib/features/playback/engine/media_session_mapping.dart
    - lib/features/playback/application/playback_providers.dart
    - lib/features/playback/application/playback_providers.g.dart
    - lib/features/playback/presentation/mini_player.dart
    - test/support/fakes.dart
    - test/features/playback/engine/radio_audio_handler_test.dart
    - test/features/playback/engine/media_session_mapping_test.dart
    - test/features/playback/presentation/mini_player_test.dart

key-decisions:
  - "ICY titles that arrive before the load's first ready snapshot are dropped, not held until ready. Holding them would let a stale title replayed by the native player leak into the new station. Media3 delivers ICY StreamTitle through its metadata renderer at the playback position, so real titles arrive after READY; the owner should still confirm on a device that a station's first title appears without waiting for the next song."
  - "Switching station clears now-playing before the old transport is stopped, and republishes the old station's item without the ICY text. This costs one extra notification redraw, only when leaving a station that was showing a title."
  - "The mini-player reuses its existing live-region line for the now-playing text instead of adding a third line, so the height and the 2x text-scale behaviour stay as in 01-03"

patterns-established:
  - "Engine streams that the UI mirrors replay the latest value (status, currentStation, nowPlaying); FakeEngine has a matching setter for each"

requirements-completed: [STRM-05, PLAY-02]

coverage:
  - id: D1
    description: "A current-generation ICY title after ready becomes the MediaItem subtitle ('Артист - Песен') and artist ('Артист') under the station name, and AudioEngine.nowPlaying emits it; windows-1251 mojibake is repaired with the playing stream's icyCharset (cp1251 repairs 'Rock Àç' to 'Rock Аз', an auto stream leaves it)"
    requirement: STRM-05
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#now playing (ICY, STRM-05 / PLAY-02) (3 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "mediaItemFor with now playing: Playing with a value shows it (artist = artist ?? text), Playing without one has no subtitle, every non-playing state keeps its state text, and Paused after a title shows 'На пауза'"
    requirement: PLAY-02
    verification:
      - kind: unit
        ref: "test/features/playback/engine/media_session_mapping_test.dart#mediaItemFor with now playing (ICY, PLAY-02) (11 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Never stale or junk: a switch clears now-playing at once and drops a late title from the old generation; a pre-ready title is ignored; a duplicate publishes one MediaItem; pause, stop and a player failure each clear; '-', empty, null, station-name and URL titles after a real title clear the line and never show 'null'"
    requirement: STRM-05
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#never stale, never junk (Pitfall E, Pitfall 6, T-08-03) (11 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The mini-player shows the now-playing text under the station name while Playing (a live region, one line with ellipsis), nothing when null, the state label in every other state; accessibility guidelines and 2x text scale pass with the extra line"
    requirement: PLAY-02
    verification:
      - kind: automated_ui
        ref: "test/features/playback/presentation/mini_player_test.dart#mini-player now playing (ICY) (11 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "On the owner's phone: real stations' artist and title appear in correct Cyrillic on the mini-player, notification, lock screen and a Bluetooth car display; the notification title stays the station name; HLS Хоризонт shows the station name only; switching station never shows the previous song; the first title appears without waiting for the next song"
    requirement: STRM-05
    verification: []
    human_judgment: true
    rationale: "Real station encoders, Media3's ICY delivery timing, the system notification and lock screen, and AVRCP car displays exist only on a device (the plan's <human-check>). There is no Android SDK in the execution environment."

# Metrics
duration: 10min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 08: Correct Cyrillic "now playing" on the notification, lock screen and mini-player, never stale Summary

**`RadioAudioHandler` now takes ICY titles from the player and turns them into `NowPlaying` values with 01-06's `parseIcyTitle`, using the `icyCharset` of the stream that is actually playing. It accepts only titles from the current load, and only after that load has reported ready. It publishes a value only when the value changes. The notification and lock screen keep the station name as the title and show the song as the subtitle and artist. The mini-player shows the same line through `nowPlayingProvider`. Starting or switching station, pausing, stopping and failing all clear the line, so an old or junk title never shows and a literal "null" never appears.**

## Performance

- **Duration:** about 10 min
- **Started:** 2026-09-25T16:27:51Z
- **Completed:** 2026-09-25T16:37:57Z
- **Tasks:** 3 of 3. All were TDD (RED, then GREEN); none needed a refactor.
- **Files modified:** 11 (all modified, none created apart from this summary)

## Accomplishments

- **STRM-05 (Cyrillic):** a windows-1251 station's `Àðòèñò - Ïåñåí` is published as `Артист - Песен`. The charset comes from `_currentStream.icyCharset`. A test proves it: the same short mojibake is repaired on a cp1251 stream and left alone on an auto stream.
- **STRM-05 (never stale):**
  - `_readySeenForGeneration` is reset by `_nextGeneration()` whenever a load is superseded, and set by the load's first ready snapshot.
  - ICY events from another generation, or from before ready, are dropped.
  - Now-playing is cleared on every start or switch, pause, stop and failure. On a switch it is cleared before the old transport stops.
- **PLAY-02:** `mediaItemFor(..., {NowPlaying? nowPlaying})` behaves as follows:
  - While Playing, `artist` is the artist (or the whole text when there is no artist) and `displaySubtitle` is the text.
  - `title` is always the station name.
  - Every non-playing state keeps its 01-07 state text, even when a value is passed.
- **Only on change (T-08-02):** a repeated title, including one that differs only in whitespace, publishes one MediaItem and emits one value. The MediaItem goes through 01-07's field-wise `sameMediaItem`.
- **Only sanitised text (T-08-01):** the handler publishes nothing but `parseIcyTitle` output. Junk (`-`, empty, null, the station name, a URL) clears the line.
- **Mini-player:** `nowPlayingProvider` is a keepAlive StreamProvider mirroring `AudioEngine.nowPlaying`, and its generated file is committed (D-17). While Playing, the mini-player's existing live-region line shows the now-playing text. Tap-target, label and contrast guidelines pass, and a long name plus a long title at 2x text scale do not overflow.
- **Tests:** the full suite has 278 tests (up from 242), and all pass. `flutter analyze` and `dart analyze` report no issues, and `build_runner build` leaves no diff. No test touches the network.
- **Left untouched, as required:**
  - `res/raw/keep.xml`: this plan adds no drawables.
  - `_lastStation` resume: tracer step 8 passes.
  - `AudioService.asyncError` logging: bootstrap is unchanged.
  - 01-07's field-wise MediaItem change detection.

## Task Commits

1. **Task 1: Cyrillic now-playing text (windows-1251 included) shows on the notification and lock screen.** RED `ca945ad` (test), GREEN `59ffe91` (feat)
2. **Task 2: The mini-player shows the same now-playing line under the station name.** RED `19caa58` (test), GREEN `02e973d` (feat)
3. **Task 3: Titles never go stale or junk after switching station, pausing or stopping.** RED `10fe3d0` (test), GREEN `2838ff1` (feat)

**Plan metadata:** see the `docs(01-08): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `ca945ad`: 5 of 42 failed, all on assertions (subtitle and artist `null`) | `59ffe91` | not needed | `check tdd-red-evidence` returned RED_EVIDENCE_OK for 3 targets: the Cyrillic title case, the cp1251 case, and mediaItemFor Playing with a value |
| 2 | `19caa58`: 4 of 51 failed, all on assertions (the second line missing) | `02e973d` | not needed | RED_EVIDENCE_OK for 2 targets: the line while Playing, and the song change with the live region |
| 3 | `10fe3d0`: 5 of 118 failed, all on assertions (`NowPlaying` instead of null) | `2838ff1` | not needed | RED_EVIDENCE_OK for 5 targets: the switch, pre-ready, pause, stop and failure cases |

Some tests passed during RED. They are characterisation tests of behaviour that Task 1 already delivered or the plan assigns to an earlier task:
- Task 1's RED: the "Playing without a value" and non-playing mapping cases, because those states already had no ICY text.
- Task 2's RED: the "no second line" and non-playing cases.
- Task 3's RED: the duplicate-title case (Task 1 already dedupes), the five junk cases (01-06's parser returns null and Task 1 publishes the change), and the Paused-after-title mapping case.

Each RED run used `flutter test --reporter json`, converted into TAP for the checker, as in 01-03 to 01-07. The RED commits hold only compile scaffolding: the `nowPlaying` members with no feed, the unused mapping parameter, and `FakeEngine.setNowPlaying`. Task 2's and Task 3's RED commits contain tests only.

## Files Created/Modified

- `lib/features/playback/domain/audio_engine.dart`: `Stream<NowPlaying?> get nowPlaying`.
- `lib/features/playback/engine/audio_service_engine.dart`: `nowPlaying` replays the handler's latest value.
- `lib/features/playback/engine/radio_audio_handler.dart`: the ICY subscription, `_onIcyTitle`, `_setNowPlaying`, `_readySeenForGeneration`, `_nextGeneration`, and clears in `_start`, `pause`, `stop` and `_fail`.
- `lib/features/playback/engine/media_session_mapping.dart`: the `nowPlaying` parameter and its Playing mapping.
- `lib/features/playback/application/playback_providers.dart` and `.g.dart`: `nowPlayingProvider`.
- `lib/features/playback/presentation/mini_player.dart`: the now-playing text in the second line while Playing.
- `test/support/fakes.dart`: `FakeEngine.nowPlaying` and `setNowPlaying`.
- Test changes:
  - `radio_audio_handler_test.dart`: 14 new tests.
  - `media_session_mapping_test.dart`: 11 new tests.
  - `mini_player_test.dart`: 11 new tests.

## Decisions Made

See `key-decisions` in the frontmatter. The one with a device consequence is dropping titles that arrive before ready. The plan and RESEARCH require it, and it is what stops a stale title leaking into a new load. If a station's first title arrived before READY, it would appear only at the next song change, because just_audio emits ICY metadata only when it changes. Media3 renders ICY metadata at the playback position, which does not advance before READY, so this should not happen. The device check (D5, step 4) confirms it.

## Deviations from Plan

### Auto-fixed Issues

None were needed. Two notes:

**1. [Note] `_nextGeneration()` replaces the bare `_generation++` in `pause`, `stop`, `_start` and `_fail`**
- **Found during:** Task 3 (GREEN)
- **Why:** The plan says to reset `_readySeenForGeneration` "on every load". Doing the reset where the generation changes makes it impossible to supersede a load without resetting the guard.
- **Committed in:** 2838ff1

**2. [Note] Additions beyond the plan's behaviour list**
- Handler tests:
  - The charset of the playing stream is proven with a cp1251 vs auto pair.
  - A resume after pause starts with no title.
  - A whitespace-only difference still counts as a duplicate.
  - The junk cases also cover empty and null titles.
- Mini-player tests: a song change and a clear, both in the live region.
- **Committed in:** ca945ad, 19caa58, 10fe3d0

---

**Total deviations:** 0 auto-fixed, plus 2 notes.
**Impact on plan:** None. There is no scope creep.

## Issues Encountered

None. `dart format` over whole directories still reports the 01-06 file `now_playing_parser_test.dart`, which is already logged in `deferred-items.md`. Only the files this plan touches were formatted.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model. All three threats are mitigated and unit-tested:
- T-08-01: only `parseIcyTitle` output reaches the MediaItem.
- T-08-02: distinct-until-changed before republishing.
- T-08-03: the generation guard, the pre-ready drop, the clears, and stop-before-load.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- **01-09 (reconnect):** Reconnecting and Interrupted keep their state text. Now-playing is not cleared while reconnecting, so the title comes back if the stream returns to Playing on the same load. Each reconnect load must go through `_nextGeneration()`, which drops titles until the new load is ready. If 01-09 wants the line cleared when a reconnect switches to a fallback stream, it calls `_setNowPlaying(null)` at that point.
- **01-11 (debug panel):** it can watch `nowPlayingProvider`.
- **End-of-phase UAT (D5), on the owner's phone:**
  1. Play БГ Радио and the other music stations through a few songs. Artist and title should appear in correct Cyrillic on the mini-player, the notification, the lock screen and the car display over Bluetooth, with no Latin-accented gibberish. The notification title should stay the station name.
  2. Play HLS Хоризонт. It should show only the station name.
  3. Switch station while a title is showing. The old title should disappear at once and never come back.
  4. Start a music station and check that the current song's title appears within a few seconds, without waiting for the next song.
- 01-02 (release signing) is still waiting on the owner.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED

All 11 modified files exist. Commits ca945ad, 59ffe91, 19caa58, 02e973d, 10fe3d0 and 2838ff1 are in git, and no tracked files were deleted. Every task's acceptance criteria and grep gates were re-run and pass. The plan-level verification (`flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze && flutter test`) passes with 278 tests.
