---
phase: 01-playback-engine-walking-skeleton
plan: 11
subsystem: playback
tags: [flutter, riverpod, debug-panel, diagnostics, widget-test, accessibility, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 09)
    provides: "AudioEngine.diagnostics, EngineDiagnostics / DiagnosticEvent (50-entry in-memory log), play(station, startStreamIndex:)"
  - phase: 01-playback-engine-walking-skeleton (plan 10)
    provides: "EngineDiagnostics.reconnectAttempt and nextRetryDelay filled"
  - phase: 01-playback-engine-walking-skeleton (plan 07)
    provides: "firstLaunchAtProvider (UTC), overridden in bootstrap"
provides:
  - "diagnosticsProvider: a keepAlive StreamProvider mirroring AudioEngine.diagnostics"
  - "DebugPanel (D-07): state, station, stream i/n and candidate, URL, kind, round, reconnect attempt, next retry delay, time-to-audio, first-launch date (ISO-8601 UTC) and the 50-entry event log newest first (HH:mm:ss.SSS)"
  - "Streams switcher: one row per streams[i] with a 'Play #i' button calling engine.play(station, startStreamIndex: i)"
  - "HomeScreen(showDebugTools: !kReleaseMode): the 'Debug' AppBar action opens DebugPanel in a modal bottom sheet"
affects: [01-12, 01-13, phase-1-uat]

# Actuals (#2632)
actuals:
  tokens: 5700
  tasks: 2
  commits: 4
plan_head_before: 04dd22cb58a5428360519b8a7713dfd84ad25a38

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Debug-only UI hangs off one const-defaulted widget parameter (showDebugTools = !kReleaseMode); only home_screen.dart imports debug_panel.dart"
    - "Debug tooling reads providers only and does no I/O, so diagnostics stay in memory"

key-files:
  created:
    - lib/features/playback/presentation/debug_panel.dart
    - test/features/playback/presentation/debug_panel_test.dart
  modified:
    - lib/features/playback/application/playback_providers.dart
    - lib/features/playback/application/playback_providers.g.dart
    - lib/app/home_screen.dart

key-decisions:
  - "The stream switcher plays with PlayContext.single(): AudioEngine exposes no current PlayContext, so there is no 'current context' to reuse. Next/previous do nothing after a switcher start until the station is started from the list again"
  - "Panel labels are plain English literals (never shipped, outside the BG copy review); null fields read as an em dash; times are HH:mm:ss.SSS local, the first-launch date ISO-8601 UTC"
  - "The Streams section sits above the event log so the switcher is reachable without scrolling past 50 events; the stream in use is shown in bold"

patterns-established:
  - "Debug and profile tooling: gate at the one entry point with a kReleaseMode-defaulted parameter, test both values of the flag, and grep-gate the import locality"

requirements-completed: [PLAY-07, PLAY-08, APP-06]

coverage:
  - id: D1
    description: "DebugPanel renders every EngineDiagnostics field and the first-launch date in ISO-8601 UTC; events newest first with HH:mm:ss.SSS; all 50 ring-buffer events; null fields as a dash; follows new diagnostics"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/presentation/debug_panel_test.dart#diagnostics (D-07) (5 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "T-11-01: HomeScreen(showDebugTools: false) has no 'Debug' tooltip, no bug icon and no DebugPanel; true opens the panel in a bottom sheet; the default is !kReleaseMode"
    requirement: APP-06
    verification:
      - kind: unit
        ref: "test/features/playback/presentation/debug_panel_test.dart#the debug action on the home screen (T-11-01) (3 tests)"
        status: pass
      - kind: other
        ref: "grep gates: kReleaseMode in home_screen.dart; debug_panel.dart imported only by home_screen.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Stream switcher: one row per stream (index, kind, codec, bitrate, URL); 'Play #2' gives exactly one play(station, startStreamIndex: 2); no station shows 'No station'; androidTapTargetGuideline and labeledTapTargetGuideline pass"
    requirement: PLAY-08
    verification:
      - kind: unit
        ref: "test/features/playback/presentation/debug_panel_test.dart#the stream switcher (SC1) (4 tests)"
        status: pass
      - kind: integration
        ref: "flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze && flutter test (437 tests, All tests passed!)"
        status: pass
    human_judgment: false
  - id: D4
    description: "On the owner's phone (debug build): every verified streams[] index of every station plays via 'Play #i' (SC1); time-to-audio is shown, typically < 3000 ms; the log shows Reconnecting -> Connecting -> Playing with timestamps during Wi-Fi toggles (SC3); the first-launch date equals the install day (SC5); a release build has no debug action"
    requirement: PLAY-08
    verification: []
    human_judgment: true
    rationale: "Real stream endpoints and on-device timing can only be observed on the owner's phone and network (the plan's <human-check>)."

# Metrics
duration: 5min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 11: A debug panel that shows what the engine is doing (debug and profile builds only) Summary

**Debug and profile builds now have a "Debug" action (bug icon) in the home screen's AppBar. It opens a bottom sheet with `DebugPanel`, which renders `EngineDiagnostics` live: state, station, `stream i/n (candidate c)`, URL, kind, round, reconnect attempt, next retry delay, last time-to-audio, the stored first-launch date in ISO-8601 UTC, and the 50-entry event log newest first with `HH:mm:ss.SSS` timestamps. A "Streams" section lists every `streams[i]` of the current station with a "Play #i" button that calls `engine.play(station, startStreamIndex: i)`, so the owner can prove each fallback endpoint plays (SC1). `HomeScreen.showDebugTools` defaults to `!kReleaseMode`, so release builds contain no debug action and never build the panel.**

## Performance

- **Duration:** about 5 min
- **Started:** 2026-09-25T19:57:42Z
- **Completed:** 2026-09-25T20:02:00Z
- **Tasks:** 2 of 2, both TDD (RED, then GREEN; no refactor needed)
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments

- **D-07 diagnostics view:**
  - `diagnosticsProvider` is a keepAlive `StreamProvider` over `AudioEngine.diagnostics` (generated `.g.dart` committed, D-17).
  - `DebugPanel` is a scrollable column: the engine fields, the first-launch date, the Streams switcher, then the event log (all 50 entries, newest first).
  - Missing values read as "—"; delays and time-to-audio read in milliseconds.
- **SC1 stream switcher:** one row per stream with index, kind, codec, bitrate and URL; the stream in use is bold. Each "Play #i" button has the tooltip "Play stream i" and a 48 dp target.
- **T-11-01 release gating:** `HomeScreen({this.showDebugTools = !kReleaseMode})`. The constant folds to false in release AOT, and `debug_panel.dart` is imported only by `home_screen.dart` (grep gate passes).
- **Privacy prohibition:** the panel only watches providers. It has no export, no file write and no network call. The event log stays in engine memory.
- **Tests:** 12 new widget tests; the full suite has 437 tests, and all pass. `flutter analyze` and `dart analyze` report no issues, and `build_runner` leaves no diff.

## Task Commits

1. **Task 1: In debug and profile builds the owner sees live engine diagnostics and the first-launch date.** RED `7a338fc` (test), GREEN `9f4cb14` (feat)
2. **Task 2: From the debug panel the owner can force-play any streams[] entry of the current station.** RED `5018deb` (test), GREEN `4a6f3ec` (feat)

**Plan metadata:** see the `docs(01-11): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `7a338fc`: 6 of 8 failed, all on assertions | `9f4cb14` | not needed | `check tdd-red-evidence` returned RED_EVIDENCE_OK for 3 targets: every field renders, events newest first, the Debug action opens the panel |
| 2 | `5018deb`: 4 of 12 failed, all on assertions | `4a6f3ec` | not needed | RED_EVIDENCE_OK for 2 targets: one row per stream with Play buttons, "No station" |

The Task 1 RED commit held scaffolding only: `diagnosticsProvider`, a `DebugPanel` stub that builds nothing (with `eventLogKey`), and the `showDebugTools` parameter with no action. Two tests passed in RED as characterisation tests: "showDebugTools false shows nothing" and "the default is on in tests". As in 01-03 to 01-10, the `flutter test --reporter json` output was converted to TAP for the checker.

## Files Created/Modified

- `lib/features/playback/presentation/debug_panel.dart` (new): `DebugPanel` and the private `_StreamRow`.
- `lib/features/playback/application/playback_providers.dart` and `.g.dart`: `diagnosticsProvider`.
- `lib/app/home_screen.dart`: the `showDebugTools` parameter, the Debug action and the bottom sheet (85 % height, drag handle).
- `test/features/playback/presentation/debug_panel_test.dart` (new): 12 widget tests.

## Decisions Made

See `key-decisions` in the frontmatter. The one the owner will notice: a station started from "Play #i" is started as a single station, so headset next/previous do nothing until it is started from the list again. The engine has no API that returns the current `PlayContext`; adding one was not worth an interface change for a debug tool.

## Deviations from Plan

### Auto-fixed Issues

None that changed behaviour.

**1. [Note] PlayContext.single() instead of "the current context"**
- **Found during:** Task 2
- **Issue:** the behaviour list says the switcher passes "the current context, or PlayContext.single() when there is none". `AudioEngine` exposes no current context, so from the panel there is never one.
- **Fix:** the switcher passes `const PlayContext.single()` explicitly (the plan's own action step calls `play(station, startStreamIndex: i)`, whose default is the same). The test asserts `SinglePlayContext`.
- **Committed in:** 4a6f3ec

---

**Total deviations:** 0 auto-fixed, 1 note.
**Impact on plan:** none; every truth and acceptance criterion holds.

## Issues Encountered

None. The open 01-06 formatting item in `deferred-items.md` was not touched; only this plan's files were formatted.

## Known Stubs

None. The "—" shown for empty fields is the display of a null value, not a placeholder.

## Threat Flags

None beyond the plan's threat model:
- T-11-01 is mitigated: `showDebugTools = !kReleaseMode`, the flag-off widget test, and the import-locality grep gate.
- T-11-02 is mitigated: the panel renders only; nothing is stored or sent.
- T-11-03 is accepted: the switcher plays only URLs from the curated station data, in debug/profile builds.

## User Setup Required

None.

## Next Phase Readiness

- **01-12 (connectivity) and 01-13 (focus):** new reducer rows appear in the panel's event log and state line automatically; no panel change is needed.
- **End-of-phase UAT (D4), on the owner's phone:**
  1. In a debug build (`flutter run`), tap the bug icon. For each station, play it and tap "Play #i" for every stream index in turn, about 20 s each. Every verified index should play.
  2. Note the time-to-audio after a normal start (typically under 3000 ms on good 4G or Wi-Fi).
  3. Toggle Wi-Fi while playing and watch the log: Reconnecting → Connecting → Playing, with timestamps.
  4. Check that the first-launch date is the day the app was first installed.
  5. Install a release build and confirm there is no bug icon.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*
