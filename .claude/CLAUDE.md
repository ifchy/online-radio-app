<!-- GSD:project-start source:PROJECT.md -->

## Project

**Online Radio (working title)**

A free Android app for listening to live internet radio, with **Bulgarian radio as the first-class experience** and worldwide stations as a secondary catalogue. It aims to be the fastest, most reliable way for someone in Bulgaria to open their phone and hear БНР Хоризонт, their local city station or their favourite music station — including in the car and with the screen off. No ads, no accounts, no sign-up in v1. Android first; iOS may follow later from the same Flutter codebase.

**Core Value:** Tap the app → hear the last Bulgarian station within ~3 seconds, and playback never stops on its own (screen off, background, network switches, short signal loss).

### Constraints

- **Tech stack**: Flutter (stable) + Dart 3, Android only in v1 — chosen over React Native (RNTP commercial licence from v5, expo-audio lacks Android Auto) and native Kotlin (full rewrite for iOS later)
- **Audio**: `just_audio` + `audio_service` + `audio_session` behind our own `AudioEngine` interface — plugins are maintained by a small team; engine must be swappable (e.g. native Media3) without touching UI
- **Supporting stack (to validate in research)**: Riverpod, go_router, drift (SQLite), shared_preferences, `http` or `dio`, `flutter_localizations` + ARB (`bg`, `en`), cached network images
- **Licensing**: only free / permissively licensed dependencies compatible with a future ad-supported app — no commercially licensed SDKs
- **Infrastructure**: no backend in v1; static hosting only (raw GitHub / jsDelivr / GitHub Pages)
- **Security**: repo is public — never commit signing keys, keystores or secrets
- **Content rights**: only stations' own official, publicly offered streams; link to their websites; honour removal requests promptly
- **SDK levels**: support older budget phones as far as the stack reasonably allows; target the API level Google Play currently requires
- **Privacy**: no personal data collected, no tracking in v1; any crash reporting must be disclosed in Data safety + privacy policy
- **Accessibility**: TalkBack labels on all controls, large-text support, sufficient contrast, big touch targets on the player
- **Battery**: no wake-locks when not playing; stop the foreground service when playback stops
- **Working agreements**: every phase leaves the app runnable; `flutter analyze` + `flutter test` must pass; playback phases verified by owner on a physical phone; Bulgarian strings reviewed by owner; conventional commits; phase work lands via PRs

<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->

## Technology Stack

## Verdict on the brief's proposed stack

| Brief proposal | Verdict | Change |
|---|---|---|
| just_audio + audio_service + audio_session behind `AudioEngine` | **KEEP** | Pin the versions below. Build `.pls`/`.m3u` resolution and explicit HLS selection yourself. Pass `useProxyForRequestHeaders: false`. |
| Riverpod | **KEEP** (v3, with code generation) | Use `riverpod_lint` 3.x. It uses the new analyzer-plugin API, so `custom_lint` is not needed. |
| go_router | **KEEP** (v18) | Requires Flutter ≥ 3.44. |
| drift (SQLite) | **KEEP** | Do **not** add `sqlite3_flutter_libs`: it is EOL. `sqlite3` 3.x bundles SQLite through build hooks. |
| shared_preferences | **KEEP** | Use the `SharedPreferencesAsync` / `SharedPreferencesWithCache` API, not the legacy singleton. |
| `http` vs `dio` | **`http`** | The app makes few requests, all simple GET/ETag calls. `dio` adds weight and gives nothing this app needs. |
| flutter_localizations + ARB | **KEEP** | Use gen-l10n with output into `lib/`. The synthetic `package:flutter_gen` has been removed. |
| Cached network images | **KEEP** `cached_network_image` 4.x | This is a new major version (Aug 2026, after a 2-year gap), so confidence is MEDIUM. |
| GitHub Actions, signed AAB | **KEEP** | Current action versions are listed below. Upload key only; Play App Signing holds the app key. |
| Min/target SDK | **min 24 / target 36 / compile 36** | 24 is the hard floor for Flutter 3.47 and for audio_session. 36 is mandatory for Play submissions since 2026-08-31. |
| Android 13 notification permission "on first play" | **Not needed for playback** | Media-session notifications are exempt from `POST_NOTIFICATIONS`. Drop the prompt unless the app later posts other kinds of notification. |

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|---|---|---|---|---|
| Flutter (stable) | **3.47.5** (Dart **3.13.4**) | UI framework / toolchain | Current stable (2026-09-18). go_router 18, cached_network_image 4 and Riverpod 3.4 already require Flutter ≥ 3.44 / Dart ≥ 3.12, so older SDKs are not an option. | HIGH (releases JSON + local install) |
| Android Gradle Plugin / Gradle / Kotlin | AGP **9.1.0**, Gradle **9.3.1**, Kotlin **2.4.0**, NDK **28.2.13676358**, JDK 17 | Android build | These are the Flutter 3.47 template defaults. just_audio 0.10.6, audio_service 0.18.19 and audio_session 0.2.4 all shipped "Support AGP 9" releases. The probe release build passed on this toolchain. | HIGH (verified by build) |
| **just_audio** | **0.10.6** (2026-06-29) | Playback engine (Media3 ExoPlayer on Android) | Flutter Favorite, ~1.2M downloads/30 days, MIT + Apache-2.0. On Android it plays progressive MP3/AAC/HE-AAC via ExoPlayer extractors and HLS via `media3-exoplayer-hls`, and exposes ICY metadata (`icyMetadataStream`). It handles audio focus, ducking and becoming-noisy through audio_session. Buffering is tunable (`AudioLoadConfiguration` / `AndroidLoadControl`). | HIGH (source inspected) |
| **audio_service** | **0.18.19** (2026-06-29) | Foreground media service, MediaSession, notification, lock screen, headset/BT buttons, Android Auto browse tree | This is the only mature, permissively licensed (MIT) Flutter plugin that exposes a full `MediaBrowserService` browse tree (`getChildren` / `getMediaItem` / `search`). That tree is what Android Auto needs in v1.1. It supports FGS type `mediaPlayback` and the `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission, and it was fixed for the Android 13 media-button and Oppo/OnePlus quirks. | HIGH for v1 features, MEDIUM for Android Auto |
| **audio_session** | **0.2.4** (2026-06-29) | Audio attributes, focus, ducking, becoming-noisy | Shared by just_audio and audio_service. Configure it once with `AudioSessionConfiguration.music()`. It is Kotlin-based, and its **minSdk is 24**, which sets the app floor together with Flutter. | HIGH (source inspected) |
| **flutter_riverpod** + riverpod_annotation + riverpod_generator | **3.4.3** / **4.0.7** / **4.0.9** | State management / DI | Current, MIT, ~3.3M downloads/30 days. It exposes the `AudioEngine` as a provider, so tests can override it. v3 adds automatic retry, `Mutation` and offline persistence. **Keep reconnect logic inside the engine, not in provider retry**, because Riverpod 3 retries failing providers by default. | HIGH |
| **go_router** | **18.0.1** (2026-09-02) | Navigation, deep links (shared station links) | Published by flutter.dev (BSD-3). `StatefulShellRoute` gives tabbed browse screens with a persistent mini-player in the shell. | HIGH |
| **drift** + drift_flutter | **2.35.0** / **0.3.1** | Favourites, recents, cached catalogue, v1.1 song history | Flutter Favorite, MIT, type-safe SQL, versioned migrations with migration tests, reactive `watch()` streams that fit Riverpod. It bundles SQLite 3.x through the `sqlite3` 3.x build hook: ~1.7 MB uncompressed per ABI, 16 KB-aligned (verified). | HIGH |
| **shared_preferences** | **2.5.5** | Small settings (theme override, last station id, first-launch date, sleep-timer default) | flutter.dev package, BSD-3. It uses DataStore on Android. | HIGH |
| **http** | **1.6.0** | Catalogue fetch (ETag / If-None-Match), Radio Browser API, `.pls`/`.m3u` resolution | Published by dart.dev (BSD-3). It is already a transitive dependency through flutter_cache_manager. Set a custom `User-Agent` on a wrapped `Client`, as Radio Browser guidelines require. | HIGH |
| **flutter_localizations** + **intl** | SDK / **0.20.3** | BG/EN UI via ARB + gen-l10n | Standard approach. `intl` is pinned by the SDK's flutter_localizations, so accept the resolved version. | HIGH |

### Supporting Libraries

| Library | Version | Purpose | When to Use | Confidence |
|---|---|---|---|---|
| cached_network_image | 4.0.2 | Station logos with disk cache and placeholders | Always. Pass `memCacheWidth`/`memCacheHeight` so logos decode small on low-end phones. Its dependency flutter_cache_manager 3.4.5 is already pulled in by audio_service (for notification art). | MEDIUM (fresh major) |
| connectivity_plus | 7.3.1 | Detect network changes (Wi-Fi ↔ 4G) and trigger reconnect at once instead of waiting for ExoPlayer's I/O timeout | Phase 1, needed for the "recovery within ~10 s" target | HIGH |
| url_launcher | 6.3.2 | `mailto:` for "report broken station", station homepages, privacy policy | Phase 4 | HIGH |
| share_plus | 13.3.0 | Share a station as text/link | Phase 3 | HIGH |
| package_info_plus | 10.2.1 | Version in About screen and bug-report emails; app version in User-Agent | Phase 1 (User-Agent), Phase 4 (About) | HIGH |
| path_provider | 2.1.6 | Bundled-snapshot / cache file locations | Phase 2 | HIGH |
| freezed + freezed_annotation | 4.0.2 / 3.1.x | Immutable station/catalogue models and sealed `PlaybackStatus` unions | Phase 1–2. Codegen is already needed for drift and Riverpod. | HIGH |
| json_serializable + json_annotation | 6.14.1 / 4.12.0 | `stations-bg.json` and Radio Browser JSON parsing | Phase 2 | HIGH |
| diacritic | 0.1.6 | Folds Latin diacritics (é→e) for world-station search | Phase 2. Bulgarian Cyrillic↔Latin transliteration is **custom code** (official Streamlined System), because no package does it properly. | MEDIUM (small, stable, last release 2024) |
| flutter_native_splash | 2.4.8 | Android 12+ splash API assets | Phase 4 | HIGH |
| flutter_launcher_icons | 0.14.4 | Adaptive/themed launcher icons | Phase 4 | HIGH |
| sentry_flutter | 9.30.1 | Crash reporting, **only if the owner opts in** | MIT SDK. Disable PII (`sendDefaultPii: false`) and disclose it in Data safety. Play Console's Android vitals only sees native crashes and ANRs, not Dart exceptions. | HIGH (package); owner decision |

### Development Tools

| Tool | Version | Purpose | Notes |
|---|---|---|---|
| build_runner | 2.16.1 | Runs drift / riverpod / freezed / json codegen | `dart run build_runner watch -d` during development. Commit generated files or run codegen in CI, but decide which once. |
| drift_dev | 2.35.0 | drift codegen and schema dumps | Use `drift_dev schema dump` plus generated migration tests from the first schema onward. |
| riverpod_lint | 3.1.9 | Riverpod-specific lints | Built on `analysis_server_plugin`; enable it under `plugins:` in `analysis_options.yaml`. `custom_lint` is no longer needed. |
| flutter_lints | 6.0.0 | Base lint set | Prefer this over `very_good_analysis` 11. VGA's `public_member_api_docs` and similar rules are noise for a solo app. |
| mocktail | 1.0.5 | Mocks for `AudioEngine`, HTTP client, clock | Unit tests for reconnect/backoff, sleep timer, catalogue parsing |
| subosito/flutter-action | v2.23.0 | Installs Flutter in CI | Pin `flutter-version: 3.47.5` and set `cache: true`. |
| actions/checkout, actions/setup-java, actions/upload-artifact | v7.0.1, v6.0.1 (Temurin 17), v7.0.1 | CI plumbing | AGP 9 requires JDK 17+. |
| r0adkll/upload-google-play | v1.1.5 | Optional: push AAB to the internal/closed track | Phase 5, service-account JSON in secrets |

## Audio stack: detailed findings

### Stream-type support on Android (just_audio 0.10.6, Media3 1.4.1)

| Stream type | Supported? | How / caveat | Confidence |
|---|---|---|---|
| MP3 (Icecast/Shoutcast progressive) | Yes | `ProgressiveAudioSource` → ExoPlayer `ProgressiveMediaSource` | HIGH |
| AAC / HE-AAC v1/v2 (ADTS over HTTP) | Yes | ExoPlayer AdtsExtractor plus the platform MediaCodec AAC decoder, which handles SBR/PS | HIGH |
| HLS (`.m3u8`) | Yes, **but** `AudioSource.uri()` picks HLS **only when the URL path or fragment ends in `.m3u8`** | For HLS URLs without that extension, construct `HlsAudioSource(uri)` explicitly, driven by the catalogue `codec`/`type` field or a `Content-Type` sniff (`application/vnd.apple.mpegurl`, `audio/mpegurl`). The `#.m3u8` fragment trick also works. | HIGH (source) |
| `.pls` / `.m3u` wrappers | **No** | Neither just_audio nor ExoPlayer parses them. Write a Dart `PlaylistResolver`: GET with a size cap → parse `FileN=` (PLS) or non-`#` lines (M3U) → try entries in order. If the body contains `#EXT-X-`, it is really HLS, so play the original URL as `HlsAudioSource`. | HIGH |
| ICY "now playing" | Yes (progressive only) | ExoPlayer sends `Icy-MetaData: 1`. just_audio surfaces `IcyInfo.title` (usually `"Artist - Title"`, which you split yourself) plus `IcyHeaders` (name, genre, bitrate). **HLS timed ID3 metadata is not surfaced**, so HLS stations have no now-playing. | HIGH (source) |
| Redirects http↔https | Yes | just_audio builds `DefaultHttpDataSource.Factory().setAllowCrossProtocolRedirects(true)` | HIGH (source) |
| Custom User-Agent | Yes | Construct `AudioPlayer(useProxyForRequestHeaders: false, userAgent: 'BGRadio/1.0 (+contact)')`. ExoPlayer then sends the UA natively and **no localhost proxy is started**. With the default (`true`), just_audio starts a cleartext `127.0.0.1` HTTP proxy for any headers. | HIGH (source) |
| Buffer tuning (time-to-audio ≤ 3 s) | Yes | `AudioLoadConfiguration(androidLoadControl: AndroidLoadControl(bufferForPlaybackDuration: ~1 s, ...))`. Tune the exact values on a device in Phase 1. | MEDIUM |
| Audio offload | Disabled by default since 0.10.5 ("to prevent playback issues") | Leave it off. | HIGH |

### Cleartext `http://` streams: how to scope them

- **Android's Network Security Config only governs platform (native) sockets.** In this app that means ExoPlayer's `DefaultHttpDataSource` (HttpURLConnection). **`dart:io` sockets ignore it**: Flutter's docs state that no policy is enforced on Dart-owned sockets. That covers `package:http` and cached_network_image. (HIGH, official Flutter breaking-change doc)
- Worldwide Radio Browser stations are on arbitrary hosts, so a domain allow-list cannot cover them. **Recommendation:**
- Confidence: MEDIUM-HIGH. The design follows from the documented behaviour; the owner should confirm it on a device with one `http://` station.

### Foreground service and Play policy (target API 36)

- **Play Console:** apps targeting 34+ must complete the foreground-service declaration for `mediaPlayback`. Budget a short screen recording of background playback in Phase 5. (MEDIUM-HIGH)
- **`POST_NOTIFICATIONS`:** media-session notifications are **exempt** on Android 13+ (official doc). The runtime prompt is not required for playback. (HIGH)
- **Keep the FGS alive during reconnects.** audio_service drops foreground state when `playing` becomes false and `androidStopForegroundOnPause` is true (the default, which is correct for battery). While auto-reconnecting, report `playing: true, processingState: buffering/loading`, never paused or idle. Otherwise the service leaves the foreground and OEM killers or Android 12+ FGS-start limits can prevent it from coming back. (HIGH, from README note and code)
- **Android 17 background-audio hardening** applies to **all apps on Android 17 devices** regardless of target. Playback, focus requests and volume calls fail silently unless the app has a visible activity or a foreground service. Apps **targeting** API 37 (expected to be required around Aug 2027) additionally need while-in-use FGS capability, which a `mediaPlayback` FGS started from the foreground provides. This reinforces the previous point. Resuming from a Bluetooth button after the service has fully stopped is the case to test. (HIGH, official doc)
- **Target 36 side effects:** edge-to-edge can no longer be opted out of (use `SafeArea` and system-bar insets); predictive back is on by default (use `PopScope`, which go_router respects); orientation and resizability locks are ignored on screens ≥ 600 dp. (HIGH, official doc)

### SDK levels

| Setting | Value | Why |
|---|---|---|
| `minSdk` | **24** (Android 7.0) | Flutter 3.47's minimum supported API (support for 23 and below is dropped; the template default is 24), and audio_session 0.2.x's `minSdk = 24`. No lower value is achievable on current Flutter. HIGH |
| `targetSdk` / `compileSdk` | **36** | Google Play requires API 36 for new apps and updates since **2026-08-31** (extension possible until 2026-11-01). The Flutter 3.47 template defaults to 36. HIGH |
| 16 KB page size | Compliant | The probe AAB's `libflutter.so`, `libapp.so`, `libsqlite3.so`, `libdartjni.so` and `libdatastore_shared_counter.so` all have LOAD alignment ≥ 16 KB (verified by ELF header check). HIGH |

### audio_service vs just_audio_background vs Media3-native

| Option | Verdict | Reasoning |
|---|---|---|
| **audio_service 0.18.19** | **Use** | It provides a full `BaseAudioHandler` you own: custom actions, browse tree for Android Auto, queue, search, and control over when the FGS stops. It is MIT, maintained by the same author as just_audio, and updated together with it. |
| just_audio_background 0.0.1-beta.17 | **Do not use** | Still beta; the last release was May 2025. It is a thin wrapper with **no custom browse tree** (so no Android Auto categories), no custom reconnect-aware state reporting, and only single-player support. just_audio's own docs point to audio_service for anything non-trivial. |
| Own Media3 `MediaLibraryService` in Kotlin (Pigeon bridge) | **Plan B behind `AudioEngine`** | This is the future-proof Android path (Google recommends Media3 sessions, and they are exempt from Android 17 hardening). It costs 1–2 weeks of Kotlin plus re-implementing notification and Auto plumbing. Trigger it only if the ryanheise plugins stall on a blocking bug. A working reference is **flutter_radio_player 4.1.0** (MIT, Media3 1.10.0, `MediaLibraryService`), but it is too small (~200 downloads/30 days) to adopt as a dependency. |
| Package | Last release | Cadence | Open issues | Health notes |
|---|---|---|---|---|
| just_audio | 0.10.6, 2026-06-29 | Bursty: Sep 2025 → Jun 2026 gap | ~345 | Single maintainer (ryanheise), Flutter Favorite. **Media3 is pinned at 1.4.1 (mid-2024)**. |
| audio_service | 0.18.19, 2026-06-29 (iOS commits 2026-07-01) | Bursty | ~204 | **Still on legacy `androidx.media` `MediaBrowserServiceCompat`**. The Media3 migration issue #942 has been open since 2022. It works, but it is not Google's current recommendation. |
| audio_session | 0.2.4, 2026-06-29 | Bursty | n/a | Migrated to Kotlin in 0.2.0 |
| flutter_riverpod | 3.4.3, 2026-09-03 | Frequent | n/a | Active |
| go_router | 18.0.1, 2026-09-02 | Frequent | n/a | flutter.dev team |
| drift / sqlite3 | 2.35.0 / 3.6.0, Sept 2026 | Frequent | n/a | Active (simolus3) |
| cached_network_image | 4.0.2, 2026-09-23 | Revived after a 2-year gap | n/a | Baseflow; watch for 4.x regressions |

### Android Auto readiness (v1.1)

- **Feasible with audio_service.** Implement `getChildren(parentMediaId)`, `getMediaItem` and `search` in the `AudioHandler`. Add `<meta-data android:name="com.google.android.gms.car.application" android:resource="@xml/automotive_app_desc"/>` and the `automotive_app_desc.xml` (`<uses name="media"/>`). audio_service's example app contains the Android Auto manifest entry. Android Auto still supports legacy `MediaBrowserServiceCompat` apps. (MEDIUM)
- **Build for it in v1:** design the `AudioHandler` media-ID tree now (`root → favourites | bg/national | bg/city/{id} | bg/genre/{id} | recents`), even if only the phone UI uses it. Adding Auto then becomes a manifest change plus a browse-tree implementation, not a refactor.
- **Flag for v1.1 research:** artwork delivery to the car (content URIs vs HTTP), content-style extras (grid vs list), Android for Cars media app-quality review, and whether the legacy service passes current Auto review without Media3.

## Installation

# Core

# Supporting

# Dev

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|---|---|---|
| audio_service + just_audio | Own Kotlin Media3 `MediaLibraryService` + Pigeon | If audio_service or just_audio stall on a blocking Android bug, or Media3-only features become mandatory (e.g. Auto review demands Media3, or playback resumption on Android 17). Swap behind `AudioEngine`. |
| Riverpod 3 | flutter_bloc | Only if the developer already knows Bloc well. Riverpod's provider overrides make the `AudioEngine` seam simpler to test. |
| drift | sqflite, or JSON files + shared_preferences only | If the ~0.8 MB compressed native SQLite per ABI matters more than typed queries and migrations. Favourites and recents alone would fit in JSON, but v1.1 song history and Auto browse queries favour drift. |
| `http` | `dio` | Only if interceptors, retry or cancel tokens become necessary across many endpoints. They will not for static JSON plus Radio Browser. |
| cached_network_image | `Image.network` + a custom `flutter_cache_manager` wrapper | If cached_network_image 4.x shows regressions. The fallback keeps the same cache manager. |
| Custom Radio Browser client | `radio_browser_api` 2.1.0 | Writing it yourself (~200 lines) makes it easier to guarantee the guidelines are followed: DNS/`/json/servers` discovery, User-Agent, `url_resolved`, click registration. |
| Sentry (if crash reporting is wanted) | Firebase Crashlytics | Crashlytics is free but a proprietary Google SDK that pulls in Firebase/GMS. It conflicts with the "permissive licences only, no tracking" stance. Choose it only if the owner accepts that. |

## What NOT to Use

| Avoid | Why | Use Instead |
|---|---|---|
| `radio_player` (pub.dev) | Licence is **CC BY-NC-SA 4.0**, which is non-commercial and incompatible with a future ad-supported app | just_audio + audio_service |
| `just_audio_background` | Beta, last release May 2025, no browse tree / Android Auto categories, limited control over the FGS lifecycle | audio_service |
| `media_kit` (libmpv) | Adds tens of MB of native libraries, has no Android MediaSession/notification/Auto integration, and the libmpv build licensing (LGPL/GPL) needs care. Built for video. | just_audio |
| `assets_audio_player` | Last release Aug 2023, effectively unmaintained | just_audio |
| `sqlite3_flutter_libs` as a direct dependency | Marked `0.6.0+eol`: "update to version 3.x of package:sqlite3 instead" | `drift_flutter`, which pulls in `sqlite3` 3.x with build hooks |
| `custom_lint` for Riverpod lints | riverpod_lint 3.x moved to `analysis_server_plugin` | riverpod_lint 3.1.9 under `plugins:` |
| `import 'package:flutter_gen/gen_l10n/...'` | The synthetic package was removed after Flutter 3.32 | `synthetic-package: false`, import from `lib/l10n/` |
| `AudioSource.uri()` for station streams | It picks HLS only by the `.m3u8` extension and treats `.pls`/`.m3u` as audio, so they fail | Explicit `ProgressiveAudioSource` / `HlsAudioSource` from resolved catalogue metadata |
| Default `AudioPlayer()` with custom headers | Starts a cleartext localhost proxy for headers, an extra hop that also needs a cleartext exception | `AudioPlayer(useProxyForRequestHeaders: false, userAgent: ...)` |
| Blanket `android:usesCleartextTraffic="true"` with no Dart-side guard | Silently allows `http://` for catalogue and API calls too | NSC file plus an HTTPS-only wrapped `http.Client` for non-media traffic |
| `permission_handler` just to request notifications | Media notifications are exempt from `POST_NOTIFICATIONS` | Nothing. Add it only if non-media notifications appear later. |
| Any ads/analytics SDK in v1 (AdMob, Firebase Analytics) | Out of scope, and it changes the Data safety declarations | Add in the dedicated ads milestone, with UMP consent |

## Stack Patterns by Variant

- Resolve it in Dart before handing it to the engine. Cache the resolved URL per station for about 1 hour, and invalidate the cache on playback error.
- Use `HlsAudioSource` when the catalogue says `hls`, when the resolved URL ends in `.m3u8`, or when the playlist body contains `#EXT-X-`. Otherwise use `ProgressiveAudioSource`.
- The engine re-creates the source and calls `load()` again from scratch. For live radio this means the live edge; never seek. Use exponential backoff (e.g. 1, 2, 4, 8 s, capped), try fallback `streams[]` in priority order, and report buffering state so the FGS stays alive.
- Keep audio_service and add the browse tree plus the manifest meta-data. Re-evaluate Media3-native only if Play's Auto review rejects the legacy service.
- The same three plugins work on iOS. Add `NSAppTransportSecurity` exceptions for `http://` streams, and `UIBackgroundModes: audio`.

## Version Compatibility

| Package A | Compatible With | Notes |
|---|---|---|
| go_router 18.0.1, cached_network_image 4.0.2 | Flutter ≥ 3.44, Dart ≥ 3.12 | They depend on the new `material_ui` / `cupertino_ui` packages |
| flutter_riverpod 3.4.3 / riverpod_generator 4.0.9 / riverpod_lint 3.1.9 | Dart ≥ 3.12; analyzer 13–14 | Resolves alongside drift_dev 2.35.0, freezed 4.0.2, json_serializable 6.14.1 (verified) |
| just_audio 0.10.6 / audio_service 0.18.19 / audio_session 0.2.4 | Flutter ≥ 3.27, AGP 9 | Plugins compile against SDK 35. The app compiles/targets 36; this works (verified build). |
| just_audio 0.10.6 | Media3 1.4.1 (bundled) | Can be forced to 1.10.0 if just_audio's `compileSdk` is overridden to 36. Compile verified; runtime unverified. |
| audio_session 0.2.x | minSdk 24 | Matches the Flutter 3.47 floor |
| drift 2.35 / drift_flutter 0.3.1 | sqlite3 ^3.4 (build hooks) | Do not also add `sqlite3_flutter_libs` 0.5.x; it conflicts with the hook-based build |
| AGP 9.x | JDK 17+ | Use Temurin 17 in CI; the local machine has Zulu 17 |
| AGP 8.6 / 8.7 | **Avoid** | The just_audio README warns of an ExoPlayer release-mode bug on these versions. Irrelevant on AGP 9.1, but do not downgrade to them. |

## Sources

- pub.dev API (`/api/packages/<name>`, `/score`) — versions, publish dates, licences, publishers, 30-day downloads for every package listed (HIGH, primary registry)
- Published source archives of just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4, flutter_radio_player_android 4.1.0 and cached_network_image 4.0.2 — `AudioPlayer.java` (ICY, HLS, data source factory), `just_audio.dart` (proxy, `AudioSource.uri`), `build.gradle.kts` (minSdk, Media3 version), READMEs, CHANGELOGs (HIGH)
- Local probe on Flutter 3.47.5: `flutter pub get` of the full set, `flutter build appbundle --release`, ELF alignment check, Media3 1.10.0 override build (HIGH)
- Flutter releases JSON (storage.googleapis.com/flutter_infra_release) — current stable 3.47.5 / Dart 3.13.4 (HIGH)
- flutter/flutter `stable` — `FlutterExtension.kt`, `gradle_utils.dart`: minSdk 24, target/compile 36, AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, NDK 28.2 (HIGH)
- [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms) — Android API 24–37 supported, ≤ 23 unsupported (HIGH)
- [Flutter: network policy breaking change (reverted)](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android) — Dart-owned sockets do not enforce platform network policy (HIGH)
- [Flutter: gen-l10n to source](https://docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source) — `flutter_gen` synthetic package removal (HIGH)
- [Play Console: Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) — API 36 required from 2026-08-31 (HIGH; corroborated by multiple secondary sources)
- [Android 16 behaviour changes (target 36)](https://developer.android.com/about/versions/16/behavior-changes-16) — edge-to-edge, predictive back, large-screen orientation (HIGH)
- [Android 17 background audio hardening](https://developer.android.com/about/versions/17/changes/bg-audio) — FGS/visible requirement for audio on all apps; while-in-use for target 37 (HIGH)
- [Android notification runtime permission](https://developer.android.com/develop/ui/views/notifications/notification-permission) — media-session notifications exempt (HIGH)
- [Media3 releases](https://developer.android.com/jetpack/androidx/releases/media3) / [androidx/media 1.10.0](https://github.com/androidx/media/releases/tag/1.10.0) — current Media3 line (MEDIUM, web search summary)
- GitHub REST API — ryanheise/just_audio and ryanheise/audio_service commit history, open issue counts; [audio_service #942 "Update Android implementation to use media3"](https://github.com/ryanheise/audio_service/issues/942), open since 2022 (HIGH)
- GitHub releases API — subosito/flutter-action v2.23.0, actions/setup-java v6.0.1, actions/checkout v7.0.1, actions/upload-artifact v7.0.1, r0adkll/upload-google-play v1.1.5 (HIGH)
- [16 KB page size guidance](https://www.freecodecamp.org/news/google-16-kb-page-size-requirement-what-to-do/) — Play requirement context (MEDIUM); compliance itself verified locally (HIGH)

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
