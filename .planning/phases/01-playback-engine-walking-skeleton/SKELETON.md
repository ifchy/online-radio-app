# Walking Skeleton — eRadioto (`bg.izk.radio`)

**Phase:** 1
**Generated:** 2026-09-25

## Capability Proven End-to-End

A listener taps БГ Радио in the eRadioto station list on a physical Android phone. A **release** build plays it with the screen locked, and the listener can pause, resume at the live edge and stop it from the mini-player, the media notification, the lock screen and a headset. Proven by 01-01 Task 1 (the tracer, with a blocking owner gate).

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Framework | Flutter 3.47.5 / Dart 3.13.4, Android only in v1; `flutter create --org bg.izk --project-name radio` → package `bg.izk.radio` | Pinned stack (CLAUDE.md). One codebase keeps iOS/CarPlay open later. The package id is owner-decided and permanent once published. |
| SDK levels | minSdk 24, targetSdk 36, compileSdk 36, written explicitly in `android/app/build.gradle.kts`; AGP 9.1 / Gradle 9.3.1 / Kotlin 2.4 / JDK 17 (template defaults) | 24 is the floor for Flutter 3.47 and audio_session. 36 has been mandatory on Play since 2026-08-31. |
| Audio stack | just_audio 0.10.6 (Media3 ExoPlayer) + audio_service 0.18.19 (FGS, MediaSession, notification, media buttons) + audio_session 0.2.4 (focus, becoming-noisy) | The only mature permissively licensed stack with a MediaBrowserService (Android Auto in v1.1). |
| Engine seam | `AudioEngine` facade (domain terms) → `RadioAudioHandler` (BaseAudioHandler, command executor) → `StreamPlayer` port (`JustAudioStreamPlayer`), plus `AudioSessionPort`, `ConnectivityPort` and `WifiLockPort` | The engine can be swapped (e.g. native Media3) without touching the UI. The fakes make the core logic unit-testable. |
| Import boundary | Only `lib/features/playback/engine/**` and `lib/app/bootstrap.dart` may import just_audio, audio_service, audio_session or connectivity_plus; enforced by a CI grep | Keeps the swap cost at one folder plus one line in bootstrap. |
| One code path | The UI's `engine.play()` routes through `handler.playFromMediaId`, the same path Bluetooth, the notification and (v1.1) Android Auto use | Everything that works from the UI also works from the car. |
| Playback logic | A pure `PlaybackStateMachine` reducer (events → next state + commands) with a generation guard on every async result; the full FGS/lock/focus table (RESEARCH 319-328) | The reliability rules (Interrupted, reconnect, budget, PLAY-10 guards) are testable with fakeAsync, with no device. |
| FGS policy | Connecting, Playing, Buffering, Reconnecting and Interrupted publish `playing: true` (FGS kept). Paused and Error drop the FGS but keep a swipeable notification. Idle stops the service. `androidStopForegroundOnPause: true` | Android 12/15/17 background-start and focus rules (Pitfall 1). Battery rule: no FGS when not playing. |
| Live radio semantics | Pause = stop the transport; resume = a fresh load at the live edge; no seek anywhere; `completed` = disconnect → reconnect | Live streams are not files (Pitfall 2). |
| Stream identity | `Station.streams[]`, ordered primary then fallbacks, with no singular URL field; a namespaced `StationId` (`curated:`, `debug:`, later `rb:`); media ids `station/<ns>:<id>` and `node/...` | Assumption-delta decision "promote". Stable ids for favourites (Phase 3) and Auto (v1.1). |
| Stream resolution | A Dart `HttpStreamResolver` for `.pls`/`.m3u`/unknown (64 KB, 5 s, ≤5 redirects, depth ≤3, ≤10 candidates, http/https only, 1 h cache); explicit `HlsAudioSource`/`ProgressiveAudioSource`, never extension sniffing | ExoPlayer does not parse playlists. HLS is detected by content, not only by extension. |
| Network security | `base-config cleartextTrafficPermitted="true"` for native media sockets; a Dart `AppHttpClient` is HTTPS-only for app-owned traffic; `MediaHttpClient` (http/https) is used only for playlist resolution | Official Bulgarian streams are often plain http:// on arbitrary hosts, and Dart sockets ignore the NSC. |
| State management | Riverpod 3 with codegen. Providers are read-only mirrors of engine streams. `ProviderContainer(retry: null)` shared with the handler via `UncontrolledProviderScope` | Reconnect logic lives only in the engine (no provider auto-retry). |
| Data layer | Phase 1 has no database. Stations are Dart constants (`phase1_stations.dart`, debug list gated by `!kReleaseMode`). One local write/read: `first_launch_at` (UTC ISO-8601, write-once) via `SharedPreferencesAsync` | The persistence proof for the skeleton is the first-launch date. drift and the remote catalogue arrive in Phase 2/3. |
| Auth | None: no accounts in v1 | Out of scope (REQUIREMENTS "Out of Scope"). |
| Localisation | gen-l10n, BG + EN ARB in `lib/l10n/`, generated code committed; `bg` device → Bulgarian, otherwise English; `EngineStrings` below the UI | D-08; the notification needs strings without a BuildContext. |
| Deployment | GitHub Actions: `ci.yml` (PR/main: build_runner staleness, analyze, dart analyze, test, deny-list, import boundary, release-manifest checks); `release.yml` (v* tags + dispatch: signed AAB + APK artifacts). Local: `flutter run --release` | D-15. No secrets on PRs; upload key only (Play App Signing in Phase 4). |
| Directory layout | Feature-first: `lib/app/` (bootstrap, app, home), `lib/core/{network,text,settings}`, `lib/features/catalog/{domain,data,application}`, `lib/features/playback/{domain,engine,application,presentation}`; `test/` mirrors `lib/` | ARCHITECTURE "Recommended Project Structure". Later phases add features without moving the engine. |
| Codegen | freezed + riverpod_generator + gen-l10n outputs committed; CI fails on stale output | D-17. |

## Stack Touched in Phase 1

- [x] Project scaffold: framework, build, lint (flutter_lints + riverpod_lint via `dart analyze`), test runner (flutter_test + fake_async + mocktail) — 01-01
- [x] Routing: a single home route (station list + mini-player). go_router with the shell and persistent mini-player arrives in Phase 2 — 01-01
- [x] Persistence: one real write and one real read (`first_launch_at` via SharedPreferencesAsync) — 01-01 Task 2
- [x] UI: station tile tap → `AudioEngine.play` → audible playback; the mini-player's play/pause/stop — 01-01 Task 1
- [x] Deployment: signed release AAB/APK from CI on tags; documented local full-stack run `flutter run --release` on a physical phone — 01-02

## Out of Scope (Deferred to Later Slices)

- Remote/bundled curated catalogue, JSON schema, Radio Browser, search, browse tabs, logos, go_router shell, banner slot (Phase 2)
- Favourites, recents, one-tap resume, now-playing screen, next/previous in the notification, sleep timer, share, theme toggle, edge-to-edge polish, user-facing trip/battery-saver toggle (Phase 3)
- Friendly error UX, "report broken station", battery-optimisation hint, full accessibility audit, performance budget, Play closed test and release (Phase 4)
- Android Auto browse tree and car-screen testing, and moving the Wi-Fi lock channel into a plugin (v1.1)
- Any ads, analytics, crash reporting or tracking SDK (not in v1)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without changing its architectural decisions:

- Phase 2: a listener finds and plays any Bulgarian station by network, city, genre or name (Cyrillic or Latin), and any worldwide station, from a remotely updatable catalogue that works offline.
- Phase 3: a listener keeps favourites and recents, resumes the last station with one tap, uses next/previous from the car, and gets a full now-playing screen, sleep timer and sharing in BG or EN.
- Phase 4: a hardened, accessible, privacy-compliant app passes a Play closed test and ships to production.
