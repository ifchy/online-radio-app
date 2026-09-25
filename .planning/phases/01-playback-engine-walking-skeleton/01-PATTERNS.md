# Phase 1: Playback Engine & Walking Skeleton - Pattern Map

**Mapped:** 2026-09-25
**Files analyzed:** 58 (new; the only modified tracked file is `.gitignore`)
**Analogs found:** 0 / 58 in code. The repo is greenfield. `git ls-files` shows only `.gitignore`, `docs/BRIEF.md` and `.planning/**` (`.claude/**` is excluded as an analog source).

Because there is no code to copy from, every file below maps to a **canonical pattern source** in the research documents. The planner should cite these sources in plan actions, in the form "implement per 01-RESEARCH.md §Pattern 3 (lines 372-403)". Line numbers are for the files as of 2026-09-25.

Abbreviations:
- **R** = `.planning/phases/01-playback-engine-walking-skeleton/01-RESEARCH.md`
- **A** = `.planning/research/ARCHITECTURE.md`
- **P** = `.planning/research/PITFALLS.md`
- **S** = `.planning/research/STACK.md` / `.claude/CLAUDE.md` (pinned versions)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Pattern Source | Plan (R §Slicing) |
|---|---|---|---|---|---|
| `pubspec.yaml` (+ `pubspec.lock`) | config | — | none (greenfield) | R §Standard Stack install cmds (181-193); `flutter: generate: true` (R 536, 777) | 01 |
| `analysis_options.yaml` | config | — | none | R 769-776 | 01 |
| `l10n.yaml` | config | — | none | R 762-768 (NO `synthetic-package` key, Pitfall C R 534-536) | 01 |
| `lib/l10n/app_en.arb`, `lib/l10n/app_bg.arb` (+ generated `app_localizations*.dart`, committed) | config / i18n | transform | none | R 777; D-08/D-09 labels; R Open Q 6 (`stateInterrupted`); A Pattern 13 (471-479) | 01 (labels 03) |
| `.gitignore` (modify: add `*.b64`) | config | — | itself | R 865 | 01 |
| `lib/main.dart` | entrypoint | — | none | A Pattern 1 (177-215) | 01 |
| `lib/app/bootstrap.dart` | composition root / provider | request-response (init) | none | A Pattern 1 (177-215); R `AudioService.init` (682-699), incl. `ProviderContainer(retry: (_, __) => null)` + `UncontrolledProviderScope` | 01 |
| `lib/app/app.dart` | component (MaterialApp) | — | none | R 777 (`localeResolutionCallback` bg→bg else en); A Pattern 13 | 01 |
| `lib/app/home_screen.dart` | component | event-driven (ref.watch) | none | D-06; R Structure (255-287) | 01 |
| `lib/core/network/app_http_client.dart` | utility (HTTP guard) | request-response | none | R 600 (`extends http.BaseClient`, reject non-https); A Anti-Pattern 10 (645-656) | 02 |
| `lib/core/network/media_http_client.dart` | utility | request-response | none | R 600 (http+https only) | 02 |
| `lib/core/network/user_agent.dart` | utility | transform | none | R 377 (UA format, no "Mozilla"); package_info_plus | 01 |
| `lib/core/text/cp1251.dart` | utility | transform (pure) | none | R 701-744 (full table + `repairCp1251`, copy verbatim) | 02 |
| `lib/core/text/sanitize.dart` | utility | transform (pure) | none | R Pattern 5 (420-426) | 02 |
| `lib/core/settings/settings_repository.dart` | service / repository | CRUD (write-once) | none | R 746-759 (`ensureFirstLaunchAt`) | 01 |
| `lib/features/catalog/domain/station.dart` (Station, StationId, StationStream, StreamKind, IcyCharset) | model (freezed) | — | none | R Structure 269; R Pattern 4 input shape (407) | 01 |
| `lib/features/catalog/data/phase1_stations.dart` | model / data | — | none | R Station Matrix (446-487); D-01..D-04 | 01 (1 station) → 02 (6) |
| `lib/features/catalog/data/debug_stations.dart` | model / data | — | none | R Matrix rows 463-466; Pitfall I (554-555), `!kReleaseMode` only | 02 |
| `lib/features/playback/domain/audio_engine.dart` | service interface (facade) | event-driven | none | A Pattern 2 (216-250) | 01 |
| `lib/features/playback/domain/playback_status.dart` (sealed) | model (freezed sealed) | — | none | R Pattern 2 state table (319-328); A Pattern 3 (251-282) | 01 (min) → 03 |
| `lib/features/playback/domain/now_playing.dart` | model | — | none | R Pattern 5 | 02 |
| `lib/features/playback/domain/play_context.dart` | model (sealed) | — | none | R Pattern 6 (428-433) | 03 |
| `lib/features/playback/domain/media_id.dart` | utility (pure parse/format) | transform | none | R Pattern 6 (430); A Android Auto (528-549) | 01 |
| `lib/features/playback/domain/retry_budget.dart` (or `engine/`) | model / policy | — | none | R 358-368; D-10 | 03 |
| `lib/features/playback/domain/engine_strings.dart` | model | — | none | A Pattern 13 (471-479); A Anti-Pattern 8 (636-640) | 01 |
| `lib/features/playback/engine/radio_audio_handler.dart` | service (BaseAudioHandler) | event-driven | none | R Pattern 2 FGS table + transitions (312-356); A Pattern 2; P Pitfall 1 (15-41), 14 (315-338) | 01 (thin) → 03 |
| `lib/features/playback/engine/audio_service_engine.dart` | service (facade impl) | event-driven | none | A Pattern 2; R "one code path" (433) | 01 |
| `lib/features/playback/engine/state_machine.dart` | service (pure reducer) | event-driven | none | R 334-356 transitions; A Pattern 3 (251-282) | 03 |
| `lib/features/playback/engine/reconnect_policy.dart` | utility (pure) | batch/timer | none | R 370 backoff; A Pattern 4 (283-305) | 03 |
| `lib/features/playback/engine/ports.dart` | interface | event-driven | none | R diagram 228-250 | 01 (StreamPlayer) → 03 |
| `lib/features/playback/engine/just_audio_stream_player.dart` | adapter | streaming | none | R Pattern 3 (372-403, copy code block 374-396) | 01 |
| `lib/features/playback/engine/audio_session_port_impl.dart` | adapter | event-driven | none | R Pattern 1 mapping table (289-310) | 03 |
| `lib/features/playback/engine/connectivity_port_impl.dart` | adapter | event-driven | none | R 346-347; Don't Hand-Roll 513 | 03 |
| `lib/features/playback/engine/wifi_lock_channel.dart` | adapter (MethodChannel) | request-response | none | R 602-642 (channel `bg.izk.radio/wifi_lock`; `MissingPluginException` = no-op) | 03 |
| `lib/features/playback/engine/resolver/stream_resolver.dart` | service | request-response + cache | none | R Pattern 4 (405-418); A Pattern 6 (319-342); P Pitfall 7 (152-174) | 02 |
| `lib/features/playback/engine/resolver/pls_parser.dart`, `m3u_parser.dart` | utility (pure) | transform | none | R 413-415 | 02 |
| `lib/features/playback/engine/icy/now_playing_parser.dart` | utility | streaming → transform | none | R Pattern 5 (420-426); A Pattern 7 (343-359); A Anti-Pattern 9 (641-644) | 02 |
| `lib/features/playback/application/*_provider.dart` (playbackStatus, nowPlaying, currentStation, debugLog) | provider | event-driven | none | A Pattern 11 (426-440); A Anti-Pattern 1 (601-605) | 01 → 03 |
| `lib/features/playback/presentation/mini_player.dart` | component | event-driven | none | D-06, D-09; accessibility constraints (TalkBack, ≥48 dp) | 01 |
| `lib/features/playback/presentation/state_label.dart` | component | transform | none | D-09 + R Open Q 6 | 03 |
| `lib/features/playback/presentation/debug_panel.dart` | component (debug only) | event-driven | none | D-07; `!kReleaseMode` guard | 03 |
| `android/app/src/main/AndroidManifest.xml` (modify template) | config | — | `flutter create` template | R 562-586; Pitfall A (524-527) | 01 |
| `android/app/src/main/res/xml/network_security_config.xml` | config | — | none | R 588-599 (verbatim) | 01 |
| `android/app/src/main/res/drawable/ic_stat_radio.xml` | asset | — | none | R 691 (monochrome vector) | 01 |
| `android/app/src/main/kotlin/bg/izk/radio/MainActivity.kt` (modify template) | platform adapter | request-response | template | R 602-642 (verbatim) | 01 (base class) / 03 (Wi-Fi lock) |
| `android/app/build.gradle.kts` (modify template) | config | — | template | R 644-680 | 01 |
| `.github/workflows/ci.yml` | config (CI) | batch | none | R 779-802 (verbatim) | 01 |
| `.github/workflows/release.yml` | config (CI) | batch | none | R 804-847 (verbatim) | 01 |
| `docs/` keystore guide (e.g. `docs/RELEASE-SIGNING.md`) | docs | — | `docs/BRIEF.md` (style only) | R 849-865 | 01 |
| `test/support/fakes.dart` | test | — | none | R Wave 0 (997-1000) | 01 → 03 |
| `test/fixtures/playlists/*` | test fixture | — | none | R 998 (file names) | 02 |
| `test/features/playback/engine/state_machine_test.dart`, `reconnect_policy_test.dart`, `radio_audio_handler_test.dart` | test | — | none | R Test Map 971-973 (`fakeAsync`) | 03 |
| `test/features/playback/engine/resolver/*_test.dart` | test | — | none | R 974 (`MockClient`, `MockClient.streaming`) | 02 |
| `test/core/text/*_test.dart` | test (golden) | — | none | R 975; goldens at R 742 | 02 |
| `test/core/network/*_test.dart` | test | — | none | R 976 | 02 |
| `test/core/settings/settings_repository_test.dart` | test | — | none | R 977, 748-750 (`InMemorySharedPreferencesAsync`) | 01 |
| `test/features/catalog/*_test.dart` | test | — | none | R 978 (release list has no `debug:` IDs) | 02 |
| `test/features/playback/presentation/*_test.dart`, `test/features/playback/domain/*_test.dart` | test | — | none | R 979-980 | 01/03 |

## Pattern Assignments

No in-repo analogs exist. Every assignment names the research excerpt to follow. Where the research gives a complete code block, **copy it verbatim** and adapt only names.

### `lib/app/bootstrap.dart` (composition root)
**Source:** A Pattern 1 (lines 177-215) + R lines 682-699.
```dart
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration.music());
final handler = await AudioService.init(
  builder: () => RadioAudioHandler(/* ports + stations + EngineStrings */),
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'bg.izk.radio.playback',
    androidNotificationChannelName: 'Playback',
    androidNotificationIcon: 'drawable/ic_stat_radio',
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: true,
    androidResumeOnClick: true,
  ),
);
// ProviderContainer(overrides: [...], retry: (_, __) => null) -> UncontrolledProviderScope
```
Order: prefs → `ensureFirstLaunchAt` → session.configure → `AudioService.init` → container. `bootstrap.dart` is the only file outside `engine/` that may import the plugin packages (the CI grep at R 799-800).

### `lib/features/playback/engine/just_audio_stream_player.dart` (adapter, streaming)
**Source:** R lines 374-396 (copy the whole block) + rules at R 399-403.
- `AudioPlayer(userAgent:, useProxyForRequestHeaders: false, handleInterruptions: false, handleAudioSessionActivation: true, audioLoadConfiguration: ...)`
- `load()`: `await stop()` → `HlsAudioSource`/`ProgressiveAudioSource` chosen by `kind` → `setAudioSource(preload: false)` → `unawaited(play())`
- Errors come from `errorStream`. Ignore `PlayerInterruptedException`. Tag every event with its `generation`.

### `lib/features/playback/engine/radio_audio_handler.dart` + `state_machine.dart`
**Source:** R State/FGS table (319-328) and transitions (334-356); A Pattern 3 (251-282); A Pattern 4 (283-305); A Pattern 5 (306-318).
- Invariant: Connecting, Reconnecting and Interrupted publish `playing: true`. Only Paused, Error and Idle publish `playing: false`.
- `androidCompactActionIndices: [0, 1]`, `systemActions: const {}`.
- The engine calls `session.setActive(false)` on pause, stop and error (Pitfall F, R 544-545).
- In `play()`, publish `playing:true, loading` before any `player.play()` (Pitfall G, R 547-549).
- The state machine is a pure reducer that emits Commands (R diagram 238-247). Test it with `fakeAsync` and fakes.

### `lib/features/playback/engine/resolver/*`
**Source:** R Pattern 4 (405-418); A Pattern 6 (319-342).
Limits: 5 s timeout, 64 KB, ≤5 redirects, depth ≤3, ≤10 candidates, scheme allow-list http/https. `#EXTM3U` + `#EXT-X-` → HLS on the original URL. 1 h in-memory cache, invalidated on error.

### `lib/core/text/cp1251.dart`
**Source:** R lines 703-742. Copy the table, `_cp1252Reverse`, `IcyCharset` and `repairCp1251` verbatim. The goldens are on line 742.

### `lib/core/settings/settings_repository.dart`
**Source:** R lines 751-758 (`ensureFirstLaunchAt(SharedPreferencesAsync, Clock)`, key `first_launch_at`, UTC ISO-8601).

### `lib/features/playback/domain/media_id.dart` + `play_context.dart`
**Source:** R Pattern 6 (428-433). IDs: `station/curated:<id>`, `station/debug:<id>`, `node/...`. `sealed class PlayContext { single(); list(ids, {source}); }`.

### Android files
- `AndroidManifest.xml`: R 563-586. It must add `INTERNET` (Pitfall A), the FGS permissions, the AudioService service and MediaButtonReceiver, `networkSecurityConfig`, and the label `eRadioto`. Do NOT add `POST_NOTIFICATIONS`.
- `network_security_config.xml`: R 589-598 verbatim.
- `MainActivity.kt`: R 605-640 verbatim (`AudioServiceActivity` + `WifiLockChannel`).
- `build.gradle.kts`: R 647-676. Never throw when `key.properties` is missing (R 680).

### CI
- `ci.yml`: R 780-801 verbatim. It runs both `flutter analyze` and `dart analyze` (Pitfall B), plus `git diff --exit-code` after codegen (D-17), the tracking-SDK deny-list and the engine import-boundary grep.
- `release.yml`: R 805-840 verbatim. Its checks: debug-cert rejection, the `dead-primary.invalid` strings check, and keystore cleanup `if: always()`.

## Shared Patterns

### Engine import boundary
**Source:** R 799-800; A Anti-Pattern 2 (606-610).
**Apply to:** all `lib/**`. Only `lib/features/playback/engine/**` and `lib/app/bootstrap.dart` may import `just_audio`, `audio_service`, `audio_session` or `connectivity_plus`.

### Generation guard for async results
**Source:** R 355, 402.
**Apply to:** the stream player, resolver, ICY parser and state machine. Drop any event whose generation is not the current one.

### Localisation below the UI
**Source:** A Pattern 13 (471-479), A Anti-Pattern 8 (636-640).
**Apply to:** the engine and handler. They use the `EngineStrings` value object and never `BuildContext`. Import generated l10n via `package:radio/l10n/app_localizations.dart`, never `flutter_gen`.

### Riverpod usage
**Source:** A Pattern 11 (426-440); R 699.
**Apply to:** `application/` providers. Providers only mirror engine streams. Global retry is disabled. No playback logic in autoDispose providers (A Anti-Pattern 1).

### Debug-only code
**Source:** R Pitfall I (554-555); D-05/D-07.
**Apply to:** `debug_stations.dart` and `debug_panel.dart`. Reference them only under `if (!kReleaseMode)`. Back this with a unit test (R 978) and the release.yml strings check.

### Codegen
**Source:** D-17; R 170-171.
**Apply to:** freezed and riverpod files. Commit `*.g.dart` and `*.freezed.dart`. The analyzer excludes them (R 773).

### Testing fakes
**Source:** R Wave 0 (997-1000).
**Apply to:** all engine tests. Use `test/support/fakes.dart` (`FakeStreamPlayer`, `FakeAudioSessionPort`, `FakeConnectivityPort`, `FakeWifiLockPort`, `FakeEngine`) with `fakeAsync`, `MockClient` and `InMemorySharedPreferencesAsync`.

## No Analog Found

All 58 files have no in-repo analog: the repo is greenfield. The planner should use the pattern sources above (R / A / P / S sections) instead of codebase excerpts. The Android files start from `flutter create` template output, which the research verified (R 193), and are then modified per R §Code Examples.

## Metadata

**Analog search scope:** `git ls-files` for the whole repo (excluding `.claude/`); headings in `.planning/research/ARCHITECTURE.md` and `PITFALLS.md`
**Files scanned:** 20 tracked files + 2 phase docs
**Pattern extraction date:** 2026-09-25
