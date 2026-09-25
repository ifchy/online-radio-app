# Phase 1: Playback Engine & Walking Skeleton - Research

**Researched:** 2026-09-25
**Domain:** Flutter (3.47.5) Android live-radio playback engine: just_audio 0.10.6 / audio_service 0.18.19 / audio_session 0.2.4, FGS policy, reconnect state machine, stream resolution, ICY/cp1251, CI + signing
**Confidence:** HIGH for plugin APIs, SDK behaviour and scaffolding (read from published source archives and run on a real Flutter 3.47.5 SDK in this session). MEDIUM for timing values and device behaviour (need the owner's phones). LOW for station stream URLs (the station sites are blocked from this environment, so every URL is UNVERIFIED until the owner checks it).

> This document builds on `.planning/research/{STACK,ARCHITECTURE,PITFALLS,SUMMARY}.md`. It does not restate them. It adds the phase-specific layer: exact APIs, corrections, station data, the state/FGS table, CI, and the test and owner-verification plan.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Test station lineup
- **D-01:** The hard-coded set is **6 stations**: **Radio 1** and **BG Radio** (owner must-haves), **Радио Витоша**, **N-JOY**, **Energy** (owner's likely picks) and **БНР Хоризонт** (added as the flagship / core-value station).
- **D-02:** Stations and URLs are a mix. The owner named the stations, and the phase researcher finds each one's **official, publicly offered** stream endpoints. The owner confirms the URLs play and are official before execution relies on them.
- **D-03:** Format coverage comes from **the alternate endpoints these same stations publish**, not from extra stations. Across `Station.streams[]` the set must cover: MP3, AAC/HE-AAC, HLS (including HLS behind a non-`.m3u8` URL), a `.pls` or `.m3u` wrapper, a plain `http://` stream, and a windows-1251 ICY title. БНР Хоризонт is the expected HLS source. If research finds that a format is **not obtainable** from these 6 stations, flag it to the owner. Do not silently swap stations.
- **D-04:** Each station carries its real alternate streams as ordered `streams[]` (primary + fallbacks), so PLAY-08 rotation runs on real data.
- **D-05:** Add a **debug-only "dead primary" test station**: its first stream is a deliberately unreachable URL and its fallback is a real stream. It exists only in debug/profile builds and **must never ship in the release station list**.

#### Skeleton screen
- **D-06:** The main screen is a **simple list of the 6 stations** (name + generic icon) with a **bottom mini-player**. The mini-player shows the station name, the now-playing text, play/pause and stop, and a state label. There's no design polish, because Phase 2/3 replace this UI. It still needs TalkBack labels and adequate touch targets.
- **D-07:** Add a **debug panel in debug/profile builds only**, hidden in release. It shows the current state-machine state, the stream URL/format in use and its index in `streams[]`, time-to-audio for the last start, the reconnect attempt / backoff delay, and a short recent-event log.
- **D-08:** **gen-l10n from day one with BG + EN ARB files** (`synthetic-package: false`, output in `lib/`). Bulgarian is the default on a `bg` device and English otherwise. The owner does the proper BG copy review in Phase 3, so Phase 1 strings are placeholders.
- **D-09:** When the player isn't simply playing, the mini-player shows a **short text state label**: "Свързване…" (connecting), "Буфериране…" (buffering), "Повторно свързване…" (reconnecting), "Грешка" (error). The friendly error UX (PLAY-09) comes in Phase 4.

#### Give-up & resume rules
- **D-10:** Reconnect give-up is a **configurable `RetryBudget` policy inside the engine**, with three named presets:
  - `standard` (default): **3 min of failing while online / 10 min while offline**
  - `trip`: longer, around 5 min online / 30 min offline
  - `batterySaver`: shorter, around 1 min online / 5 min offline

  Phase 1 wires up only `standard`. Choosing the preset must be a single engine-level setting, so a future UI toggle needs no engine refactor. Research/planning may tune the exact trip/saver numbers. When the budget runs out, the app goes to Error: it releases focus, stops the FGS, and the notification shows the error with a play button.
- **D-11:** After a phone call (transient focus loss), **always auto-resume if the radio was playing**, no matter how long the call lasted. It resumes at the live edge. It never resumes if the user had paused or stopped (PLAY-10).
- **D-12:** The media notification and lock screen show **Play/Pause + Stop**. Pause keeps the media session and notification, and resume reloads at the live edge. Stop ends the session, removes the notification and stops the service. Leave room in the action layout for next/prev, which Phase 3 adds (PLAY-04).
- **D-13:** On pause: **drop the foreground service** (`androidStopForegroundOnPause: true`), **keep the notification**, which the user can swipe away. No wake-locks or Wi-Fi lock while paused. There is no auto-stop timer.

#### CI, signing & device testing
- **D-14:** The owner has **no upload keystore yet**. The plan includes a **human checkpoint** with step-by-step instructions: create the upload keystore locally with `keytool`, back it up outside the repo, and add it to GitHub Actions secrets (base64 keystore, store/key passwords, alias). CI decodes it at build time. `.gitignore` must block `*.jks`, `*.keystore` and `key.properties`. Nothing secret is ever committed.
- **D-15:** Build delivery:
  - Tags and a manual `workflow_dispatch` build a **signed release AAB plus a signed release APK** and upload them as CI artifacts, so the owner can sideload the APK.
  - Every PR runs `flutter analyze` + `flutter test`.
  - The owner also iterates locally with `flutter run --release` / `--profile`.
- **D-16:** Physical test devices the owner has:
  - **a Xiaomi/Redmi/POCO**
  - **a Samsung Galaxy**
  - **a car with a Bluetooth head unit**
  - **a car with Android Auto**

  The owner has **no Android 7–9 device**, so the minSdk 24 install/launch check runs on an **API 24 emulator**. Background audio is verified only on the physical phones. Car testing in Phase 1 uses **plain Bluetooth**; if the Android Auto car is used, do it with projection disabled.
- **D-17:** **Commit generated code** (`*.g.dart`, `*.freezed.dart`, drift output). CI runs `build_runner build` and fails on `git diff --exit-code`, which catches stale generated files.

### Claude's Discretion
- Exact trip/batterySaver budget numbers, the backoff schedule, and the stall-watchdog and connect timeouts (start from `.planning/research/ARCHITECTURE.md` Pattern 3/4 and tune on device).
- The placeholder app icon and the skeleton's visual styling (Material 3 defaults are fine).
- Debug panel layout and log length.
- Whether the Phase 1 workflow also uploads a debug APK on PRs.

### Deferred Ideas (OUT OF SCOPE)
- **User-facing Trip mode / Battery saver toggle** for the reconnect budget. This is a new UI capability needing a settings surface → Phase 3 (listening experience) or the v1.1 backlog. The engine presets land in Phase 1 (D-10).
- **Android Auto testing on the owner's Android Auto car** → v1.1 (Android Auto is out of v1 scope). The car is noted as the v1.1 test rig.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PLAY-01 | Screen-off / background playback via media FGS; the service stops when the user stops | §State/FGS table: `playing:true` starts the FGS and a PARTIAL wake lock, and `idle` stops the service (audio_service source). Manifest block. Wi-Fi lock channel. Owner checks with `dumpsys`. |
| PLAY-02 | Play/pause/stop and station name/now playing on the notification and lock screen | `PlaybackState.controls` per state. `MediaItem.title` = station and `artist`/`displaySubtitle` = ICY. D-12 layout. |
| PLAY-03 | Wired, BT headset and car BT buttons | `MediaButtonReceiver` in the manifest. `BaseAudioHandler.click()` default (verified): media = toggle on `playing`. Owner device matrix. |
| PLAY-05 | Duck for navigation, pause for calls, resume after a transient interruption unless the user paused | `handleInterruptions:false`, and our own audio_session mapping (verified event mapping). `Interrupted` state keeps the FGS. Auto-duck needs no callback on API 26+ (cited). |
| PLAY-06 | Pause on unplug or BT disconnect | `becomingNoisyEventStream`. It is registered only while focus is held (verified). Maps to Paused. |
| PLAY-07 | Reconnect at the live edge in about 10 s, with backoff, a bounded budget and the FGS alive | Pure state machine + `ReconnectPolicy` + `RetryBudget` presets. Watchdogs (connect, buffering, post-network-change flow check). `connectivity_plus` default-network callback (verified). |
| PLAY-08 | Fallback streams in priority order | Rotation rules. Real `streams[]` per station (§Station matrix). Debug dead-primary station. |
| PLAY-10 | User stop/pause (incl. noisy) is never undone by reconnect | Transitions table: only `Interrupted`→gain and `Reconnecting`→timer may start playback. Focus is abandoned on pause/stop. |
| PLAY-11 | Resume = live edge, no seek bar | Pause = `player.stop()`, which disposes the native player (verified). Resume = fresh load. No `MediaAction.seek`. |
| STRM-01 | MP3 + AAC/HE-AAC | `ProgressiveAudioSource`. Station matrix covers both. |
| STRM-02 | HLS incl. non-`.m3u8` URLs | `HlsAudioSource` chosen by resolver `kind`. `AudioSource.uri` extension logic quoted. Non-`.m3u8` case is **not found** among the 6 stations, so it is FLAGGED; unit tests + debug sniff station cover it. |
| STRM-03 | `.pls`/`.m3u` resolved by the app | `StreamResolver` design + limits. N-JOY `njoy.mp3.m3u` (Icecast-generated) is the real-data case. |
| STRM-04 | Plain `http://` in release; app-owned traffic HTTPS-only | NSC `base-config cleartextTrafficPermitted="true"` + `AppHttpClient` HTTPS guard. **The `INTERNET` permission is missing from the template's main manifest** (verified). |
| STRM-05 | ICY now-playing, cp1251 repair, no stale title | Media3 `IcyDecoder` UTF-8→ISO-8859-1 fallback (verified). Repair algorithm + in-repo table. Native ICY state is never reset on load (verified), so we stop() + a generation guard. |
| APP-06 | First-launch date stored on the very first run | `SharedPreferencesAsync` write-once. In-memory fake for tests (verified API). |
| APP-07 | Media controls work with the notification permission denied | Do not declare or request `POST_NOTIFICATIONS`. Media-session notifications are exempt (cited). Owner check. |
| PLAT-01 | minSdk 24, target 36 | Flutter 3.47.5 template values verified (24/36/36). Set explicitly. API 24 emulator check. |
| PLAT-03 | 60 min screen-off on Xiaomi + Samsung | FGS + PARTIAL wake lock (audio_service) + Wi-Fi lock (ours, since just_audio has none: verified). Owner checkpoint. |
| PLAT-04 | CI analyze + test on PRs, signed AAB on tags, no secrets | Workflow layout with verified action tags. Keystore checkpoint. **`flutter analyze` does not report riverpod_lint; add `dart analyze`** (verified). |
| PLAT-06 | No wake-locks/FGS when not playing; no tracking SDKs | State/FGS table (Paused/Idle/Error release everything). CI dependency deny-list check. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These carry the same authority as locked decisions. The planner must verify compliance.

- **Stack:** Flutter stable (3.47.5, Dart 3.13.4), Android only. Audio through `just_audio` + `audio_service` + `audio_session`, **behind our own `AudioEngine` interface**, so the engine can be swapped without touching the UI.
- **Pinned versions:** use those in CLAUDE.md "Recommended Stack". For this phase they resolve together (verified in this session): just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4, flutter_riverpod 3.4.3, riverpod_annotation 4.0.7, riverpod_generator 4.0.9, riverpod_lint 3.1.9, shared_preferences 2.5.5, http 1.6.0, connectivity_plus 7.3.1, package_info_plus 10.2.1, freezed 4.0.2, freezed_annotation 3.1.0, build_runner 2.16.1, mocktail 1.0.5, flutter_lints 6.0.0, intl 0.20.3.
- **Required patterns:** `AudioPlayer(useProxyForRequestHeaders: false, userAgent: ...)`. Explicit `ProgressiveAudioSource`/`HlsAudioSource` (never `AudioSource.uri()` for stations). Build `.pls`/`.m3u` resolution yourself. `http`, not `dio`. `SharedPreferencesAsync`/`WithCache`, not the legacy singleton. gen-l10n output in `lib/`. `riverpod_lint` under `plugins:` (no `custom_lint`). Do not add `sqlite3_flutter_libs`.
- **Forbidden:** `just_audio_background`, `radio_player`, `media_kit`, `assets_audio_player`, `permission_handler` for notifications, any ads/analytics/tracking SDK, blanket `usesCleartextTraffic="true"` without a Dart-side HTTPS guard, and `import 'package:flutter_gen/gen_l10n/...'`.
- **SDK:** min 24 / target 36 / compile 36. AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, JDK 17. Never downgrade AGP to 8.6/8.7.
- **Licensing:** only free, permissively licensed dependencies.
- **Security:** the repo is public. Never commit signing keys, keystores or secrets. Upload key only; Play App Signing holds the app key.
- **Content rights:** only stations' own, official, publicly offered streams.
- **Privacy:** no personal data and no tracking in v1.
- **Accessibility:** TalkBack labels on all controls, large text, contrast, big player touch targets.
- **Battery:** no wake-locks when not playing; stop the FGS when playback stops.
- **Working agreements:** every phase leaves the app runnable; `flutter analyze` + `flutter test` pass; playback phases are verified by the owner on a physical phone; the owner reviews Bulgarian strings; conventional commits; phase work lands via PRs.
- **GSD workflow:** file edits happen through GSD commands (execute-phase).

## Summary

Phase 1 turns an empty repo into a signed, CI-built `bg.izk.radio` app whose engine plays six hard-coded Bulgarian stations and keeps playing through the Android lifecycle. The project research already chose the stack and the architecture (facade + `StreamPlayer` port + explicit state machine). This research confirmed the exact plugin behaviour by reading the published 0.10.6 / 0.18.19 / 0.2.4 source. It also ran `flutter create`, dependency resolution, codegen, gen-l10n, `flutter analyze` and `flutter test` on a real Flutter 3.47.5 SDK in a Linux container with no Android SDK.

Several facts change or sharpen the plan:

1. **Release-build blockers.** The Flutter template's **main** `AndroidManifest.xml` has **no `INTERNET` permission** (only the debug/profile manifests have it), and none of the plugins add it. Every stream would fail in release only.
2. **Lint blind spot.** `flutter analyze` **does not report riverpod_lint plugin diagnostics**. Only `dart analyze` does (it exits with code 2 on a `missing_provider_scope` warning). CI must run both.
3. **gen-l10n.** `synthetic-package: false` in `l10n.yaml` now only prints a "no longer has any effect and should be removed" warning. The intent of D-08 is met by omitting the key. `flutter: generate: true` is still required.
4. **Wi-Fi lock.** just_audio never calls `setWakeMode`, and ExoPlayer's default is `WAKE_MODE_NONE`. The Wi-Fi lock (Pitfall 4) therefore has to come from our own small platform channel.
5. **ICY and interruptions.**
   - The native ICY title is never reset on load, but `player.stop()` disposes the native player. Stop-then-load is therefore the stale-title fix.
   - just_audio never abandons audio focus. The engine must call `session.setActive(false)` on pause, stop and error.
   - `player.play()`'s Future only completes on pause/stop/complete. Never `await` it in the engine.

For stations, the Global-Audio group (Radio 1, BG Radio, Energy) publishes official MP3 streams on `play.global.audio` (an Icecast server) and AAC streams via StreamTheWorld `livestream-redirect`, both tagged `dist=WEBSITEBG` (the station website's own tag). N-JOY (bTV Radio Group) serves MP3 on `live.btvradio.bg`, including an Icecast-generated `njoy.mp3.m3u`. БНР Хоризонт has the cdn.bg HLS URL and `stream.bnr.bg:8011` Icecast. Three things are missing:
- **No official Радио Витоша endpoint** was found.
- **No natural "HLS behind a non-`.m3u8` URL"** exists among the six.
- **The cp1251 ICY charset of each station cannot be known** without a byte probe.

All three are owner flags per D-03, with a concrete probe protocol below.

**Primary recommendation:** Build it as a walking skeleton first: scaffold, manifest (with `INTERNET`), one station through `AudioServiceActivity` + audio_service, CI green, signed release APK on the owner's phone. Then add stream resolution/ICY and the six real stations. Then add the pure-Dart state machine (tested with `fake_async`, a fake `StreamPlayer` and fake session/connectivity ports) that owns interruptions, FGS mapping, watchdogs, backoff, budget and fallback rotation. Keep it one phase with three to four plans, and put a blocking owner smoke check after the skeleton plan.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Playback decisions (state machine, reconnect, budget, fallback, interruptions) | Dart domain/engine (main isolate, `RadioAudioHandler`) | — | Must run with the UI gone (screen off, activity destroyed). audio_service runs the handler in the main isolate. |
| Audio decoding, HTTP/HLS fetching, ICY decoding | Native: Media3 ExoPlayer inside just_audio | — | Only native sockets are governed by the NSC; ExoPlayer tolerates `ICY 200 OK`. |
| FGS, MediaSession, notification, media buttons, PARTIAL wake lock | Native: audio_service `AudioService` | Dart handler publishes `PlaybackState` | audio_service starts/stops the FGS purely from `playing` and `processingState` (verified). |
| Audio focus, becoming-noisy | Native: audio_session `AndroidAudioManager` | Dart engine maps events → state | `handleInterruptions:false`, so the engine is the single owner. |
| Wi-Fi lock | Native: app `MainActivity` MethodChannel (Kotlin) | Dart `WifiLockPort` | No plugin provides it (verified). |
| Playlist (`.pls`/`.m3u`) resolution, HLS sniff | Dart `StreamResolver` + `package:http` | — | Must run before the player load. Pure, unit-testable. |
| cp1251 repair, ICY parsing, sanitising | Dart `core/text` + `NowPlayingParser` | — | Pure functions with golden tests. |
| Network change detection | Native connectivity_plus (default-network callback) | Dart `ConnectivityPort` | The engine decides; the plugin only reports. |
| UI (station list, mini-player, debug panel, labels) | Flutter presentation | Riverpod providers mirror engine streams | The UI is a subscriber and command sender only. |
| First-launch date | Dart `SettingsRepository` over `SharedPreferencesAsync` (DataStore on Android) | — | Written once in bootstrap. |
| Build, sign, verify | GitHub Actions (ubuntu) | Owner's machine for local `--release` | Secrets only in tag/dispatch jobs. |

## Standard Stack

The stack is pinned in CLAUDE.md. This is the **Phase 1 subset** only, verified to resolve on Flutter 3.47.5 in this session [VERIFIED: `flutter pub add` + `pubspec.lock` in probe project].

### Core (Phase 1)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| just_audio | 0.10.6 | ExoPlayer (Media3 1.4.1) playback, ICY, HLS | Pinned; source inspected |
| audio_service | 0.18.19 | FGS, MediaSession, notification, media buttons | Pinned; source inspected |
| audio_session | 0.2.4 | Focus, interruption, becoming-noisy | Pinned; source inspected |
| flutter_riverpod / riverpod_annotation | 3.4.3 / 4.0.7 | Provider mirrors of engine streams, DI overrides | Pinned |
| shared_preferences | 2.5.5 | `SharedPreferencesAsync` for first-launch date | Pinned |
| http | 1.6.0 | Playlist resolver, future HTTPS-only app client | Pinned; `MockClient` for tests |
| connectivity_plus | 7.3.1 | Default-network change events | Pinned; Android impl uses `registerDefaultNetworkCallback` (verified) |
| package_info_plus | 10.2.1 | App version for the User-Agent | Pinned |
| freezed_annotation | 3.1.0 | Sealed unions (`PlaybackStatus`, commands, events) | Pinned; sealed + `switch` verified in probe |
| flutter_localizations + intl | SDK / 0.20.3 | gen-l10n BG/EN | Pinned |

### Dev (Phase 1)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| build_runner | 2.16.1 | freezed + riverpod codegen | Always; outputs committed (D-17) |
| riverpod_generator | 4.0.9 | `@riverpod` providers | Providers |
| riverpod_lint | 3.1.9 | Lints via `analysis_server_plugin` | Under `plugins:`; **only surfaced by `dart analyze`** |
| freezed | 4.0.2 | Codegen for sealed unions | Domain types |
| mocktail | 1.0.5 | Mocks where fakes are overkill | Tests |
| fake_async | 1.3.3 (`any`; pinned by flutter_test) | Virtual time for state machine/backoff/watchdog tests | Engine tests |
| clock | 1.1.3 (transitive via audio_service; add direct dep) | Injectable clock (`fakeAsync` provides it) | Budget timing |
| flutter_lints | 6.0.0 | Base lints | Template default |

**Not in Phase 1** (the project research assigns them to later phases): go_router, drift/drift_flutter, cached_network_image, json_serializable, diacritic, url_launcher, share_plus, path_provider, flutter_native_splash, flutter_launcher_icons. Do not add them now. That keeps the APK and the codegen surface small, and D-17 then only covers `*.g.dart`, `*.freezed.dart` and the l10n output.

**Installation (verified command sequence):**
```bash
flutter create --org bg.izk --project-name radio --platforms android \
  --description "eRadioto - Bulgarian internet radio" .
flutter pub remove cupertino_icons
flutter pub add just_audio:^0.10.6 audio_service:^0.18.19 audio_session:^0.2.4 \
  flutter_riverpod:^3.4.3 riverpod_annotation:^4.0.7 shared_preferences:^2.5.5 \
  http:^1.6.0 connectivity_plus:^7.3.1 package_info_plus:^10.2.1 \
  freezed_annotation:^3.1.0 'flutter_localizations:{"sdk":"flutter"}' intl:any clock:^1.1.3
flutter pub add --dev build_runner:^2.16.1 riverpod_generator:^4.0.9 riverpod_lint:^3.1.9 \
  freezed:^4.0.2 mocktail:^1.0.5 fake_async:any
```
`flutter create` produces `namespace = "bg.izk.radio"`, `applicationId = "bg.izk.radio"` and `android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt` [VERIFIED: probe run]. The manifest label comes out as `"radio"` and must be changed to `"eRadioto"`. The repo already has `.gitignore`, `docs/` and `.planning/`. `flutter create .` adds missing files but does not overwrite existing ones unless you pass `--overwrite` [ASSUMED]. Review `git status` after it runs.

## Package Legitimacy Audit

The GSD `package-legitimacy` seam supports only npm/pypi/crates (`Usage: ... --ecosystem <npm|pypi|crates>`), so it cannot check pub.dev packages. The audit below was done manually against the pub.dev API (`/api/packages/<name>`, `/score`) on 2026-09-25. Every package is already named in CLAUDE.md (the project's decided stack) except `fake_async` and `clock`, which are dart.dev/tools.dart.dev first-party packages.

| Package | Registry | Latest / published | Downloads (30 d) | Publisher | Licence | Verdict | Disposition |
|---------|----------|-------------------|------------------|-----------|---------|---------|-------------|
| just_audio | pub.dev | 0.10.6 / 2026-06-29 | 1,216,963 | ryanheise.com | MIT + Apache-2.0 | OK | Approved |
| audio_service | pub.dev | 0.18.19 / 2026-06-29 | 216,134 | ryanheise.com | MIT | OK | Approved |
| audio_session | pub.dev | 0.2.4 / 2026-06-29 | 1,419,104 | ryanheise.com | MIT | OK | Approved |
| flutter_riverpod | pub.dev | 3.4.3 / 2026-09-03 | 3,265,597 | dash-overflow.net | MIT | OK | Approved |
| riverpod_annotation | pub.dev | 4.0.7 / 2026-09-03 | 1,217,293 | dash-overflow.net | MIT | OK | Approved |
| riverpod_generator | pub.dev | 4.0.9 / 2026-09-03 | 1,036,192 | dash-overflow.net | MIT | OK | Approved |
| riverpod_lint | pub.dev | 3.1.9 / 2026-09-03 | 530,244 | (none; repo rrousselGit/riverpod) | MIT | OK (unverified publisher, same repo as riverpod) | Approved |
| shared_preferences | pub.dev | 2.5.5 / 2026-03-25 | 6,833,018 | flutter.dev | BSD-3 | OK | Approved |
| http | pub.dev | 1.6.0 / 2025-11-10 | 12,083,117 | dart.dev | BSD-3 | OK | Approved |
| connectivity_plus | pub.dev | 7.3.1 / 2026-07-23 | 3,656,195 | fluttercommunity.dev | BSD-3 | OK | Approved |
| package_info_plus | pub.dev | 10.2.1 / 2026-07-15 | 5,959,506 | fluttercommunity.dev | BSD-3 | OK | Approved |
| freezed / freezed_annotation | pub.dev | 4.0.2 / 3.1.0 | 2.8M / 4.1M | dash-overflow.net | MIT | OK | Approved |
| build_runner | pub.dev | 2.16.1 / 2026-09-02 | 6,666,832 | tools.dart.dev | BSD-3 | OK | Approved |
| mocktail | pub.dev | 1.0.5 / 2026-04-10 | 3,422,955 | felangel.dev | MIT | OK | Approved |
| fake_async | pub.dev | 1.3.3 / 2025-01-28 | 8,179,113 | dart.dev | Apache-2.0 | OK | Approved |
| clock | pub.dev | 1.1.3 / 2026-08-28 | 11,636,241 | tools.dart.dev | Apache-2.0 | OK | Approved |
| flutter_lints | pub.dev | 6.0.0 / 2025-05-27 | 8,661,907 | flutter.dev | BSD-3 | OK | Approved |
| enough_convert (considered for cp1251) | pub.dev | 1.6.0 / 2022-06-15 | 31,493 | enough.de | **MPL-2.0** | — | **Not used**: weak copyleft and stale. Use the in-repo table. |
| charset (considered for cp1251) | pub.dev | 2.0.1 / 2023-06-25 | 161,374 | shirne.com | Apache-2.0 | — | **Not used**: a 128-entry table is smaller than the dependency. |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none. No Phase 1 package runs install scripts; pub has no postinstall hooks. Note that drift/sqlite3 build hooks are not in Phase 1.

## Architecture Patterns

### System Architecture Diagram

```
  UI (StationList, MiniPlayer, DebugPanel)        OS surfaces (notification, lock screen,
        │ commands        ▲ ref.watch              BT/AVRCP, wired headset, car BT)
        ▼                 │                                  │ media button / notification tap
  AudioEngine facade ─────┴─ status/nowPlaying/station ◀─────┤
        │                                                     ▼
        ▼                                       audio_service native AudioService
  RadioAudioHandler (BaseAudioHandler) ◀── callbacks: play/pause/stop/click/playFromMediaId/
        │  publishes PlaybackState + MediaItem ──────▶ FGS start/stop, wake lock, notification
        │
        ├─▶ PlaybackStateMachine (pure)  ◀── events ──┬── StreamPlayer events (state, error, icy, buffered)
        │        │ emits Commands                     ├── AudioSessionPort (interruption, noisy)
        │        ▼                                    ├── ConnectivityPort (online/offline/changed)
        │   CommandExecutor                           └── Timers (connect timeout, stall, backoff, budget)
        │     ├─ Resolve(stream i) ──▶ StreamResolver ──http──▶ .pls/.m3u/HLS sniff ──▶ ResolvedStream
        │     ├─ Load+Play(resolved) ──▶ JustAudioStreamPlayer ──▶ ExoPlayer (HTTP/HLS, ICY, NSC)
        │     ├─ StopTransport ──▶ player.stop() (native player disposed ⇒ fresh ICY state)
        │     ├─ Focus(release) ──▶ AudioSession.setActive(false)
        │     ├─ WifiLock(acquire|release) ──▶ MethodChannel ──▶ WifiManager lock (Kotlin)
        │     └─ Publish(state) ──▶ PlaybackState/MediaItem
        │
        └─▶ NowPlayingParser (ICY title → sanitise → cp1251 repair → split → distinct)
```

### Recommended Project Structure (Phase 1 slice of ARCHITECTURE.md)

```
lib/
├── main.dart                         # calls bootstrap()
├── app/
│   ├── bootstrap.dart                # composition root: prefs, first-launch, session.configure, AudioService.init, container
│   ├── app.dart                      # MaterialApp + l10n delegates
│   └── home_screen.dart              # station list + MiniPlayer + (debug) DebugPanel
├── core/
│   ├── network/app_http_client.dart  # HTTPS-only client for app-owned traffic (guard, used from Phase 2)
│   ├── network/user_agent.dart       # 'eRadioto/<ver> (Android; +<repo url>)'
│   ├── text/cp1251.dart              # table + repair
│   ├── text/sanitize.dart            # control/bidi strip, clamp
│   └── settings/settings_repository.dart  # firstLaunchAt (write-once)
├── l10n/ app_en.arb, app_bg.arb (+ generated app_localizations*.dart, committed)
└── features/
    ├── catalog/domain/               # Station, StationId, StationStream(kind, url, codec, bitrate, icyCharset), StreamKind
    ├── catalog/data/phase1_stations.dart        # the 6 stations (release)
    ├── catalog/data/debug_stations.dart         # D-05, only referenced under !kReleaseMode
    └── playback/
        ├── domain/                   # AudioEngine, PlaybackStatus (sealed), NowPlaying, PlayContext, RetryBudget, EngineStrings, media_id.dart
        ├── engine/                   # ONLY folder importing just_audio/audio_service/audio_session/connectivity_plus
        │   ├── radio_audio_handler.dart, audio_service_engine.dart
        │   ├── state_machine.dart, reconnect_policy.dart, retry_budget.dart
        │   ├── ports.dart (StreamPlayer, AudioSessionPort, ConnectivityPort, WifiLockPort)
        │   ├── just_audio_stream_player.dart, audio_session_port_impl.dart, connectivity_port_impl.dart, wifi_lock_channel.dart
        │   ├── resolver/{stream_resolver,pls_parser,m3u_parser}.dart
        │   └── icy/now_playing_parser.dart
        ├── application/              # playbackStatusProvider, nowPlayingProvider, currentStationProvider, debugLogProvider
        └── presentation/             # mini_player.dart, debug_panel.dart, state_label.dart
android/app/src/main/{AndroidManifest.xml, res/xml/network_security_config.xml, res/drawable/ic_stat_radio.xml,
                      kotlin/bg/izk/radio/MainActivity.kt}
.github/workflows/{ci.yml, release.yml}
test/ mirrors lib/ (engine/, resolver/, text/, domain/, presentation/) + test/fixtures/playlists/*
```

### Pattern 1: Engine-owned interruptions (single owner)

**What:** Construct `AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: true, useProxyForRequestHeaders: false, userAgent: ua, audioLoadConfiguration: ...)`. Subscribe to `AudioSession.instance` `interruptionEventStream` and `becomingNoisyEventStream` in the engine.

**Why (verified):**
- With `handleInterruptions: true`, just_audio calls `pause()` on noisy and on `pause`/`unknown` interruptions. It resumes with `play()` on the end of a `pause` interruption. It only ducks when usage is `game`. All of that happens behind the state machine's back [VERIFIED: just_audio-0.10.6/lib/just_audio.dart:370-415].
- With `handleAudioSessionActivation: true`, `play()` still calls `audioSession.setActive(true)` (focus request) first [VERIFIED: just_audio.dart:1097-1098: `final audioSession = await AudioSession.instance; if (!_handleAudioSessionActivation || await audioSession.setActive(true)) {`].
- just_audio **never calls `setActive(false)`**. The only `setActive` call in the file is line 1098 [VERIFIED: grep]. So the engine must abandon focus itself on user pause, stop and error.

**audio_session event mapping (Android)** [VERIFIED: audio_session-0.2.4/lib/src/core.dart:254-281]:

| Android focus change | `AudioInterruptionEvent` | Engine action |
|---|---|---|
| `AUDIOFOCUS_LOSS_TRANSIENT` (phone call) | `begin: true, type: pause` | Active state → **Interrupted**: `player.stop()`, keep the FGS (`playing: true`), release the Wi-Fi lock |
| `AUDIOFOCUS_LOSS` (another media app) | `begin: true, type: unknown` (and audio_session already abandons focus, AndroidAudioManager.kt:353) | → **Paused** (no auto-resume) |
| `AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK` | `begin: true, type: duck` (only when `willPauseWhenDucked` is false/null) | `setVolume(0.3)`; state unchanged |
| `AUDIOFOCUS_GAIN` after pause-type loss | `begin: false, type: pause` | If **Interrupted** → Connecting (fresh load at the live edge). Otherwise ignore. |
| `AUDIOFOCUS_GAIN` after duck | `begin: false, type: duck` | `setVolume(1.0)` |

- On API 26+, the system auto-ducks music without calling the listener, so duck events mostly arrive on API 24/25 [CITED: developer.android.com/media/optimize/audio-focus: "the system can duck and restore the volume without invoking the app's `onAudioFocusChange()` callback"]. Handling duck with `setVolume` is therefore correct and never double-ducks.
- `requestAudioFocus` returns `true` early if a request is already held (`if (audioFocusRequest != null) return true`) [VERIFIED: AndroidAudioManager.kt:345-347]. After a transient loss we still hold the request, so the next `play()` needs no new focus grant. After a permanent loss, audio_session abandons, so the next `play()` re-requests.
- The becoming-noisy receiver is registered **only while focus is held** (`registerNoisyReceiver()` on grant, `unregisterNoisyReceiver()` in `abandonAudioFocus()`) [VERIFIED: AndroidAudioManager.kt:365-376]. That is fine, because noisy only matters while playing.

### Pattern 2: The state machine and FGS mapping (the heart of the phase)

These states extend ARCHITECTURE.md Pattern 3 with `Interrupted` (resolved in SUMMARY.md) and D-10…D-13. The **audio_service contract** below was verified in `AudioService.java:503-566, 705-723`:
- `!wasPlaying && playing` → `enterPlayingState()`: `startForegroundService` + `startForeground` + PARTIAL wake lock
- `wasPlaying && !playing` → `exitPlayingState()`: if `androidStopForegroundOnPause`, `stopForeground(STOP_FOREGROUND_DETACH)` + release the wake lock
- `processingState` transition non-idle → `idle`: `stop()` = deactivate the session, cancel the notification, `stopSelf()`

| Engine state | `PlaybackState.processingState` | `playing` | FGS + PARTIAL wake lock | Wi-Fi lock | Audio focus | Notification controls |
|---|---|---|---|---|---|---|
| Idle | `idle` | false | **stopped** (service stops) | released | abandoned | none (removed) |
| Connecting(stationIdx, streamIdx, round) | `loading` | **true** | held | held | requested by `play()` | [pause, stop] |
| Playing | `ready` | true | held | held | held | [pause, stop] |
| Buffering | `buffering` | true | held | held | held | [pause, stop] |
| Reconnecting(attempt, nextAt, waitingForNetwork) | `buffering` | **true** | **held** | held | held | [pause, stop] |
| Interrupted (transient focus loss) | `buffering` | **true** | **held** (D-11, Android 17 guidance) | released | held (not abandoned) | [pause, stop] |
| Paused (user / noisy / permanent loss) | `ready` | false | dropped (notification kept, swipeable, D-13) | released | **abandoned** by engine | [play, stop] |
| Error(kind) | `error` + `errorMessage` | false | dropped (notification kept with play, D-10) | released | **abandoned** | [play, stop] |

- `androidCompactActionIndices: [0, 1]`. `systemActions: const {}` (no seek, PLAY-11).
- Leave index slots for `[skipToPrevious, play/pause, skipToNext, stop]` in Phase 3 (D-12).
- Android explicitly recommends keeping the `mediaPlayback` FGS through transient failures under 10 minutes and through `AUDIOFOCUS_LOSS_TRANSIENT`, and stopping it on `AUDIOFOCUS_LOSS`, a user pause or an unrecoverable failure [CITED: developer.android.com/about/versions/17/changes/bg-audio]. The table above follows that guidance exactly.

**Transition rules** (additions and corrections to ARCHITECTURE.md Pattern 3):

- `play(station, context)` from any state: stop the transport, clear now-playing, bump `generation`, then go to Connecting(stream 0, round 0). **Publish `playing:true, loading` first**, so the FGS starts from the user action. Then resolve and load.
- Connecting + `ready && playing` → Playing. Stop the connect timer and record time-to-audio. Reset the backoff after **30 s** of stable Playing.
- Connecting + error or connect timeout (**10 s**) → next stream index in the same round.
  - After the last index: if the station has **never** reached Playing in this session, round++ (max **2 rounds**), then Error(`allStreamsFailed`).
  - Otherwise → Reconnecting.
- Playing + `buffering` → Buffering, and arm the stall watchdog (**8 s**) → Reconnecting(attempt 0, delay 0).
- Playing/Buffering + `completed` or player error → Reconnecting. `completed` on a live stream is a disconnect (Pitfall 2).
- Reconnecting timer fires:
  - online → Connecting. Start at the stream that was last working, then rotate.
  - offline → `waitingForNetwork = true`, pause the backoff clock.
- Connectivity online/changed while Reconnecting or Buffering → retry **now** and reset the backoff.
- Connectivity changed while Playing → arm a **5 s flow check**. If `bufferedPosition` has not advanced by then (just_audio broadcasts `bufferedPosition` every ~500 ms while ready+playing [VERIFIED: AudioPlayer.java:114-137]), reload at once instead of waiting for the buffer to drain.
- Budget (`RetryBudget`) exhausted → Error(`offline` | `streamUnreachable` | `allStreamsFailed`).
- User pause / headset `click()` while `playing:true` / noisy / `AUDIOFOCUS_LOSS` → Paused: stop the transport, release focus, stop timers.
- User stop / notification swipe (`onNotificationDeleted` → `stop()` by default [VERIFIED: BaseAudioHandler]) → Idle.
- Paused/Error/Idle + `play()` (UI, notification, BT) → Connecting at the live edge. This is always a user action.
- **Guards (PLAY-10):**
  - Only two paths may start playback without a user command: `Interrupted`+gain and `Reconnecting`+timer/connectivity.
  - Interruption and noisy events in Paused/Idle/Error are ignored.
  - Every async result (resolve, load, error, ICY) carries the `generation` it was issued for. Stale ones are dropped.
- `onTaskRemoved`: if Paused/Idle/Error → `stop()`. If active → keep playing. The default is a no-op [VERIFIED].

**`RetryBudget` presets** (D-10; the numbers for trip and saver are within Claude's discretion):

| Preset | Online failing budget | Offline budget | Note |
|---|---|---|---|
| `standard` (wired in Phase 1) | 3 min | 10 min | Locked by D-10 |
| `trip` | 5 min | **10 min** (recommended, instead of ~30) | Android 17 guidance: keep the FGS through transient failures "of under 10 minutes". Holding a silent FGS for 30 min is outside that guidance. **Owner confirm** (Assumption A6). |
| `batterySaver` | 1 min | 5 min | as D-10 |

- The budget clock starts at the first failure of an outage.
- Offline time counts only against the offline budget, and online-failing time only against the online budget.
- Both reset after 30 s of stable Playing.

**Backoff:** 0, 1, 2, 4, 8, 15, 30 s (cap), ±20 % jitter, from an injected `Random` (ARCHITECTURE.md Pattern 4).

### Pattern 3: `StreamPlayer` port over just_audio (exact call sequence)

```dart
// engine/just_audio_stream_player.dart — the ONLY just_audio import besides ports' impl.
final _player = AudioPlayer(
  userAgent: userAgent,                    // 'eRadioto/1.0.0 (Android; +https://github.com/<owner>/<repo>)' — no "Mozilla"
  useProxyForRequestHeaders: false,        // UA via ExoPlayer setUserAgent; no 127.0.0.1 proxy
  handleInterruptions: false,              // engine owns focus/noisy events
  handleAudioSessionActivation: true,      // play() still requests focus
  audioLoadConfiguration: const AudioLoadConfiguration(
    androidLoadControl: AndroidLoadControl(
      bufferForPlaybackDuration: Duration(milliseconds: 1000),            // default 2500 — faster start (tune)
      bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 2500), // default 5000 (tune)
    ),
  ),
);

Future<void> load(ResolvedStream s) async {
  await _player.stop();                                   // disposes native ExoPlayer ⇒ fresh ICY state, live edge
  final src = s.kind == StreamKind.hls
      ? HlsAudioSource(s.uri, tag: s.generation)
      : ProgressiveAudioSource(s.uri, tag: s.generation);
  await _player.setAudioSource(src, preload: false);      // no await-on-network here
  unawaited(_player.play());                              // NEVER await: completes only on pause/stop/complete
}
```

- **Errors:** listen to `errorStream` (`PlayerException(code, message, index)`, derived from `PlaybackEvent.errorCode`). `playbackEventStream` no longer carries errors since 0.10.0 ("Replace playbackEventStream.onError by errorStream") [VERIFIED: CHANGELOG + just_audio.dart:343-352]. On a native error, just_audio switches to `idle` and deactivates the platform itself (just_audio.dart:1594-1598). `PlayerInterruptedException` from superseded loads must be caught and ignored.
- **State:** `playerStateStream` (`playing` + `ProcessingState {idle, loading, buffering, ready, completed}`) and `bufferedPositionStream`.
- **ICY:** `icyMetadataStream` → `IcyMetadata{info: IcyInfo{title, url}, headers: IcyHeaders{bitrate, genre, name, metadataInterval, url, isPublic}}`. `title` is an **already-decoded Java String** [VERIFIED: just_audio.dart:2050-2141; AudioPlayer.java:902-920].
- `stop()` → `_setPlatformActive(false)`, which **disposes the native player** when switching to the idle platform ("if (oldPlatform != null && oldPlatform is! _IdleAudioPlayer) await _disposePlatform(oldPlatform)") [VERIFIED: just_audio.dart:1629]. The native `icyInfo`/`icyHeaders` fields are **never reset on load** (the only assignments are at AudioPlayer.java:249 and 267) [VERIFIED]. So stop-before-load is the stale-title fix (just_audio #871). Also drop ICY events whose generation is not the current one, or that arrive before the first `ready`.
- The UA goes to ExoPlayer natively: `DefaultHttpDataSource.Factory().setUserAgent(userAgent).setAllowCrossProtocolRedirects(true)` [VERIFIED: AudioPlayer.java:743-745].

### Pattern 4: `StreamResolver` with hard input limits

- Input: `StationStream{url, kind: progressive|hls|pls|m3u|unknown, icyCharset: auto|utf8|cp1251}`.
- The catalogue `kind` wins, so curated entries skip sniffing.
- For `pls`/`m3u`/`unknown`: `http.Request('GET', uri)..followRedirects = true..maxRedirects = 5` [VERIFIED: http-1.6.0 BaseRequest fields]. Enforce:
  - 5 s timeout
  - read at most **64 KB**, then cancel the subscription
  - if `Content-Type` starts with `audio/` (except the `mpegurl` types) → progressive (stop reading: it is a live stream)
- Parsing is tolerant: strip the BOM, handle CRLF, case-insensitive `FileN=`, skip `#` lines in M3U, resolve relative URLs with `Uri.resolve`.
- `#EXTM3U` + any `#EXT-X-` tag → **HLS on the original URL**. Content-Type alone is not decisive: `audio/x-mpegurl` is used for plain M3U too.
- Candidates are kept in order (they are fallbacks). Nesting depth ≤ 3. Max 10 candidates.
- **Scheme allow-list:** `http`, `https` only.
- Cache resolved results in memory for 1 h per URL, and invalidate on playback error. (This settles SUMMARY.md's TTL gap for Phase 1. A persisted snapshot comes in Phase 3.)
- Never probe the audio stream itself from Dart: `dart:io` rejects `ICY 200 OK` (Pitfall 7).

### Pattern 5: Now-playing pipeline

`IcyInfo.title` → `sanitize` (strip C0/C1 controls and bidi overrides U+202A–202E, U+2066–2069; collapse whitespace; clamp to 200 chars) → `repairCp1251(hint: station.icyCharset)` → drop junk (empty, `-`, equals the station name, URL-like) → split on the first `" - "` into artist/title → `distinct`.

Emit a new `MediaItem` only on change. The `MediaItem` has `title = station name`, `artist`/`displaySubtitle = ICY text`, and `isLive: true` (the field exists [VERIFIED: MediaItem fields]).

Clear now-playing on every `play()`/load and on Paused/Idle/Error.

### Pattern 6: Media-ID scheme and `PlayContext` (shape now, use in Phase 3/v1.1)

- Media IDs: `station/curated:<id>`, `station/debug:<id>`, `node/recents`, `node/favourites`, `node/bg/national`, `node/bg/city/<id>`, `node/bg/genre/<id>`. There is a pure `MediaId.parse/format` with round-trip tests.
- `sealed class PlayContext { single(); list(List<StationId> ids, {String source}); }`.
- `skipToNext/Previous` wrap within the list. Implement and unit-test them now. **Do not** show them in the notification in Phase 1 (D-12).
- The UI calls `engine.play(station, context:)`, which routes through the handler's `playFromMediaId` path (ARCHITECTURE.md "one code path").

### Anti-Patterns to Avoid (phase-specific additions)
- **`await player.play()` in engine code.** It only completes on pause/stop/complete [VERIFIED: doc comment just_audio.dart:1065-1080], so the command loop would deadlock.
- **`await player.setAudioSource(src)` with the default `preload: true` as the connect signal.** It can hang until ExoPlayer gives up. Use `preload: false` + `play()` + our own 10 s connect timer.
- **Reporting `playing: false` for Reconnecting or Interrupted.** audio_service would `stopForeground` immediately [VERIFIED], and Android 12+ may then refuse the restart.
- **Holding focus while paused.** It keeps the noisy receiver alive and invites spurious `gain` events. Call `session.setActive(false)`.
- **Debug stations referenced from release code paths.** Guard with `if (!kReleaseMode)` (a const bool, tree-shaken by AOT) and verify in CI (below).

## Station Stream Matrix (D-01..D-05)

**Provenance caveat.** Every station website, Radio Browser and the stream-directory sites were blocked by the egress proxy, both for `curl` and for WebFetch. The URLs below come **only from web-search index snippets** of the stations' own pages and of forums or directories that quote them. **Every URL is UNVERIFIED** [ASSUMED] until the owner runs the D-02 protocol. The `dist=WEBSITEBG` query tag appears on the stations' own website URLs, so it is the station's own distribution tag, not a third-party aggregator tag. `dist=RADIOPLAY` belongs to radioplay.bg, which appears to be the same group's own player site.

| Station (StationId) | # | URL | Format / bitrate | Scheme | Wrapper | Source of the URL | Status |
|---|---|---|---|---|---|---|---|
| **Radio 1** `curated:radio1` | 0 | `https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_1AAC_L.aac?dist=WEBSITEBG` | AAC (likely HE-AAC), 302 redirect to a Triton edge | https | none | radio1.bg streams list, via search snippet | UNVERIFIED |
| | 1 | `http://play.global.audio/radio1128?dist=WEBSITEBG` | MP3 128 | http | none | radio1.bg, via search snippet | UNVERIFIED |
| | 2 | `http://play.global.audio/radio164?dist=WEBSITEBG` | MP3 64 | http | none | radio1.bg, via search snippet | UNVERIFIED |
| **BG Radio** `curated:bg-radio` | 0 | `http://play.global.audio/bgradio128` | MP3 128 (`audio/mpeg`) | http | none | bgradio.bg/live-stream, via search snippet | UNVERIFIED |
| | 1 | `https://playerservices.streamtheworld.com/api/livestream-redirect/BG_RADIOAAC_L.aac?dist=WEBSITEBG` | AAC, 302 | https | none | bgradio.bg/live-stream, via search snippet | UNVERIFIED |
| | 2 | `http://play.global.audio/bgradio.aac` | AAC | http | none | bgradio.bg/live-stream, via search snippet | UNVERIFIED |
| **Energy** `curated:energy` | 0 | `https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ENERGYAAC_L.aac?dist=WEBSITEBG` | AAC, 302 | https | none | radioenergy.bg, via search snippet | UNVERIFIED |
| | 1 | `http://play.global.audio/nrj128` | MP3 128 | http | none | forum/directory snippet | UNVERIFIED |
| | 2 | `http://play.global.audio/nrj64?dist=WEBSITEBG` | MP3 64 | http | none | radioenergy.bg, via search snippet | UNVERIFIED |
| **N-JOY** `curated:njoy` | 0 | `http://live.btvradio.bg/njoy.mp3.m3u` | **M3U wrapper** → MP3 (Icecast-generated) | http | **m3u** | indexed URL on live.btvradio.bg (bTV Radio Group Icecast2) | UNVERIFIED |
| | 1 | `http://live.btvradio.bg/njoy.mp3` | MP3 | http | none | bTV Radio Group stream list, via search snippet | UNVERIFIED |
| **Радио Витоша** `curated:vitosha` | — | **not found** | a directory reports "AAC ~105 kbps" | ? | ? | none of the accessible sources quote an official URL | **OWNER MUST CAPTURE** from radiovitosha.com's player |
| **БНР Хоризонт** `curated:bnr-horizont` | 0 | `https://lb-hls.cdn.bg/2032/fls/Horizont.stream/playlist.m3u8` | **HLS**, 302 from the load balancer to `e1xx-ts.cdn.bg/...playlist.m3u8` | https | none | forum report of the bnr.bg player; PITFALLS measured the 302 [MEASURED 2026-09-24] | UNVERIFIED |
| | 1 | `http://stream.bnr.bg:8011/horizont.aac` | AAC / HE-AAC (directories: 36–64 kbps AAC+) | http | none | forum snippets (Feb 2025, Jan 2026); bnr.bg live page says it lists "128 kbit or 64 kbit" addresses | UNVERIFIED; port 8011 failed from the research location (Pitfall 20) |
| | 2 | `http://stream.bnr.bg:8011/horizont.mp3` (name assumed) | MP3 128 | http | none | **name guessed from the pattern**; copy the real one from bnr.bg/horizont/page/live | ASSUMED |
| **debug:dead-primary** (debug/profile only, D-05) | 0 | `https://dead-primary.invalid/stream.mp3` | — (NXDOMAIN, fast failure) | https | none | RFC 6761 reserved `.invalid` TLD | by design |
| | 1 | same as Radio 1 #1 | MP3 | http | none | — | — |
| **debug:slow-primary** (optional, debug only) | 0 | `http://192.0.2.1/stream.mp3` | — (TEST-NET-1, packets black-holed → connect-timeout path) | http | none | RFC 5737 documentation range | by design |
| | 1 | same as BG Radio #0 | MP3 | http | none | — | — |

**D-03 coverage matrix**

| Required format | Covered by | Status |
|---|---|---|
| MP3 | Radio 1 #1/#2, BG Radio #0, Energy #1/#2, N-JOY #1 | ✓ (pending D-02) |
| AAC / HE-AAC | StreamTheWorld `.aac` (Radio 1 #0, BG Radio #1, Energy #0), BG Radio #2, Хоризонт #1 | ✓ (pending D-02). Whether HE-AAC (SBR) vs LC is confirmed by `ffprobe`. |
| HLS | Хоризонт #0 | ✓ (pending D-02) |
| **HLS behind a non-`.m3u8` URL** | **none of the 6 stations publishes one** | **FLAG to owner.** Proposed coverage: (a) resolver unit tests with `MockClient` serving `#EXTM3U`/`#EXT-X-` from an extension-less URL; (b) on device, a debug-only entry "Хоризонт (HLS sniff)" with `kind: unknown`, which forces the resolver's content sniff to pick `HlsAudioSource` from the body, not from the URL. Owner decides whether that is acceptable or whether another official source should be sought. |
| `.pls` or `.m3u` wrapper | N-JOY #0 (`njoy.mp3.m3u`) | ✓ (pending D-02). Global Audio's Icecast probably also serves `/<mount>.m3u` (`bgradio128.xspf` is indexed) [ASSUMED]. |
| plain `http://` | N-JOY, play.global.audio, stream.bnr.bg | ✓ |
| windows-1251 ICY title | **unknown**: depends on each station's encoder | **FLAG to owner.** Run the byte probe below on every progressive URL. If none sends cp1251, SC1's "windows-1251 station" cannot be demonstrated with these 6. Coverage then comes from golden unit tests, and the owner decides. |
| Bonus: 302 redirect https→https/http | StreamTheWorld `livestream-redirect`, cdn.bg load balancer | ✓ (exercises `setAllowCrossProtocolRedirects(true)`) |

**Recommended order:**
- Keep the verified-working, most robust stream first.
- Хоризонт: HLS first. It is measured reachable, while port 8011 is blocked on some networks.
- N-JOY: the `.m3u` first, so STRM-03 runs on every N-JOY play, with the direct MP3 as fallback.
- Stations with HTTPS StreamTheWorld AAC: AAC first, to minimise cleartext.

**Phase 2 note:** the catalogue validator's "reject `dist=` URLs" rule (Pitfall 9) must allow the station group's own `dist=WEBSITEBG` on its own hosts. Otherwise it will reject these official URLs. See Open Question 3.

### Owner verification protocol for D-02 (run on the owner's Mac; nothing to install except ffmpeg)

1. **Official-source check (per station):** open the station's website player in Chrome → DevTools → Network → filter "media" (or look for `.mp3`/`.aac`/`.m3u8`/`livestream-redirect`) → press play → copy the request URL. For БНР, copy the addresses listed on `bnr.bg/horizont/page/live`. Record `source` (page URL) and `verifiedAt` (date) for every stream. **Радио Витоша must be captured this way.**
2. **Reachability + headers:** `curl -s -D - -o /dev/null --max-time 6 -A 'eRadioto/0.1 (Android)' '<URL>'`. Exit code 28 (timeout) is **expected** for live streams. Read the printed headers: status, `content-type`, `icy-metaint`, `icy-br`, `location` for redirects. For playlists: `curl -sL --max-time 6 '<URL>' | head -20`.
3. **Codec / bitrate:** `ffprobe -hide_banner -i '<URL>' 2>&1 | grep -E 'Stream|Duration|icy|bitrate'` (`brew install ffmpeg`). This shows `aac (HE-AAC)` vs `aac (LC)` vs `mp3`.
4. **ICY charset probe (for the cp1251 flag):**
   ```bash
   curl -s -H 'Icy-MetaData: 1' --max-time 25 '<URL>' | LC_ALL=C grep -a -o "StreamTitle='[^;]*';" | head -1 | tee /tmp/t.bin | xxd | head -5
   iconv -f WINDOWS-1251 -t UTF-8 /tmp/t.bin ; echo ; iconv -f UTF-8 -t UTF-8 /tmp/t.bin && echo "(valid UTF-8)"
   ```
   How to read the result:
   - Cyrillic in **UTF-8** shows as byte pairs `d0 xx` / `d1 xx`.
   - Cyrillic in **cp1251** shows as single bytes `c0`–`ff`, and iconv from WINDOWS-1251 prints readable text.
   - If `icy-metaint` is absent, the stream has no ICY.
   Wait for a song with a Cyrillic title (БГ Радио plays Bulgarian music only, so it is the best candidate).
5. **Play test:** open each URL in VLC for about 30 s.
6. Fill in the station table with the results (status → VERIFIED/REJECTED, codec, charset). Mark a stream's `icyCharset: cp1251` only when the probe proves it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Foreground service, notification, MediaSession, media buttons | Own Kotlin service | audio_service `AudioService` + `MediaButtonReceiver` | Already handles Android 13 media buttons and FGS types. Our job is only to publish correct `PlaybackState`. |
| Focus + becoming-noisy plumbing | Own AudioManager channel | audio_session `interruptionEventStream`/`becomingNoisyEventStream` | Verified mapping above. |
| Network-change detection | Polling / own NetworkCallback | connectivity_plus `onConnectivityChanged` | Uses `registerDefaultNetworkCallback` on API 24+ [VERIFIED]. |
| HTTP redirects, timeouts | Raw sockets | `package:http` `Request.followRedirects/maxRedirects` | |
| Virtual time in tests | Real `Future.delayed` sleeps | `fake_async` + `clock` | Deterministic backoff/watchdog tests. |
| Sealed unions / copyWith | Handwritten `==`/`hashCode` | freezed 4 `sealed class` | Verified with `switch` exhaustiveness in probe. |
| Wi-Fi lock | A third-party pub plugin of unknown provenance | ~30 lines of Kotlin in `MainActivity` using `WifiManager.createWifiLock(WIFI_MODE_FULL_HIGH_PERF, tag)` + `setReferenceCounted(false)` (the same call Media3's own `WifiLockManager` makes [VERIFIED: androidx/media 1.4.1 & 1.8.0 WifiLockManager.java]) | Tiny, and no dependency risk. |
| cp1251 decoding | A charset package | In-repo 128-entry table (below) | MPL/stale packages. The table is authoritative (generated from Python's `cp1251` codec in this session). |

**Key insight:** in this phase the hard part is **ordering and ownership**: who stops the FGS, who owns focus, and which async result is stale. It is not decoding or networking. Every native piece already exists. Custom code should be the pure state machine and small parsers, all unit-tested.

## Common Pitfalls (new or sharpened for Phase 1; see PITFALLS.md 1–7, 13, 14 for the rest)

### Pitfall A: No `INTERNET` permission in release builds
**What goes wrong:** Everything plays in `flutter run` (debug) and nothing plays in release.
**Why:** The Flutter 3.47.5 template puts `<uses-permission android:name="android.permission.INTERNET"/>` only in `src/debug` and `src/profile` manifests. The main manifest has none [VERIFIED: probe `android/app/src/main/AndroidManifest.xml`]. just_audio and audio_service manifests are empty `<manifest/>` [VERIFIED]. connectivity_plus adds only `ACCESS_NETWORK_STATE`.
**Avoid:** Add `INTERNET` to `src/main/AndroidManifest.xml` in the skeleton plan. Add a CI check that greps the merged release manifest (`build/app/intermediates/merged_manifests/release/...`) for `INTERNET`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `mediaPlayback`.

### Pitfall B: `flutter analyze` silently skips riverpod_lint
**What goes wrong:** CI is green while `missing_provider_scope` and other Riverpod lints are violated.
**Evidence:** In the probe, removing `ProviderScope` gave `flutter analyze` → "No issues found!" (exit 0), `dart analyze` → `warning - lib/main.dart:6:16 - ... - missing_provider_scope` (exit 2) [VERIFIED].
**Avoid:** CI runs `flutter analyze` **and** `dart analyze`. The first `dart analyze` builds the plugin (it needs pub.dev access).

### Pitfall C: `synthetic-package` in `l10n.yaml`
**What goes wrong:** `synthetic-package: false` prints "The argument "synthetic-package" no longer has any effect and should be removed". `true` is a hard `throwToolExit` [VERIFIED: flutter_tools localizations_utils.dart:490-503].
**Avoid:** Omit the key. Output already goes into `lib/l10n/` when `arb-dir: lib/l10n` and no `output-dir` is set. `flutter: generate: true` in `pubspec.yaml` is still **required**. Without it, `flutter gen-l10n` warns "Attempted to generate localizations code without having the flutter: generate flag turned on" [VERIFIED]. `flutter pub get` regenerates the l10n files [VERIFIED]. This honours D-08's intent; the literal key would only add a warning.

### Pitfall D: Awaiting just_audio futures in the engine loop
`play()` completes only on pause/stop/complete. `setAudioSource(preload: true)` may hang until ExoPlayer errors. See Pattern 3.

### Pitfall E: Stale ICY title after switching station
Native ICY fields persist across `load` on the same ExoPlayer [VERIFIED]. Fix: `stop()` before load (disposes the native player), plus a generation guard, plus clear on switch.

### Pitfall F: Focus never released
just_audio never abandons focus [VERIFIED]. If the engine doesn't call `setActive(false)` on pause/stop/error, the app keeps focus. Other apps then see a "focus holder", the noisy receiver stays registered, and spurious `gain` events can arrive.

### Pitfall G: FGS restart from background after a user pause
**What goes wrong:** Resume from the lock screen or BT after a pause needs a new FGS start plus a focus request. On Android 15+ (target 35+), focus requests fail unless the app is the top app or running an FGS [CITED: audio-focus doc]. The official FGS background-start exemption list mentions notification interaction but **not media buttons** [CITED: fgs/restrictions-bg-start].
**Avoid:** In `play()`, publish `playing: true` (which starts the FGS in audio_service) **before** `player.play()` requests focus. **Verify on device:** resume from the lock screen and from the car BT after a 5-min pause on Android 15/16 (and 17 if available). Watch logcat for `ForegroundServiceStartNotAllowedException` / `AUDIOFOCUS_REQUEST_FAILED`. Media-button delivery is believed to carry a temporary FGS-start allowance [ASSUMED].

### Pitfall H: VoIP calls that take permanent focus
WhatsApp or Viber calls may request `AUDIOFOCUS_GAIN` (permanent) instead of transient. Per Android guidance that means Paused with no auto-resume, which contradicts the owner's D-11 expectation for "calls" [ASSUMED behaviour of those apps]. Add a WhatsApp/Viber call to the device matrix. If they take permanent focus, record it as a known limitation. Do **not** auto-resume after `AUDIOFOCUS_LOSS` (Google: "won't ever receive an AUDIOFOCUS_GAIN").

### Pitfall I: Debug station leaking into release
Keep `debug_stations.dart` referenced only inside `if (!kReleaseMode)`. The CI release job asserts `unzip -p app-release.apk 'lib/arm64-v8a/libapp.so' | strings | grep -c 'dead-primary.invalid'` equals `0`. The AOT snapshot keeps string literals, so `strings` finds them if they are present [ASSUMED; the check itself is the verification].

### Pitfall J: `WIFI_MODE_FULL_HIGH_PERF` is deprecated in API 34
It is listed under "Deprecated Fields" in the API 34 diff [CITED: developer.android.com/sdk/api_diff/34/changes/android.net.wifi.WifiManager]. Media3 still uses it through 1.8.0 [VERIFIED]. Use it with `@Suppress("DEPRECATION")`. `WIFI_MODE_FULL_LOW_LATENCY` only acts while the app is in the foreground with the screen on [ASSUMED], so it is useless screen-off. Verify with `adb shell dumpsys wifi | grep -i -A3 "wifilock"` that the lock is held while playing and released on pause/stop. Whether it has a real effect on Android 14+ is an owner observation (stutter on Wi-Fi with the screen off).

## Code Examples

### Manifest (merge into `android/app/src/main/AndroidManifest.xml`)
```xml
<!-- Source: audio_service 0.18.19 README "Android setup" + Pitfall A -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          xmlns:tools="http://schemas.android.com/tools">
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.WAKE_LOCK"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
  <!-- NO POST_NOTIFICATIONS: media-session notifications are exempt (APP-07) -->
  <application android:label="eRadioto" android:name="${applicationName}" android:icon="@mipmap/ic_launcher"
               android:networkSecurityConfig="@xml/network_security_config">
    <activity android:name=".MainActivity" ...template attributes unchanged... />
    <service android:name="com.ryanheise.audioservice.AudioService"
             android:foregroundServiceType="mediaPlayback"
             android:exported="true" tools:ignore="Instantiatable">
      <intent-filter><action android:name="android.media.browse.MediaBrowserService"/></intent-filter>
    </service>
    <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
              android:exported="true" tools:ignore="Instantiatable">
      <intent-filter><action android:name="android.intent.action.MEDIA_BUTTON"/></intent-filter>
    </receiver>
  </application>
</manifest>
```

### `res/xml/network_security_config.xml` (STRM-04)
```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Cleartext is permitted app-wide for NATIVE sockets because live-radio streams are often http://
     on arbitrary hosts. Only ExoPlayer (media) uses native sockets in this app. Dart sockets
     (package:http) ignore this file; app-owned traffic is forced to HTTPS by AppHttpClient. -->
<network-security-config>
  <base-config cleartextTrafficPermitted="true">
    <trust-anchors><certificates src="system"/></trust-anchors>
  </base-config>
</network-security-config>
```
The Dart-side guard: `AppHttpClient extends http.BaseClient`, `send()` throws `ArgumentError` for `request.url.scheme != 'https'`, with a unit test. `StreamResolver` uses a separate `MediaHttpClient` that allows `http` + `https` only.

### `MainActivity.kt` (activity base + Wi-Fi lock channel)
```kotlin
// Source: audio_service README "Custom Android activity"; lock call mirrors Media3 WifiLockManager
package bg.izk.radio

import android.content.Context
import android.net.wifi.WifiManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WifiLockChannel.register(flutterEngine, applicationContext)
    }
}

object WifiLockChannel {
    private var lock: WifiManager.WifiLock? = null
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "bg.izk.radio/wifi_lock")
            .setMethodCallHandler { call, result ->
                val wm = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
                when (call.method) {
                    "acquire" -> {
                        @Suppress("DEPRECATION")
                        val l = lock ?: wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "eRadioto:stream")
                            .also { it.setReferenceCounted(false); lock = it }
                        if (!l.isHeld) l.acquire()
                        result.success(true)
                    }
                    "release" -> { lock?.let { if (it.isHeld) it.release() }; result.success(true) }
                    "isHeld" -> result.success(lock?.isHeld == true)
                    else -> result.notImplemented()
                }
            }
    }
}
```
The engine is cached by audio_service (`AudioServicePlugin.getFlutterEngine`) and outlives the activity, so the handler stays registered after the activity is destroyed. It uses `applicationContext`, so nothing leaks. **Gap:** if the Dart engine is ever started by the service with no activity (Android Auto or media resumption after process death, v1.1), this channel is not registered. The Dart port must treat `MissingPluginException` as a no-op. Move it to an in-repo plugin package in v1.1.

### Gradle signing (`android/app/build.gradle.kts`, AGP 9 with `android.newDsl=false` from the template)
```kotlin
// Source: docs.flutter.dev/deployment/android (flutter/website sites/docs/src/content/deployment/android.md)
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")   // android/key.properties (gitignored)
if (keystorePropertiesFile.exists()) keystoreProperties.load(FileInputStream(keystorePropertiesFile))

android {
    namespace = "bg.izk.radio"
    compileSdk = 36
    defaultConfig { applicationId = "bg.izk.radio"; minSdk = 24; targetSdk = 36; /* versionCode/Name from flutter */ }
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }
    buildTypes {
        release {
            // Local dev without key.properties falls back to debug signing so `flutter run --release` works.
            // CI release job verifies the certificate is NOT the debug cert (see release.yml).
            signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release")
                            else signingConfigs.getByName("debug")
        }
    }
}
```
- The Flutter 3.47.5 template values are `compileSdkVersion = 36`, `minSdkVersion = 24`, `targetSdkVersion = 36`, `ndkVersion = "28.2.13676358"` [VERIFIED: flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:23,26,34,42]. Writing them out explicitly follows Pitfall 11.
- R8: "Code shrinking is always enabled in release builds" [CITED: Flutter Android deployment doc]. Media3 AARs ship consumer rules. audio_service keeps its drawables by default [CITED: audio_service README]. No extra keep rules are known to be required [ASSUMED]. The release-build device test is the proof.
- Do **not** throw in Gradle when `key.properties` is missing. The `release` block is evaluated for every variant, so a throw would break debug/PR builds.

### `AudioService.init` in bootstrap
```dart
// Source: audio_service 0.18.19 AudioServiceConfig fields (verified)
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration.music());   // usage media, contentType music, gain
final handler = await AudioService.init(
  builder: () => RadioAudioHandler(/* ports + stations + EngineStrings.forLocale(PlatformDispatcher.instance.locale) */),
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'bg.izk.radio.playback',   // permanent once shipped
    androidNotificationChannelName: 'Playback',             // localise from PlatformDispatcher locale at init
    androidNotificationIcon: 'drawable/ic_stat_radio',      // monochrome vector; default mipmap renders as a blob
    androidNotificationOngoing: false,                      // swipeable when paused (D-13)
    androidStopForegroundOnPause: true,                     // D-13 (default true)
    androidResumeOnClick: true,                             // BT/headset PLAY after pause resumes (user action)
  ),
);
```
Build the container with `ProviderContainer(overrides: [...], retry: (_, __) => null)`. That disables Riverpod 3's automatic provider retry, so reconnect logic lives only in the engine. The `Retry` typedef is `Duration? Function(int retryCount, Object error)` [VERIFIED: riverpod-3.4.3 provider_container.dart:287, 892-903]. Hand the container to `UncontrolledProviderScope`.

### cp1251 repair (in-repo, table generated from Python's `cp1251` codec this session)
```dart
// core/text/cp1251.dart
const _cp1251High = <int>[ // bytes 0x80..0xFF → Unicode; 0x98 undefined → U+FFFD
  0x0402,0x0403,0x201A,0x0453,0x201E,0x2026,0x2020,0x2021, 0x20AC,0x2030,0x0409,0x2039,0x040A,0x040C,0x040B,0x040F,
  0x0452,0x2018,0x2019,0x201C,0x201D,0x2022,0x2013,0x2014, 0xFFFD,0x2122,0x0459,0x203A,0x045A,0x045C,0x045B,0x045F,
  0x00A0,0x040E,0x045E,0x0408,0x00A4,0x0490,0x00A6,0x00A7, 0x0401,0x00A9,0x0404,0x00AB,0x00AC,0x00AD,0x00AE,0x0407,
  0x00B0,0x00B1,0x0406,0x0456,0x0491,0x00B5,0x00B6,0x00B7, 0x0451,0x2116,0x0454,0x00BB,0x0458,0x0405,0x0455,0x0457,
  0x0410,0x0411,0x0412,0x0413,0x0414,0x0415,0x0416,0x0417, 0x0418,0x0419,0x041A,0x041B,0x041C,0x041D,0x041E,0x041F,
  0x0420,0x0421,0x0422,0x0423,0x0424,0x0425,0x0426,0x0427, 0x0428,0x0429,0x042A,0x042B,0x042C,0x042D,0x042E,0x042F,
  0x0430,0x0431,0x0432,0x0433,0x0434,0x0435,0x0436,0x0437, 0x0438,0x0439,0x043A,0x043B,0x043C,0x043D,0x043E,0x043F,
  0x0440,0x0441,0x0442,0x0443,0x0444,0x0445,0x0446,0x0447, 0x0448,0x0449,0x044A,0x044B,0x044C,0x044D,0x044E,0x044F,
];
// cp1252 chars that an Icecast "latin1→utf8" double-encode may produce for bytes 0x80..0x9F.
const _cp1252Reverse = <int, int>{0x20AC:0x80,0x201A:0x82,0x0192:0x83,0x201E:0x84,0x2026:0x85,0x2020:0x86,0x2021:0x87,
  0x02C6:0x88,0x2030:0x89,0x0160:0x8A,0x2039:0x8B,0x0152:0x8C,0x017D:0x8E,0x2018:0x91,0x2019:0x92,0x201C:0x93,
  0x201D:0x94,0x2022:0x95,0x2013:0x96,0x2014:0x97,0x02DC:0x98,0x2122:0x99,0x0161:0x9A,0x203A:0x9B,0x0153:0x9C,
  0x017E:0x9E,0x0178:0x9F};

enum IcyCharset { auto, utf8, cp1251 }

String repairCp1251(String s, {IcyCharset hint = IcyCharset.auto}) {
  if (hint == IcyCharset.utf8 || s.isEmpty) return s;
  if (s.runes.any((r) => r >= 0x0400 && r <= 0x04FF)) return s;           // already real Cyrillic
  final bytes = <int>[];
  for (final r in s.runes) {
    if (r < 0x100) { bytes.add(r); }
    else if (_cp1252Reverse[r] case final b?) { bytes.add(b); }
    else { return s; }                                                     // not a byte-string ⇒ genuine Unicode
  }
  bool isCyrLetter(int b) => b >= 0xC0 || b == 0xA8 || b == 0xB8;
  final high = bytes.where(isCyrLetter).length;
  if (hint == IcyCharset.auto) {
    if (high < 2) return s;                                                // "Björk"
    final letters = bytes.where((b) => (b | 0x20) >= 0x61 && (b | 0x20) <= 0x7A || isCyrLetter(b)).length;
    var run = 0, maxRun = 0;
    for (final b in bytes) { run = isCyrLetter(b) ? run + 1 : 0; if (run > maxRun) maxRun = run; }
    if (maxRun < 3 && high / letters < 0.4) return s;                     // "Mötley Crüe", "Sigur Rós"
  }
  return String.fromCharCodes(bytes.map((b) => b < 0x80 ? b : _cp1251High[b - 0x80]));
}
// Golden: 'Àðòèñò - Ïåñåí' → 'Артист - Песен'; 'Mötley Crüe' unchanged; 'Beyoncé' unchanged; 'Björk' unchanged.
```
Basis: Media3 `IcyDecoder` "try decoding UTF-8 first, then fall back to ISO-8859-1" [VERIFIED: androidx/media 1.4.1 IcyDecoder.java]. cp1251 bytes are almost never valid UTF-8, so they arrive as U+0080–U+00FF chars and map 1:1 back to bytes. Python confirmed that `'Àðòèñò - Ïåñåí'.encode('latin-1').decode('cp1251') == 'Артист - Песен'`.

### First-launch date (APP-06)
```dart
// SharedPreferencesAsync API verified in shared_preferences 2.5.5; tests use
// SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()
// (package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart — add as dev dep).
Future<DateTime> ensureFirstLaunchAt(SharedPreferencesAsync prefs, Clock clock) async {
  const key = 'first_launch_at';
  final existing = await prefs.getString(key);
  if (existing != null) return DateTime.parse(existing);
  final now = clock.now().toUtc();
  await prefs.setString(key, now.toIso8601String());
  return now;
}
```

### `l10n.yaml` + analysis options (verified working on 3.47.5)
```yaml
# l10n.yaml   (no synthetic-package key — see Pitfall C)
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  exclude: [build/**, android/**, "**/*.g.dart", "**/*.freezed.dart"]
plugins:
  riverpod_lint: ^3.1.9
```
Add `flutter:\n  generate: true` to `pubspec.yaml`. Import with `import 'package:radio/l10n/app_localizations.dart';`. For locale resolution, use `localeResolutionCallback`: `bg` → bg, anything else → en.

### CI (`.github/workflows/ci.yml`: PRs and main; no secrets)
```yaml
name: ci
on: { pull_request: {}, push: { branches: [main] } }
permissions: { contents: read }
jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: subosito/flutter-action@v2.23.0
        with: { channel: stable, flutter-version: 3.47.5, cache: true }
      - run: flutter pub get                       # also regenerates lib/l10n (generate: true)
      - run: dart run build_runner build -d
      - run: git diff --exit-code                  # D-17 stale generated code (incl. l10n)
      - run: flutter analyze
      - run: dart analyze                          # surfaces riverpod_lint (Pitfall B)
      - run: flutter test
      - name: No tracking SDKs (PLAT-06)
        run: "! grep -E '^  (firebase_|google_mobile_ads|sentry|appsflyer|amplitude|mixpanel|facebook_)' pubspec.lock"
      - name: Engine import boundary
        run: "! grep -rlE \"package:(just_audio|audio_service|audio_session|connectivity_plus)/\" lib | grep -v '^lib/features/playback/engine/' | grep -v '^lib/app/bootstrap.dart'"
  # Optional (Claude's discretion): debug APK artifact on PRs needs setup-java@v6.0.1 (temurin 17) + flutter build apk --debug.
```

### Release (`.github/workflows/release.yml`: tags + manual only)
```yaml
name: release
on: { push: { tags: ['v*'] }, workflow_dispatch: {} }
permissions: { contents: read }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: actions/setup-java@v6.0.1
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2.23.0
        with: { channel: stable, flutter-version: 3.47.5, cache: true }
      - name: Decode upload keystore
        env:
          KS_B64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KS_PASS: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_PASS: ${{ secrets.ANDROID_KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
        run: |
          echo "$KS_B64" | base64 -d > "$RUNNER_TEMP/upload.jks"
          printf 'storeFile=%s\nstorePassword=%s\nkeyPassword=%s\nkeyAlias=%s\n' \
            "$RUNNER_TEMP/upload.jks" "$KS_PASS" "$KEY_PASS" "$KEY_ALIAS" > android/key.properties
      - run: flutter pub get
      - run: flutter build appbundle --release --build-number=${{ github.run_number }}
      - run: flutter build apk --release --build-number=${{ github.run_number }}
      - name: Verify not debug-signed + no debug stations
        run: |
          keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk | tee /tmp/cert.txt
          ! grep -q "CN=Android Debug" /tmp/cert.txt
          test "$(unzip -p build/app/outputs/flutter-apk/app-release.apk lib/arm64-v8a/libapp.so | strings | grep -c 'dead-primary.invalid')" = "0"
      - uses: actions/upload-artifact@v7.0.1
        with: { name: eradioto-${{ github.ref_name }}, path: "build/app/outputs/bundle/release/app-release.aab\nbuild/app/outputs/flutter-apk/app-release.apk", if-no-files-found: error }
      - if: always()
        run: rm -f "$RUNNER_TEMP/upload.jks" android/key.properties
```
The action tags and inputs were verified on raw.githubusercontent:
- `actions/checkout@v7.0.1` (node24)
- `actions/setup-java@v6.0.1` (`distribution`, `java-version`)
- `actions/upload-artifact@v7.0.1` (`name`, `path`, `if-no-files-found`)
- `subosito/flutter-action@v2.23.0` (`channel`, `flutter-version`, `cache`, from `action.yaml`)

The Flutter template's `android/.gitignore` excludes `gradlew` and `gradle-wrapper.jar` [VERIFIED]. The Flutter tool re-injects the wrapper at build time [ASSUMED]. Confirm on the first CI release run.

### Keystore creation (D-14 human checkpoint; owner's Mac, JDK 17 `keytool`)
```bash
keytool -genkeypair -v -keystore ~/eradioto-upload.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
#   PKCS12: key password = store password (keytool uses the store password for the key).
# Back up ~/eradioto-upload.jks + passwords to a password manager / offline storage (NOT the repo).
base64 -i ~/eradioto-upload.jks | tr -d '\n' > ~/eradioto-upload.b64
gh secret set ANDROID_KEYSTORE_BASE64 < ~/eradioto-upload.b64
gh secret set ANDROID_KEYSTORE_PASSWORD    # prompts; paste
gh secret set ANDROID_KEY_PASSWORD         # same as store password for PKCS12
gh secret set ANDROID_KEY_ALIAS --body upload
rm ~/eradioto-upload.b64
# Local release builds: create android/key.properties (gitignored) with storeFile=/Users/<you>/eradioto-upload.jks
```
Also enable **GitHub secret scanning + push protection** in the repo settings (free for public repos) [ASSUMED availability for the owner's account].

The existing `.gitignore` already blocks the D-14 patterns [VERIFIED: .gitignore:112-115, 120, 128 → `key.properties`, `**/android/key.properties`, `*.jks`, `*.keystore`, `*.p12`, `secrets/`]. Add `*.b64` defensively. The template's `android/.gitignore` also ignores `key.properties`, `**/*.keystore` and `**/*.jks` [VERIFIED: probe].

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `playbackEventStream.onError` for player errors | `errorStream` (`PlayerException`) + `PlaybackEvent.errorCode` | just_audio 0.10.0 | Subscribe to `errorStream` |
| `ConcatenatingAudioSource` | `setAudioSources([...])` playlist API | just_audio 0.10.0 | Single source per load in this app |
| `synthetic-package` / `package:flutter_gen` | Generated files in `lib/l10n` (key ignored with a warning) | Flutter ≥ 3.32; warning in 3.47.5 | Omit the key |
| `custom_lint` + riverpod_lint 2 | riverpod_lint 3 via `analysis_server_plugin` under `plugins:` | Riverpod 3 | Surfaced by `dart analyze` only |
| FGS dropped on any pause | Keep the FGS through transient failures < 10 min and `AUDIOFOCUS_LOSS_TRANSIENT` | Android 17 bg-audio hardening (all apps) | `Interrupted`/`Reconnecting` report `playing:true` |
| Audio offload on by default | Off by default | just_audio 0.10.5 | Leave off |

**Deprecated/outdated:** `WIFI_MODE_FULL_HIGH_PERF` is deprecated in API 34 (still used by Media3). `androidOffloadSchedulingEnabled` is deprecated (use `androidAudioOffloadPreferences`; unused here).

## Walking Skeleton & Slicing Recommendation

**Recommendation: keep Phase 1 as one phase with 4 plans, and make the skeleton → resilience boundary explicit, so the `/gsd-phase --insert` split remains a cheap fallback.** A formal split now would renumber phases and duplicate the device matrix. The architecture is designed once in any case.

`human_verify_mode: end-of-phase` [VERIFIED: .planning/config.json:32 `"human_verify_mode": "end-of-phase"`] batches owner checks at the end. That is risky here. Recommend that the planner make two checkpoints **blocking mid-phase exceptions**:
1. the D-14 keystore setup plus the skeleton smoke test on the owner's phone (end of Plan 01)
2. the D-02 URL verification (before Plan 02's station data is relied on)

Everything else batches at the end.

| Plan | Wave | Vertical slice (each leaves the app runnable) | Owner checkpoint |
|---|---|---|---|
| **01 Walking skeleton** | 1 | `flutter create`; pins; lints (`dart analyze`); l10n BG/EN; manifest (INTERNET, FGS, service, receiver, NSC, label, notification icon); `MainActivity : AudioServiceActivity`; domain `Station`/`StationStream`/`StationId`/media IDs; `AudioEngine` facade + thin `RadioAudioHandler` + `JustAudioStreamPlayer` playing **one** progressive station (play/pause/stop, notification); bootstrap + first-launch date; station list + bare mini-player; `ci.yml` + `release.yml`; keystore guide | **Blocking:** D-14 keystore + secrets. Tag `v0.1.0` → sideload the signed APK → one station plays screen-off with notification controls. Also record the first FGS demo video if it works. |
| **02 Streams & now-playing** | 2 | `StreamResolver` (pls/m3u/HLS sniff, limits, cache), `ResolvedStream` → Hls/Progressive; the 6 stations with `streams[]` (after D-02), including the debug stations under `!kReleaseMode`; `NowPlayingParser` + cp1251 + sanitise + clear on switch; `AppHttpClient` HTTPS guard; fixtures + golden tests | **Blocking before merge:** D-02 URL protocol (Витоша captured; cp1251 probe results; HLS-non-m3u8 decision) |
| **03 Resilience engine** | 3 | Pure `PlaybackStateMachine` with all states incl. `Interrupted`; `ReconnectPolicy` + `RetryBudget` presets (standard wired); watchdogs (connect 10 s, stall 8 s, network flow 5 s); fallback rotation (2 rounds DOA); audio_session/connectivity/Wi-Fi-lock ports; FGS/`PlaybackState` mapping table; focus release; live-edge resume; D-09 labels; debug panel (D-07) with time-to-audio + event ring log; `PlayContext` + skip next/prev (API only) | End-of-phase batch |
| **04 Device verification & hardening** | 4 | Fixes from device runs; tune buffer/timeouts; API 24 emulator install; merged-manifest CI check; FGS demo video | End-of-phase batch: SC1–SC5 matrix below |

**If Plan 03's device verification drags** (OEM kills, Android 15+ FGS restart failures), insert "1.1 Resilience" and move Plans 03–04 into it. Plans 01–02 are then a coherent "1A: skeleton, formats, now-playing" (as SUMMARY.md describes).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Every station URL in the Station Matrix is official, current and plays | Station Matrix | Wrong URLs break SC1. Mitigation: the D-02 protocol before Plan 02 relies on them. |
| A2 | `stream.bnr.bg:8011/horizont.mp3` is the 128 kbit name | Station Matrix | Fallback missing. The owner copies the real address from bnr.bg. |
| A3 | Icecast servers (play.global.audio, live.btvradio.bg) auto-serve `/<mount>.m3u` | Station Matrix | N-JOY's `.m3u` might be a stale index entry. The owner's curl confirms it. |
| A4 | At least one of the 6 stations sends cp1251 ICY | Coverage matrix | If none does, SC1's cp1251 clause is shown only by unit tests. Owner decision. |
| A5 | Media-button/BT delivery lets audio_service restart the FGS from background after a user pause on Android 12+ | Pitfall G | Resume from BT or lock screen after a pause could fail silently on Android 15+. Device check; the fallback is to keep the FGS during pause (conflicts with D-13). |
| A6 | Trip offline budget should be 10 min, not ~30 min | RetryBudget | Owner preference. Only a preset value; Phase 1 wires `standard` only. |
| A7 | `WIFI_MODE_FULL_LOW_LATENCY` is ineffective with the screen off; `FULL_HIGH_PERF` still has an effect on Android 14+ | Pitfall J | Wi-Fi stutter with the screen off on newer phones. Owner observation. |
| A8 | No extra R8 keep rules are needed for just_audio/audio_service/Media3 | Gradle | Release-only crash. Caught by the release-build device test. |
| A9 | `flutter create .` does not overwrite the existing `.gitignore`/docs | Installation | Lost ignore rules. Review `git status`/diff after create. |
| A10 | WhatsApp/Viber calls may take permanent focus | Pitfall H | Radio doesn't auto-resume after VoIP calls. Documented limitation. |
| A11 | The Dart AOT snapshot keeps the string literal so the `strings` leak check works | Pitfall I / release.yml | A false "0" could pass. Complement with a unit test that release-mode station list excludes `debug:` IDs (inject a mode flag). |
| A12 | The Flutter tool re-injects the gitignored Gradle wrapper at build time | CI | CI build fails at first run. Confirm on the first tag build. |
| A13 | Proposed timing values (connect 10 s, stall 8 s, flow 5 s, buffer 1 s/2.5 s, backoff 0–30 s) meet the ~10 s recovery | Pattern 2/3 | Slower recovery. Tune on device (Claude's discretion). |

## Open Questions (owner / planner)

1. **Радио Витоша stream.** No official URL was found in accessible sources.
   - Recommendation: the owner captures it from radiovitosha.com's player (protocol step 1).
   - If none is publicly offered, flag it per D-03. Don't swap the station.
2. **"HLS behind a non-`.m3u8` URL".** Not obtainable from the 6 stations.
   - Recommendation: unit tests plus a debug-only `kind: unknown` Хоризонт entry that exercises the content sniff on device.
   - The owner accepts this or names another official source.
3. **`dist=WEBSITEBG` URLs vs the Phase 2 "reject `dist=`" catalogue rule.** These are the stations' own website tags. Phase 2 needs an allow-list of "own" tags per host.
4. **cp1251 station.** Unknown until the probe runs. If none of the 6 sends cp1251, the owner decides whether unit-test coverage satisfies SC1.
5. **Blocking mid-phase checkpoints** vs `human_verify_mode: end-of-phase`. The planner should make the keystore/skeleton smoke check and the D-02 check blocking.
6. **Interrupted notification label.** D-09 lists no label for "interrupted by a call". Suggest an ARB key `stateInterrupted` (placeholder "Прекъснато") shown in the mini-player and notification subtitle. The owner reviews the copy in Phase 3.

## Environment Availability

| Dependency | Required By | Available (this container) | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | analyze/test/codegen | ✗ preinstalled; ✓ installable from `storage.googleapis.com` (done in scratchpad) | 3.47.5 / Dart 3.13.4 (sha256 `2132e990…2cbb`) | — |
| pub.dev | dependency resolution, riverpod_lint plugin build | ✓ | — | — |
| Android SDK / `dl.google.com` | `flutter build apk/appbundle` | ✗ (blocked) | — | GitHub Actions ubuntu runner + the owner's Mac |
| Java | Gradle | ✓ Java 21 here; CI uses Temurin 17 | — | — |
| Station hosts, Radio Browser, directories | URL verification | ✗ (proxy 403 / DNS) | — | Owner protocol (D-02) |
| Physical Xiaomi + Samsung, BT headset, car BT | SC2–SC4 | owner only | — | none (by design) |
| API 24 emulator | PLAT-01 | owner's machine | — | none |
| ffmpeg/ffprobe, VLC | D-02 protocol | owner's Mac (`brew install ffmpeg`) | — | curl-only checks |

**Setup for an executor in a fresh Linux container (verified this session):**
```bash
curl -sSLO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.5-stable.tar.xz
echo "2132e990f236f8d22e7c6314b29a191a95b10d7cbcfec9b4e2e303d996652cbb  flutter_linux_3.47.5-stable.tar.xz" | sha256sum -c
tar xf flutter_linux_3.47.5-stable.tar.xz && export PATH="$PWD/flutter/bin:$PATH"
git config --global --add safe.directory '*'; flutter --disable-analytics
flutter pub get && dart run build_runner build -d && flutter analyze && dart analyze && flutter test
```
`flutter analyze` and `flutter test` (widget tests included) passed with **no Android SDK** present [VERIFIED].

**Missing dependencies with no fallback:** physical-device verification (owner), D-02 URL confirmation (owner).
**Missing with fallback:** Android builds → CI and the owner's machine.

## Validation Architecture

> `workflow.nyquist_validation` is `false` [VERIFIED: .planning/config.json:24 `"nyquist_validation": false`]. This section is included because the orchestrator asked for the test strategy (item 9). It is guidance, not a Nyquist gate.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + `fake_async` 1.3.3 + `mocktail` 1.0.5 + `package:http/testing.dart` `MockClient` |
| Config file | none (defaults); `test/fixtures/` for playlists and ICY samples |
| Quick run command | `flutter test test/features/playback/engine` |
| Full suite command | `flutter test && dart analyze` |

### Phase Requirements → Test Map (what Dart VM tests can prove)
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLAY-07/08/10/11, PLAY-05/06 (logic) | Every row of the transitions table, incl. `Interrupted`→gain resumes, Paused ignores gain/noisy, `completed`→Reconnecting, DOA 2-round rotation, budget exhaustion → Error with release commands, stale-generation drop | unit (pure state machine + `FakeStreamPlayer`, `FakeAudioSessionPort`, `FakeConnectivityPort`, `FakeWifiLockPort` under `fakeAsync`) | `flutter test test/features/playback/engine/state_machine_test.dart` | ❌ Wave 0 |
| PLAY-07 | Backoff sequence + ±20 % jitter bounds (seeded `Random`), reset after 30 s Playing, online/offline budget clocks per preset | unit | `flutter test test/features/playback/engine/reconnect_policy_test.dart` | ❌ |
| PLAY-01/02 (mapping) | State → `PlaybackState{processingState, playing, controls, compact indices}` per the FGS table; `MediaItem` title/subtitle | unit (handler with fakes; `BaseAudioHandler` is pure Dart) | `flutter test test/features/playback/engine/radio_audio_handler_test.dart` | ❌ |
| STRM-02/03 | PLS (CRLF, BOM, lowercase keys, NumberOfEntries missing), M3U (plain/extended/relative URLs), HLS-in-.m3u, extension-less HLS via body sniff, audio/* content-type short-circuit, 64 KB cap, depth 3, scheme allow-list, redirect limit | unit (`MockClient`, `MockClient.streaming` for the cap) | `flutter test test/features/playback/engine/resolver` | ❌ |
| STRM-05 | cp1251 golden table (Cyrillic mojibake, cp1252 double-encode, Western accents unchanged, pure ASCII unchanged, `icyCharset` hints), sanitiser (controls/bidi/clamp), `" - "` split, junk filter, distinct | unit | `flutter test test/core/text` | ❌ |
| STRM-04 | `AppHttpClient` rejects `http://`; `MediaHttpClient` allows http/https only | unit | `flutter test test/core/network` | ❌ |
| APP-06 | Write-once first-launch (second call returns the original value) | unit (`InMemorySharedPreferencesAsync`) | `flutter test test/core/settings` | ❌ |
| D-05 | Release station list contains no `debug:` IDs | unit (inject build-mode flag) | `flutter test test/features/catalog` | ❌ |
| D-06/D-09 | Mini-player shows state labels in BG/EN, TalkBack semantics labels present, controls ≥ 48 dp | widget (fake `AudioEngine` via provider override) | `flutter test test/features/playback/presentation` | ❌ |
| Media IDs / PlayContext | `MediaId` parse/format round-trip; next/prev wrap | unit | `flutter test test/features/playback/domain` | ❌ |
| Architecture | Only `engine/` (+ bootstrap) imports plugin packages | CI grep (ci.yml) | see ci.yml | ❌ |

### Only provable on a device (owner checkpoints → success criteria)
| SC | Check (owner, release build unless noted) | Evidence to capture |
|---|---|---|
| SC1 | Each of the 6 stations plays, and every `streams[]` index plays (debug panel index switch); Хоризонт HLS; N-JOY `.m3u`; http station in **release**; Cyrillic now-playing (cp1251 station if the probe found one); title clears on switch; dead-primary falls over (debug build) | Screenshot/debug-panel log per station |
| SC2 | 60 min screen-off on **Xiaomi and Samsung** (Wi-Fi and 4G); controls from the notification, lock screen, wired headset, BT headset, car BT (projection off); **POST_NOTIFICATIONS denied/never granted**; after Stop: `adb shell dumpsys activity services bg.izk.radio` shows no foreground service, `adb shell dumpsys power \| grep -i wake_lock` shows no `AudioService` lock, `adb shell dumpsys wifi \| grep -i -A3 wifilock` shows no `eRadioto:stream`, and the notification is gone. **Record the unlisted FGS demo video.** | dumpsys outputs, video link |
| SC3 | Wi-Fi→4G (`adb shell svc wifi disable`), airplane toggle (`adb shell cmd connectivity airplane-mode enable/disable`), a 60 s signal loss; audio back within ~10 s at the live edge; dead primary → fallback; budget → Error with the notification play button after 3 min failing | Debug-panel event log with timestamps |
| SC4 | Phone call with the screen off → pause and resume after hang-up (also a >10-min call; also WhatsApp/Viber); Google Maps prompt ducks; unplug / BT disconnect pauses; 5-min pause → resume is live (compare with FM or the web player); after a user pause nothing auto-resumes (toggle Wi-Fi while paused) | logcat: `adb logcat \| grep -E "ForegroundService\|AudioFocus\|ExoPlayer\|audio_service"` with no `ForegroundServiceStartNotAllowedException` |
| SC5 | Install and launch on an **API 24 emulator**; target 36 in the merged manifest; CI PR run green; tag → signed AAB+APK artifacts; `git log --all -- '*.jks' '*.keystore' 'key.properties'` is empty; first-launch date is present after the first run (debug panel shows it); no tracking SDK (CI check) | CI links, emulator screenshot |

### Sampling Rate
- **Per task commit:** `flutter test <touched dir>` + `dart analyze`
- **Per wave merge:** full `flutter test && flutter analyze && dart analyze` + `git diff --exit-code` after codegen
- **Phase gate:** full suite green + owner device matrix before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/fixtures/playlists/` (pls_crlf_bom.pls, pls_lowercase.pls, m3u_plain.m3u, m3u_ext_relative.m3u, hls_master_as_m3u.m3u, hls_media_noext.txt)
- [ ] `test/support/fakes.dart`: `FakeStreamPlayer`, `FakeAudioSessionPort`, `FakeConnectivityPort`, `FakeWifiLockPort`, `FakeEngine`
- [ ] dev deps: `fake_async`, `shared_preferences_platform_interface` (for the in-memory prefs), `clock` as a direct dependency

## Security Domain

`security_enforcement: true`, ASVS level 1 [VERIFIED: .planning/config.json:48-49 `"security_enforcement": true`, `"security_asvs_level": 1`].

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No accounts in v1 |
| V3 Session Management | no | — |
| V4 Access Control | no | — (exported `AudioService`/`MediaButtonReceiver` are required by audio_service; they expose only media controls) |
| V5 Input Validation | **yes** | Resolver limits (scheme allow-list http/https, 64 KB, 5 s, ≤5 redirects, depth ≤3, ≤10 candidates); ICY sanitiser (controls/bidi strip, 200-char clamp); `Uri.tryParse` with rejection |
| V6 Cryptography | no (signing only) | keytool RSA-2048 upload key; Play App Signing later; never hand-roll |
| V8 Data Protection | yes (minimal) | Only `first_launch_at` stored locally; no PII; debug logs local, ring buffer, not exported |
| V9 Communications | **yes** | NSC documents why cleartext is on for native media sockets; `AppHttpClient` HTTPS-only for app-owned traffic; the resolver may use http (media) |
| V10 Malicious Code / Supply chain | yes | Pinned versions + committed `pubspec.lock`; no tracking SDK deny-list in CI; package audit above |
| V14 Configuration | **yes** | Secrets only in tag/dispatch jobs; `permissions: contents: read`; no `pull_request_target`; keystore in `$RUNNER_TEMP`, deleted `if: always()`; no `set -x`; debug-signing and debug-station leak checks; merged-manifest check |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Keystore/passwords committed or printed in CI logs | Information disclosure | `.gitignore` (verified patterns), GitHub secrets only, masked env, no echo, secret scanning + push protection, upload key only (reset possible via Play Console) |
| Fork PR exfiltrating secrets | Elevation / disclosure | Secrets are referenced only in `release.yml` (tags/dispatch); `ci.yml` has none; never `pull_request_target` |
| Release accidentally debug-signed | Tampering (update chain) | `keytool -printcert` check fails on `CN=Android Debug` |
| Debug dead-primary/panel shipped to users | Information disclosure / tampering | `!kReleaseMode` guard + unit test + `strings` check in release job |
| Malicious or oversized playlist (memory/CPU exhaustion, redirect loops) | DoS | 64 KB cap, 5 s timeout, ≤5 redirects, depth ≤3, ≤10 candidates |
| Playlist pointing to `file:`/`content:`/`javascript:`/intent URIs | Tampering | Scheme allow-list `http`/`https` only before handing to ExoPlayer |
| ICY title injection (bidi overrides, control chars, huge strings) into the notification/lock screen/car display | Spoofing / DoS | Sanitiser + clamp before `MediaItem` |
| App-owned traffic downgraded to http | Tampering / MITM | `AppHttpClient` rejects non-https (unit-tested); NSC cleartext justified for media only |
| Tracking/analytics SDK creeping in | Information disclosure (privacy) | CI deny-list on `pubspec.lock`; no `POST_NOTIFICATIONS`/extra permissions |
| Battery drain from endless retries (availability for the user) | DoS (self) | `RetryBudget`, offline pause of backoff, FGS/Wi-Fi lock released in Paused/Idle/Error |

## Sources

### Primary (HIGH confidence, read or run this session)
- pub.dev archives: just_audio 0.10.6 (`lib/just_audio.dart`, `android/.../AudioPlayer.java`, `build.gradle.kts`, `CHANGELOG.md`, `README.md`), audio_service 0.18.19 (`lib/audio_service.dart`, `AudioService.java`, `AudioServiceActivity.java`, `AudioServicePlugin.java`, README), audio_session 0.2.4 (`lib/src/core.dart`, `AndroidAudioManager.kt`), connectivity_plus 7.3.1 + platform_interface 2.1.0, http 1.6.0, shared_preferences 2.5.5 + platform_interface 2.4.2, riverpod 3.4.3, riverpod_lint 3.1.9
- pub.dev API metadata (versions, publishers, licences, 30-day downloads) for all Phase 1 packages
- Flutter 3.47.5 SDK (sha256-verified tarball): `flutter create` output, `FlutterExtension.kt`, `localizations_utils.dart`; probe project: `pub add`, `build_runner`, `gen-l10n`, `flutter analyze`, `dart analyze`, `flutter test`
- androidx/media (raw GitHub): `IcyDecoder.java` 1.4.1, `WifiLockManager.java` 1.4.1/1.8.0, `ExoPlayer.java` 1.4.1 (default `WAKE_MODE_NONE`)
- flutter/website `sites/docs/src/content/deployment/android.md` (keystore, signing, R8, PQC note)
- GitHub action manifests: actions/checkout v7.0.1, actions/setup-java v6.0.1, actions/upload-artifact v7.0.1, subosito/flutter-action v2.23.0
- Python `cp1251` codec (table generation + round-trip check)

### Secondary (MEDIUM: official docs via WebFetch)
- [Android: Manage audio focus](https://developer.android.com/media/optimize/audio-focus): auto-ducking without callback, LOSS vs LOSS_TRANSIENT, Android 15 focus requirement
- [Android 17 background audio hardening](https://developer.android.com/about/versions/17/changes/bg-audio): keep the FGS through transient failures < 10 min
- [FGS background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start): exemption list
- [Notification runtime permission](https://developer.android.com/develop/ui/views/notifications/notification-permission): media-session exemption
- [WifiManager API 34 diff](https://developer.android.com/sdk/api_diff/34/changes/android.net.wifi.WifiManager): `WIFI_MODE_FULL_HIGH_PERF` deprecated

### Tertiary (LOW: web-search snippets only; all station URLs)
- [radio1.bg](https://www.radio1.bg/), [bgradio.bg/live-stream](https://www.bgradio.bg/live-stream), [radioenergy.bg](https://www.radioenergy.bg/), [btvradio.bg streams article](https://btvradio.bg/za-grada/slushaite-btv-radio-onlain-i-prez-mobilniya-si-telefon.html), [live.btvradio.bg/njoy.mp3.m3u](http://live.btvradio.bg/njoy.mp3.m3u), [play.global.audio (Icecast)](https://play.global.audio/), [bnr.bg/horizont/page/live](https://bnr.bg/horizont/page/live), [Predavatel forum: БНР internet links](https://forum.predavatel.com/viewtopic.php?t=26861), [Predavatel forum: full BG stream list](https://forum.predavatel.com/viewtopic.php?t=26587), [radioverified: Radio Vitosha](https://radioverified.com/stations/radio-vitosha/), [radioplay.bg](https://www.radioplay.bg/)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH. Resolved and exercised on Flutter 3.47.5 in this session.
- Plugin APIs / FGS / focus behaviour: HIGH. Read from the published source with line references.
- Architecture (state/FGS table): HIGH for the mapping to plugin behaviour; MEDIUM for Android 15–17 runtime (device verification).
- Timings/buffer values: MEDIUM. Tune on device.
- Station URLs and charsets: LOW. Owner verification is mandatory (D-02).
- CI/signing: HIGH for structure and action tags; MEDIUM for first-run details (wrapper injection, `strings` check).

**Research date:** 2026-09-25
**Valid until:** 2026-10-25 for the stack and APIs (pinned). Station URLs should be re-checked right before Plan 02 executes.
