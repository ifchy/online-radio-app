---
phase: 01-playback-engine-walking-skeleton
reviewed: 2026-09-25T20:42:41Z
depth: standard
files_reviewed: 54
files_reviewed_list:
  - .github/workflows/ci.yml
  - .github/workflows/release.yml
  - analysis_options.yaml
  - android/app/build.gradle.kts
  - android/app/src/main/AndroidManifest.xml
  - android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt
  - android/app/src/main/res/raw/keep.xml
  - android/app/src/main/res/xml/network_security_config.xml
  - lib/app/app.dart
  - lib/app/bootstrap.dart
  - lib/app/home_screen.dart
  - lib/core/network/app_http_client.dart
  - lib/core/network/media_http_client.dart
  - lib/core/network/user_agent.dart
  - lib/core/settings/settings_repository.dart
  - lib/core/text/cp1251.dart
  - lib/core/text/icy_charset.dart
  - lib/core/text/sanitize.dart
  - lib/features/catalog/application/catalog_providers.dart
  - lib/features/catalog/data/debug_stations.dart
  - lib/features/catalog/data/phase1_stations.dart
  - lib/features/catalog/data/station_directory.dart
  - lib/features/catalog/domain/station.dart
  - lib/features/playback/application/playback_providers.dart
  - lib/features/playback/domain/audio_engine.dart
  - lib/features/playback/domain/engine_diagnostics.dart
  - lib/features/playback/domain/engine_strings.dart
  - lib/features/playback/domain/media_id.dart
  - lib/features/playback/domain/now_playing.dart
  - lib/features/playback/domain/play_context.dart
  - lib/features/playback/domain/playback_status.dart
  - lib/features/playback/domain/retry_budget.dart
  - lib/features/playback/engine/audio_service_engine.dart
  - lib/features/playback/engine/audio_session_port_impl.dart
  - lib/features/playback/engine/connectivity_port_impl.dart
  - lib/features/playback/engine/icy/now_playing_parser.dart
  - lib/features/playback/engine/just_audio_stream_player.dart
  - lib/features/playback/engine/media_session_mapping.dart
  - lib/features/playback/engine/ports.dart
  - lib/features/playback/engine/radio_audio_handler.dart
  - lib/features/playback/engine/reconnect_policy.dart
  - lib/features/playback/engine/resolver/m3u_parser.dart
  - lib/features/playback/engine/resolver/playlist_text.dart
  - lib/features/playback/engine/resolver/pls_parser.dart
  - lib/features/playback/engine/resolver/stream_resolver.dart
  - lib/features/playback/engine/state_machine.dart
  - lib/features/playback/engine/wifi_lock_channel.dart
  - lib/features/playback/presentation/debug_panel.dart
  - lib/features/playback/presentation/mini_player.dart
  - lib/features/playback/presentation/state_label.dart
  - lib/l10n/app_bg.arb
  - lib/l10n/app_en.arb
  - lib/main.dart
  - pubspec.yaml
findings:
  critical: 1
  warning: 7
  info: 10
  total: 18
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-09-25T20:42:41Z
**Depth:** standard
**Files Reviewed:** 54
**Status:** issues_found

## Summary

I reviewed the whole Phase 1 walking skeleton: the pure reducer (`state_machine.dart`), the serial-queue handler, the just_audio/audio_session/connectivity adapters, the playlist resolver, the HTTP clients, the ICY text pipeline, the UI, the Android glue and the CI/release workflows.

The reducer's generation guards hold up. I traced every timer kind (connect, stall, backoff, stablePlaying, budget, flowCheck) against pause, stop, a new UserPlay and an error, and in every case a user command wins over a pending retry. The budget timer ignores the generation, but its `running && (Reconnecting|Connecting)` guard makes that safe. `playing: true` stays on through Reconnecting and Interrupted, so the foreground service stays up while recovering, as the design intends.

The serious problems sit where the pure reducer's assumptions meet the plugins. I checked each one below against the pinned plugin sources in `~/.pub-cache` (just_audio 0.10.6, audio_session 0.2.4, audio_service 0.18.19):

- **Ducking can stick at 30 % volume.** The reducer assumes that a new load is "not a new focus request". Because just_audio re-activates the session on every `play()`, audio_session replaces its focus callback each time. After any load during a duck, the duck's end arrives as `gainAfterPause`, and the reducer ignores that outside Interrupted.
- **A denied focus request is invisible to the engine.** Playing during a call spins through every stream and ends in a misleading error.
- **Interrupted has no time limit.** It holds the foreground service and audio_service's partial wake lock indefinitely.
- **The resolver never lets ExoPlayer try `unknown` URLs** that turn out to be live audio without an `audio/*` content type.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: A reload during a duck leaves the player stuck at 30 % volume; the duck's end is misreported as `gainAfterPause` and ignored

**Files:**
- `lib/features/playback/engine/state_machine.dart:839-841` (`_start` keeps `ducked`: "Focus is still held (a new station is not a new focus request)")
- `lib/features/playback/engine/state_machine.dart:1367-1381` (`gainAfterPause` is ignored unless Interrupted; only `duckEnd` restores volume)
- `lib/features/playback/engine/just_audio_stream_player.dart:19,103` (`handleAudioSessionActivation: true`; `play()` on every load)
- `lib/features/playback/engine/audio_session_port_impl.dart:59-67`

**Issue:** just_audio calls `AudioSession.setActive(true)` inside every `play()` (just_audio.dart:1098), and `load()` calls `play()` on every Load: a retry, the next candidate, the next stream, UserPlay or skip. In audio_session 0.2.4 (`core.dart:245-281`), every `setActive(true)` builds a **new** focus callback closure with a fresh local `var ducked = false`. `AndroidAudioManager.requestAudioFocus` then replaces `_onAudioFocusChanged` with that new closure (`android.dart:75`). The native side sees that a request already exists and simply returns `true` (`AndroidAudioManager.kt:346-348`), so Android is never asked again and the other app keeps its duck.

**Sequence:**
1. A navigation prompt ducks us. The engine sets `ducked: true` and `SetVolume(0.3)`.
2. The stream stalls, the network changes or the user presses "next". A Load runs `play()`, then `setActive(true)`, and the closure is replaced with `ducked = false`.
3. The prompt ends. Android sends AUDIOFOCUS_GAIN, and the new closure maps it to `(begin: false, type: pause)`, which becomes `FocusChange.gainAfterPause`.
4. `_focusChanged` ignores `gainAfterPause` in Playing, Connecting or Reconnecting (line 1367-1370). `ducked` stays true and the volume stays at 0.3 until the user pauses, stops or the station errors.

This is the car-plus-navigation scenario the app is built for. Dead zones (reconnects) and prompts overlap all the time there. The unit tests cannot catch it, because the fake AudioSessionPort never re-maps events.

**Fix:** Make the engine the single owner of session activation, and treat any gain as the end of a duck:
```dart
// just_audio_stream_player.dart
AudioPlayer(..., handleInterruptions: false, handleAudioSessionActivation: false, ...)

// ports.dart: AudioSessionPort
Future<bool> activate(); // setActive(true), called once per session start

// state_machine.dart: _focusChanged
FocusChange.gainAfterPause => state.status is Interrupted
    ? _resumeAfterInterruption(state, now)
    : state.ducked
        ? Transition(state.copyWith(ducked: false), const [SetVolume(1.0)])
        : _unchanged(state),
```
Also add a `RequestFocus` command, issued by `_start` only when focus is not already held, so audio_session's closure is not rebuilt on every reload. Add a handler test in which a Load happens between `duckBegin` and the gain.

## Warnings

### WR-01: A denied audio-focus request is invisible to the engine; the station rotates through every stream and ends in `allStreamsFailed`

**Files:** `lib/features/playback/engine/just_audio_stream_player.dart:96-103`, `lib/features/playback/engine/state_machine.dart:1025-1029`

**Issue:** When `setActive(true)` returns false, just_audio's `play()` quietly reverts `playing` to false and never activates the platform, so nothing loads (just_audio.dart:1117-1120). A request fails like this when a phone call holds focus and the engine holds no request of its own: UserPlay from Idle, Paused or Error during a call, or the media-card or Bluetooth Play. The engine receives no event at all. It sits in Connecting until the 10 s connect timer, moves to the next candidate and stream (each Load is denied again), invalidates every cached resolution and gives up after 2 rounds as `allStreamsFailed`. That takes 20–60 s of "Connecting…" and then a misleading error. When the call ends, no gain arrives, because no focus request was ever registered.

**Fix:** Once the engine activates the session itself (see CR-01), map `activate() == false` to an event such as `FocusDenied`. Handle it by moving to Interrupted, with focus requested and waiting for the gain, or to Paused with a specific error kind. Never feed it into stream rotation.

### WR-02: Interrupted has no upper bound, so the foreground service and a partial wake lock can be held indefinitely

**Files:** `lib/features/playback/engine/state_machine.dart:1384-1407`, `lib/features/playback/engine/media_session_mapping.dart:26-28`

**Issue:** Interrupted reports `playing: true`. audio_service's `enterPlayingState()` then acquires a `PARTIAL_WAKE_LOCK` (AudioService.java:710) and keeps the foreground service. The reducer deliberately runs no budget in Interrupted ("a call of any length resumes"), and only the gain, a user command, a permanent loss or becoming noisy can leave it. Some apps request transient focus and never abandon it: voice assistants, some VoIP and navigation apps, or an app stuck in a bad state. In that case the phone holds a CPU wake lock and a foreground service forever while no audio plays. That breaks the CLAUDE.md battery rule "no wake-locks when not playing".

**Fix:** Arm a long timer on entering Interrupted, for example `EngineTimings.maxInterruption = Duration(minutes: 30)`. When it fires, go to Paused with `_stopEverything`, which also releases focus. A gain before then resumes as today.

### WR-03: The resolver never lets ExoPlayer try an `unknown` URL that is live audio without an `audio/*` Content-Type

**File:** `lib/features/playback/engine/resolver/stream_resolver.dart:206-214, 258-264, 310-314`

**Issue:** For `StreamKind.unknown`, anything that is not `audio/*` has its body read as a playlist. Several common live streams fail this way, and none of the failures is treated as a format failure:
- Icecast Ogg/Opus mounts (`application/ogg`), `application/octet-stream` and servers with no Content-Type. The body read runs into the 64 KB cap (`tooLarge`) or the 5 s timeout.
- Shoutcast v1 (`ICY 200 OK`). `dart:io` rejects the status line and the resolver throws `network`. The class doc even says "Audio streams are never probed from Dart … Pitfall 7".

In every case the URL is never handed to ExoPlayer, which could play it. No release station uses `unknown` yet, but Phase 2 Radio Browser entries will.

**Fix:** For `unknown`, on `tooLarge`, `timeout`, `network` (a protocol error) or a binary body, fall back to `[ResolvedStream(url, PlayableKind.progressive)]`. Sniff only the first ~1–4 KB to decide between playlist and audio, then cancel the subscription.

### WR-04: Bootstrap has no failure handling; a non-essential first-launch write can keep the app on the splash screen for good

**File:** `lib/app/bootstrap.dart:41-46, 64-96`

**Issue:** `ensureFirstLaunchAt()` does a DataStore write, and a DataStore `CorruptionException`, a full disk or an I/O error makes it throw. `session.configure(...)` and `AudioService.init(...)` can throw too. Each is awaited before `runApp` with no try/catch, so any throw leaves the app on the launch theme at every start. The comment says APP-06 is written "before anything else can fail", but its own failure is not contained, and the core value ("tap the app → hear the station") depends on a diagnostics date.

**Fix:**
```dart
DateTime firstLaunchAt;
try {
  firstLaunchAt = await settings.ensureFirstLaunchAt();
} catch (e) {
  debugPrint('first-launch record failed: $e');
  firstLaunchAt = clock.now().toUtc();
}
```
Also wrap the rest so that a failure still calls `runApp` with an error screen.

### WR-05: Connectivity debounce can hide a network switch, so the flow check never runs and recovery waits for the buffer to drain

**File:** `lib/features/playback/engine/connectivity_port_impl.dart:61-70, 82-99`

**Issue:** The debounce keeps only the **last** raw result. It also compares only the *set of transport types*. Two cases are therefore reported as "no change":
- Wi-Fi A, then `[none]`, then Wi-Fi B (or a mobile-to-mobile handover) inside 500 ms. The last result is `[wifi]` again and the offline blip is discarded.
- Any switch between two networks of the same type with no offline gap in between.

The old socket is dead, but no `ConnectivityChanged` arrives, so no flow check is armed. Recovery then waits for ExoPlayer to drain its buffer plus the 8 s stall watchdog. That can exceed the ~10 s recovery target.

**Fix:** Latch "went offline during this debounce window" in `_listen`. When the window settles online, report `networkChanged: true` if the latch is set, even when the final set matches `_lastOnlineSet`.

### WR-06: The release workflow signs and publishes artifacts without running analyze, test or the codegen check

**File:** `.github/workflows/release.yml:92-99`

**Issue:** The workflow runs on any `v*` tag and on `workflow_dispatch` from any branch. It goes straight from `pub get` to a signed AAB/APK. Nothing ties the tagged commit to a green `ci.yml` run, so a tag on an untested or un-regenerated commit ships signed. That contradicts the working agreement ("`flutter analyze` + `flutter test` must pass").

**Fix:** Turn `ci.yml`'s `analyze-test` into a reusable workflow (`on: workflow_call`). Then add `jobs.checks: uses: ./.github/workflows/ci.yml` and `build: needs: checks`, or at least run `flutter analyze`, `dart analyze` and `flutter test` before the build steps. Consider restricting `workflow_dispatch` to `main`/tags with `if: startsWith(github.ref, 'refs/tags/') || github.ref == 'refs/heads/main'`.

### WR-07: `unawaited(_player.play())` can surface as an uncaught async error

**File:** `lib/features/playback/engine/just_audio_stream_player.dart:103`

**Issue:** `AudioPlayer.play()` awaits `playCompleter.future`, and `_sendPlayRequest` completes that future with an error when the platform `play` call throws (just_audio.dart:1147-1155, awaited at 1121). The future is unawaited and has no `catchError`, so any such error goes to the zone's uncaught handler. Bootstrap sets no `PlatformDispatcher.onError`/`FlutterError.onError`, so it is only printed. Real load failures already arrive through `errorStream`.

**Fix:**
```dart
unawaited(_player.play().catchError((Object _) {
  // Failures are reported through errorStream (PlayerFailed).
}));
```

## Info

### IN-01: An ICY title that arrives before the first `ready` is dropped with no replay

**File:** `lib/features/playback/engine/radio_audio_handler.dart:586-589`

**Issue:** `_onIcyTitle` throws away any title seen before `_readySeenForGeneration`. just_audio's `icyMetadataStream` is `distinct()` (just_audio.dart:533-534), and Icecast sends zero-length metadata blocks while the title is unchanged. If the first title of a load is ever delivered before the ready snapshot, the now-playing line stays blank until the song changes.

**Fix:** Store the latest title for the current generation, and publish it from `_onSnapshot` when `ready` is first seen.

### IN-02: `errorMessage` exposes an untranslated enum name to the system media UI

**File:** `lib/features/playback/engine/media_session_mapping.dart:43-46`

**Issue:** `PlaybackError.kind.name` (`allStreamsFailed`, `streamUnreachable`) is set as the session's error message, and some Android versions and OEM skins show it in the media controls.

**Fix:** Pass a localised string through `EngineStrings`, or leave the field null until Phase 4 adds the friendly error text.

### IN-03: The ICY sanitiser misses some invisible and bidi format characters

**File:** `lib/core/text/sanitize.dart:36-40`

**Issue:** LRM/RLM/ALM (U+200E, U+200F, U+061C), zero-width characters (U+200B–U+200D, U+FEFF) and the U+2028/U+2029 separators are not removed. They cannot override text direction, but they can hide or reorder text in a car display.

**Fix:** Add these ranges to `_isStripped`, or strip the whole Unicode `Cf` category except ZWJ inside emoji.

### IN-04: The domain layer imports the engine layer

**File:** `lib/features/playback/domain/engine_diagnostics.dart:2`

**Issue:** `domain/engine_diagnostics.dart` imports `engine/ports.dart` for `PlayableKind`, which reverses the domain→engine dependency direction the `AudioEngine` seam relies on.

**Fix:** Move `PlayableKind` into `domain/`, or store `kind` as a string in the diagnostics.

### IN-05: The exported MediaBrowserService accepts any caller

**Files:** `android/app/src/main/AndroidManifest.xml:39-47`, `lib/features/playback/engine/radio_audio_handler.dart:277-286`

**Issue:** Any installed app can bind to the service, send play/pause/`playFromMediaId`, and read the last station through `getChildren(recentRootId)`. This is normal for media apps, but it is worth recording before Android Auto work widens the browse tree.

**Fix:** In v1.1, validate callers (package allow-list or platform signature) for anything beyond the recent root.

### IN-06: Player failure codes are ignored, so decoder or format failures are reported as `allStreamsFailed`

**File:** `lib/features/playback/engine/state_machine.dart:1002-1005`

**Issue:** `_playerFailed` always calls `_nextCandidate(formatFailure: false)`. An ExoPlayer "unrecognized format" or decoder error therefore never produces `PlaybackErrorKind.unsupportedFormat`.

**Fix:** Map the known just_audio/ExoPlayer source-format error codes to `formatFailure: true`.

### IN-07: The mini-player region label says "Now playing" in Paused and Error

**Files:** `lib/l10n/app_en.arb:61`, `lib/l10n/app_bg.arb:16`, `lib/features/playback/presentation/mini_player.dart:39`

**Issue:** TalkBack announces "Now playing: X" / "Сега звучи: X" while the station is paused or has failed. The state label under it corrects this, but the region label is misleading.

**Fix:** Use a neutral label such as "Player: {station}" / "Плейър: {station}".

### IN-08: The shared, mutable `playContext` leaks into external `playFromMediaId` calls

**Files:** `lib/features/playback/engine/radio_audio_handler.dart:175, 223-229`, `lib/features/playback/engine/audio_service_engine.dart:50`

**Issue:** A car, Bluetooth or system-UI `playFromMediaId` uses whatever list the phone UI last set, which may not contain the requested station. In that case next/previous silently does nothing.

**Fix:** Pass the context as an argument (for example an internal `playStation(station, context)` method) and use `PlayContext.single()` or a context derived from the media ID for external callers.

### IN-09: A UserPlay of the station that is already playing restarts it

**File:** `lib/features/playback/engine/state_machine.dart:722-728, 811-851`

**Issue:** Tapping the currently playing station, or a car re-sending `playFromMediaId`, drops the audio and reconnects, causing an audible gap.

**Fix:** If this is not intended, treat UserPlay of the same station with the same start stream while Playing or Buffering as a no-op.

### IN-10: Release signing properties are fragile for some passwords

**Files:** `android/app/build.gradle.kts:18`, `.github/workflows/release.yml:77-84`

**Issue:** `Properties.load(InputStream)` decodes ISO-8859-1 and trims leading whitespace, so a non-ASCII password or one with a leading space fails to open the store. `keyPassword` is not checked early, only `storePassword` is. The failure appears late, as an opaque Gradle signing error.

**Fix:** Load with `InputStreamReader(it, Charsets.UTF_8)`. Also check the key password in the early step with `keytool -list -keypass:env KEY_PASS`, or `-certreq` against the alias.

---

_Reviewed: 2026-09-25T20:42:41Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
