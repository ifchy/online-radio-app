---
phase: 01-playback-engine-walking-skeleton
plan: 09
subsystem: playback
tags: [flutter, audio_service, state-machine, reducer, fallback-streams, fakeAsync, diagnostics, media-buttons, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "RadioAudioHandler, generations on every player event, playbackStateFor (the FGS table), _lastStation resume, PlayContext"
  - phase: 01-playback-engine-walking-skeleton (plan 04)
    provides: "StreamResolver.resolve/invalidate and StreamResolutionException reasons"
  - phase: 01-playback-engine-walking-skeleton (plan 05)
    provides: "Stations with ordered fallback streams (2-3 each, N-JOY 1) and the dead-primary / slow-primary debug stations"
  - phase: 01-playback-engine-walking-skeleton (plan 08)
    provides: "ICY generation and ready guards, _setNowPlaying clears, sameMediaItem dedupe"
provides:
  - "PlaybackStateMachine: a pure reducer (state, event, now) -> (next state, commands) with EngineState, EngineEvent, EngineCommand, EngineTimings (connectTimeout 10 s, maxDeadOnArrivalRounds 2) and TimerKind.connect"
  - "Fallback rotation: next resolved candidate, then next stream; two dead-on-arrival rounds, then PlaybackError(allStreamsFailed), or unsupportedFormat when every failure was a format failure"
  - "RadioAudioHandler as the command executor: one serial event queue, publish before commands, background resolves stamped with their generation, dart:async timers per TimerKind, dispose()"
  - "EngineDiagnostics / DiagnosticEvent (D-07): state, station, stream and candidate in use, URL, kind, round, time-to-audio, 50-entry in-memory event log"
  - "PlayContext.neighbour; skipToNext/skipToPrevious on the handler (headset and car MediaButton.next/previous) and on AudioEngine"
  - "AudioEngine.play(..., startStreamIndex:) through the playFromMediaId extras key 'startStreamIndex' (RadioAudioHandler.startStreamIndexExtra); AudioEngine.diagnostics"
  - "FakeStreamResolver (scripted per-URL candidates, errors, delays, gates) and FakeEngine skip/diagnostics/startStreamIndex support"
affects: [01-10, 01-11, 01-12, 01-13, phase-3-next-prev, v1.1-android-auto]

# Actuals (#2632)
actuals:
  tokens: 22986
  tasks: 2
  commits: 4
plan_head_before: 7ae6545975fa627760d3e2b4dad4fe1d762b57ce

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every playback input is an EngineEvent reduced by the pure PlaybackStateMachine; the handler only executes the returned EngineCommands, in order, on one serial queue"
    - "After each transition the handler publishes station, media item and PlaybackState before running any command (Pitfall G)"
    - "Resolve runs in the background and comes back as Resolved/ResolveFailed stamped with its generation, so a slow playlist never blocks a pause or stop"
    - "User-facing handler methods await _dispatch(event) and then _settle(), which waits for the queue and the current generation's resolution only"
    - "The reducer owns the generation counter; the handler resets _readySeenForGeneration whenever the generation changes (the 01-08 _nextGeneration rule, moved)"
    - "Stale events return the same EngineState instance and no commands, so tests can assert `same(state)`"

key-files:
  created:
    - lib/features/playback/engine/state_machine.dart
    - lib/features/playback/domain/engine_diagnostics.dart
    - test/features/playback/engine/state_machine_test.dart
  modified:
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/features/playback/engine/audio_service_engine.dart
    - lib/features/playback/domain/audio_engine.dart
    - lib/features/playback/domain/play_context.dart
    - test/support/fakes.dart
    - test/features/playback/engine/radio_audio_handler_test.dart
    - test/app/tracer_e2e_test.dart

key-decisions:
  - "A round ends when rotation returns to the session's start stream (EngineState.startStreamIndex), so startStreamIndex 1 of 3 rotates 1, 2, 0 per round; a one-stream station (N-JOY) gets exactly two attempts"
  - "When every failure of a dead station was a format failure (unsupportedScheme, notAPlaylist, empty), the error kind is unsupportedFormat; otherwise allStreamsFailed. This keeps 01-04's actionable unsupportedFormat result"
  - "UserPlay and UserResume start a new session (everPlayed false). Resume after a pause starts on lastWorkingStreamIndex; resume after an error starts on the stream the user started at"
  - "A failure while Playing/Buffering (player error or completed) is Error(streamUnreachable) in this plan; the reducer's row is where 01-10 puts Reconnecting. The unreachable-in-01-09 'everPlayed and round ends' row also errors (streamUnreachable) and is pure-tested"
  - "PlayContext.neighbour returns null for a one-station list (restarting the same station is not a skip); skip after Stop moves from the last station"
  - "The Load command is awaited in the queue: with preload false and the player stopped, just_audio's setAudioSources only deactivates the platform, and the network work happens in the unawaited play(), so a dead host cannot block a pause"

patterns-established:
  - "New engine behaviour is a reducer row plus a pure test; the handler gains a command case only when a new side effect appears"
  - "Command failures (a platform stop or focus release throwing) are logged to diagnostics and never stop the queue; reducer bugs are also reported through Zone.handleUncaughtError"

requirements-completed: [PLAY-08, PLAY-10, PLAY-11, PLAY-03]

coverage:
  - id: D1
    description: "Pure reducer rows: UserPlay publishes Connecting(stream 0, round 0) with exactly StopTransport, ClearNowPlaying, StartTimer(connect, 10 s), Resolve; candidate then stream rotation with a new generation per load; round 1 from the start stream; exactly two dead-on-arrival rounds then PlaybackError(allStreamsFailed) with CancelAllTimers, InvalidateResolution, ClearNowPlaying, StopTransport, ReleaseFocus; unsupportedFormat for format-only failures; startStreamIndex wrap; out-of-range start -> 0"
    requirement: PLAY-08
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#UserPlay starts a station / Connecting rotates through candidates and streams (PLAY-08)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Connecting -> Playing cancels the connect timer and records time-to-audio from the user's play (across fallbacks); Playing <-> Buffering; a failure or completed while Playing/Buffering -> Error(streamUnreachable)"
    requirement: PLAY-08
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#Connecting reaches Playing / Playing and Buffering"
        status: pass
    human_judgment: false
  - id: D3
    description: "PLAY-10/PLAY-11 guards: every stale-generation event is a no-op in Connecting and Playing; pause/stop while connecting cancel all timers and a later resolve result is dropped; only UserPlay and UserResume leave Paused, Idle and Error; resume is a fresh Resolve at the live edge and no command seeks"
    requirement: PLAY-10
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#stale generations change nothing (PLAY-10) / user commands (PLAY-10, PLAY-11)"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#fallback rotation ... pause/stop while connecting: a resolve result landing afterwards never loads"
        status: pass
    human_judgment: false
  - id: D4
    description: "Handler under fakeAsync: playing/loading with 'Connecting…' is published before the resolve; dead primary -> stream 1 at once, then Playing; resolve-failing primary -> stream 1; slow primary -> stream 1 after 10 s; all dead -> exactly 6 loads (3 streams x 2 rounds) then Error with release() and playing false and no later retries; one-stream station -> 2 loads; a late failure, snapshot or first-attempt timer never acts"
    requirement: PLAY-08
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#fallback rotation (PLAY-08, PLAY-10), under fakeAsync (10 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Diagnostics (D-07): state, station id, stream and candidate index, URL, kind, round, time-to-audio 2.5 s across a fallback, reconnectAttempt 0 and nextRetryDelay null until 01-10, and an event log capped at 50 entries, newest last; AudioEngine.diagnostics replays the latest"
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#diagnostics: state, the stream in use, time-to-audio and a 50-entry event log, newest last (D-07)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Next/previous (PLAY-03): neighbour wraps both ways and is null for single, unknown and one-station lists; skipToNext/skipToPrevious, MediaButton.next/previous via click and the engine facade step through the list with the same context; a single station does nothing; the notification keeps Pause + Stop (D-12); startStreamIndex through engine.play and the extras, invalid extras -> streams[0]"
    requirement: PLAY-03
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#next/previous and the start stream (PLAY-03, D-12) (14 tests)"
        status: pass
    human_judgment: false
  - id: D7
    description: "Existing behaviour kept: the 8-step tracer (incl. _lastStation resume after Stop), resolver integration, notification text and ICY now-playing suites"
    verification:
      - kind: integration
        ref: "flutter test (356 tests, All tests passed!) incl. test/app/tracer_e2e_test.dart"
        status: pass
      - kind: other
        ref: "flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze (No issues found!, no generated diff)"
        status: pass
    human_judgment: false
  - id: D8
    description: "On the owner's phone in a debug build: 'ТЕСТ: мъртъв основен поток' plays its fallback at once and 'ТЕСТ: бавен основен поток' after about 10 s, with the notification showing 'Свързване…' meanwhile; a headset or car next/previous button steps through the home list"
    requirement: PLAY-08
    verification: []
    human_judgment: true
    rationale: "Real DNS failures, black-holed connects, ExoPlayer timeouts and Bluetooth media buttons exist only on a device on a real network (the plan's <human-check>). There is no Android SDK in the execution environment."

# Metrics
duration: 16min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 09: A dead primary stream falls over to its fallbacks, and next/previous step through the list Summary

**Playback is now driven by a pure `PlaybackStateMachine`. A failed or silent attempt (resolve failure, player failure, a load that ends at once, or 10 s without audio) moves to the stream's next resolved candidate, then to the next stream. A station that never plays is given up after exactly two rounds with `PlaybackError(allStreamsFailed)`: the transport stops, focus is released and every timer is cancelled. `RadioAudioHandler` is now a serial command executor. It publishes each new state before acting, drops every stale result, and keeps a 50-entry in-memory diagnostics log with the stream in use and the time-to-audio. Headset and car next/previous buttons step through the list the station was started from, and `engine.play(station, startStreamIndex:)` can start any stream.**

## Performance

- **Duration:** about 16 min
- **Started:** 2026-09-25T16:43:54Z
- **Completed:** 2026-09-25T16:59:40Z
- **Tasks:** 2 of 2, both TDD (RED, then GREEN; no refactor needed)
- **Files modified:** 10 (3 created, 7 modified)

## Accomplishments

- **PLAY-08 (dead primary):**
  - Rotation goes through candidates first, then `streams[]`, each load under a new generation.
  - A round ends when rotation returns to the start stream. Two rounds without audio end the session.
  - A one-stream station such as N-JOY gets exactly two attempts.
  - The connect timer is 10 s per attempt. Time-to-audio is counted from the user's play, across fallbacks.
  - Both limits live in `EngineTimings`, so they can be tuned on a device.
- **PLAY-10 (nothing survives a pause or stop):**
  - Every async result carries the generation it was issued for; stale events return the same state with no commands.
  - Pause and stop cancel all timers and supersede the generation, so a resolve that lands later never loads.
  - Only `UserPlay` and `UserResume` leave Paused, Idle and Error.
- **PLAY-11:** resume is always a fresh `Resolve` + `Load` at the live edge. The command set has no seek, and a test enforces it.
- **T-09-02 (battery):** a dead station ends with `CancelAllTimers`, `InvalidateResolution`, `ClearNowPlaying`, `StopTransport` and `ReleaseFocus`. `playing` becomes false, so audio_service drops the foreground service, and nothing retries afterwards (checked 5 fake minutes later).
- **Handler as executor:**
  - One serial queue. Each event is reduced, published (station, media item, then PlaybackState) and its commands are awaited before the next event is reduced.
  - When the queue is idle a player event is reduced synchronously, so the tracer's immediate assertions still hold.
  - Resolves run in the background, so a slow playlist never delays a pause.
  - Load is awaited. With `preload: false` on a stopped player, just_audio's `setAudioSources` only deactivates the platform (`just_audio.dart:896-900`), so a dead host cannot block the queue.
- **Carried forward, as required:**
  - (a) `res/raw/keep.xml`: no new drawables, so it is unchanged.
  - (b) `_lastStation`: `play()` from Idle restarts it, `getChildren(recentRootId)` returns it, and tracer step 8 passes.
  - (c) `AudioService.asyncError` logging: `bootstrap.dart` is untouched; the new constructor parameters have defaults.
  - (d) 01-07's field-wise `sameMediaItem` dedupe is kept.
  - (e) Now-playing is cleared by `ClearNowPlaying` on start, switch, pause, stop and failure. Every generation change resets `_readySeenForGeneration`.
  - (f) The interim "completed while playing → Error" now lives in the reducer's Playing/Buffering row, which is where 01-10 puts Reconnecting.
- **D-07 diagnostics:** `EngineDiagnostics` is kept in memory only (T-09-03). It holds the state, station id, stream and candidate index, URL, kind, round, last time-to-audio and a 50-entry event log (`UserPlay(curated:bg-radio, from stream 0) → Connecting(stream 0, round 0)`, …). `reconnectAttempt` and `nextRetryDelay` stay 0/null until 01-10.
- **PLAY-03 next/previous:**
  - `PlayContext.neighbour` wraps within a list.
  - The handler's `skipToNext`/`skipToPrevious` restart the neighbour with the same context. audio_service's `click(MediaButton.next/previous)` reaches them, so headset and car buttons work.
  - The notification still shows Pause + Stop only (D-12), and `playbackStateFor` is byte-identical.
- **Tests:** the full suite has 356 tests (up from 278), and all pass: 54 pure reducer tests, 10 fakeAsync rotation and diagnostics tests, and 14 next/previous and start-stream tests. `flutter analyze` and `dart analyze` report no issues, and `build_runner` leaves no diff. No test touches the network.

## Task Commits

1. **Task 1: A dead or slow primary stream falls over to its fallbacks, and a dead station errors after two rounds.** RED `0c350df` (test), GREEN `a72f44a` (feat)
2. **Task 2: Headset and car next/previous step through the station list, and the engine can start any stream of a station.** RED `b6302ac` (test), GREEN `6be862d` (feat)

**Plan metadata:** see the `docs(01-09): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `0c350df`: 57 of 86 failed | `a72f44a` | not needed | `check tdd-red-evidence` returned RED_EVIDENCE_OK for 7 targets: the UserPlay command order, the two-round give-up, dead primary, slow primary, all dead, pause while Connecting, and diagnostics |
| 2 | `b6302ac`: 7 of 46 failed, all on assertions | `6be862d` | not needed | RED_EVIDENCE_OK for 4 targets: neighbour wrap, skip wrap, headset buttons, and startStreamIndex 2 |

Notes on Task 1's RED run:
- 27 of the 57 failures were assertions, including all 7 targets.
- The other 30 failed during setup. Their helpers walk the reducer (`s.currentStream!`, `player.lastLoad`), and the no-op stub never leaves Idle. The RED commit held compile scaffolding only: the reducer types with a no-op `transition`, `EngineDiagnostics`, and the handler's timings/clock/diagnostics/dispose members.

Tests that passed in RED are characterisation tests:
- the existing resolver, notification-text and ICY suites
- the reducer's "stays Connecting" and resting-state no-op rows
- the old handler already dropping a resolve after pause or stop
- in Task 2, the null neighbours, the single-station no-op, the unchanged controls and the default or invalid start index

As in 01-03 to 01-08, each RED run used `flutter test --reporter json`, converted into TAP for the checker.

## Files Created/Modified

- `lib/features/playback/engine/state_machine.dart` (new): `PlaybackStateMachine`, `Transition`, `EngineState`, the `EngineEvent` and `EngineCommand` sealed families, `EngineTimings`, `TimerKind` and `describeStatus`. It imports only dart:core, the domain types and `ports.dart`.
- `lib/features/playback/domain/engine_diagnostics.dart` (new): `EngineDiagnostics` and `DiagnosticEvent`.
- `lib/features/playback/engine/radio_audio_handler.dart`: now the serial command executor. Also adds skip, the `startStreamIndex` extras key, diagnostics and `dispose()`.
- `lib/features/playback/engine/audio_service_engine.dart`: `play(startStreamIndex:)` through the extras, skip, and replayed diagnostics.
- `lib/features/playback/domain/audio_engine.dart`: `diagnostics`, `skipToNext`, `skipToPrevious`, and `play(..., startStreamIndex)`.
- `lib/features/playback/domain/play_context.dart`: `neighbour`.
- `test/support/fakes.dart`: `FakeStreamResolver` and `ResolveScript`; `FakeEngine` skip counters, `setDiagnostics` and `PlayCall.startStreamIndex`.
- `test/features/playback/engine/state_machine_test.dart` (new): the 54 pure reducer tests.
- `test/features/playback/engine/radio_audio_handler_test.dart`: the rotation, diagnostics and next/previous groups; handlers are disposed on teardown; two 01-04 expectations updated (see Deviations).
- `test/app/tracer_e2e_test.dart`: stops at the end (see Deviations).

## Decisions Made

See `key-decisions` in the frontmatter. The ones that change what the user sees:
- **Error kind of a dead station.** It is `allStreamsFailed` unless every failure was a format failure, in which case it is `unsupportedFormat`. Phase 4's error text (PLAY-09) can then say "this stream format isn't supported" instead of "can't reach the station".
- **Where resume starts.** After a pause it starts on the stream that last worked; after an error, on the stream the user started at.
- **One-station lists.** `neighbour` treats a one-station list as having no neighbour, so next/previous never restarts the current station.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan contract] Two 01-04 resolve-failure tests now expect two rounds**
- **Found during:** Task 1 (RED)
- **Issue:** "a failed resolve … ends in PlaybackError(streamUnreachable)" and "a playlist with nothing playable ends in PlaybackError(unsupportedFormat)" asserted the pre-rotation behaviour: one attempt and one invalidation. This plan's behaviour spec requires two dead-on-arrival rounds for a station that never played, and then `allStreamsFailed`.
- **Fix:**
  - The 404 test now expects `allStreamsFailed` and two invalidations.
  - The format test still expects `unsupportedFormat`, because the reducer keeps that kind when every failure was a format failure. It now expects two invalidations.
- **Files modified:** test/features/playback/engine/radio_audio_handler_test.dart, lib/features/playback/engine/state_machine.dart
- **Verification:** both tests pass, and the pure reducer tests cover both kinds.
- **Committed in:** 0c350df, a72f44a

**2. [Rule 3 - Blocking] The tracer ends with a Stop**
- **Found during:** Task 1 (GREEN)
- **Issue:** all 8 tracer steps passed, but step 8 ends in Connecting. The new 10 s connect timer was still pending when `testWidgets` checked for pending timers, so the test failed.
- **Fix:** after step 8, the tracer calls `engine.stop()` and asserts Idle. Stop cancels every engine timer.
- **Files modified:** test/app/tracer_e2e_test.dart
- **Verification:** the tracer passes.
- **Committed in:** a72f44a

**3. [Rule 2 - Missing Critical] The event queue survives failures, and hostile extras are ignored**
- **Found during:** Task 1 and Task 2 (GREEN)
- **Issue:** without guards, one bug would disable playback until the app restarts:
  - a throwing platform call (stop, focus release),
  - a reducer bug,
  - a `startStreamIndex` extra from another app that is out of range or not an int.
- **Fix:**
  - Command failures are logged to diagnostics and the next command still runs.
  - Reducer errors are logged, reported through `Zone.handleUncaughtError`, and the queue goes on.
  - Only an in-range int extra is honoured; anything else starts at `streams[0]`.
- **Files modified:** lib/features/playback/engine/radio_audio_handler.dart, lib/features/playback/engine/state_machine.dart
- **Verification:** the invalid-extras tests (out of range, negative, string) and the out-of-range reducer tests pass.
- **Committed in:** a72f44a, 6be862d

**4. [Rule 2 - Missing Critical] A load that completes before any audio counts as a failure**
- **Found during:** Task 1 (tests)
- **Issue:** the plan lists resolve failure, player failure and the connect timer as the ways an attempt fails. A progressive source that ends at once (a server that closes the connection) would otherwise wait out the full 10 s.
- **Fix:** Connecting + `completed` rotates like a failure.
- **Files modified:** lib/features/playback/engine/state_machine.dart
- **Verification:** "a load that completes at once counts as a failure" passes.
- **Committed in:** a72f44a

**5. [Note] Additions to the planned types**
- `EngineState` also has:
  - `startStreamIndex`, which marks the round boundary for a non-zero start;
  - `onlyFormatFailures`, which picks the error kind;
  - the helpers `currentStream` and `currentCandidate`.
- `Resolve` carries its `generation`, like `Load` and `StartTimer`, so the reducer stays the only source of generations.
- `ResolveFailed.reason` is nullable, for unexpected (non-resolver) errors.
- The handler takes optional `timings` and `clock`, and has `dispose()` for tests.
- 01-08's `_nextGeneration()` is gone: the reducer owns the counter, and `_apply` resets `_readySeenForGeneration` on every generation change. The rule "every load goes through a new generation that re-arms the ICY guard" still holds.
- **Committed in:** 0c350df, a72f44a

---

**Total deviations:** 4 auto-fixed (1 Rule 1 plan-contract, 1 Rule 3 blocking, 2 Rule 2 missing-critical), plus 1 note.
**Impact on plan:** every change serves the plan's own truths: dead stations error after two rounds, nothing acts after a pause, and the engine never stops on its own because of a bug. There is no scope creep, and the notification controls and the FGS table are unchanged.

## Issues Encountered

- `dart format` was run only on the files this plan touches. The 01-06 formatting item in `deferred-items.md` is still open and was not touched.

## Known Stubs

None. `EngineDiagnostics.reconnectAttempt` and `nextRetryDelay` are 0/null by design until 01-10 fills them, as the plan specifies.

## Threat Flags

None beyond the plan's threat model:
- T-09-01 is mitigated by the generation guard, timers cancelled on pause and stop, and the resting-state guard. All are unit-tested.
- T-09-02 is mitigated: two rounds, then Error with every stop command. Unit-tested.
- T-09-03 is mitigated: diagnostics live in memory only. Nothing writes them to storage or the network.
- T-09-04 is accepted: skip moves only within the curated list the user started from.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- **01-10 (reconnect):**
  - Replace the reducer's Playing/Buffering failure rows and the "everPlayed and round ends" row with Reconnecting, starting at `lastWorkingStreamIndex`.
  - Add `TimerKind`s for the backoff and the stall watchdog.
  - Fill `reconnectAttempt` and `nextRetryDelay` in diagnostics.
  - `playbackStateFor` already maps Reconnecting to playing: true.
- **01-11 (debug panel):** `AudioEngine.diagnostics` and `play(station, startStreamIndex:)` are ready for the stream switcher and the event log.
- **01-12 (connectivity) and 01-13 (focus):** add events and reducer rows; the handler needs a new command case only for a new side effect.
- **End-of-phase UAT (D8), on the owner's phone (debug build, `flutter run`):**
  1. Play "ТЕСТ: мъртъв основен поток". The fallback (Радио 1) should play by itself at once.
  2. Play "ТЕСТ: бавен основен поток". БГ Радио should play after about 10 s. The notification should show "Свързване…" until then.
  3. Start a station from the home list and press next/previous on a headset or the car's Bluetooth controls. The station should step through the list and wrap around at both ends.
- 01-02 (release signing) is still waiting on the owner.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED

All 10 created or modified files exist. Commits 0c350df, a72f44a, b6302ac and 6be862d are in git, and no tracked file was deleted. The TDD gate commits are present: test(01-09) before feat(01-09) for both tasks. Both tasks' acceptance criteria and grep gates were re-run and pass (reducer purity, wiring, skip and startStreamIndex; playbackStateFor unchanged). The plan-level verification (`flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze && flutter test`) passes with 356 tests.
