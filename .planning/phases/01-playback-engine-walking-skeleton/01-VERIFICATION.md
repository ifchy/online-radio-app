---
phase: 01-playback-engine-walking-skeleton
verified: 2026-09-25T22:31:51Z
status: gaps_found
score: 24/30 must-haves verified
covered_files: [".github/workflows/ci.yml",".github/workflows/release.yml",".gitignore",".planning/REQUIREMENTS.md",".planning/ROADMAP.md",".planning/phases/01-playback-engine-walking-skeleton/01-01-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-01-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-02-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-02-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-03-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-03-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-04-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-04-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-05-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-05-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-06-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-06-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-07-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-07-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-08-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-08-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-09-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-09-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-10-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-10-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-11-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-11-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-12-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-12-SUMMARY.md",".planning/phases/01-playback-engine-walking-skeleton/01-13-PLAN.md",".planning/phases/01-playback-engine-walking-skeleton/01-13-SUMMARY.md","analysis_options.yaml","android/app/build.gradle.kts","android/app/src/main/AndroidManifest.xml","android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt","android/app/src/main/res/drawable/ic_stat_radio.xml","android/app/src/main/res/drawable/launch_background.xml","android/app/src/main/res/raw/keep.xml","android/app/src/main/res/xml/network_security_config.xml","docs/RELEASE-SIGNING.md","lib/app/app.dart","lib/app/bootstrap.dart","lib/app/home_screen.dart","lib/core/network/app_http_client.dart","lib/core/network/media_http_client.dart","lib/core/network/user_agent.dart","lib/core/settings/settings_repository.dart","lib/core/text/cp1251.dart","lib/core/text/icy_charset.dart","lib/core/text/sanitize.dart","lib/features/catalog/application/catalog_providers.dart","lib/features/catalog/data/debug_stations.dart","lib/features/catalog/data/phase1_stations.dart","lib/features/catalog/data/station_directory.dart","lib/features/catalog/domain/station.dart","lib/features/playback/application/playback_providers.dart","lib/features/playback/domain/audio_engine.dart","lib/features/playback/domain/engine_diagnostics.dart","lib/features/playback/domain/engine_strings.dart","lib/features/playback/domain/media_id.dart","lib/features/playback/domain/now_playing.dart","lib/features/playback/domain/play_context.dart","lib/features/playback/domain/playback_status.dart","lib/features/playback/domain/retry_budget.dart","lib/features/playback/engine/audio_service_engine.dart","lib/features/playback/engine/audio_session_port_impl.dart","lib/features/playback/engine/connectivity_port_impl.dart","lib/features/playback/engine/icy/now_playing_parser.dart","lib/features/playback/engine/just_audio_stream_player.dart","lib/features/playback/engine/media_session_mapping.dart","lib/features/playback/engine/ports.dart","lib/features/playback/engine/radio_audio_handler.dart","lib/features/playback/engine/reconnect_policy.dart","lib/features/playback/engine/resolver/m3u_parser.dart","lib/features/playback/engine/resolver/playlist_text.dart","lib/features/playback/engine/resolver/pls_parser.dart","lib/features/playback/engine/resolver/stream_resolver.dart","lib/features/playback/engine/state_machine.dart","lib/features/playback/engine/wifi_lock_channel.dart","lib/features/playback/presentation/debug_panel.dart","lib/features/playback/presentation/mini_player.dart","lib/features/playback/presentation/state_label.dart","lib/l10n/app_bg.arb","lib/l10n/app_en.arb","lib/l10n/app_localizations.dart","lib/l10n/app_localizations_bg.dart","lib/l10n/app_localizations_en.dart","lib/main.dart","pubspec.lock","pubspec.yaml","test/app/tracer_e2e_test.dart","test/core/network/http_clients_test.dart","test/core/settings/settings_repository_test.dart","test/core/text/cp1251_test.dart","test/core/text/sanitize_test.dart","test/features/catalog/phase1_stations_test.dart","test/features/catalog/station_test.dart","test/features/playback/domain/media_id_test.dart","test/features/playback/engine/audio_session_port_impl_test.dart","test/features/playback/engine/connectivity_port_impl_test.dart","test/features/playback/engine/icy/now_playing_parser_test.dart","test/features/playback/engine/media_session_mapping_test.dart","test/features/playback/engine/radio_audio_handler_test.dart","test/features/playback/engine/reconnect_policy_test.dart","test/features/playback/engine/resolver/playlist_parsers_test.dart","test/features/playback/engine/resolver/stream_resolver_test.dart","test/features/playback/engine/state_machine_test.dart","test/features/playback/engine/wifi_lock_channel_test.dart","test/features/playback/presentation/debug_panel_test.dart","test/features/playback/presentation/mini_player_test.dart","test/support/fakes.dart"]
covered_digest: "v1:sha256:8649d73153de55e6ef8e741460570d6f9ca5406cb208194e3a70a97e808afb11"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "A navigation prompt lowers (ducks) the radio volume and restores it afterwards without stopping playback (01-13 must-have; ROADMAP SC4 'Navigation prompts duck the audio'; PLAY-05)"
    status: partial
    reason: "Code review finding CR-01 is confirmed against the pinned plugin sources. just_audio calls AudioSession.setActive(true) on every play(), and JustAudioStreamPlayer.load() calls play() on every Load. audio_session 0.2.4 (core.dart:241-281) builds a new focus closure with a fresh `ducked = false` on every activation, and android.dart:75 replaces the callback. If a Load happens during a duck (a stall reload, a network-change reload, a fallback or next/previous), the duck's AUDIOFOCUS_GAIN arrives as (end, pause), which maps to FocusChange.gainAfterPause. state_machine.dart:1367-1370 ignores that outside Interrupted, so `ducked` stays true and the volume stays at 0.3 until the user pauses, stops or the station errors. Scope: AudioSessionConfiguration.music() leaves androidWillPauseWhenDucked unset, so on API 26+ Android ducks automatically and never calls the app. The defect therefore bites on Android 7.0/7.1 (API 24/25), which PLAT-01 explicitly supports, and in any configuration where Android hands ducking to the app. No test covers a Load between duckBegin and the gain, because FakeAudioSessionPort emits engine-level FocusChange values and never models audio_session's per-activation closure."
    artifacts:
      - path: "lib/features/playback/engine/state_machine.dart"
        issue: "_focusChanged treats gainAfterPause as a no-op unless Interrupted, even while `ducked` is true (lines 1367-1370). _start keeps `ducked` on a new Load (line 841)."
      - path: "lib/features/playback/engine/just_audio_stream_player.dart"
        issue: "handleAudioSessionActivation: true plus play() on every load() re-requests focus and resets audio_session's duck tracking."
      - path: "test/features/playback/engine/radio_audio_handler_test.dart"
        issue: "No test for duckBegin -> reload (Load) -> gain arriving as gainAfterPause."
    missing:
      - "In _focusChanged, when `ducked` is true, treat gainAfterPause outside Interrupted as the end of the duck: ducked=false plus SetVolume(1.0)."
      - "Better: make the engine the single owner of session activation (handleAudioSessionActivation: false, an explicit activate on session start), so audio_session's closure isn't rebuilt on every reload (see REVIEW CR-01 fix)."
      - "Add a reducer test and a handler test in which a Load runs between duckBegin and the gain, and the gain arrives as gainAfterPause."
  - truth: "In a release build the ~5 hard-coded stations together cover MP3, AAC+, HLS (including HLS behind a non-.m3u8 URL), a .pls/.m3u playlist URL and a plain http:// stream, and now-playing is correct Cyrillic on a windows-1251 station (ROADMAP SC1; D-03)"
    status: partial
    reason: "The release lineup (lib/features/catalog/data/phase1_stations.dart) covers MP3, AAC, .m3u8 HLS and plain http:// only. No release station uses a .pls/.m3u wrapper (N-JOY's .m3u was rejected), no release station serves HLS behind a non-.m3u8 URL (the only sniff case is the debug-only 'ТЕСТ: Хоризонт (HLS sniff)', whose URL still ends in .m3u8), and no stream is known to send windows-1251 (every stream is icyCharset auto, and the owner ran no byte probe). The capability exists and is unit-tested: stream_resolver_test 27/27, playlist_parsers_test 9/9, cp1251_test 19/19, now_playing_parser_test 28/28, and auto-detection repairs cp1251 without a hint. The owner recorded this reduction at the D-02 checkpoint (option-a/option-c, 2026-09-25), but ROADMAP SC1 was never amended, so the release-build clause of the roadmap contract is unmet. No later phase explicitly takes it over."
    artifacts:
      - path: "lib/features/catalog/data/phase1_stations.dart"
        issue: "No .pls/.m3u stream, no non-.m3u8 HLS stream, and no stream known to be windows-1251 in the release list."
      - path: ".planning/ROADMAP.md"
        issue: "SC1 still requires .pls/.m3u, non-.m3u8 HLS and a windows-1251 station in the release lineup."
    missing:
      - "Either accept the owner's D-02 decision with an override (suggested YAML in the report body) and amend ROADMAP SC1,"
      - "or add owner-verified official streams that exercise a .pls/.m3u wrapper (the candidate http://play.global.audio/bgradio128.m3u is noted as unverified in 01-05-SUMMARY) and, if one exists, a windows-1251 ICY sender, then confirm them on device."
advisory: []
behavior_unverified_items: []
coincidental_reliance_items:
  - truth: "A phone call pauses the radio and it resumes by itself at the live edge after hang-up (SC4, D-11)"
    reason: fixture-only
    harden: "Handler tests drive FakeAudioSessionPort with engine-level FocusChange values. The production path depends on audio_session's per-activation closure mapping LOSS_TRANSIENT then GAIN to (begin,pause) then (end,pause), and on nothing re-activating the session in between. That holds today because Interrupted issues no Load, but it isn't declared or tested. Add a port-level test that feeds AudioInterruptionEvent sequences, including re-activation, through focusChangeFor and the handler."
---

# Phase 1: Playback Engine & Walking Skeleton Verification Report

**Phase Goal:** A user on a physical Android phone can start a Bulgarian station and it keeps playing on its own through screen-off, background, calls, headphone changes, network switches and dead primary streams. The live edge, correct Cyrillic now-playing and media controls all work.
**Verified:** 2026-09-25T22:31:51Z
**Status:** gaps_found
**Re-verification:** No. This is the initial verification.

> **MVP-mode discrepancy (warning).** ROADMAP marks this phase `**Mode:** mvp`, but the goal is not a user story: `user-story.validate` returns `valid: false`. The orchestrator asked for verification anyway, so this report verifies against the ROADMAP success criteria (the contract). The User Flow Coverage table below is derived from the goal as written. To make MVP mode consistent, run `/gsd mvp-phase 1` to reformat the goal, or drop `mode: mvp`.

## User Flow Coverage

User story (derived from the goal): a listener in Bulgaria opens eRadioto, taps a station, and it keeps playing on its own with correct now-playing and working controls.

| Step | Expected | Evidence in codebase | Status |
|------|----------|----------------------|--------|
| Open app | Station list, BG/EN, mini-player slot | `lib/app/home_screen.dart` (ListView of `StationDirectory.phase1().all`, `bottomNavigationBar: MiniPlayer()`); mini_player_test 51/51 | ✓ |
| Tap a station | Engine plays via the same path Bluetooth uses | `home_screen.dart` onTap → `audioEngineProvider.play` → `AudioServiceEngine.play` → `handler.playFromMediaId` → `UserPlay` → Resolve → Load; tracer_e2e_test passes | ✓ |
| Hear audio in a release build | FGS + INTERNET + cleartext for native sockets | APK built on this checkout: badging shows INTERNET and FOREGROUND_SERVICE_MEDIA_PLAYBACK, merged manifest has `foregroundServiceType="mediaPlayback"`, NSC `cleartextTrafficPermitted="true"` | ? human (device) |
| Screen off / background | `playing: true` in every active state keeps the FGS | `media_session_mapping.dart` FGS table; mapping test 32/32 | ✓ code / ? 60-min device run |
| Survive drops, network switches, dead primary | Reconnect with backoff and budget, fallback rotation | `state_machine.dart` `_reconnect`/`_retry`/`_reloadNow`/`_nextStream`; reducer groups pass | ✓ code / ? ≤10 s on device |
| Calls, unplug, nav prompts | Interrupted→resume, noisy→pause, duck→restore | Call and noisy paths ✓; duck restore FAILS on API 24/25 after a mid-duck reload (CR-01) | ✗ partial |
| Now-playing Cyrillic | cp1251 repair, clears on switch | `now_playing_parser.dart`, handler "never stale" group; tests pass | ✓ code / ? real stations |
| Outcome | "Keeps playing on its own…, media controls all work" | Engine logic is complete and wired. Two gaps (duck restore on API 24/25, SC1 release format coverage) plus owner device checks remain | ✗ gaps |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: in a release build on a phone, each of the ~5 stations plays | ? UNCERTAIN (human) | 5 stations in `phase1_stations.dart`, wired end to end. Owner approved the 01-01 tracer for БГ Радио; the remaining stations need a device check (01-05 human-check) |
| 2 | SC1: the release lineup covers MP3, AAC+, HLS incl. non-.m3u8, .pls/.m3u, plain http://, and a windows-1251 station | ✗ FAILED (partial) | Release has MP3/AAC/.m3u8 HLS/http only. No .pls/.m3u, no non-.m3u8 HLS, no cp1251 station (owner D-02 option-a/c). Override suggested below |
| 3 | SC1/STRM-05: Cyrillic now-playing is correct and clears on station switch | ✓ VERIFIED | `parseIcyTitle` → `repairCp1251` (auto heuristic) → sanitise → split. Handler clears on every new generation and gates on first ready. now_playing_parser_test 28/28, cp1251_test 19/19, handler "now playing" group 14/14 |
| 4 | SC2/PLAT-03: 60 min screen-off on Xiaomi and Samsung | ? UNCERTAIN (human) | Wi-Fi lock channel plus the FGS table are present; device-only |
| 5 | SC2/PLAY-02/03: controls from notification, lock screen, wired, BT and car BT | ? UNCERTAIN (human) | MediaButtonReceiver exported; `BaseAudioHandler.click` → pause/play/skip wired into the handler; controls `[pause\|play, stop]` with compact `[0,1]` |
| 6 | APP-07 (backstop): controls work with notification permission denied / channel blocked | ? UNCERTAIN (insufficient_spec, human) | Static: no POST_NOTIFICATIONS in the main manifest, the merged release manifest or APK badging; the CI guard exists. The behavior is non-inferable |
| 7 | SC2/PLAT-06: after Stop the notification goes and no FGS, wake lock, Wi-Fi lock or focus remains | ✓ VERIFIED (engine) | `_stop` → CancelAllTimers, StopTransport, ReleaseFocus; Idle → processingState idle, no controls; Wi-Fi lock released. Handler "Wi-Fi lock, focus and FGS per state" 18/18. dumpsys confirmation is a human item |
| 8 | SC3/PLAY-07: after a Wi-Fi→4G switch, airplane mode or a drop, audio returns at the live edge without user action | ✓ VERIFIED (logic) | Connectivity → `_reloadNow`/flow check/offline wait; stall watchdog 8 s; reducer connectivity group 38/38, handler network group 12/12. Wall-clock ≤10 s is a human item |
| 9 | SC3/PLAY-08: a dead primary falls back to the next stream | ✓ VERIFIED | `_nextCandidate`/`_nextStream`; reducer rotation 13/13, handler fallback rotation 10/10 |
| 10 | SC3: retries stop after a bounded budget | ✓ VERIFIED | Two dead-on-arrival rounds; standard 3 min online / 10 min offline budget; `_giveUp` releases everything. Reducer reconnect group 13/13 |
| 11 | SC4/PLAY-05: a call pauses, and playback resumes after hang-up | ✓ VERIFIED (coincidental-reliance) | transientLoss → Interrupted (transport stopped, focus kept, `playing: true`); gainAfterPause → fresh `_start`. just_audio 0.10.6 `stop()` never abandons focus (verified in the plugin source). Reducer focus group 54/54, handler calls group 13/13 |
| 12 | SC4/PLAY-05: navigation prompts duck, then restore | ✗ FAILED (partial) | CR-01 confirmed: volume stuck at 0.3 on API 24/25 when a Load overlaps a duck |
| 13 | SC4/PLAY-06: unplug or BT disconnect pauses and stays paused | ✓ VERIFIED | `BecomingNoisy` → `_pause` (focus released); "becoming noisy pauses" tests pass |
| 14 | SC4/PLAY-11: resume after a 5-min pause is live, not stale | ✓ VERIFIED | Pause = StopTransport (`_player.stop()` disposes the native player); resume = `_start` → new Load; no seek command exists (test "no command ever seeks"); `systemActions: {}` |
| 15 | SC4/PLAY-10: nothing restarts playback the user paused or stopped | ✓ VERIFIED | "only UserPlay and UserResume leave {Paused,Idle,Error}"; "after a user pause or stop… no commands"; user-commands group 17/17 |
| 16 | SC5/PLAT-01: minSdk 24, target 36 | ✓ VERIFIED | `build.gradle.kts` explicit; aapt2 badging of this checkout's release APK: minSdk 24, targetSdk 36. Install on API 24 is an open owner check |
| 17 | SC5/PLAT-04: every PR runs analyze and test; stale codegen fails CI | ✓ VERIFIED | `ci.yml` on `pull_request`/push main: build_runner then `git diff --exit-code`, flutter analyze, dart analyze, flutter test; no secrets, no `pull_request_target` |
| 18 | SC5/PLAT-04: v* tags produce a signed AAB and APK, and fail closed without secrets | ✓ VERIFIED (workflow) | `release.yml`: secret presence gate, keytool check, not-debug-signed and same-cert checks, `if: always()` cleanup. The rc.3 run result can't be checked here (no `gh`); the owner sideload covers it |
| 19 | SC5: no key or secret in the public repo | ✓ VERIFIED | `.gitignore` covers *.jks/*.keystore/key.properties/*.b64; `git log --all --diff-filter=A` shows no keystore/properties/b64/p12/pem ever added; no private-key or AWS-key patterns |
| 20 | SC5/APP-06: first-launch date stored once on the first run | ✓ VERIFIED | `SettingsRepository.ensureFirstLaunchAt` is write-once and awaited before `AudioService.init`; settings_repository_test 6/6 (WR-04 robustness caveat) |
| 21 | SC5/PLAT-06: no tracking SDK | ✓ VERIFIED | pubspec.lock deny-list grep clean; CI deny-list step |
| 22 | 01-03: BG/EN UI, accessible mini-player with state labels, no seek | ✓ VERIFIED | mini_player_test 51/51 (labels bg/en, a11y guidelines, 2x text). TalkBack on device is a human item |
| 23 | 01-07: notification state text, mono icon, localised channel, fixed control order | ✓ VERIFIED | `mediaItemFor`/`playbackStateFor`; mapping test 32/32; `ic_stat_radio.xml`, `keep.xml` |
| 24 | 01-04: resolver limits and scheme allow-list; AppHttpClient HTTPS-only | ✓ VERIFIED | stream_resolver_test 27/27, http_clients_test 19/19 |
| 25 | 01-05/01-11: no debug stations or debug panel in release | ✓ VERIFIED | Release `libapp.so` strings: `bg.izk.radio.playback`=1 (positive control), `dead-primary.invalid`=0, `192.0.2.1`=0; `kReleaseMode` gating; debug_panel_test 12/12 |
| 26 | 01-09/PLAY-03: headset/car next and previous step through the start list | ✓ VERIFIED (logic) | `_skip` → `PlayContext.neighbour`; handler next/previous group passes. Device is a human item |
| 27 | 01-10/D-10: one engine-level RetryBudget preset setting | ✓ VERIFIED | `RetryBudgetPreset` standard/trip/batterySaver; `AudioEngine.setRetryBudget` → SetRetryBudget event; tests pass |
| 28 | 01-13/PLAT-03/06: Wi-Fi lock held only in Connecting, Playing, Buffering and Reconnecting | ✓ VERIFIED | `wantsWifiLock` + `_syncWifiLock`; MainActivity `WifiLockChannel` (HIGH_PERF, non-refcounted); per-state tests pass |
| 29 | 01-13: another media app pauses for good; a swipe while paused ends the service | ✓ VERIFIED | permanentLoss → `_pause`; `onTaskRemoved` group passes |
| 30 | 01-12: offline wait, one fresh connection per outage, connectivity after pause starts nothing | ✓ VERIFIED | Idempotency group and "after a user pause or stop… connectivity starts nothing" pass |

**Score:** 24/30 truths verified (0 present-but-behavior-unverified). 2 FAILED (partial) and 4 UNCERTAIN route to the owner's device check.

### Required Artifacts

`gsd-tools verify.artifacts` returned 53/53 passing across all 13 plans. I also read the core files: `state_machine.dart` (1458 lines, full reducer), `radio_audio_handler.dart` (686 lines, serial queue), resolver, mapping, adapters and workflows. No stubs, no placeholder returns, no hollow providers. The providers mirror real engine streams, and `audioEngineProvider` is overridden in bootstrap.

| Artifact | Status | Details |
|----------|--------|---------|
| `lib/features/playback/engine/state_machine.dart` | ✓ VERIFIED | Pure reducer; every row traced |
| `lib/features/playback/engine/radio_audio_handler.dart` | ✓ VERIFIED | Wired from bootstrap via `AudioService.init` |
| `lib/features/playback/engine/just_audio_stream_player.dart` | ⚠️ VERIFIED with defect | `handleAudioSessionActivation: true` is the CR-01 root |
| `lib/features/playback/engine/audio_session_port_impl.dart` | ✓ VERIFIED | Mapping table matches audio_session 0.2.4 |
| `lib/features/catalog/data/phase1_stations.dart` | ⚠️ VERIFIED, reduced | 5 stations, 12 streams; reduced format matrix (gap 2) |
| `.github/workflows/ci.yml`, `release.yml` | ✓ VERIFIED | See truths 17-18 |
| `android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt` | ✓ VERIFIED | WifiLockChannel registered |

### Key Link Verification

`gsd-tools verify.key-links` returned 31/31 verified. Manual spot checks:

| From | To | Via | Status |
|------|----|-----|--------|
| home_screen.dart | AudioEngine | `ref.read(audioEngineProvider).play(station, context: PlayContext.list(...))` | WIRED |
| AudioServiceEngine.play | RadioAudioHandler | `playFromMediaId` + `startStreamIndex` extra | WIRED |
| RadioAudioHandler | PlaybackStateMachine | `_machine.transition` on a serial queue | WIRED |
| RadioAudioHandler | media session | `_publishStatus` before commands (publish-before-load) | WIRED |
| bootstrap | ConnectivityPortImpl, WifiLockChannel, HttpStreamResolver(MediaHttpClient) | constructor injection | WIRED |
| Dart WifiLockChannel | Kotlin WifiLockChannel | MethodChannel `bg.izk.radio/wifi_lock` | WIRED (no-op if the service cold-starts without the activity) |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real data | Status |
|----------|------|--------|-----------|--------|
| MiniPlayer | status/station/nowPlaying | `playbackStatusProvider` etc. → `AudioServiceEngine._replayLatest(handler streams)` | Yes | ✓ FLOWING |
| Notification | MediaItem/PlaybackState | `_publishStatus`/`_setNowPlaying` from reducer state and ICY | Yes | ✓ FLOWING |
| DebugPanel | diagnostics, firstLaunchAt | handler `_emitDiagnostics`; bootstrap override | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

The orchestrator already ran the full suite once (599 passed). I ran only named groups and files:

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Focus, calls, noisy, duck (reducer) | `flutter test state_machine_test.dart --plain-name "audio focus and becoming noisy"` | +54 passed | ✓ PASS |
| Reconnect / live edge | `--plain-name "reconnect after a drop or a stall"` | +13 | ✓ PASS |
| User commands win | `--plain-name "user commands"` | +17 | ✓ PASS |
| Fallback rotation (reducer) | `--plain-name "Connecting rotates through candidates and streams"` | +13 | ✓ PASS |
| Connectivity/offline | `--plain-name "connectivity, the flow check and the offline budget"` | +38 | ✓ PASS |
| Wi-Fi lock/focus/FGS per state (handler) | `radio_audio_handler_test --plain-name "Wi-Fi lock, focus and the foreground service per state"` | +18 | ✓ PASS |
| Calls/ducks/unplug (handler) | `--plain-name "calls, navigation prompts, unplugging and other media apps"` | +13 | ✓ PASS |
| Now playing (handler) | `--plain-name "now playing (ICY, STRM-05 / PLAY-02)"` | +14 | ✓ PASS |
| Network changes (handler) | `--plain-name "network changes and offline periods"` | +12 | ✓ PASS |
| Fallback rotation (handler) | `--plain-name "fallback rotation"` | +10 | ✓ PASS |
| Tracer e2e / FGS mapping | `tracer_e2e_test.dart`, `media_session_mapping_test.dart` | +1, +32 | ✓ PASS |
| Resolver, parsers, cp1251, ICY, HTTP clients, settings, UI, catalogue, connectivity, Wi-Fi lock | per-file runs | 27, 9, 19, 28, 19, 6, 51, 12, 19, 15, 5 | ✓ PASS |
| Release APK SDK levels / permissions | `aapt2 dump badging app-release.apk` | min 24, target 36; no POST_NOTIFICATIONS | ✓ PASS |
| No debug stations in release | `strings libapp.so` with positive control | control 1, `dead-primary.invalid` 0, `192.0.2.1` 0 | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist, and no plan declares a probe. Step 7c: N/A.

### Requirements Coverage

All 20 phase requirement IDs are claimed by at least one plan's `requirements:`. REQUIREMENTS.md maps exactly these 20 to Phase 1, so none are orphaned.

| Requirement | Source Plans | Status | Evidence |
|-------------|--------------|--------|----------|
| PLAY-01 | 01,07,10,13 | ✓ SATISFIED (code) / ? device | FGS table, `androidStopForegroundOnPause: true`, Stop → idle |
| PLAY-02 | 01,06,07,08 | ✓ SATISFIED | Mapping + ICY on the media item |
| PLAY-03 | 01,09,13 | ? NEEDS HUMAN | MediaButtonReceiver, click/skip wired; REQUIREMENTS says Pending |
| PLAY-05 | 13 | ✗ PARTIAL | Calls ✓; duck restore broken on API 24/25 (gap 1) |
| PLAY-06 | 13 | ✓ SATISFIED | BecomingNoisy → pause |
| PLAY-07 | 10,11,12 | ✓ SATISFIED (logic) / ? ≤10 s | WR-05 caveat for same-type network switches |
| PLAY-08 | 05,09,11 | ✓ SATISFIED | Rotation + debug dead/slow stations |
| PLAY-10 | 09,10,12,13 | ✓ SATISFIED | Generation guards, resting-state tests |
| PLAY-11 | 01,03,09,10 | ✓ SATISFIED | No seek command or control; fresh load on resume |
| STRM-01 | 01,05 | ✓ SATISFIED | MP3 + AAC in release |
| STRM-02 | 04,05 | ✓ SATISFIED (code) | HLS release; non-.m3u8 via sniff tests + debug entry only (gap 2) |
| STRM-03 | 04,05 | ✓ SATISFIED (code only) | Resolver/parsers tested; no release station exercises it (gap 2) |
| STRM-04 | 01,04,05 | ✓ SATISFIED | NSC cleartext for native sockets; AppHttpClient HTTPS-only; http:// БГ Радио in the owner tracer |
| STRM-05 | 05,06,08 | ✓ SATISFIED (code) | cp1251 auto repair; no real cp1251 station verified |
| APP-06 | 07,11 | ✓ SATISFIED | Write-once first launch (WR-04 caveat) |
| APP-07 | 01,02,07,13 | ? NEEDS HUMAN | No POST_NOTIFICATIONS anywhere; behavior is device-only |
| PLAT-01 | 02 | ✓ SATISFIED / ? API 24 install | Badging verified |
| PLAT-03 | 13 | ? NEEDS HUMAN | 60-min run |
| PLAT-04 | 02 | ✓ SATISFIED | WR-06 caveat |
| PLAT-06 | 01,02,13 | ✓ SATISFIED with caveat | WR-02: Interrupted has no time bound |

### Prohibitions

| Plan | Statement (short) | Tier | Disposition |
|------|-------------------|------|-------------|
| 01-05 | Only stations' own official streams; no silent substitutes (D-03) | judgment | Non-authoritative LLM judgment: consistent. Every URL has a `// Source:` station-page comment, Витоша was excluded rather than substituted, and rejected hosts are asserted absent in tests. **unverified-prohibition: human review recommended.** Note: Phase 2 SC4 will fail CI on `dist=` URLs, and 7 current streams carry `?dist=WEBSITEBG`. Reconcile before the catalogue migration |
| 01-11 | No listening activity transmitted or persisted; diagnostics log only in memory and only in debug/profile | test | **Flagged (fail-closed).** The CI deny-list enforces the SDK part. Code inspection finds only `first_launch_at` persisted and only resolver GETs outbound. No test enforces non-persistence. The "only in debug/profile builds" clause is literally false: `RadioAudioHandler._log` keeps the 50-entry in-memory ring buffer in release too, although nothing displays, stores or sends it. Human review recommended |
| 01-13 | No unrequested audio (launch, after pause/stop, noisy, permanent loss, budget error) | test | ✓ Enforced by named tests: resting-state "only UserPlay and UserResume leave", "after a user pause or stop, and in an error… no commands", permanentLoss/noisy groups. Bootstrap never dispatches a play, and the handler starts Idle |

### Test Quality Audit

| Test File | Linked Req | Skipped | Circular | Assertion Level | Verdict |
|-----------|-----------|---------|----------|-----------------|---------|
| state_machine_test.dart | PLAY-05..11 | 0 | No | Behavioral (state + exact command lists) | ✓ |
| radio_audio_handler_test.dart | PLAY-01..10, PLAT-03/06 | 0 | No | Behavioral (fakeAsync, fakes) | ✓, but fakes skip audio_session re-mapping (CR-01 blind spot) |
| cp1251/now_playing_parser/sanitize | STRM-05 | 0 | No | Value (goldens from the Python cp1251 table) | ✓ |
| stream_resolver/playlist_parsers | STRM-02/03 | 0 | No | Value/behavioral | ✓ |
| phase1_stations_test | STRM-01..05 | 0 | No | Value (asserts the reduced matrix) | ✓ (documents gap 2 rather than closing it) |

Disabled tests: 0. Circular patterns: 0. Insufficient assertions: 0.

### Anti-Patterns Found

No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers in `lib`, `android/app/src/main` or `.github`. No stub returns. The only `.skip(` hit is `Stream.skip(1)` in a test, not a disabled test.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| state_machine.dart | 1367-1370, 841 | gainAfterPause ignored while ducked | 🛑 Blocker | Gap 1 (CR-01) |
| state_machine.dart | 1395-1407 | Interrupted has no upper bound (WR-02) | ⚠️ Warning | FGS + audio_service PARTIAL_WAKE_LOCK held while silent if a transient focus holder never releases. By design for calls (D-11), but in tension with PLAT-06. Owner decision |
| just_audio_stream_player.dart | 96-103 | Focus denial invisible (WR-01), `unawaited(play())` (WR-07) | ⚠️ Warning | Play during a call → 20-60 s "Connecting…" then `allStreamsFailed`. Not a must-have path |
| stream_resolver.dart | 206-314 | `unknown` non-audio/* never handed to ExoPlayer (WR-03) | ⚠️ Warning | No release station uses `unknown`; matters for Phase 2 Radio Browser |
| bootstrap.dart | 41-96 | No failure handling before `runApp` (WR-04) | ⚠️ Warning | A DataStore write error could leave the app on the splash screen |
| connectivity_port_impl.dart | 61-99 | Debounce loses same-type switches (WR-05) | ⚠️ Warning | Wi-Fi A→B may exceed ~10 s. Wi-Fi→4G and airplane mode (SC3 wording) are detected |
| release.yml | 92-99 | Signs without analyze/test (WR-06) | ⚠️ Warning | PLAT-04 met literally; a tag on an untested commit ships signed |
| 01-04-SUMMARY.md | human-check | Mentions "N-JOY (.m3u wrapper)" | ℹ️ Info | Stale: N-JOY now ships cdn.btv.bg MP3 |

### How the code review findings affect the must-haves

- **CR-01 (critical): it breaks a must-have.** It falsifies the 01-13 truth "ducks … and restores it afterwards" and makes PLAY-05 partial on API 24/25. On API 26+ the OS ducks without calling the app, so the owner's likely test phones will not show it. That is why it can't be left to UAT. It is gap 1.
- **WR-02: no must-have breaks; flagged for an owner decision.** SC2's "after the user stops…" still holds. It weakens PLAT-06 ("no wake-locks or FGS when not playing") in a misbehaving-focus-holder edge case.
- **WR-05: it doesn't break SC3 as worded.** It weakens PLAY-07's ~10 s target for same-type network handovers.
- **WR-01, WR-03, WR-04, WR-06, WR-07 and the IN-xx findings: no Phase 1 must-have is falsified.** They are robustness and hygiene issues.

### Decision Coverage

All 17 trackable CONTEXT.md decisions are honored by shipped artifacts (`check.decision-coverage-verify`: 17/17, none not honored). Non-blocking gate.

### Human Verification Required

These remain after the gaps are closed. The owner uses the CI-signed release APK unless a step says otherwise.

1. **Sideload rc.3 (01-02 open).** Test: install `app-release.apk` from the `eradioto-v0.1.0-rc.3` artifact and open it. Expected: it installs over nothing (clean) and launches, and the signer is the upload cert. Why human: the CI run result and the install can't be checked here (no `gh`, no device).
2. **API 24 install (01-02 open, PLAT-01).** Test: `flutter run --release` on an Android 7.0 emulator. Expected: the app launches and a station plays. Why human: needs an emulator. While on API 24/25, also reproduce CR-01: play, trigger a Maps voice prompt, force a reload (toggle Wi-Fi) during it, and check whether the volume recovers.
3. **SC1 station sweep (01-05/01-11).** Test: in release, play every station; in debug, use "Play #i" for every stream index and the HLS-sniff entry. Expected: audio within about 5 s; no ТЕСТ stations in release. Why human: real station servers.
4. **Cyrillic now-playing (01-06/01-08).** Test: watch ICY titles on the mini-player, notification, lock screen and car display; switch stations. Expected: correct Cyrillic, the title stays the station name, no stale title, HLS shows the name only. Why human: real ICY senders.
5. **SC2 60-min screen-off (01-13, PLAT-03, APP-07).** Test: on Xiaomi and Samsung, notification permission denied, 60 min on Wi-Fi and on 4G; controls from the notification, lock screen, wired, BT and car BT; Stop; swipe while paused; `dumpsys` for FGS, wake lock and the `eRadioto:stream` Wi-Fi lock. Expected: no dropout or kill; controls work; nothing remains after Stop. Record the FGS demo video. Why human: OEM power management and system UI.
6. **SC3 recovery timing (01-10/01-12).** Test: Wi-Fi off while playing, airplane mode for 60 s, blocked for more than 3 min and more than 10 min. Expected: audio returns within ~10 s at the live edge while "Повторно свързване…" shows; then an error with Play and no FGS; pause + Wi-Fi toggle restarts nothing. Why human: real network timings.
7. **SC4 interruptions (01-13).** Test: calls of more than 1 min and more than 10 min, a WhatsApp/Viber call, Maps prompts, wired and BT unplug, a 5-min pause then Play from the lock screen and car, another media app; capture logcat. Expected: calls resume live, prompts duck then restore, unplug stays paused, resume is live, another app pauses for good, no `ForegroundServiceStartNotAllowedException` or `AUDIOFOCUS_REQUEST_FAILED`. Why human: telephony and focus on real devices.
8. **UI/notification visuals (01-03/01-07).** Test: a Bulgarian-locale phone with TalkBack, and at 2x font. Expected: BG strings, state labels announced, a white radio status icon (not a square), channel "Възпроизвеждане". Why human: visual and accessibility checks.
9. **Next/previous from headset and car (01-09).** Expected: steps through the home list with wrap. Why human: hardware buttons.
10. **Prohibition review (01-05 judgment, 01-11 test-tier flagged).** The owner confirms every shipped URL is official. The owner then either accepts the in-memory diagnostics ring buffer in release builds or gates `_log` behind `!kReleaseMode`.

### Gaps Summary

The engine is real, complete and well wired. The pure reducer, serial-queue handler, FGS table, resolver, cp1251 pipeline, CI and signed release all exist, are substantive and are exercised by passing behavioral tests. Two things stand between this and the phase contract:

1. **Duck restore (CR-01)**, a code defect on supported API 24/25 devices. A reload during a navigation prompt leaves the radio at 30 % volume indefinitely. The fix is small (treat gainAfterPause as the end of a duck while `ducked`, or own session activation in the engine) and needs one new test.
2. **SC1 release format matrix.** The owner deliberately shipped a reduced lineup (no .pls/.m3u, no non-.m3u8 HLS, no known cp1251 station), and those formats are proven only by unit tests. The owner decided this, so an override is the natural resolution:

```yaml
overrides:
  - must_have: "In a release build the stations together cover MP3, AAC+, HLS including non-.m3u8, a .pls/.m3u playlist URL, a plain http:// stream and a windows-1251 station"
    reason: "D-02/D-03 owner decision 2026-09-25 (option-a/option-c): no official .pls/.m3u, non-.m3u8 HLS or verified cp1251 endpoint exists for the chosen stations, and D-03 forbids substitutes. The capability is covered by resolver, sniff and cp1251 golden tests and the debug HLS-sniff station; release coverage moves to the Phase 2 catalogue."
    accepted_by: "{owner}"
    accepted_at: "{ISO timestamp}"
```

If that override is accepted and CR-01 is fixed, the phase moves to `human_needed` with the owner device checks above.

---

_Verified: 2026-09-25T22:31:51Z_
_Verifier: Claude (gsd-verifier)_
