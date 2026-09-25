---
phase: 01-playback-engine-walking-skeleton
plan: 13
subsystem: playback
tags: [flutter, audio_session, audio-focus, becoming-noisy, wifi-lock, method-channel, kotlin, state-machine, fakeAsync, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 12)
    provides: "ConnectivityPort as the handler's 6th positional parameter, the connectivity rows (Interrupted only records the flag)"
  - phase: 01-playback-engine-walking-skeleton (plan 10)
    provides: "Reconnecting keeps playing true, RetryBudgetClock.reset, CancelAllTimers on every new session"
  - phase: 01-playback-engine-walking-skeleton (plan 09)
    provides: "The pure PlaybackStateMachine, the serial event queue, generations, focus release on pause/stop/error"
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "just_audio with handleInterruptions: false, playbackStateFor (Interrupted -> buffering, playing true), WAKE_LOCK permission"
provides:
  - "FocusChange (transientLoss, permanentLoss, duckBegin, duckEnd, gainAfterPause); AudioSessionPort.focusChanges / becomingNoisy; focusChangeFor(AudioInterruptionEvent) mapping in audio_session_port_impl.dart"
  - "Reducer events FocusChanged / BecomingNoisy, command SetVolume, EngineState.ducked, PlaybackStateMachine.duckVolume (0.3)"
  - "Rows: transient loss in an active state -> Interrupted (transport stopped, focus + FGS kept, no budget); gain in Interrupted -> fresh load from the last working stream; permanent loss / noisy -> Paused with focus released; duck 0.3 -> 1.0; volume restored whenever focus is released or regained after a call"
  - "WifiLockPort (ports.dart), WifiLockChannel (Dart, MethodChannel bg.izk.radio/wifi_lock, MissingPluginException/PlatformException no-op), Kotlin object WifiLockChannel in MainActivity.kt (WIFI_MODE_FULL_HIGH_PERF, non-reference-counted, tag eRadioto:stream)"
  - "RadioAudioHandler(player, session, directory, resolver, strings, connectivity, wifiLock, …): wantsWifiLock(status), lock derived after every transition, onTaskRemoved override"
  - "FakeWifiLockPort; FakeAudioSessionPort.emitFocus / emitNoisy"
affects: [phase-1-uat, phase-3-settings, phase-4-play-declaration, v1.1-android-auto]

# Actuals (#2632)
actuals:
  tokens: 18083
  tasks: 2
  commits: 4
plan_head_before: 77f0f7740e5928dd0531fad932294a5382b06429

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Focus and noisy events are one more input on the serial queue; the engine is their single owner (just_audio handleInterruptions: false)"
    - "Resources that follow the state (the Wi-Fi lock) are derived in the handler after each transition, not emitted as reducer commands; the call is awaited only when the derived value changes, so no-command transitions stay synchronous"
    - "Cross-cutting reducer invariants are applied in one wrapper around the reducer (_restoreVolumeOnRelease), not in each row"

key-files:
  created:
    - lib/features/playback/engine/wifi_lock_channel.dart
    - test/features/playback/engine/wifi_lock_channel_test.dart
    - test/features/playback/engine/audio_session_port_impl_test.dart
  modified:
    - android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt
    - lib/features/playback/engine/ports.dart
    - lib/features/playback/engine/audio_session_port_impl.dart
    - lib/features/playback/engine/state_machine.dart
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/app/bootstrap.dart
    - test/support/fakes.dart
    - test/features/playback/engine/state_machine_test.dart
    - test/features/playback/engine/radio_audio_handler_test.dart
    - test/app/tracer_e2e_test.dart

key-decisions:
  - "Interrupted bumps the generation, stops the transport, cancels every timer and resets the retry budget, but keeps focus (audio_session still holds the request) and playing true (FGS kept). Nothing but the gain, a user command, a permanent loss or becoming noisy leaves it, so a call of any length resumes (D-11)"
  - "The resume after a call is a new session from lastWorkingStreamIndex (a fresh Resolve + Load at the live edge) that keeps everPlayed, so a drop after the call reconnects instead of being given up as dead on arrival"
  - "Becoming noisy and a permanent focus loss reuse the user-pause row (_pause), so they release focus, stop every timer and can never auto-resume; in Paused, Idle and PlaybackError they do nothing"
  - "EngineState.ducked tracks a duck: duckBegin/duckEnd only emit SetVolume when the flag changes; any transition that releases focus (pause, stop, error, noisy, permanent loss) appends SetVolume(1.0), because no duckEnd arrives once focus is abandoned; the resume after a call restores 1.0 first; a new station keeps the duck (focus is still held)"
  - "The Wi-Fi lock is derived in the handler after each transition: held in Connecting, Playing, Buffering and Reconnecting; released in Interrupted, Paused, PlaybackError and Idle. The handler remembers what it last asked for, so each enter/leave of the held set is exactly one platform call"
  - "WifiLockPort is the handler's 7th positional parameter (after ConnectivityPort), matching the 01-12 convention; tests pass FakeWifiLockPort"
  - "onTaskRemoved stops only in Paused, Idle or PlaybackError; an active or Interrupted station keeps playing after a swipe from recents"
  - "No new drawable or resource is looked up by name, so res/raw/keep.xml is unchanged"

patterns-established:
  - "A platform resource with a battery cost is held only for the states in the RESEARCH FGS table and is covered by an 8-variant invariant test (playing flag, lock, focus)"

requirements-completed: [PLAY-05, PLAY-06, PLAY-10, PLAT-06]

coverage:
  - id: D1
    description: "audio_session mapping: begin+pause -> transientLoss, begin+unknown -> permanentLoss, begin+duck -> duckBegin, end+pause -> gainAfterPause, end+duck -> duckEnd, end+unknown ignored; every FocusChange is produced"
    requirement: PLAY-05
    verification:
      - kind: unit
        ref: "test/features/playback/engine/audio_session_port_impl_test.dart (7 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Pure rows: transient loss in Connecting/Playing/Buffering/Reconnecting -> Interrupted with [CancelAllTimers, ClearNowPlaying, StopTransport], no ReleaseFocus, playing true; gain -> Connecting at stream 1 (last working) with a fresh Resolve; a 15-minute call with every timer firing changes nothing, then resumes; connectivity and stale player events ignored while Interrupted; UserPause/UserStop from Interrupted"
    requirement: PLAY-05
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#audio focus and becoming noisy (PLAY-05, PLAY-06, PLAY-10, D-11)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Permanent loss and becoming noisy in every active state and Interrupted -> Paused with stopAll; later gain/online change nothing. Duck 0.3 -> 1.0 with no status change; pause while ducked restores 1.0; a call during a duck restores 1.0 on resume"
    requirement: PLAY-06
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#another media app / becoming noisy / navigation prompts"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#calls, navigation prompts, unplugging and other media apps"
        status: pass
    human_judgment: false
  - id: D4
    description: "PLAY-10: in Paused, Idle (after stop and never played) and PlaybackError, gainAfterPause, transientLoss, permanentLoss, duckBegin, BecomingNoisy and ConnectivityChanged(online, networkChanged) give no commands (pure); after a user pause/stop and in an error, the handler loads nothing on gain, noisy or online events over 15 fake minutes"
    requirement: PLAY-10
    verification:
      - kind: unit
        ref: "test/features/playback/engine/state_machine_test.dart#after a user pause or stop, and in an error, focus, noisy and network events start nothing (PLAY-10)"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#after a user pause/stop, in PlaybackError"
        status: pass
    human_judgment: false
  - id: D5
    description: "Invariant table over all 8 PlaybackStatus variants: (playing, Wi-Fi lock, focus) = Connecting/Playing/Buffering/Reconnecting (true, held, held), Interrupted (true, released, held), Paused/PlaybackError (false, released, released), Idle (false, released, released, processingState idle); acquire/release exactly once per enter/leave; post-stop state; onTaskRemoved stops only in Paused/Idle/PlaybackError"
    requirement: PLAT-06
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#Wi-Fi lock, focus and the foreground service per state (PLAT-03, PLAT-06, PLAY-01)"
        status: pass
      - kind: unit
        ref: "test/features/playback/engine/wifi_lock_channel_test.dart (5 tests incl. no handler registered)"
        status: pass
      - kind: integration
        ref: "test/app/tracer_e2e_test.dart (lock held after the tile tap and Play, released after Pause and Stop)"
        status: pass
      - kind: integration
        ref: "flutter analyze && dart analyze && flutter test (599 tests, All tests passed!); flutter build apk --release (built, channel and lock tag present in the dex)"
        status: pass
    human_judgment: false
  - id: D6
    description: "SC4 on the owner's phones, release build, screen off: normal call > 1 min and > 10 min resume live; WhatsApp/Viber call (A10 if permanent focus); Maps voice prompts duck; wired and Bluetooth unplug pause and stay paused; pause + Wi-Fi toggle restarts nothing; resume after a 5-minute pause from the lock screen and car Bluetooth is live, with no ForegroundServiceStartNotAllowedException / AUDIOFOCUS_REQUEST_FAILED in logcat; another media app pauses for good"
    requirement: PLAY-05
    verification: []
    human_judgment: true
    rationale: "Telephony, VoIP apps, navigation ducking, headset hardware and car head units exist only on the owner's devices (the plan's Task 1 <human-check>)."
  - id: D7
    description: "SC2 on Xiaomi and Samsung, CI-signed release APK, notification permission denied: 60 min screen-off on Wi-Fi and on 4G without dropouts or an OS kill; dumpsys wifi shows the eRadioto:stream lock while playing; controls from notification, lock screen, wired, BT and car BT; after Stop no FGS, AudioService wake lock or Wi-Fi lock; a swipe while paused ends the service; FGS demo video recorded"
    requirement: PLAT-03
    verification: []
    human_judgment: true
    rationale: "OEM battery management, Wi-Fi power save, Bluetooth and car head units exist only on the owner's physical devices (the plan's Task 2 <human-check>, PROJECT working agreement)."

# Metrics
duration: 11min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 13: The radio behaves like a radio around calls, headphones and screen-off Wi-Fi, and Stop leaves nothing running Summary

**Audio-focus and becoming-noisy events now go through the state machine, and the engine is their only owner. A phone call moves an active station to `Interrupted`: the transport stops, but focus and the foreground service stay (`playing: true`). When the call ends, the station resumes with a fresh load at the live edge from the stream that last worked, however long the call was (D-11). A navigation prompt ducks the volume to 0.3 and restores it afterwards. Another media app taking focus, unplugged headphones and a Bluetooth disconnect all pause like a user pause, and nothing resumes them. A new `bg.izk.radio/wifi_lock` MethodChannel holds a `WIFI_MODE_FULL_HIGH_PERF` lock. The lock is held only in Connecting, Playing, Buffering and Reconnecting. A swipe from recents while paused, stopped or in an error ends the service.**

## Performance

- **Duration:** about 11 min
- **Started:** 2026-09-25T20:18:02Z
- **Completed:** 2026-09-25T20:29:25Z
- **Tasks:** 2 of 2, both TDD (RED, then GREEN; no refactor needed)
- **Files modified:** 13 (3 created, 10 modified)

## Accomplishments

- **Focus mapping** (`audio_session_port_impl.dart`):
  - `focusChangeFor` maps `interruptionEventStream` exactly as in the RESEARCH table. The end of an `unknown` interruption is ignored, because Android sends no gain after a permanent loss.
  - `becomingNoisyEventStream` feeds `becomingNoisy`.
  - just_audio still runs with `handleInterruptions: false`, so the grep gate holds.
- **Reducer rows** (`state_machine.dart`, still pure):
  - `FocusChanged` / `BecomingNoisy` events, a `SetVolume` command and `EngineState.ducked`.
  - Transient loss → `Interrupted`. The gain → a new session from `lastWorkingStreamIndex` that keeps `everPlayed`.
  - Permanent loss or noisy → the pause row.
  - Duck → 0.3, and back to 1.0.
  - A wrapper restores full volume whenever a transition releases focus.
  - The documented list of paths that start playback without a user command is now exactly two: Interrupted + gain, and Reconnecting + timer/connectivity.
- **Handler** (`radio_audio_handler.dart`):
  - Subscribes to `focusChanges` and `becomingNoisy` on the serial queue and executes `SetVolume` with `player.setVolume`.
  - `wantsWifiLock(status)` decides the lock after every transition, with one call per change.
  - `onTaskRemoved` calls `stop()` only in Paused, Idle or PlaybackError.
- **Wi-Fi lock:**
  - `MainActivity.kt` is the RESEARCH code: `AudioServiceActivity` plus `object WifiLockChannel` (non-reference-counted, application context, `@Suppress("DEPRECATION")`).
  - The Dart `WifiLockChannel` treats `MissingPluginException` and `PlatformException` as no-ops.
  - `bootstrap.dart` passes `WifiLockChannel()`.
- **Tests:** 599 in total, up from 502, and all pass.
  - 7 mapping tests
  - about 55 pure reducer tests
  - about 30 fakeAsync handler tests, including the 8-variant invariant table and the onTaskRemoved cases
  - 5 MethodChannel tests
  - lock assertions added to the tracer test
  - `flutter analyze` and `dart analyze` are clean. `flutter build apk --release` succeeds, and the dex contains `bg.izk.radio/wifi_lock` and `eRadioto:stream`.

## Task Commits

1. **Task 1: Phone calls pause and resume the radio, navigation prompts duck it, and unplugging or another media app pauses it.** RED `ebac95f` (test), GREEN `8001c70` (feat)
2. **Task 2: Screen-off Wi-Fi stays awake while playing, and Stop or a task swipe leaves nothing running.** RED `f3f5616` (test), GREEN `5bf40a5` (feat)

**Plan metadata:** see the `docs(01-13): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `ebac95f`: 35 of the engine suite failed, all on assertions (no compile or runtime errors) | `8001c70` | not needed | The scaffolding compiled: `FocusChange`, the port getters returning empty streams, both events reduced as no-ops, and the `SetVolume` command and executor. The existing no-seek exhaustiveness test gained `SetVolume()`. |
| 2 | `f3f5616`: 11 failed, all on assertions | `5bf40a5` | not needed | The scaffolding compiled: `WifiLockPort`, a stub `WifiLockChannel`, `FakeWifiLockPort`, the 7th constructor parameter at every call site, and the bootstrap wiring. The Idle onTaskRemoved case failed with "No element" because nothing was logged without the override. That is an assertion on missing behaviour, not a harness error. |

Before GREEN, one RED handler test was split in two. It ran two `fakeAsync` blocks in one test, and they shared the per-test `player` fixture.

## Files Created/Modified

- `android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt`: `configureFlutterEngine` plus the `WifiLockChannel` object.
- `lib/features/playback/engine/ports.dart`: `FocusChange`, the extended `AudioSessionPort` and `WifiLockPort`.
- `lib/features/playback/engine/audio_session_port_impl.dart`: the event streams and `focusChangeFor`.
- `lib/features/playback/engine/wifi_lock_channel.dart` (new): the Dart channel.
- `lib/features/playback/engine/state_machine.dart`: the events, `SetVolume`, `ducked`, `duckVolume`, `_focusChanged`, `_interrupt`, `_resumeAfterInterruption`, `_restoreVolumeOnRelease` and the updated reducer docs.
- `lib/features/playback/engine/radio_audio_handler.dart`: the subscriptions, `SetVolume`, `wantsWifiLock`, `_syncWifiLock`, `onTaskRemoved` and the 7th parameter.
- `lib/app/bootstrap.dart`: `WifiLockChannel()`.
- `test/support/fakes.dart`: `FakeAudioSessionPort.emitFocus`/`emitNoisy` and `FakeWifiLockPort`.
- Tests: `audio_session_port_impl_test.dart` (new), `wifi_lock_channel_test.dart` (new), `state_machine_test.dart`, `radio_audio_handler_test.dart` and `tracer_e2e_test.dart`.

## Decisions Made

See `key-decisions` in the frontmatter. These are the ones the owner will notice on a device:
- **During a call** the notification shows "Прекъснато" with Pause and Stop, and the foreground service stays. After hang-up it shows "Свързване…", then the live stream. If the owner presses Pause during the call, nothing resumes after it.
- **A new station during a navigation prompt** keeps the ducked volume until the prompt ends. Focus is still held, so the prompt's duckEnd restores it. On API 26+ Android ducks by itself, so this path matters mainly on Android 7.x.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Volume stuck at 0.3 after a pause or a call during a duck**
- **Found during:** Task 1 design
- **Issue:** the plan's rows are duckBegin → 0.3 and duckEnd → 1.0. audio_session delivers focus events only while it holds a request.
  - After a pause (focus abandoned), the duckEnd never arrives. just_audio keeps its volume across loads, so the next play would start at 0.3.
  - A call that starts during a duck resets audio_session's duck flag. The gain then arrives as a pause-type end, not duckEnd.
- **Fix:**
  - `EngineState.ducked` tracks the duck.
  - A wrapper appends `SetVolume(1.0)` to any transition that releases focus while ducked.
  - The resume after a call restores 1.0 first.
  - `_start` carries the flag, because a new station keeps the focus request.
- **Files modified:** state_machine.dart, state_machine_test.dart, radio_audio_handler_test.dart
- **Committed in:** ebac95f, 8001c70

**2. [Rule 1 - Bug] The Wi-Fi lock sync must not make no-command transitions asynchronous**
- **Found during:** Task 2 (GREEN)
- **Issue:** awaiting the lock sync after every transition added a microtask gap even when nothing changed. Events queued back to back, such as a stale snapshot, a stale failure and then the current ready snapshot, were no longer reduced in the same turn. The tracer test caught this.
- **Fix:** the queue awaits `_syncWifiLock` only when `wantsWifiLock(status)` differs from what was last asked.
- **Committed in:** 5bf40a5

**3. [Rule 2 - Missing Critical] The mapping is unit-tested**
- **Found during:** Task 1
- **Issue:** the plan's acceptance criterion "maps all five FocusChange values and becomingNoisy" had only a grep gate.
- **Fix:** the mapping is a pure top-level `focusChangeFor(AudioInterruptionEvent)`, and the new `audio_session_port_impl_test.dart` checks all six event combinations. This test file is not in the plan's file list.
- **Committed in:** 8001c70, f3f5616 (formatting)

**4. [Note] Additions to the planned API**
- `Interrupted` resets the retry budget and bumps the generation. Stale player events and timers of the stopped load are dropped, and no budget runs during a call.
- Idle, Paused and PlaybackError also ignore `transientLoss`, `permanentLoss` and `duckBegin`, not only gain, noisy and online. They produce no commands at all.
- `FakeAudioSessionPort.close()` and `FakeWifiLockPort.isHeld()` exist for completeness.

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 2 missing-critical), plus 1 note.
**Impact on plan:** every truth and acceptance criterion holds, and there is no scope creep. `playbackStateFor` and the notification strings are unchanged.

## Issues Encountered

- A `dart format test/` reformatted three unrelated 01-06 test files (the open formatting item in `deferred-items.md`). They were restored with `git checkout -- <file>` before committing. Only this plan's files were formatted.

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model:
- **T-13-01 is mitigated.** The lock is derived from state (held only in Connecting, Playing, Buffering and Reconnecting) and is non-reference-counted. The invariant table test covers it, and the post-Stop dumpsys check is an owner item.
- **T-13-02 is mitigated.** Only Interrupted + gainAfterPause resumes. Noisy and permanent loss go through the pause row, and every PLAY-10 row is unit-tested.
- **T-13-03 is mitigated.** Interrupted keeps `playing: true`, so the foreground service never drops during a call. Resuming after a user pause from Bluetooth or the lock screen is an owner check (Pitfall G / A5).
- **T-13-04 is accepted.** The channel is in-process and exposes only the app's own lock.

## User Setup Required

None.

## Owner Device Matrix (end-of-phase UAT, not run here)

These human checks are batched into the Phase 1 UAT. They could not run in this environment, and the results and the FGS demo video link go here once the owner has run them.

**SC4 (Task 1), release build, screen off:**
1. A normal call longer than 1 minute, then one longer than 10 minutes. After hang-up the radio should resume live by itself both times.
2. A WhatsApp or Viber call. Expected: the same as (1). If the app takes permanent focus, the radio stays paused; record that as the known limitation A10 (Pitfall H).
3. Google Maps voice prompts. The radio should duck under them and never stop.
4. Unplug wired headphones, and separately turn off a Bluetooth headset or car Bluetooth. Playback should pause and stay paused.
5. Pause, toggle Wi-Fi, and wait 2 minutes. Nothing should restart.
6. Pause for 5 minutes, then press Play from the lock screen and from car Bluetooth. Audio should be live. Capture `adb logcat | grep -E "ForegroundService|AudioFocus|ExoPlayer|audio_service"`: there should be no `ForegroundServiceStartNotAllowedException` and no `AUDIOFOCUS_REQUEST_FAILED`.
7. Start YouTube. The radio should pause and stay paused.

**SC2 / PLAT-03 / APP-07 (Task 2), CI-signed release APK, notification permission denied on Android 13+:**
1. 60 minutes with the screen off on Wi-Fi, then on 4G, on both Xiaomi and Samsung. There should be no dropouts and no OS kill.
2. While playing, run `adb shell dumpsys wifi | grep -i -A3 wifilock`. It should show an `eRadioto:stream` lock.
3. Control playback from the notification, the lock screen, a wired headset, a Bluetooth headset and the car's plain Bluetooth (disable Android Auto projection first, D-16). Play, pause and stop should work from every surface.
4. Press Stop, then run `adb shell dumpsys activity services bg.izk.radio`, `adb shell dumpsys power | grep -i wake_lock` and the wifi dumpsys again. There should be no foreground service, no AudioService wake lock and no `eRadioto:stream` lock, and the notification should be gone.
5. Pause, then swipe the app away from recents. The service should end and the notification should disappear.
6. Record the unlisted FGS demo video for the Phase 4 Play declaration, if it was not recorded at the 01-01 gate. **Link:** _pending (owner)_

## Next Phase Readiness

- Phase 1 has all 13 plans executed. What remains is the end-of-phase verification and the owner's device matrix above, plus the D7 items of 01-10 and 01-12.
- **v1.1 (Android Auto / media resumption):** move the Wi-Fi lock channel into an in-repo plugin, so it is registered when the service starts the engine without an activity. Until then that case plays without a Wi-Fi lock.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED

All 13 created or modified files exist. Commits ebac95f, 8001c70, f3f5616 and 5bf40a5 are in git, and no tracked file was deleted. The TDD gate commits are in order: test(01-13) before feat(01-13) for both tasks. Both tasks' grep gates were re-run and pass:
- Task 1: `interruptionEventStream` and `becomingNoisyEventStream` in the adapter, `transientLoss` in the reducer, and `handleInterruptions: false` in the player.
- Task 2: the channel name, `WIFI_MODE_FULL_HIGH_PERF` and `setReferenceCounted(false)` in Kotlin, the channel name and `MissingPluginException` in Dart, `onTaskRemoved`, and `WifiLockChannel()` in bootstrap.

The reducer still has no Flutter or plugin import, and the CI engine import boundary holds. `flutter analyze && dart analyze && flutter test` passes with 599 tests, and `flutter build apk --release` succeeds.
