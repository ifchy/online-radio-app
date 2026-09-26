---
phase: 01-playback-engine-walking-skeleton
plan: 10
subsystem: playback
tags: [flutter, audio_service, state-machine, reconnect, backoff, retry-budget, stall-watchdog, fakeAsync, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 09)
    provides: "The pure PlaybackStateMachine, the serial command executor in RadioAudioHandler, generations on every async result, EngineDiagnostics, fallback rotation"
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "playbackStateFor (Reconnecting -> buffering, playing true), the FGS table"
provides:
  - "RetryBudgetPreset standard (3/10 min), trip (5/10 min), batterySaver (1/5 min) as one engine-level setting (D-10)"
  - "ReconnectPolicy: 0, 1, 2, 4, 8, 15, 30 s capped, ±20 % jitter from an injected Random"
  - "RetryBudgetClock / BudgetExhaustion: an immutable outage clock with separate online-failing and offline budgets, start/recovered/onConnectivity/exhausted/remaining/reset/withPreset"
  - "Reducer rows: 8 s stall watchdog, Reconnecting on a drop, completed or failed retry round, retries from lastWorkingStreamIndex, budget give-up, 30 s stable reset, SetRetryBudget"
  - "AudioEngine.setRetryBudget -> AudioServiceEngine -> RadioAudioHandler.setRetryBudget (SetRetryBudget on the queue); RadioAudioHandler(initialRetryBudget:, reconnectPolicy:)"
  - "EngineDiagnostics.reconnectAttempt and nextRetryDelay filled"
affects: [01-11, 01-12, 01-13, phase-3-settings]

# Actuals (#2632)
actuals:
  tokens: 18221
  tasks: 2
  commits: 4
plan_head_before: 7aaa24f1c0b29844178ae3c190950106f924a8c8

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The retry budget is a value in EngineState (RetryBudgetClock), so the reducer stays pure; the handler only runs the timers it asks for"
    - "The budget timer is the one timer not guarded by generation (it spans every retry of an outage): its guard is the clock itself (running) plus an active outage status"
    - "Every reconnect entry is CancelAllTimers, ClearNowPlaying, StopTransport, [InvalidateResolution], StartTimer(backoff), StartTimer(budget, remaining)"
    - "A new session (UserPlay/UserResume) starts with CancelAllTimers, so nothing of the old session can fire into it"

key-files:
  created:
    - lib/features/playback/domain/retry_budget.dart
    - lib/features/playback/engine/reconnect_policy.dart
    - test/features/playback/engine/reconnect_policy_test.dart
  modified:
    - lib/features/playback/engine/state_machine.dart
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/features/playback/domain/audio_engine.dart
    - lib/features/playback/engine/audio_service_engine.dart
    - lib/features/playback/domain/engine_diagnostics.dart
    - test/support/fakes.dart
    - test/features/playback/engine/state_machine_test.dart
    - test/features/playback/engine/radio_audio_handler_test.dart

key-decisions:
  - "A retry is a Connecting (as RESEARCH and the plan specify), so the notification alternates 'Повторно свързване…' while waiting and 'Свързване…' while a retry loads; both keep playing true and the FGS"
  - "EngineState.attempt counts the retries started in the outage: Reconnecting(attempt n) waits delayFor(n); the backoff firing starts retry n+1. A retry round (from lastWorkingStreamIndex, rotating through candidates and streams) that fails goes back to Reconnecting with the next delay"
  - "The budget clock stops (recovered) when a retry reaches Playing, so playing time never counts; a drop within 30 s resumes it with the time already spent and continues the backoff; 30 s stable resets both"
  - "A stall reconnects without InvalidateResolution (the URL was fine); a player failure or completed invalidates the stream"
  - "Budget exhaustion online -> PlaybackError(streamUnreachable), offline -> PlaybackError(offline) (reachable once 01-12 feeds connectivity)"
  - "SetRetryBudget applies to an outage in progress: the budget timer is re-armed for what is left under the new preset"

patterns-established:
  - "Timers that span generations need their own guard in the reducer; every other TimerFired is dropped when its generation is stale"

requirements-completed: [PLAY-07, PLAY-10, PLAY-11, PLAY-01]

coverage:
  - id: D1
    description: "ReconnectPolicy steps 0/1/2/4/8/15/30 s capped, every jittered delay within ±20 %, attempt 0 always 0 s; preset values; RetryBudgetClock online/offline accounting, recovered/resume, reset, withPreset, remaining"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/reconnect_policy_test.dart (22 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Pure rows: stall 8 s -> Reconnecting(0) with immediate retry and a fresh load under a new generation; drop/completed -> Reconnecting with InvalidateResolution and backoff; retry from lastWorkingStreamIndex then rotation; backoff 0,1,2,4,8,15,30,30 s; stale triggers emit no Load; playbackStateFor(Reconnecting).playing true"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#reconnect after a drop or a stall (PLAY-07, PLAY-11)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Budget: 3 min standard online -> PlaybackError(streamUnreachable) with CancelAllTimers, StopTransport, ReleaseFocus and playing false; the budget timer spans retries; 30 s stable resets budget and attempt; batterySaver gives up after 1 min; a change mid-outage re-arms the budget timer"
    requirement: PLAY-01
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#the retry budget setting (D-10)"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#reconnect after a drop (PLAY-07, PLAY-10, PLAY-11), under fakeAsync"
        status: pass
    human_judgment: false
  - id: D4
    description: "PLAY-10: pause, stop or another station during Reconnecting or while a retry resolves cancels every timer; no later timer fire or resolve result starts anything (checked 10 fake minutes later)"
    requirement: PLAY-10
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#user commands win over a reconnect (PLAY-10)"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#pause/stop during Reconnecting, while a retry is resolving, another station during Reconnecting"
        status: pass
    human_judgment: false
  - id: D5
    description: "Handler under fakeAsync: loads at 0, 1, 3, 7, 15, 30, 60, 90, 120, 150 s after a drop, then Error at 3 min with release and no retries; diagnostics reconnectAttempt 2 / nextRetryDelay 2 s while waiting; engine.setRetryBudget reaches the handler"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#backoff per attempt ... standard gives up after 3 min online"
        status: pass
      - kind: integration
        ref: "flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze && flutter test (425 tests, All tests passed!)"
        status: pass
    human_judgment: false
  - id: D6
    description: "On Xiaomi and Samsung in a release build: 60 s of no internet -> the notification stays showing 'Повторно свързване…' and audio returns within ~10 s at the live edge; > 3 min blocked -> error notification with Play and no foreground service in dumpsys (SC3)"
    requirement: PLAY-07
    verification: []
    human_judgment: true
    rationale: "Real stream drops, ExoPlayer timeouts and OS FGS behaviour cannot be simulated in the container (the plan's <human-check>)."

# Metrics
duration: 11min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 10: Drops and stalls come back at the live edge, with backoff and a bounded retry budget Summary

**A station that was playing no longer ends in an error when its stream drops. A player failure, a `completed` snapshot, or 8 s stuck in Buffering now leads to Reconnecting. The engine then retries at the live edge after a backoff of 0, 1, 2, 4, 8, 15 or 30 s (±20 % jitter), starting from the stream that last worked. Throughout, the status reports `playing: true`, so the foreground service and notification stay up. An immutable `RetryBudgetClock` in the reducer state limits the outage. With the `standard` preset, the engine gives up after 3 minutes of failing while online: it shows `PlaybackError(streamUnreachable)`, and the transport, focus and every timer are released. 30 s of stable playback resets both the backoff and the budget. The give-up policy is one engine setting, `AudioEngine.setRetryBudget(standard | trip | batterySaver)` (D-10). Pause, stop or another station always wins over a pending retry.**

## Performance

- **Duration:** about 11 min
- **Started:** 2026-09-25T19:42:00Z
- **Completed:** 2026-09-25T19:53:04Z
- **Tasks:** 2 of 2, both TDD (RED, then GREEN; no refactor needed)
- **Files modified:** 11 (3 created, 8 modified)

## Accomplishments

- **D-10, retry budget presets:**
  - `RetryBudgetPreset` has three presets: `standard` (3 min online / 10 min offline), `trip` (5 / 10 min) and `batterySaver` (1 / 5 min).
  - The trip offline value is a single constant (RESEARCH A6).
  - `AudioEngine.setRetryBudget` goes through `AudioServiceEngine` to `RadioAudioHandler.setRetryBudget` and then onto the serial queue as `SetRetryBudget`. A change applies to an outage already in progress.
  - `FakeEngine` records these calls.
- **Backoff and budget clock:**
  - `ReconnectPolicy` gets its randomness from an injected `Random`, and tests seed it. `jitter: 0` gives exact delays.
  - `RetryBudgetClock` is pure and immutable. Time spent failing while online counts only against the online budget, and time offline only against the offline budget.
  - Once a retry plays again, `recovered` stops the clock, so playing time never counts. `reset` ends the outage.
- **PLAY-07, the reducer rows:**
  - Playing + buffering arms the 8 s stall watchdog. A ready snapshot cancels it. If it fires, the stream is reloaded through Reconnecting(attempt 0), which retries at once under a new generation.
  - A drop or `completed` while Playing or Buffering, and a failed retry round, all lead to Reconnecting. The failed stream's resolution is invalidated, except after a stall.
  - Each retry is a fresh `Resolve` + `Load`, with no seek (PLAY-11).
  - Rows 01-09 said "error on a drop" and "error when a round ends after the station played". Both now lead to Reconnecting.
- **PLAY-01, the foreground service while recovering:**
  - Reconnecting maps to `buffering`, and a retry Connecting to `loading`. Both report `playing: true`.
  - When the engine gives up, it cancels every timer, invalidates the stream, clears now-playing, stops the transport and releases focus. `playing` then becomes false, so audio_service drops the foreground service.
- **PLAY-10:**
  - Pause and stop cancel every timer, including backoff, stall, stable and budget, and reset the outage.
  - A new session starts with `CancelAllTimers`.
  - Every `TimerFired` except the budget timer is guarded by generation. The budget timer is guarded by the clock instead.
  - Tests confirm that nothing loads in the 10 fake minutes after the user acts.
- **Diagnostics:** `reconnectAttempt` holds the number of retries in the current outage. `nextRetryDelay` holds the current backoff and is set only while Reconnecting.
- **Tests:** 425 tests in total, up from 356, and all pass.
  - 22 `reconnect_policy_test` tests
  - about 25 new pure reducer tests
  - 14 new fakeAsync handler tests
  - 4 retry-budget setting tests
  - `flutter analyze` and `dart analyze` are clean, and `build_runner` leaves no diff.

## Task Commits

1. **Task 1: The retry budget presets and the backoff policy exist as one engine-level setting.** RED `1bf03d5` (test), GREEN `400d3dc` (feat)
2. **Task 2: Drops and stalls reconnect at the live edge with backoff, keep the FGS alive, and give up after the budget.** RED `193f8cc` (test), GREEN `420f3be` (feat)

**Plan metadata:** see the `docs(01-10): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `1bf03d5`: 21 of 72 failed | `400d3dc` | not needed | `check tdd-red-evidence` returned RED_EVIDENCE_OK for 5 targets: the standard preset values, the jitter bounds, the offline/online split, withPreset, and engine.setRetryBudget reaching the handler |
| 2 | `193f8cc`: 42 of 147 failed | `420f3be` | not needed | RED_EVIDENCE_OK for 7 targets: the stall row, the 3 min budget, the handler backoff and give-up, the 30 s stable reset, the batterySaver switch, pause during Reconnecting, and UserPlay during Reconnecting |

The RED commits contained scaffolding only, so the tests failed on assertions and not at compile time:
- Task 1: the new types with no-op bodies.
- Task 2: the new `TimerKind`s, `EngineTimings` fields, `EngineState.budget`/`attempt`, the `SetRetryBudget` event (reduced as a no-op), and the `policy` constructor argument.

Some tests passed during RED. These are characterisation tests: for example, "no outage is never exhausted", the stop-during-reconnect row (the old code reached Idle from Error), and the existing suites. As in 01-03 to 01-09, the JSON reporter output was converted to TAP for the checker.

## Files Created/Modified

- `lib/features/playback/domain/retry_budget.dart` (new): `RetryBudgetPreset`.
- `lib/features/playback/engine/reconnect_policy.dart` (new): `ReconnectPolicy`, `RetryBudgetClock`, `BudgetExhaustion`. It imports only `dart:math` and the domain enum.
- `lib/features/playback/engine/state_machine.dart`:
  - new `TimerKind`s: stall, backoff, stablePlaying, budget
  - `EngineTimings.stallTimeout` (8 s) and `stablePlayingReset` (30 s)
  - `EngineState.budget` and `attempt`
  - the `SetRetryBudget` event
  - the reducer now takes `policy`
  - the reconnect, retry, budget and stable rows
- `lib/features/playback/engine/radio_audio_handler.dart`:
  - new constructor parameters `initialRetryBudget` (it seeds `EngineState.budget`) and `reconnectPolicy` (default `ReconnectPolicy(Random())`)
  - `retryBudget` and `setRetryBudget`
  - diagnostics fill `reconnectAttempt` and `nextRetryDelay`
- `lib/features/playback/domain/audio_engine.dart` and `lib/features/playback/engine/audio_service_engine.dart`: `setRetryBudget`.
- `lib/features/playback/domain/engine_diagnostics.dart`: doc comments only (see Deviations).
- `test/support/fakes.dart`: `FakeEngine.retryBudgetCalls`.
- Tests: `reconnect_policy_test.dart` (new), `state_machine_test.dart`, `radio_audio_handler_test.dart`.

## Decisions Made

See `key-decisions` in the frontmatter. These are the ones the owner will notice:
- **Notification text during an outage.** It shows "Повторно свързване…" while waiting between retries and "Свързване…" while a retry is loading. A retry is a Connecting state, as RESEARCH and the plan specify. The notification and the foreground service stay up throughout. If the owner prefers "Повторно свързване…" all the way through, a later plan can add a retry flag to `PlaybackStatus.connecting`.
- **What resets the backoff.** Recovery alone does not reset it; 30 s of stable playback does. A stream that flaps (plays a few seconds, then drops) backs off further on each drop and still hits the 3 min budget.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Plan contract] 01-09 expectations updated for the new rows**
- **Found during:** Task 2 (RED)
- **Issue:** several existing tests asserted the interim 01-09 behaviour that this plan replaces:
  - "error after one round when the station had played"
  - "drop while Playing/Buffering → Error"
  - "Buffering has no commands"
  - the exact command list of a new session
  - two handler tests expecting `PlaybackError` after a player failure
- **Fix:**
  - Those tests now expect Reconnecting and the stall-timer commands.
  - A new session's command list now starts with `CancelAllTimers` (see 2).
  - The two handler tests now assert Reconnecting, then the immediate retry.
- **Files modified:** test/features/playback/engine/state_machine_test.dart, test/features/playback/engine/radio_audio_handler_test.dart
- **Committed in:** 193f8cc, 420f3be

**2. [Rule 2 - Missing Critical] A new session cancels every timer of the old one**
- **Found during:** Task 2
- **Issue:** the plan requires that UserPlay of another station during Reconnecting "wins the same way" as pause/stop. That includes cancelling the pending backoff, stall and budget timers. 01-09's `_start` only replaced the connect timer.
- **Fix:** `_start` (which also serves UserResume) now emits `CancelAllTimers` first.
- **Committed in:** 420f3be

**3. [Rule 2 - Missing Critical] The retry budget clock stops while playback is back**
- **Found during:** Task 1 design
- **Issue:** the plan's `RetryBudgetClock` API has no way to stop counting while a retry plays but the outage is not yet 30 s stable. Without one, playing time would count as "failing" and use up the budget.
- **Fix:**
  - Added `recovered(now)` and the `active`/`running` getters. `start` now resumes a stopped outage and keeps its elapsed time.
  - Added `onlineFailingAt`/`offlineAt` for tests and diagnostics.
- **Committed in:** 400d3dc

**4. [Rule 2 - Missing Critical] The budget timer is robust to firing early and to generation changes**
- **Found during:** Task 2
- **Issue:** one outage spans many generations, because every retry increments the generation. A budget timer guarded by generation would go stale after the first retry. A timer that fires a millisecond early would never give up.
- **Fix:**
  - The budget timer acts only while the clock is running in Reconnecting or a retry Connecting. If it fires early, it re-arms for the time left.
  - The backoff timer and every reconnect entry also check whether the budget is exhausted.
- **Committed in:** 420f3be

**5. [Note] Additions to the planned API**
- `ReconnectPolicy` takes an optional `jitter` (default 0.2), so tests can assert exact delays.
- `RadioAudioHandler` takes an optional `reconnectPolicy`, for deterministic handler tests.
- `engine_diagnostics.dart` had two stale doc comments ("0/null until 01-10"). They were updated. This file is not in the plan's file list, but the change is to doc comments only.

---

**Total deviations:** 4 auto-fixed (1 Rule 1 plan-contract, 3 Rule 2 missing-critical), plus 1 note.
**Impact on plan:** each change serves the plan's truths: nothing restarts after a user command, the budget bounds battery and data use, and playing time is never counted as failing. There is no scope creep. The notification controls and `playbackStateFor` are unchanged.

## Issues Encountered

- A `dart format` over the whole playback folder reformatted an unrelated 01-06 test (the open formatting item in `deferred-items.md`). That change was reverted before committing; only this plan's files were formatted.

## Known Stubs

None. The offline budget (`BudgetExhaustion.offline` → `PlaybackError(offline)`) exists and is tested at the clock level. The engine treats the network as online until 01-12 passes connectivity into `RetryBudgetClock.onConnectivity`, as the plan specifies.

## Threat Flags

None beyond the plan's threat model:
- T-10-01 is mitigated: the presets, the backoff capped at 30 s with jitter, and a full release when the budget is exhausted. Unit-tested with fakeAsync.
- T-10-02 is mitigated: Reconnecting and retry Connecting both report `playing: true`. Unit-tested.
- T-10-03 is mitigated: `CancelAllTimers` on pause, stop and a new session; the generation guard on every timer except the budget timer, which is guarded by the clock; only UserPlay/UserResume leave Paused, Idle or Error. Unit-tested.

## User Setup Required

None.

## Next Phase Readiness

- **01-11 (debug panel):** `EngineDiagnostics.reconnectAttempt`/`nextRetryDelay` and the `Reconnecting(attempt n)` state string are ready.
- **01-12 (connectivity):**
  - Feed `RetryBudgetClock.onConnectivity(now, online:)` through a new event.
  - Add the rows "Reconnecting + online → retry now and reset the backoff" and "offline → waitingForNetwork".
  - Offline exhaustion already maps to `PlaybackError(offline)`.
- **01-13 (focus):** Interrupted + gain is the other path allowed to start playback without a user command. Pause, stop and a new session already reset the outage.
- **End-of-phase UAT (D6), on Xiaomi and Samsung, release build:**
  1. Play a station and unplug the router (Wi-Fi stays connected) for 60 s, then plug it back in. The notification should stay up, mostly showing "Повторно свързване…" (it switches to "Свързване…" while each retry loads). Audio should come back by itself within about 10 s, at the live edge.
  2. Block the station's host, or keep the router unplugged, for more than 3 minutes. The notification should then show the error state with a Play button, and `adb shell dumpsys activity services bg.izk.radio` should show no foreground service.
  3. Optional: confirm the notification text during an outage is acceptable (see Decisions).

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED

All 11 created or modified files exist. Commits 1bf03d5, 400d3dc, 193f8cc and 420f3be are in git, and no tracked file was deleted. The TDD gate commits are in order: test(01-10) before feat(01-10) for both tasks. Both tasks' grep gates were re-run and pass (presets, policy, clock, setRetryBudget; stallTimeout, delayFor, SetRetryBudget; no Flutter or plugin import in the reducer). The plan-level verification (`flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze && flutter test`) passes with 425 tests.
