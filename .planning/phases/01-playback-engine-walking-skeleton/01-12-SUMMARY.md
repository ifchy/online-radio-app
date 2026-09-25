---
phase: 01-playback-engine-walking-skeleton
plan: 12
subsystem: playback
tags: [flutter, connectivity_plus, state-machine, reconnect, offline-budget, flow-check, fakeAsync, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 10)
    provides: "RetryBudgetClock.onConnectivity / exhausted(offline), the Reconnecting rows, the budget timer, ReconnectPolicy"
  - phase: 01-playback-engine-walking-skeleton (plan 09)
    provides: "The pure PlaybackStateMachine, the serial event queue, StreamPlayer.bufferedPositions, generations"
provides:
  - "ConnectivityPort / ConnectivityChange (ports.dart) and ConnectivityPortImpl over connectivity_plus: 500 ms debounce, online = anything but none, networkChanged = a different set than the last online one; isOnline via checkConnectivity sets the baseline"
  - "Reducer events ConnectivityChanged(online, networkChanged) and BufferedPositionChanged(generation, position); TimerKind.flowCheck; EngineTimings.flowCheckDelay (5 s) and connectivityDebounce (500 ms); EngineState.online, lastBuffered, flowCheckBaseline"
  - "Rows: offline during an outage -> Reconnecting(waitingForNetwork) with no backoff and the offline budget running; online or a network change while Reconnecting/Buffering -> retry now with the backoff reset; network change while Playing -> 5 s flow check that reloads only without buffered progress; offline budget -> PlaybackError(offline)"
  - "RadioAudioHandler(…, strings, ConnectivityPort, …): seeds from isOnline(), queues connectivity changes and buffered positions; bootstrap passes ConnectivityPortImpl(Connectivity())"
  - "FakeConnectivityPort in test/support/fakes.dart"
affects: [01-13, phase-1-uat, phase-3-settings, phase-4-error-ux]

# Actuals (#2632)
actuals:
  tokens: 18249
  tasks: 2
  commits: 4
plan_head_before: 3bd228611b01281218366e70e7b063d05780cfbe

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Connectivity is one more event on the serial queue; the budget clock owns the online flag (EngineState.online is a getter over it), so the two never disagree"
    - "Every mid-session reload goes through _reloadNow (retry from the last working stream, backoff reset, new generation); a second trigger in the same outage finds Connecting or a stale generation and emits no load"
    - "High-rate player signals (buffered position) are reduced but not written to the diagnostics log"

key-files:
  created:
    - lib/features/playback/engine/connectivity_port_impl.dart
    - test/features/playback/engine/connectivity_port_impl_test.dart
  modified:
    - lib/features/playback/engine/ports.dart
    - lib/features/playback/engine/state_machine.dart
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/features/playback/engine/reconnect_policy.dart
    - lib/app/bootstrap.dart
    - test/support/fakes.dart
    - test/features/playback/engine/state_machine_test.dart
    - test/features/playback/engine/radio_audio_handler_test.dart
    - test/app/tracer_e2e_test.dart

key-decisions:
  - "The adapter starts as 'online on an unknown network' and reports only differences from the last state seen (isOnline or an earlier change): the platform's current-state echo on subscribe is silent, an offline first event is reported, and a Wi-Fi -> none -> Wi-Fi flap inside the debounce reports nothing"
  - "networkChanged compares with the last set the device was online on, so airplane mode on Wi-Fi then off on mobile data is online + networkChanged; going offline is never a network change"
  - "Offline while Playing or Buffering only records the flag: the buffer keeps playing, and the stall watchdog or a player failure moves to Reconnecting, which then waits for the network directly"
  - "Offline while a retry is connecting abandons the retry (StopTransport, new generation) and waits; a user start that is still Connecting is left alone (its connect timer and rotation cover it)"
  - "The reducer's buffered-position event is BufferedPositionChanged, because ports.dart already has a BufferedPosition value class and state_machine.dart imports it"
  - "A station that never played and is given up while offline reports PlaybackError(offline) instead of allStreamsFailed"

patterns-established:
  - "Connectivity rows exist only for Reconnecting, a retry Connecting, Buffering and Playing; every other state just records the flag (PLAY-10)"

requirements-completed: [PLAY-07, PLAY-10]

coverage:
  - id: D1
    description: "ConnectivityPortImpl: [wifi] then [mobile] -> one change (online, networkChanged); [wifi] then [none] -> offline; three changes within 500 ms -> one change; flap back to the same state -> nothing; back on the same/another network after offline; isOnline false for [none], true for [mobile]/[wifi]/[wifi, vpn]; isOnline sets the baseline; platform stream listened only while the port is; pending debounce dropped on cancel; FakeConnectivityPort"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/connectivity_port_impl_test.dart (15 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Pure rows: offline while Playing records only; drop while offline -> Reconnecting(waitingForNetwork) with no backoff timer and a 10 min budget timer; offline while Reconnecting or a retry Connecting -> waiting, late results dropped; online while waiting -> Connecting from the last working stream with attempt reset and a fresh Resolve/Load; network change deep in the backoff -> retry now, next wait 1 s; online with no change -> nothing; network change while Buffering -> reload now"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#connectivity, the flow check and the offline budget (PLAY-07, PLAY-10, D-10)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Flow check: a network change while Playing arms a 5 s check; no buffered progress -> immediate reload; progress -> nothing; positions from an older load are not progress; a stale check does nothing; offline at the check -> waiting, not a retry"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#the flow check after a network change while Playing"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#Wi-Fi to 4G while Playing (stuck / still arriving)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Offline budget (D-10, T-12-01): 10 min offline -> PlaybackError(offline) with CancelAllTimers, StopTransport, ReleaseFocus and playing false; an early budget fire re-arms; offline time counts only against the offline budget (2 min online + 8 min offline leaves 1 min online); the budget timer is re-armed when the flag changes mid-outage; handler: no loads during 9 min 59 s offline, error at 10 min, nothing after"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#the offline budget"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#standard offline budget: 10 min offline -> Error(offline)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Idempotency (T-12-02): stall timer and network change at the same moment, in either order, give exactly one Resolve (pure) and one extra Load (handler, same fakeAsync tick); online or a network change while Connecting gives no new load"
    requirement: PLAY-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#idempotency: one outage, one fresh connection"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#idempotency / online while Connecting"
        status: pass
    human_judgment: false
  - id: D6
    description: "PLAY-10 (T-12-03): in Paused, Idle (after stop and never played) and PlaybackError every connectivity event gives no commands; pause while waiting for the network cancels the budget timer (still Paused 15 min later); after pause/stop the handler loads nothing on offline/online/network change"
    requirement: PLAY-10
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#after a user pause or stop, and in an error, connectivity starts nothing (PLAY-10)"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#after a user pause/stop, connectivity events start nothing"
        status: pass
      - kind: integration
        ref: "flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze && flutter test (502 tests, All tests passed!)"
        status: pass
    human_judgment: false
  - id: D7
    description: "On Xiaomi and Samsung in a release build: Wi-Fi off while playing and an airplane-mode toggle (60 s) -> audio back by itself within ~10 s at the live edge, notification shows 'Повторно свързване…' meanwhile; pause + Wi-Fi toggle -> nothing restarts; airplane mode > 10 min -> error notification with Play and no foreground service in dumpsys (SC3)"
    requirement: PLAY-07
    verification: []
    human_judgment: true
    rationale: "Real network switches, airplane mode and OS FGS behaviour cannot be simulated in the container (the plan's <human-check>)."

# Metrics
duration: 8min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 12: Wi-Fi↔4G switches and offline periods are ridden out without draining the battery Summary

**The engine now listens to the network through a debounced `ConnectivityPort` (connectivity_plus, 500 ms). When playback drops while the phone is offline, the engine does not burn retries. It waits in `Reconnecting(waitingForNetwork: true)` with the notification and foreground service kept up, and only the offline budget runs. After 10 minutes (standard preset) it gives up with `PlaybackError(offline)`, and the transport, focus and all timers are released. When the network comes back, or the phone moves to another network, a Reconnecting or Buffering station retries at once from the stream that last worked, with the backoff reset. It does not wait for ExoPlayer's I/O timeouts. A network change while Playing arms a 5 s flow check, and the stream is reloaded only if the buffered position has stopped advancing. One outage always gives one fresh connection, and connectivity never restarts a paused, stopped or failed station.**

## Performance

- **Duration:** about 8 min
- **Started:** 2026-09-25T20:07:03Z
- **Completed:** 2026-09-25T20:14:52Z
- **Tasks:** 2 of 2, both TDD (RED, then GREEN; no refactor needed)
- **Files modified:** 11 (2 created, 9 modified)

## Accomplishments

- **The connectivity adapter** (`connectivity_port_impl.dart`, the only file that imports connectivity_plus):
  - It debounces `onConnectivityChanged` by 500 ms (T-12-02).
  - `online` is true when the result list holds anything other than `none`.
  - `networkChanged` is true when the device is online on a different set of results than the last set it was online on.
  - It reports only real differences. `isOnline()` (via `checkConnectivity`) sets the baseline, so the platform's current-state echo on subscribe is silent.
- **Reducer rows** (`state_machine.dart`, still pure):
  - Offline during an outage → waiting for the network, with no backoff and the offline budget running (T-12-01).
  - Back online or on a new network while Reconnecting or Buffering → `_reloadNow`: a retry with the backoff reset and a new generation, at the live edge.
  - A network change while Playing → the 5 s flow check against `lastBuffered` of the current generation.
  - The budget timer is re-armed whenever the flag changes mid-outage.
  - A backoff that fires while offline waits instead of retrying.
- **PLAY-10 / T-12-03:** Paused, Idle and PlaybackError only record the flag. A user start that is still Connecting is left alone.
- **Handler and bootstrap:**
  - `RadioAudioHandler` takes the port as its sixth positional parameter and seeds itself from `isOnline()` (a failing port counts as online).
  - Connectivity changes and buffered positions go through the serial queue. Buffered positions are not written to the 50-entry diagnostics log.
  - `nextRetryDelay` is null while waiting for the network.
  - `bootstrap.dart` passes `ConnectivityPortImpl(Connectivity(), debounce: EngineTimings().connectivityDebounce)`.
- **Tests:** 502 in total, up from 437, and all pass. The new tests are 15 adapter tests, 38 pure reducer tests and 12 fakeAsync handler tests. `flutter analyze` and `dart analyze` report no issues, `build_runner` leaves no diff, and the CI import-boundary and tracking-SDK checks pass.

## Task Commits

1. **Task 1: A debounced connectivity adapter reports when the network goes away, comes back or changes.** RED `43207bf` (test), GREEN `cb041ca` (feat)
2. **Task 2: Wi-Fi↔4G switches and airplane toggles come back at the live edge, and offline waits end after the budget.** RED `07ba2e7` (test), GREEN `f55bd88` (feat)

**Plan metadata:** see the `docs(01-12): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `43207bf`: 10 of 15 failed, all on assertions | `cb041ca` | not needed | The adapter stub returned an empty stream and always-online. The 5 tests that passed in RED are characterisation tests: the default debounce, isOnline true, an online first signal staying silent, the listener lifecycle and the fake. |
| 2 | `07ba2e7`: 30 of 502 failed, all on assertions | `f55bd88` | not needed | The scaffolding (events reduced as no-ops, `TimerKind.flowCheck`, the timings, the state fields, the constructor parameter and the bootstrap wiring) compiled. The tracer test passed with `FakeConnectivityPort`. |

Before GREEN, two RED reducer tests were corrected. They failed one stream of the three-stream station where they meant to fail a whole retry round, so a `failRound` helper was added. The RED commit contains the original version.

## Files Created/Modified

- `lib/features/playback/engine/ports.dart`: `ConnectivityChange`, `ConnectivityPort`.
- `lib/features/playback/engine/connectivity_port_impl.dart` (new): `ConnectivityPortImpl`.
- `lib/features/playback/engine/state_machine.dart`:
  - events `ConnectivityChanged` and `BufferedPositionChanged`
  - `TimerKind.flowCheck`
  - `EngineTimings.flowCheckDelay` and `connectivityDebounce`
  - `EngineState.online`, `lastBuffered`, `flowCheckBaseline` and `currentBufferedPosition`
  - `_connectivityChanged`, `_reloadNow` and `_flowCheck`
  - offline handling in `_reconnect` and `_retry`
  - `describeStatus` gains ", waiting for network"
- `lib/features/playback/engine/radio_audio_handler.dart`: the `ConnectivityPort` parameter, `_watchConnectivity`, `_onBufferedPosition`, the log filter and the diagnostics.
- `lib/features/playback/engine/reconnect_policy.dart`: a doc comment only (the "until 01-12" note).
- `lib/app/bootstrap.dart`: the adapter wiring.
- `test/support/fakes.dart`: `FakeConnectivityPort`.
- Tests: `connectivity_port_impl_test.dart` (new), `state_machine_test.dart`, `radio_audio_handler_test.dart`, `tracer_e2e_test.dart`.

## Decisions Made

See `key-decisions` in the frontmatter. These are the ones the owner will notice on a device:
- **Wi-Fi turned off while playing.** The engine does not stop the audio still in the buffer. Once the buffer runs dry, the player fails or stalls (8 s). The engine then waits for the network without retrying, and it reconnects as soon as mobile data comes up. That moment usually comes as a network change, which triggers the reconnect.
- **The flow check and HLS.** БНР Хоризонт is HLS-only, and an HLS buffered position moves in whole segments. For a live stream it cannot run ahead of the live edge. After a network change, a healthy HLS stream may therefore show no progress within 5 s and be reloaded anyway, which costs one short gap. RESEARCH A13 leaves this timing to be tuned on a device. If it happens often on Хоризонт, lengthen `flowCheckDelay`, or skip the check for HLS.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The reducer event is named `BufferedPositionChanged`, not `BufferedPosition`**
- **Found during:** Task 2
- **Issue:** `ports.dart` already defines a `BufferedPosition` value class (the `StreamPlayer` stream element), and `state_machine.dart` imports `ports.dart`. A second class with the same name would not compile.
- **Fix:** the event is `BufferedPositionChanged(generation, position)`. The handler maps each port `BufferedPosition` to it.
- **Committed in:** 07ba2e7, f55bd88

**2. [Rule 2 - Missing Critical] Buffered positions are kept out of the diagnostics log**
- **Found during:** Task 2
- **Issue:** just_audio reports the buffered position about every 500 ms while playing. Logging each event would push every useful entry out of the 50-entry log within about 25 s, and the owner's UAT depends on that log (01-11).
- **Fix:** `_apply` does not log `BufferedPositionChanged`. A handler test covers this.
- **Committed in:** f55bd88

**3. [Rule 2 - Missing Critical] Offline handling of a retry in flight, a backoff firing offline, and give-up while offline**
- **Found during:** Task 2
- **Issue:** the behaviour list covers offline "during an outage". Two cases were not covered:
  - A retry that is loading when the network drops would otherwise keep rotating and fail through the online budget.
  - A never-played station given up in airplane mode would report `allStreamsFailed`.
- **Fix:**
  - Offline during a retry Connecting abandons the retry and waits. `_retry` also waits when offline.
  - `_nextStream` gives up with `PlaybackErrorKind.offline` when the network is down.
- **Committed in:** f55bd88

**4. [Note] Additions to the planned API**
- `EngineState.online` is a getter over `budget.online` rather than a separate field, so there is only one online flag.
- `EngineState.flowCheckBaseline` and `currentBufferedPosition` implement "the last buffered position for the flow check" with a generation guard, so positions from an older load never count as progress.
- `FakeConnectivityPort` counts `isOnlineCalls`.
- `reconnect_policy.dart` had a stale doc comment ("until 01-12"), which was updated. This file is not in the plan's file list, but the change is to a doc comment only.

---

**Total deviations:** 3 auto-fixed (1 Rule 3 blocking, 2 Rule 2 missing-critical), plus 1 note.
**Impact on plan:** every truth and acceptance criterion holds, and there is no scope creep. The notification strings and `playbackStateFor` are unchanged: waiting for the network maps to Reconnecting, which is `buffering` with `playing: true`.

## Issues Encountered

None. Only this plan's files were formatted. The open 01-06 formatting item in `deferred-items.md` was not touched.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model:
- **T-12-01 is mitigated.** There are no backoff retries while offline, the 10 min offline budget has its own timer, and everything is released when it runs out. Unit-tested with fakeAsync.
- **T-12-02 is mitigated.** The adapter has a 500 ms debounce. Online while Connecting does nothing, and a double trigger gives one load (both orders, pure and handler).
- **T-12-03 is mitigated.** Paused, Idle and PlaybackError only record the flag. Unit-tested for every event kind.

## User Setup Required

None.

## Next Phase Readiness

- **01-13 (audio focus):** Interrupted currently falls into the "record the flag only" branch for connectivity. If Interrupted + gain should reload after a network change during a call, 01-13 can add that row.
- **End-of-phase UAT (D7), on Xiaomi and Samsung, release build** (in a debug build the 01-11 debug panel shows each step):
  1. Play a station on Wi-Fi, then run `adb shell svc wifi disable`. Audio should return by itself within about 10 s of mobile data coming up, at the live edge.
  2. Run `adb shell cmd connectivity airplane-mode enable`, wait 60 s, then disable it. Meanwhile the notification should stay up showing "Повторно свързване…". Audio should return within about 10 s of the network returning.
  3. Pause, toggle Wi-Fi off and on, and wait 2 minutes. Nothing should restart.
  4. Play a station, enable airplane mode and wait more than 10 minutes. The notification should show the error state with a Play button, and `adb shell dumpsys activity services bg.izk.radio` should show no foreground service.
  5. Optional: on БНР Хоризонт (HLS), switch Wi-Fi to 4G a few times and note whether each switch causes a short gap (see Decisions: the flow check and HLS).

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*
