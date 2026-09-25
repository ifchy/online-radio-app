---
phase: 01-playback-engine-walking-skeleton
plan: 01
subsystem: playback
tags: [flutter, just_audio, audio_service, audio_session, riverpod, freezed, android, foreground-service, media-session, tracer]

# Dependency graph
requires: []
provides:
  - "Runnable bg.izk.radio (eRadioto) Flutter app, Android only, Flutter 3.47.5 template defaults (minSdk 24 / target 36 / compile 36)"
  - "Domain contracts: Station/StationId/StationStream/StreamKind (ordered streams[], no singular URL), MediaId, PlayContext, PlaybackStatus (8 variants), PlaybackErrorKind, AudioEngine"
  - "Engine seam: StreamPlayer + AudioSessionPort ports, JustAudioStreamPlayer (no header proxy, engine-owned interruptions, explicit HLS/progressive sources), AudioSessionPortImpl"
  - "RadioAudioHandler (BaseAudioHandler): publish-before-load, generation guard, focus release, live-edge resume, last-station media resumption"
  - "media_session_mapping: playbackStateFor (FGS table for all eight variants) and mediaItemFor"
  - "AudioServiceEngine facade: play routes through handler.playFromMediaId (the Bluetooth/notification path)"
  - "Composition root bootstrap.dart (AudioSession music config, AudioService.init, ProviderContainer with retry disabled, asyncError logging)"
  - "Android manifest (INTERNET, FGS mediaPlayback, AudioService, MediaButtonReceiver, NSC cleartext for native media sockets) and res/raw/keep.xml for audio_service icons"
  - "One-station list (БГ Радио, http://play.global.audio/bgradio128, verified on device)"
  - "End-to-end tracer test with FakeStreamPlayer/FakeAudioSessionPort"
affects: [01-02, 01-03, 01-04, 01-05, 01-06, 01-07, 01-08, 01-09, 01-10, 01-11, 01-12, 01-13, android-auto, release-build]

# Actuals (#2632)
actuals:
  tokens: 37300
  tasks: 1
  commits: 3
plan_head_before: 5b849fb65fdeb6b222fc78be00deb0bacbe479ec

# Tech tracking
tech-stack:
  added: [just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4, flutter_riverpod 3.4.x, riverpod_annotation, riverpod_generator, riverpod_lint, freezed, freezed_annotation, json_serializable, json_annotation, build_runner, drift, drift_flutter, shared_preferences, http, connectivity_plus, package_info_plus, flutter_localizations, intl, mocktail, shared_preferences_platform_interface]
  patterns:
    - "Feature-first layout: lib/features/<feature>/{domain,data,application,engine}"
    - "Engine import boundary: only lib/features/playback/engine/ and lib/app/bootstrap.dart import just_audio/audio_service/audio_session/connectivity_plus"
    - "Publish-before-load: Connecting + MediaItem are published to the media session before StreamPlayer.load so the FGS starts from the user action"
    - "Generation counter: every player event is stamped; events from older generations are dropped"
    - "Pause = stop transport; Play = fresh load at the live edge (never seek)"
    - "One play path: UI -> AudioEngine.play -> handler.playFromMediaId, shared with Bluetooth and the notification"
    - "Riverpod ProviderContainer with retry: (_, _) => null; reconnect logic belongs to the engine"
    - "Generated *.freezed.dart / *.g.dart files are committed (D-17)"

key-files:
  created:
    - lib/app/bootstrap.dart
    - lib/app/app.dart
    - lib/app/home_screen.dart
    - lib/core/network/user_agent.dart
    - lib/core/text/icy_charset.dart
    - lib/features/catalog/domain/station.dart
    - lib/features/catalog/data/phase1_stations.dart
    - lib/features/catalog/data/station_directory.dart
    - lib/features/catalog/application/catalog_providers.dart
    - lib/features/playback/domain/audio_engine.dart
    - lib/features/playback/domain/playback_status.dart
    - lib/features/playback/domain/media_id.dart
    - lib/features/playback/domain/play_context.dart
    - lib/features/playback/engine/ports.dart
    - lib/features/playback/engine/just_audio_stream_player.dart
    - lib/features/playback/engine/audio_session_port_impl.dart
    - lib/features/playback/engine/media_session_mapping.dart
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/features/playback/engine/audio_service_engine.dart
    - lib/features/playback/application/playback_providers.dart
    - android/app/src/main/res/xml/network_security_config.xml
    - android/app/src/main/res/raw/keep.xml
    - test/support/fakes.dart
    - test/app/tracer_e2e_test.dart
  modified:
    - pubspec.yaml
    - pubspec.lock
    - analysis_options.yaml
    - android/app/src/main/AndroidManifest.xml
    - android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt
    - lib/main.dart

key-decisions:
  - "android/app/src/main/res/raw/keep.xml keeps @drawable/audio_service_* in release builds. audio_service looks its icons up by name, so resource shrinking strips them, and the Android 13+ Stop CustomAction then throws. Never remove this file."
  - "bootstrap.dart logs AudioService.asyncError, because audio_service otherwise swallows handler/setState failures silently."
  - "RadioAudioHandler keeps _lastStation after Stop. play() from Idle restarts it live, and getChildren(AudioService.recentRootId) returns it, so Android's resumable media card works. Only in memory for now; persisted last-station comes with later roadmap work."
  - "Completed while Playing/Buffering maps to PlaybackError(streamUnreachable) so no FGS runs without audio. 01-09 replaces this with reconnect."
  - "БГ Радио stream http://play.global.audio/bgradio128 is confirmed working on a physical phone in a release build (RESEARCH A1 resolved)."

patterns-established:
  - "Release-only verification: any behaviour that depends on R8/resource shrinking, the manifest or the FGS must be checked on a device in a release build; debug builds and unit tests cannot catch it"
  - "Media-resumption contract: the handler must answer AudioService.recentRootId and handle play() from Idle"

requirements-completed: [PLAY-01, PLAY-02, PLAY-03, PLAY-11, STRM-01, STRM-04, APP-07, PLAT-06]

coverage:
  - id: D1
    description: "Tap БГ Радио runs through every Dart layer (HomeScreen -> AudioServiceEngine -> RadioAudioHandler -> StreamPlayer) with publish-before-load, streams.first.url as a progressive source, stale-generation drop, pause/resume/headset click/togglePause/stop transitions, the control sets, and last-station resume after Stop"
    requirement: PLAY-11
    verification:
      - kind: integration
        ref: "test/app/tracer_e2e_test.dart#tapping БГ Радио plays it through every layer; notification, headset and facade controls pause, resume at the live edge and stop"
        status: pass
      - kind: other
        ref: "flutter analyze (No issues found!)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Manifest declares INTERNET, FOREGROUND_SERVICE_MEDIA_PLAYBACK, the mediaPlayback AudioService, MediaButtonReceiver, eRadioto label and the network security config, and does not declare the notification runtime permission; engine options and the plugin import boundary hold"
    requirement: APP-07
    verification:
      - kind: other
        ref: "plan 01-01 <verify> manifest grep chain"
        status: pass
      - kind: other
        ref: "plan 01-01 <verify> engine/import-boundary grep chain"
        status: pass
    human_judgment: false
  - id: D3
    description: "Release build on a physical phone: БГ Радио (plain http://) plays with the screen off; notification and lock-screen Pause/Play/Stop work; headset button pauses and resumes; after Stop the notification disappears and no foreground service remains"
    requirement: PLAY-01
    verification:
      - kind: manual_procedural
        ref: "Owner tracer check, Motorola edge 60 / Android 16, release build, adb dumpsys activity services bg.izk.radio"
        status: pass
    human_judgment: true
    rationale: "FGS, notification, cleartext config and shrinking only show up on a real device in a release build; the owner approved this check"
  - id: D4
    description: "Controls still work with the notification permission denied (APP-07 backstop), Play after pause is live with no replayed audio, and the resumable media card's Play restarts the last station after Stop"
    requirement: APP-07
    verification: []
    human_judgment: true
    rationale: "The owner approved the whole human check, but the relayed observations do not name these three items explicitly. The media-card fix (0e083d2) landed during the check. Verifier should reconfirm on device."

# Metrics
duration: 2h 3m
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 01: Walking skeleton (tracer) Summary

**eRadioto plays БГ Радио end to end in a release build on a physical phone: HomeScreen -> AudioEngine facade -> audio_service RadioAudioHandler -> just_audio ExoPlayer. It keeps playing with the screen off, and notification, lock-screen and headset controls work. Stop leaves no foreground service.**

## Performance

- **Duration:** 2h 3m wall clock. The original executor took about 13 min; the rest was the owner's device check and two orchestrator fixes.
- **Started:** 2026-09-25T12:39:03Z
- **Completed:** 2026-09-25T14:42:07Z
- **Tasks:** 1 of 1 (a tracer with a blocking-human gate, approved)
- **Files modified:** 53 (52 in the task commit and 1 new in the fixes; bootstrap.dart, radio_audio_handler.dart and the tracer test were edited again)

## Accomplishments

- Scaffolded the `bg.izk.radio` / "eRadioto" Flutter app on Flutter 3.47.5 with the full Phase 1 dependency set. `pubspec.lock` and all freezed/riverpod generated files are committed.
- Wrote the domain contracts: `Station` with an ordered `streams[]` and no singular URL, `StationId` namespaces, `MediaId`, `PlayContext`, the 8-variant `PlaybackStatus` and the `AudioEngine` interface.
- Built the engine seam. `JustAudioStreamPlayer` runs with `useProxyForRequestHeaders: false`, `handleInterruptions: false`, explicit HLS/progressive sources and an unawaited `play()`. `RadioAudioHandler` publishes before it loads, guards events by generation, releases focus, and resumes at the live edge.
- Added the FGS mapping table (`playbackStateFor`) for all eight statuses. Controls are [pause, stop] while playing, [play, stop] when paused or on error, none when idle, and there are no seek or system actions.
- Owner-verified on a Motorola edge 60 (Android 16) in a release build:
  - playback continues with the screen off;
  - notification and lock-screen Pause/Play/Stop work;
  - the headset button toggles playback;
  - after Stop the notification disappears and dumpsys shows no foreground service.

## Task Commits

1. **Task 1 (tracer): Tap БГ Радио and hear it in a release build.** `e38db8f` (feat), the original executor's commit of 52 files.
2. **Owner-check fix: keep audio_service notification icons in release builds.** `675acdc` (fix)
3. **Owner-check fix: make Android's media card resume the last station after Stop.** `0e083d2` (fix)

**Plan metadata:** see the `docs(01-01): complete walking skeleton plan` commit.

## Files Created/Modified

- `lib/app/bootstrap.dart` is the composition root. It sets up the audio session, calls AudioService.init (channel `bg.izk.radio.playback`, `androidStopForegroundOnPause: true`), builds the ProviderContainer with retry disabled, and logs asyncError.
- `lib/features/playback/engine/radio_audio_handler.dart` is the BaseAudioHandler state machine. It covers play/pause/stop, the generation guard, publish-before-load, and resumption of the last station.
- `lib/features/playback/engine/just_audio_stream_player.dart` wraps just_audio's ExoPlayer as a `StreamPlayer`.
- `lib/features/playback/engine/media_session_mapping.dart` maps each status to the PlaybackState/MediaItem shown in the notification and on the lock screen.
- `lib/features/playback/engine/audio_service_engine.dart` is the `AudioEngine` facade over the handler.
- `lib/features/playback/domain/*` holds the AudioEngine, PlaybackStatus, MediaId and PlayContext contracts.
- `lib/features/catalog/**` holds Station/StationId/StationStream, the one-station `phase1Stations`, `StationDirectory` and its provider.
- `lib/app/home_screen.dart`, `lib/app/app.dart` and `lib/main.dart` form the app shell with the station list.
- `android/app/src/main/AndroidManifest.xml` declares the permissions, AudioService, MediaButtonReceiver, the NSC, and the eRadioto label.
- `android/app/src/main/res/xml/network_security_config.xml` allows cleartext for native media sockets.
- `android/app/src/main/res/raw/keep.xml` keeps `@drawable/audio_service_*` through release resource shrinking.
- `android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt` extends `AudioServiceActivity`.
- `test/support/fakes.dart` and `test/app/tracer_e2e_test.dart` hold the fakes and the end-to-end tracer test (8 steps).

## Decisions Made

- **keep.xml is mandatory.** audio_service resolves its notification drawables by name, which the release resource shrinker cannot see.
- **asyncError is logged.** audio_service swallows handler errors, and without logging the first phone failure produced no diagnostics.
- **Media resumption uses an in-memory last station.** Android's system UI queries `EXTRA_RECENT` and may keep a resumable media card after Stop, so the handler has to answer it. Persisting the last station, so resumption works after process death, is later roadmap work.
- **The БГ Радио URL is confirmed.** `http://play.global.audio/bgradio128` plays over cleartext in a release build.

## Deviations from Plan

### Auto-fixed Issues (original executor, commit e38db8f)

**1. [Rule 2 - Missing Critical] Completed while Playing/Buffering becomes PlaybackError**
- **Found during:** Task 1
- **Issue:** A live stream that ends ("completed") would leave the handler reporting playing with no audio, which keeps the FGS and wake lock alive for nothing.
- **Fix:** A completed snapshot in Playing or Buffering becomes `PlaybackError(streamUnreachable)`. That stops the player, releases focus, and drops the FGS. Plan 01-09 replaces this with reconnect.
- **Files modified:** lib/features/playback/engine/radio_audio_handler.dart
- **Committed in:** e38db8f

**2. [Rule 2 - Missing Critical] A failed player.load becomes PlaybackError(streamUnreachable)**
- **Found during:** Task 1
- **Issue:** The plan only handled failures that arrive on the failures stream. An exception thrown by `load()` itself would have left the handler stuck in Connecting, with the FGS still up.
- **Fix:** The load is wrapped. If it throws and its generation is still current, the handler fails into PlaybackError(streamUnreachable).
- **Files modified:** lib/features/playback/engine/radio_audio_handler.dart
- **Committed in:** e38db8f

**3. [Rule 2 - Missing Critical] Pause and stop invalidate the old generation**
- **Found during:** Task 1
- **Issue:** Late events from a load that had already been paused or stopped could flip the state back to Playing.
- **Fix:** `pause()` and `stop()` increment the generation, so the old load's events are dropped.
- **Files modified:** lib/features/playback/engine/radio_audio_handler.dart
- **Committed in:** e38db8f

**4. [Rule 1 - Bug] freezed classic-class syntax and the Riverpod retry signature**
- **Found during:** Task 1
- **Issue:** `@override` on freezed classic-class fields, and `retry: (_, __) => null`, both raised analyzer issues under Dart 3.13.
- **Fix:** Removed `@override` from the fields and used the wildcard `retry: (_, _) => null`.
- **Files modified:** lib/features/catalog/domain/station.dart, lib/features/playback/domain/playback_status.dart, lib/app/bootstrap.dart
- **Committed in:** e38db8f

**5. [Note] How the tracer test checks publish-before-load, and build_runner -d**
- The test proves publish-before-load by recording the published playback state at each `load()` call, not by a global timestamp.
- build_runner 2.16.1 ignores `-d` and prints a warning. The command in the plan still works.

### Issues found in owner verification (fixed by the orchestrator)

**6. [Rule 1 - Bug] Release resource shrinking stripped audio_service's notification icons**
- **Found during:** Owner tracer check, first phone test
- **Issue:** Audio stopped 1–2 s after the screen locked and no notification appeared. Release resource shrinking removed `drawable/audio_service_stop`, because audio_service looks it up by name. On Android 13+ audio_service builds Stop as a `PlaybackStateCompat.CustomAction`, which throws on icon id 0. So `setState` failed on every play and pause, the FGS never started, and `dumpsys` showed `startForegroundCount=0`. audio_service swallowed the error.
- **Fix:** Added `android/app/src/main/res/raw/keep.xml` with `tools:keep="@drawable/audio_service_*"`. `bootstrap.dart` now logs `AudioService.asyncError`.
- **Files modified:** android/app/src/main/res/raw/keep.xml (new), lib/app/bootstrap.dart
- **Verification:** The owner's repeated release-build test passed: screen-off playback, notification, and no FGS after Stop.
- **Committed in:** 675acdc

**7. [Rule 1 - Bug] The system media card's Play did nothing after Stop**
- **Found during:** Owner tracer check
- **Issue:** audio_service always answers the system UI's `EXTRA_RECENT` browse root, so Android can keep a resumable media card after Stop. The handler had dropped the station on Stop, and the plan's "play() in Idle does nothing" rule made the card's Play a no-op.
- **Fix:** The handler keeps `_lastStation`. `play()` from Idle restarts it at the live edge, and `getChildren(AudioService.recentRootId)` returns it. The tracer test gained step 8. This changes the plan's Idle rule on purpose: a Play from the media card is a user action, so it does not break the "no audio the user did not ask for" prohibition.
- **Files modified:** lib/features/playback/engine/radio_audio_handler.dart, test/app/tracer_e2e_test.dart
- **Verification:** Tracer test step 8 passes, and `flutter analyze` and `flutter test` are clean (re-run at close-out).
- **Committed in:** 0e083d2
- **Known limit:** The last station lives only in memory, so resumption after process death needs a persisted last station.

---

**Total deviations:** 6 auto-fixed (3 Rule 2 missing-critical and 1 Rule 1 bug by the executor; 2 Rule 1 bugs found in owner verification), plus 1 note.
**Impact on plan:** All the fixes were needed for correctness or battery. Without keep.xml, background playback does not work at all in release builds. There is no scope creep.

## Lesson for Later Plans

- **Every release-only behaviour must be verified on a device.** Resource shrinking, R8, manifest merging, FGS start and cleartext policy are invisible to `flutter test` and to debug builds. The first failure here passed every automated check. Any later plan that touches notification icons (01-07 sets the monochrome drawable), manifest entries, Gradle and signing (01-02), or the FGS lifecycle (01-09, 01-13) must include a release-build device check.
- **`android/app/src/main/res/raw/keep.xml` must stay.** If 01-07 adds its own notification drawable, which is also resolved by name, it must be covered by keep.xml too.
- **Watch the `AudioService.asyncError` log first** whenever the notification or FGS misbehaves.

## Issues Encountered

- The first release-build phone test failed: audio stopped 1–2 s after lock and there was no notification. See deviation 6 for the root cause and fix.
- The owner tested on a Motorola edge 60 (Android 16), not the Xiaomi or Samsung that D-16 named. Xiaomi and Samsung, and Android 15/17, remain part of the Phase 1 device matrix (STATE blockers).

## Known Stubs

None. `phase1Stations` holding one station is intended (D-01); plan 01-05 replaces it with the six owner-verified stations.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: information-disclosure | lib/features/playback/engine/radio_audio_handler.dart | The exported MediaBrowserService now answers `recentRootId` with the last-played station (name and media ID) to any connecting browse client. It is low sensitivity and in line with T-01-02 (the exports are required). It is recorded so `/gsd-secure-phase` can accept it explicitly. |

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- The walking skeleton is proven on a real device, and the later Phase 1 plans (01-02 onward) can build on this architecture.
- Outstanding from the human check, to reconfirm in verify-work: controls with the notification permission denied (APP-07 backstop), no replayed audio after resume, and the media-card resume on the device.
- Outstanding (STATE blocker): record the unlisted FGS demo video now that background playback works.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED
