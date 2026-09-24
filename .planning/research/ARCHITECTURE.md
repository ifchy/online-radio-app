# Architecture Research

**Domain:** Flutter (Android-first) live internet radio app. Bulgarian curated catalogue, Radio Browser for worldwide stations, background media playback.
**Researched:** 2026-09-24
**Confidence:** MEDIUM overall. Package facts were read directly from pub.dev, the audio_service wiki and the Radio Browser API docs. The GSD `classify-confidence` seam rates WebFetch sources as LOW, so each package fact below carries a tag. The architectural recommendations are reasoned from those facts plus established Flutter/ExoPlayer patterns. Items marked **VERIFY** must be confirmed on a physical phone in the phase that builds them.

---

## Standard Architecture

### The one idea that shapes everything

A radio app has **two independent "heads"** that control and observe playback:

1. **The Flutter UI**: screens, mini-player, now-playing.
2. **The OS media session**: notification, lock screen, Bluetooth/AVRCP, headset buttons, system media-resumption card, and Android Auto in v1.1.

The UI can disappear completely while head 2 keeps running. That happens when the screen is off, when the activity is destroyed after a swipe-away, or when Android Auto starts the service with no activity at all. Some rules follow from this:

- Playback state, the reconnect state machine, the ICY now-playing text and the sleep timer live **below** the UI. They go in a long-lived object that is created in `main()` and does not depend on widgets. In audio_service terms, that object is the `AudioHandler`.
- The UI is a **subscriber and command sender only**. It never talks to `just_audio` directly.
- Anything the media session may need without the UI must be reachable from the handler as plain Dart objects, with no `BuildContext` or widget-scoped providers. That covers the station repository, the search index, favourites and recents. This is what makes the Android Auto browse tree (v1.1) and "play from search" possible later without a rewrite.

audio_service 0.18.x runs the `AudioHandler` **in the main isolate**. Since 0.18 there has been no separate background isolate, and `IsolatedAudioHandler` exists only for callers in other isolates. The service keeps the shared FlutterEngine alive after the activity dies, which is why the activity must extend `AudioServiceActivity`. So you do **not** need an isolate or message-passing layer. Riverpod, drift and the handler all share one isolate and one `ProviderContainer`. [pub.dev audio_service 0.18.19 + wiki FAQ, via WebFetch; seam tier LOW, primary source]

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ PRESENTATION  (features/*/presentation)          Flutter widgets, go_router   │
│  ┌───────────┐ ┌───────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌───────┐ │
│  │ BG Home   │ │ World /   │ │ Library  │ │ Now      │ │ Mini-   │ │Settings│ │
│  │ (nat/city │ │ Search    │ │ (favs,   │ │ Playing  │ │ player  │ │About  │ │
│  │  /genre)  │ │           │ │ recents) │ │ screen   │ │ (shell) │ │Report │ │
│  └─────┬─────┘ └─────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ └───┬───┘ │
│        │ ref.watch / ref.read(...notifier)  (never touches data sources)│     │
├────────┴─────────────┴────────────┴────────────┴────────────┴──────────┴─────┤
│ APPLICATION  (features/*/application)       Riverpod Notifiers / Stream-     │
│  catalogProvider · bulgariaHomeProvider · searchResultsProvider(q) ·         │
│  favouritesProvider · recentsProvider · playbackStatusProvider ·             │
│  nowPlayingProvider · sleepTimerProvider · localeProvider · themeProvider    │
├──────────────────────────────────────────────────────────────────────────────┤
│ DOMAIN + SERVICES  (features/*/domain, pure Dart, unit-testable)             │
│  ┌──────────────────────── AudioEngine (facade interface) ────────────────┐ │
│  │  impl: AudioServiceEngine ──wraps──▶ RadioAudioHandler (BaseAudioHandler)│ │
│  │     ├─ PlaybackStateMachine (idle/connecting/buffering/playing/         │ │
│  │     │                        reconnecting/error)                        │ │
│  │     ├─ ReconnectPolicy (backoff+jitter, fallback-stream rotation)       │ │
│  │     ├─ StallWatchdog · ConnectivityMonitor · AudioSession events        │ │
│  │     ├─ StreamResolver (.pls/.m3u/HLS sniff → ResolvedStream)            │ │
│  │     ├─ NowPlayingParser (ICY → artist/title, cp1251 repair)             │ │
│  │     ├─ MediaLibraryTree (browse tree; v1: recents root only)            │ │
│  │     └─ StreamPlayer port ──impl──▶ JustAudioStreamPlayer (just_audio)   │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│  StationRepository (merge curated + RB) · SearchIndex (translit fold) ·      │
│  LibraryRepository (favs/recents) · SettingsRepository · SleepTimer          │
├──────────────────────────────────────────────────────────────────────────────┤
│ DATA SOURCES  (features/*/data, core/*)                                      │
│  ┌───────────────┐ ┌───────────────┐ ┌──────────────┐ ┌──────────────────┐  │
│  │ Bundled asset │ │ Curated remote│ │ RadioBrowser │ │ drift AppDatabase│  │
│  │ stations-bg   │ │ (jsDelivr/raw │ │ client +     │ │ (catalog cache,  │  │
│  │ .json         │ │  GH, ETag)    │ │ ServerPool   │ │ favs, recents,   │  │
│  └───────────────┘ └───────────────┘ └──────────────┘ │ resolved urls)   │  │
│  ┌──────────────────────┐ ┌──────────────────────┐    └──────────────────┘  │
│  │ SharedPreferences    │ │ HttpClient (UA, TO)  │                          │
│  │ (settings, lastStn,  │ │ connectivity_plus    │                          │
│  │  firstLaunchDate)    │ │                      │                          │
│  └──────────────────────┘ └──────────────────────┘                          │
├──────────────────────────────────────────────────────────────────────────────┤
│ PLATFORM (Android)  audio_service MediaBrowserService + MediaSession (legacy │
│  androidx.media) · Media3 ExoPlayer (inside just_audio) · AudioFocus via     │
│  audio_session · Notification · (v1.1) Android Auto                          │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Dependency direction is strictly downward.** Presentation depends on Application, Application on Domain, and Domain on data-source *interfaces*. The one exception is the composition root (`bootstrap.dart`), which wires the concrete implementations together.

### Component Responsibilities

| Component | Owns | Does NOT own | Implementation |
|-----------|------|--------------|----------------|
| **AudioEngine** (interface) | The app-facing playback API in domain terms: `play(Station, {PlayContext})`, `stop()`, `togglePause()`, `skipNext/Prev`, `Stream<PlaybackStatus>`, `Stream<NowPlaying?>`, `Stream<Station?>` | Anything about just_audio, audio_service or Android | Abstract Dart class in `features/playback/domain`. **This is the replaceability seam.** A future native Media3 module would replace *both* audio_service and just_audio, so the seam has to sit above both. |
| **AudioServiceEngine** | Adapts the `AudioEngine` API onto the `RadioAudioHandler`: maps `Station` → `MediaItem`, and handler streams → domain streams | UI | Thin adapter class |
| **RadioAudioHandler** | The single source of truth for playback. Handles media-session callbacks (play/pause/stop/skip/`playFromMediaId`/`playFromSearch`/`getChildren`), publishes `PlaybackState` and `MediaItem`, and hosts the state machine | Widgets, localisation lookup (receives an `EngineStrings` object) | `extends BaseAudioHandler with QueueHandler`, created once in `main()` via `AudioService.init` |
| **PlaybackStateMachine** | The explicit states and legal transitions. It turns player events, connectivity events and timer events into commands | I/O. It emits *commands* (`Load(url)`, `Stop`, `ScheduleRetry(d)`) that the handler executes | Pure Dart; unit-tested with a fake clock and fake player |
| **ReconnectPolicy** | Backoff schedule, jitter, retry budget, fallback-stream rotation order | When to trigger a retry (that is the state machine's job) | Pure Dart value object |
| **StallWatchdog** | Detects "we intend to play but have been buffering > N s" | — | `Timer` driven by `processingState` |
| **ConnectivityMonitor** | Emits `online/offline/networkChanged` | Retry decisions | `connectivity_plus` stream, debounced |
| **StreamResolver** | Turns a station stream URL into `ResolvedStream{uri, kind: progressive/hls}` by parsing `.pls`/`.m3u`, sniffing content-type, following nested playlists (depth ≤ 3) and caching results | Playback | Pure Dart with an injected `HttpClient`; parser unit tests |
| **NowPlayingParser** | ICY `StreamTitle` → `NowPlaying{artist?, title, raw}`. Splits on " - ", drops junk and station slogans, repairs cp1251 mojibake, de-duplicates | Display formatting | Pure Dart |
| **MediaLibraryTree** | Maps media IDs ↔ browse nodes (root → favourites / recents / BG national / city / genre). In v1 only the `recent` root is used, for system media resumption | — | Pure Dart; reads repositories |
| **StationRepository** | The merged station catalogue. Curated wins. Handles ID aliasing (RB uuid → curated id), exposes lookups by id, city, genre and network, and `Stream<Catalog>` | Search ranking | Class over three sources + drift DAO |
| **CuratedCatalogSource** | Bundled snapshot load, remote fetch with `If-None-Match`, schema/version validation, cache write | Merging | `data/curated/` |
| **RadioBrowserClient + ServerPool** | Server discovery, random failover, `User-Agent`, search, `byuuid`, click registration | Merge policy | `data/radio_browser/` |
| **SearchIndex** | Folded search keys (script- and diacritic-insensitive), ranking, fuzzy matching over the local BG set. Also runs the dual-script query fan-out to Radio Browser for world search | Station storage | Pure Dart; built off the UI thread when large |
| **LibraryRepository** | Favourites (ordered), recents (capped), and a station snapshot per entry | — | drift DAO with `watch()` streams |
| **SettingsRepository** | Locale override, theme override, `firstLaunchDate` (write-once), last-station snapshot, one-time flags (battery hint, notification-permission asked) | — | `SharedPreferencesWithCache` / `SharedPreferencesAsync` |
| **SleepTimer** | Deadline (duration or "end of current hour"), countdown stream, optional fade-out, then `engine.stop()` | — | Pure Dart with a `Clock`; lives next to the engine, **not** in a widget |
| **AppRouter / Shell** | Routes, persistent mini-player, bottom navigation, future banner slot | Playback logic | go_router `StatefulShellRoute.indexedStack` |

---

## Recommended Project Structure

The layout is feature-first, with a thin `core/` for cross-cutting infrastructure. The Flutter project root **is** the repo root, so `catalog/stations-bg.json` can be declared directly as an asset. There is only one copy of the file, and the bundled snapshot is always the committed catalogue.

```
/
├── catalog/
│   ├── stations-bg.json            # curated catalogue (also the bundled asset)
│   └── stations-bg.schema.json     # JSON Schema; CI validates the catalogue against it
├── tool/
│   ├── validate_catalog.dart       # schema + uniqueness + id stability checks (CI)
│   └── probe_streams.dart          # resolves & probes every stream URL (manual/CI cron)
├── android/app/src/main/
│   ├── AndroidManifest.xml         # AudioService, MediaButtonReceiver, FGS mediaPlayback
│   └── res/xml/network_security_config.xml
├── lib/
│   ├── main.dart                   # calls bootstrap(); nothing else
│   ├── app/
│   │   ├── bootstrap.dart          # COMPOSITION ROOT: prefs, db, container, AudioService.init
│   │   ├── app.dart                # MaterialApp.router, l10n delegates, theme
│   │   ├── router.dart             # go_router config, shell, route names
│   │   ├── shell_scaffold.dart     # NavigationBar + MiniPlayer + BannerSlot(empty in v1)
│   │   └── theme.dart
│   ├── core/
│   │   ├── database/app_database.dart   # drift DB: lists tables from features, migrations
│   │   ├── network/http_client.dart     # shared client, User-Agent, timeouts
│   │   ├── network/connectivity.dart
│   │   ├── prefs/prefs_keys.dart
│   │   ├── text/bg_transliteration.dart # official 2009 BG table, both directions
│   │   ├── text/fold.dart               # search-key folding pipeline
│   │   ├── text/cp1251.dart             # mojibake repair for ICY
│   │   ├── clock.dart                   # injectable Clock for timers/tests
│   │   └── logging.dart                 # local ring-buffer log (no tracking)
│   ├── l10n/
│   │   ├── app_en.arb              # template (keys + @descriptions)
│   │   └── app_bg.arb              # reviewed by owner
│   └── features/
│       ├── playback/
│       │   ├── domain/        # AudioEngine, PlaybackStatus, NowPlaying, PlayContext, EngineStrings
│       │   ├── engine/        # RadioAudioHandler, AudioServiceEngine, state_machine.dart,
│       │   │                  # reconnect_policy.dart, stall_watchdog.dart,
│       │   │                  # stream_player.dart (port) + just_audio_stream_player.dart,
│       │   │                  # resolver/{stream_resolver,pls_parser,m3u_parser}.dart,
│       │   │                  # icy/now_playing_parser.dart, media_library_tree.dart
│       │   ├── application/   # playback providers, sleep_timer.dart
│       │   └── presentation/  # mini_player.dart, now_playing_screen.dart, sleep_timer_sheet.dart
│       ├── catalog/
│       │   ├── domain/        # Station, StationId, StationStream, Region, Genre, Catalog
│       │   ├── data/          # curated/{bundled,remote,dto}, radio_browser/{server_pool,client,dto},
│       │   │                  # catalog_dao.dart, station_repository.dart, merge.dart
│       │   ├── application/   # catalogProvider, bulgariaHomeProvider, worldBrowseProviders
│       │   └── presentation/  # bulgaria_home, city/genre lists, world browse, station_tile, station_logo
│       ├── search/
│       │   ├── domain/        # search_index.dart, scorer.dart
│       │   ├── application/   # searchResultsProvider(query)
│       │   └── presentation/
│       ├── library/           # favourites + recents: data (dao), application, presentation
│       ├── settings/          # settings repo, language/theme, about, licences, battery hint
│       └── report/            # "report broken station" (mailto via url_launcher)
└── test/                      # mirrors lib/; heavy on engine/, resolver/, text/, search/, merge
```

### Structure Rationale

- **`features/playback/engine/` is isolated.** It is the only folder that imports `just_audio` and `audio_service`, and a lint or grep check in CI should enforce that. Swapping in a Media3 engine later means replacing this folder and one line in `bootstrap.dart`.
- **`features/catalog/domain` is the shared kernel.** `Station` is used by playback, library, search and presentation. Define it **in Phase 1**, even though the catalogue arrives in Phase 2, so the hard-coded skeleton stations use the real model and nothing is re-typed later.
- **`core/database/app_database.dart` is central on purpose.** A drift `@DriftDatabase(tables: [...])` needs one class that lists every table. The table and DAO definitions stay in their features, and only the database class and migrations live in `core`.
- **`core/text/` holds language logic.** Transliteration, folding and cp1251 are used by search, the ICY parser and catalogue tooling. They are pure functions with dense unit tests.
- **`app/bootstrap.dart` is the only file that knows every concrete class.** Everything else receives dependencies through constructors or providers.

---

## Architectural Patterns

### Pattern 1: Composition root in `main()`, where the handler and ProviderContainer share one graph

**What:** Build the `ProviderContainer` *before* `runApp`, build repositories from it, pass them to the `AudioHandler` as plain objects, then hand the same container to the widget tree with `UncontrolledProviderScope`.
**Why:** The handler must work without widgets (screen off, activity destroyed, Android Auto in v1.1), and it must see the same repositories as the UI (for example, favourites changed in the UI become visible to the car browse tree).
**Trade-offs:** `main()` gets more involved and needs care for cold start < 2 s. Keep only the essentials before the first frame: prefs, lazy drift open, `AudioService.init`, and loading the bundled catalogue.

```dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferencesWithCache.create(cacheOptions: ...);
  final db = AppDatabase(driftDatabase(name: 'radio')); // opens lazily, background isolate
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(prefs),
    databaseProvider.overrideWithValue(db),
  ]);
  await container.read(settingsRepositoryProvider).ensureFirstLaunchDate(); // write-once

  final handler = await AudioService.init(
    builder: () => RadioAudioHandler(
      player: JustAudioStreamPlayer(userAgent: kUserAgent),
      resolver: container.read(streamResolverProvider),
      stations: container.read(stationRepositoryProvider),
      library: container.read(libraryRepositoryProvider),
      connectivity: container.read(connectivityProvider),
      strings: EngineStrings.forLocale(PlatformDispatcher.instance.locale),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: '<appId>.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true, // battery: no FGS while paused
    ),
  );
  container.updateOverrides([... , audioEngineProvider.overrideWithValue(AudioServiceEngine(handler))]);
  // (or: create engine provider that reads a late-bound handler holder)
  runApp(UncontrolledProviderScope(container: container, child: const RadioApp()));
}
```

### Pattern 2: Two-level playback abstraction (facade plus player port)

**What:**
- `AudioEngine` is the **facade** the app uses. It is expressed in domain terms (`Station`, `PlaybackStatus`, `NowPlaying`).
- `StreamPlayer` is a narrow internal **port** over just_audio: `load(ResolvedStream)`, `play()`, `stop()`, `setVolume()`, plus streams for `processingState`, `playing`, `errors`, `icy`.

**When:** Always. The facade gives replaceability, as the brief requires. The port lets you unit-test the state machine with `FakeStreamPlayer`, which covers the brief's "unit tests for reconnect logic".
**Trade-offs:** One extra layer of mapping. It is worth it because reconnect logic is the product's core value and is otherwise only testable on a phone.

```dart
abstract interface class AudioEngine {
  Stream<PlaybackStatus> get status;       // replay-latest
  Stream<NowPlaying?> get nowPlaying;
  Stream<Station?> get currentStation;
  Future<void> play(Station station, {PlayContext context = const PlayContext.single()});
  Future<void> togglePause();              // live radio: pause == stop transport, keep session
  Future<void> stop();                     // release focus, drop FGS, clear notification
  Future<void> skipToNext();               // next station within PlayContext (favs/list)
  Future<void> skipToPrevious();
  Future<void> setVolume(double v);        // used by sleep-timer fade
}

sealed class PlaybackStatus { const PlaybackStatus(); }
final class Idle extends PlaybackStatus { const Idle(); }
final class Connecting extends PlaybackStatus { final Station station; final int streamIndex; ... }
final class Buffering extends PlaybackStatus { final Station station; ... }
final class Playing extends PlaybackStatus { final Station station; ... }
final class Paused extends PlaybackStatus { final Station station; ... }      // user pause
final class Reconnecting extends PlaybackStatus { final Station station; final int attempt; final DateTime nextAttemptAt; final bool waitingForNetwork; ... }
final class PlaybackError extends PlaybackStatus { final Station station; final PlaybackErrorKind kind; ... }
enum PlaybackErrorKind { offline, streamUnreachable, unsupportedFormat, allStreamsFailed, unknown }
```

The UI maps `PlaybackErrorKind` to localised text. The domain never holds user-facing strings.

### Pattern 3: Explicit playback state machine

| From | Event | To | Side effects |
|------|-------|----|--------------|
| Idle / Paused / Error | `play(station)` | Connecting | Request focus. Resolve the stream (cache first), then `player.load(resolved)` and `player.play()`. Start the connect timeout (≈ 10 s). |
| Connecting | player `ready && playing` | Playing | Reset the backoff. Record the recent. Send the RB click (once per session). Log time-to-audio. |
| Connecting | load error / timeout | Connecting (next stream) or Reconnecting | Rotate to the next `station.streams[i]`. Once every stream has failed in this round, go to Reconnecting. |
| Playing | `processingState == buffering` | Buffering | Arm the StallWatchdog (≈ 8 s). |
| Buffering | ready again | Playing | Disarm the watchdog. |
| Buffering | watchdog fires | Reconnecting | `player.stop()`, then schedule an **immediate** retry (attempt 0). |
| Playing / Buffering | `errorStream` event | Reconnecting | `player.stop()`, then schedule a retry with backoff. |
| Playing | `processingState == completed` | Reconnecting | An Icecast server closing the socket looks like end-of-stream. A live station never legitimately "completes". |
| Reconnecting | backoff timer fires, online | Connecting | Fresh `load()`, which lands on the **live edge** (see Pattern 5). |
| Reconnecting | offline | Reconnecting(waitingForNetwork) | Pause the backoff clock. Keep the session and notification ("Reconnecting…"). |
| Reconnecting(waiting) | connectivity → online / network changed | Connecting | Retry immediately and reset the backoff. |
| Reconnecting | budget exhausted (e.g. 3 min online-failing or 10 min offline) | Error | Release focus and stop the foreground service. The notification shows the error plus a play button. |
| Any active | user pause / headset / focus loss (transient) | Paused | `player.stop()` releases the network. Keep the `MediaItem`. When focus is regained after a transient loss, resume = play. |
| Any active | becoming-noisy (unplug) | Paused | Same as user pause. No auto-resume. |
| Any active | focus loss (permanent) | Paused | — |
| Any | user stop / sleep timer end | Idle | Release everything. `androidStopForegroundOnPause` + `stop()` lets the service die (battery rule). |

**Mapping to audio_service `PlaybackState`:**
- Connecting → `processingState: loading, playing: true`
- Buffering and Reconnecting → `buffering, playing: true`

The notification and foreground service therefore **stay alive while reconnecting**. That keeps the OS from killing the process during a Wi-Fi→4G switch, and headset "pause" still works.
- Paused → `ready, playing: false`
- Error → `error` with `errorMessage`
- Idle → `idle`

**Handle audio interruptions yourself.** Construct `AudioPlayer(handleInterruptions: false)` and subscribe to `AudioSession.interruptionEventStream` and `becomingNoisyEventStream` inside the handler. With the default `true`, just_audio pauses, ducks and resumes the player *behind the state machine's back* [just_audio API docs: "automatically pause/duck and resume/unduck when audio interruptions occur … or when headphones are unplugged", via WebFetch]. For live radio that breaks the pause = stop-transport rule and leaves the notification out of sync. Ducking can still be a plain `setVolume(0.3)`. **VERIFY** in Phase 1: focus is still requested correctly with `handleAudioSessionActivation: true`.

### Pattern 4: Reconnect with backoff, network awareness and a stall watchdog

- **Schedule:** 0 s, 1 s, 2 s, 4 s, 8 s, 15 s, 30 s (cap), each with ±20 % jitter. Reset after 30 s of stable `Playing`.
- **Two failure classes:**
  - **Never started.** The station was dead on arrival: a bad URL, 404 or unsupported codec. Rotate quickly through the fallback streams, allow at most 2 rounds, then show `allStreamsFailed` so the user isn't left waiting.
  - **Dropped while playing.** The network is flaky. Retry patiently with backoff, and prefer the stream that was working.
- **Network change:** Listen to `connectivity_plus`, debounced by about 500 ms.
  - If the state is Reconnecting or Buffering when the network comes up or changes type, retry **now** and reset the backoff.
  - If the network type changes while Playing, do nothing. The StallWatchdog handles it if the old socket dies.
- **Why the watchdog is required, not optional:** ExoPlayer's own retries on a progressive live source, plus 8 s HTTP connect/read timeouts, can take well over the ~10 s recovery target before an error reaches Dart. just_audio does not expose `LoadErrorHandlingPolicy`, so the app-level watchdog is what meets the target. (MEDIUM: based on Media3 defaults. **VERIFY** with a Wi-Fi→4G switch on a real phone in Phase 1.)
- **Offline:** Stop consuming retries while offline and wait for connectivity. This saves battery and matches the "no wake-locks when not playing" rule once the overall budget runs out.

```dart
class ReconnectPolicy {
  static const _steps = [0, 1, 2, 4, 8, 15, 30]; // seconds
  Duration delayFor(int attempt, Random rng) {
    final base = _steps[attempt.clamp(0, _steps.length - 1)];
    final jitter = base * 0.2 * (rng.nextDouble() * 2 - 1);
    return Duration(milliseconds: ((base + jitter) * 1000).round());
  }
}
```

### Pattern 5: Live-edge rejoin by reloading, never by resuming stale buffers

**What:** For live radio, "pause" stops the transport and releases the socket, and "resume" does a fresh `load()`. The same applies to every reconnect.
- For Icecast/Shoutcast, a new HTTP connection *is* the live edge.
- For live HLS, a fresh prepare starts at the default live position.

**Why:**
- Resuming an ExoPlayer pause on a progressive stream plays minutes-old buffered audio.
- The server often drops idle connections anyway.
- Live HLS paused beyond its window throws `BehindLiveWindowException`.

**Trade-off:** Resume costs roughly 1 s of reconnect. That is acceptable, and it is what users expect from "radio".

### Pattern 6: StreamResolver, a playlist wrapper resolver with cache

just_audio documents no `.pls`/`.m3u` parsing, and ExoPlayer plays media plus HLS only. So the app must resolve wrappers before it calls `load()`. [just_audio README via WebFetch: no mention of .pls/.m3u. MEDIUM]

```
input URL (+ hint from catalogue: type = direct|pls|m3u|hls|unknown)
  ├─ cached ResolvedStream (drift, TTL ~7 d, keyed by station+stream index)  → use, done
  ├─ path ends .m3u8 or hint=hls                                             → HLS, done
  ├─ path ends .pls / .m3u / .asx or hint=pls|m3u|unknown
  │     GET with small Range/byte limit, 5 s timeout, inspect Content-Type + first bytes
  │     ├─ "[playlist]" / audio/x-scpls        → parse File1..n, recurse (depth ≤ 3)
  │     ├─ #EXTM3U + #EXT-X-TARGETDURATION or #EXT-X-STREAM-INF → HLS (use original URL)
  │     ├─ m3u list                            → first http(s) line(s), recurse
  │     └─ audio/* or unknown binary           → progressive, done
  └─ else                                                                  → progressive
output: ResolvedStream{uri, kind: progressive|hls, candidates:[...]} → HlsAudioSource / ProgressiveAudioSource
```

- **Pick the source type explicitly.** HLS URLs without `.m3u8` must go through `HlsAudioSource`, because `AudioSource.uri` infers the type from the extension.
- **Keep sniffing off the hot path.**
  - Catalogue tooling (`tool/probe_streams.dart`) should store *direct* URLs plus a `type` hint wherever possible, so curated stations skip the sniff completely.
  - Radio Browser already provides `url_resolved`.
  - For the ≤ 3 s time-to-audio target, the last-station snapshot also stores its last resolved URL.

### Pattern 7: ICY now-playing flow

```
ExoPlayer IcyDecoder ─▶ just_audio icyMetadataStream (IcyMetadata.info.title)
   ─▶ NowPlayingParser: trim · drop empty/"-"/station-name-only/slogan list ·
       cp1251 repair (if string is all U+0080–U+00FF and no Cyrillic → latin1 bytes → cp1251) ·
       split "Artist - Title" · distinct-until-changed
   ─▶ RadioAudioHandler: mediaItem.add(current.copyWith(artist: np.artist, title/displaySubtitle: ...))
       ├─▶ notification / lock screen / Bluetooth AVRCP / (v1.1 Auto, song history)
       └─▶ AudioServiceEngine.nowPlaying ─▶ nowPlayingProvider ─▶ mini-player + now-playing screen
```

- **Keep the station identity stable.** Use `MediaItem.title` = station name, and put the ICY text in `artist`/`displaySubtitle`. The notification then always shows *which station* is playing, and the subtitle changes with the song.
- **cp1251 repair.** Many Bulgarian Icecast servers send cp1251 metadata. Media3's `IcyDecoder` tries UTF-8 and falls back to ISO-8859-1, so the raw bytes can be recovered losslessly on the Dart side. (MEDIUM: reasoned from Media3 decoder behaviour. **VERIFY** against real БНР and commercial streams in Phase 1.)
- **HLS stations** usually carry no ICY data, and just_audio doesn't expose timed ID3. Now-playing is simply absent for them, and the UI must handle `null` gracefully.
- **Update rate.** Emit a new `MediaItem` only when the parsed value changes, because each emission redraws the notification.

### Pattern 8: Station repository (layered sources plus merge, curated wins)

```
               ┌─────────────────────────────── on launch (instant, offline-safe)
Bundled asset ─┤ if drift has catalogue with version ≥ bundled.version → use drift copy
               └ else parse bundled (in compute()) → write drift
                          │
                          ▼  emit Catalog v(n)  ──────────────▶ UI renders immediately
Remote curated (after first frame, jittered, ≤ 1×/6 h):
   GET stations-bg.json  If-None-Match: <etag>
     304 → touch fetched_at
     200 → parse + validate (schema subset, version > current, ids unique, ≥ 1 stream each)
           → txn write drift (raw json + etag + version) → emit Catalog v(n+1)
     error → keep current, silent
Radio Browser BG (TTL ~24 h, background):
   /json/stations/search?countrycode=BG&hidebroken=true&order=clickcount&limit=1000
     → drift rb_stations cache → merge
Merge (pure function, unit-tested):
   1. curated stations → Station(id: StationId.curated(id))
   2. aliases: curated.radioBrowserUuid → claims that RB uuid
   3. RB station suppressed if uuid claimed OR fold(name)+normalised host/path matches a curated one
   4. remaining RB BG stations → Station(id: StationId.rb(uuid), source: rb, lower rank)
   5. field rule: curated fields always win; RB may only fill gaps curated leaves null (never streams)
```

- **Stable, namespaced IDs.** Use `StationId` = `curated:<id>` or `rb:<uuid>` everywhere: favourites, recents, `MediaItem.id`, and the share payload.
- **ID aliasing.** If a Radio Browser station the user favourited is later added to the curated list, the repository resolves `rb:<uuid>` → `curated:<id>` through the alias map, so the favourite quietly upgrades instead of breaking.
- **Snapshots.** Favourites and recents store a **station snapshot** (JSON) so they render and play without network and without the RB station being in any cache. The snapshot is refreshed whenever the live catalogue has a newer version of that station.
- **Remote host.** Prefer jsDelivr (`cdn.jsdelivr.net/gh/<owner>/<repo>@main/catalog/stations-bg.json`) with raw GitHub as fallback. jsDelivr branch URLs are CDN-cached for hours, which is acceptable for a catalogue but means urgent removals need a purge call. **VERIFY** jsDelivr ETag behaviour in Phase 2.
- **World catalogue is not merged into the DB.** Worldwide browse and search are live Radio Browser calls with an in-memory LRU. Only stations the user plays or favourites are persisted, as snapshots.

### Pattern 9: Radio Browser ServerPool

Per the API guidelines, the pool must do dynamic discovery, randomise, fail over, send a speaking UA, use `countrycode`, `stationuuid` and `url_resolved`, and register clicks through `/json/url/{uuid}`. [api.radio-browser.info / docs.radio-browser.info via WebFetch]

```
discover():
  1. InternetAddress.lookup('all.api.radio-browser.info') → IPs
  2. InternetAddress.reverse(ip) → hostnames (de1.api.radio-browser.info, …)   // HTTPS needs names, not IPs
  3. fallback: GET https://all.api.radio-browser.info/json/servers
  4. fallback: last-known list from prefs (persist on success, TTL 24 h)
  shuffle → ordered pool
request(path): try pool[i]; on timeout/5xx → next; mark bad for 10 min; ≤ 3 hosts per request
headers: User-Agent: "<AppName>/<version> (Android; +https://<github pages url>)"
click: fire-and-forget GET /json/url/{uuid} on first Playing per session (counted once/day/IP server-side)
```

Discovery runs lazily on first Radio Browser need. It is never part of startup and never on the resume-playback path.

### Pattern 10: Search index with Bulgarian transliteration

- **One canonical fold function** applied to both the query and the index keys:
  1. lowercase → strip Latin diacritics
  2. Cyrillic → Latin using the **official 2009 Transliteration Act table** (щ→sht, ъ→a, ю→yu, я→ya, ц→ts, ж→zh, and the "-ия" → "ia" word-final rule)
  3. fold informal Latin variants onto the same skeleton (ia/iya/ya, iu/yu, w→v, x→h, 4→ch, 6→sh, q→ya …)
  4. collapse punctuation and whitespace

  Because both sides meet in one Latin skeleton, "horizont", "Хоризонт" and "hor1zont" (fuzzy) all match, and "бг радио" matches "BG Radio" (бг→bg). You never have to solve the ambiguous Latin→Cyrillic direction to *search*. Latin→Cyrillic is only needed to build a Cyrillic query for Radio Browser (below).
- **Ranking:**
  - exact token > token prefix > substring > fuzzy (Damerau–Levenshtein ≤ 1 for tokens ≥ 4 chars, ≤ 2 for ≥ 8)
  - boosts: curated, favourite, national network, recently played
  - searched fields: name, `nameLatin`, city, network, genres
- **Size:** A few hundred curated stations plus about 1,000 RB Bulgarian ones is a linear scan well under 10 ms. Precompute the folded keys once per catalogue version, in `compute()` when the RB set is loaded. Do **not** use SQLite FTS here, because FTS tokenisers don't understand the fold.
- **World search:** Debounce 300 ms and cancel stale requests. If the query is Cyrillic, query RB with both the original and its Latin transliteration. If it is Latin and "looks Bulgarian", also send the Latin→Cyrillic form. Merge by uuid and put local BG results first.
- **Built for the handler too.** SearchIndex is plain Dart, so in v1.1 `playFromSearch` ("Hey Google, play Horizont") reuses it directly.

### Pattern 11: Riverpod provider layering

| Layer | Providers | Lifetime | Depends on |
|-------|-----------|----------|------------|
| L0 infra | `prefsProvider`, `databaseProvider`, `httpClientProvider`, `clockProvider`, `connectivityProvider`, `audioEngineProvider` | keepAlive, overridden in bootstrap | — |
| L1 data | `curatedCatalogSourceProvider`, `radioBrowserClientProvider`, `stationRepositoryProvider`, `libraryRepositoryProvider`, `settingsRepositoryProvider`, `streamResolverProvider`, `searchIndexProvider` | keepAlive | L0 |
| L2 state | `catalogProvider` (StreamProvider over repo), `bulgariaHomeProvider` (derived sections), `worldBrowseProvider(filter)`, `searchResultsProvider(query)` (autoDispose family), `favouritesProvider` / `recentsProvider` (drift `watch()`), `isFavouriteProvider(id)`, `playbackStatusProvider`, `nowPlayingProvider`, `currentStationProvider` (StreamProviders over the engine), `sleepTimerProvider`, `localeProvider`, `themeModeProvider` | autoDispose for screen-scoped data; keepAlive for playback and settings | L1 |
| L3 UI | widgets: `ref.watch(L2)`, and commands via `ref.read(xNotifier).method()` or `ref.read(audioEngineProvider).play(...)` | — | L2 only |

**Rules:**
- Playback providers are **read-only mirrors** of the engine. The engine never reads Riverpod.
- Do not keep playback state in a Notifier that "also" calls the player. That creates a second source of truth.
- Use `select` in the mini-player (`ref.watch(playbackStatusProvider.select(...))`) so ICY ticks don't rebuild whole screens.
- Riverpod 3.x is current (flutter_riverpod 3.4.3). Codegen is optional; drift already requires `build_runner`, so enabling `riverpod_generator` adds little cost. [pub.dev via WebFetch]

### Pattern 12: go_router shell with a persistent mini-player

```dart
final rootKey = GlobalKey<NavigatorState>();
GoRouter(
  navigatorKey: rootKey,
  initialLocation: '/bg',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (ctx, state, shell) => ShellScaffold(shell: shell), // NavigationBar + MiniPlayer + BannerSlot
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/bg', ..., routes: [
          GoRoute(path: 'city/:cityId', ...), GoRoute(path: 'genre/:genreId', ...),
          GoRoute(path: 'national', ...)])]),
        StatefulShellBranch(routes: [GoRoute(path: '/world', ..., routes: [GoRoute(path: 'search', ...)])]),
        StatefulShellBranch(routes: [GoRoute(path: '/library', ...)]),
      ],
    ),
    GoRoute(path: '/player', parentNavigatorKey: rootKey, pageBuilder: fullscreenSlideUp), // no mini-player, never banner
    GoRoute(path: '/station/:stationId', parentNavigatorKey: rootKey, ...),               // share/deep link target
    GoRoute(path: '/settings', parentNavigatorKey: rootKey, ..., routes: [about, licences]),
  ],
);
```

- **Shell layout:** `ShellScaffold` = `Scaffold(body: Column[Expanded(shell), MiniPlayer(), BannerSlot()], bottomNavigationBar: NavigationBar)`.
  - `MiniPlayer` collapses to zero height while `currentStation == null`.
  - `BannerSlot` is `SizedBox.shrink()` in v1. It reserves the layout position the future ads milestone needs, with **no ad code**, and it is structurally absent from `/player`.
- **Branch stacks survive tab switches** (`indexedStack`). go_router 18.x is feature-complete (bug-fix-only), which makes it a stable dependency. [pub.dev via WebFetch]

### Pattern 13: Localisation that also works below the UI

- `flutter_localizations` + gen-l10n, with `app_en.arb` as the template (every key gets an `@description`) and `app_bg.arb` reviewed by the owner.
- `supportedLocales: [bg, en]`. Resolution: device language `bg` → bg, anything else → en. An override from settings is stored in prefs and exposed as `localeProvider`.
- **The handler needs strings too**, for example the notification subtitle "Reconnecting…" / "Свързване…" and error text. Give it an `EngineStrings` value object. Build it via `lookupAppLocalizations(locale)`, which is generated and needs no `BuildContext`, and refresh it when `localeProvider` changes. The Android notification channel name is fixed at `AudioService.init` time, so pick it from `PlatformDispatcher.instance.locale`.
- **Station names:** The model carries `name` (Cyrillic) and `nameLatin`, and `displayName(locale)` lives in presentation. Search always indexes both.

---

## Data Flow

### Request flow: "tap station → audio"

```
StationTile.onTap
  → ref.read(audioEngineProvider).play(station, context: PlayContext.list(ids))
  → AudioServiceEngine → handler.playFromMediaId('curated:bnr-horizont', extras)   [same path as car/BT]
  → RadioAudioHandler: queue = context list; mediaItem.add(station→MediaItem); state=Connecting
  → StreamResolver.resolve(station.streams[0])   (cache hit ⇒ 0 ms)
  → StreamPlayer.load(ResolvedStream) → just_audio → ExoPlayer (HTTP, ICY, HLS)
  → processingState ready + playing ⇒ state=Playing
       ├─ playbackState.add(...)  → notification / lock screen / BT
       ├─ LibraryRepository.recordRecent(station snapshot)   → drift → recentsProvider (watch)
       ├─ SettingsRepository.lastStation = snapshot(+resolved url)
       └─ RadioBrowserClient.click(uuid) if station has RB uuid (fire & forget)
  → AudioServiceEngine.status stream → playbackStatusProvider → MiniPlayer rebuild
```

The UI calls `playFromMediaId` just like Bluetooth, the notification and (v1.1) Android Auto do. That gives one code path, and everything that works from the UI also works from the car.

### State management

```
                 commands                                  events (streams, replay-latest)
UI ──ref.read──▶ AudioEngine ──▶ RadioAudioHandler ──▶ StateMachine ──▶ StreamPlayer(just_audio)
 ▲                                   │   ▲                  ▲   ▲            │
 │                                   │   └── AudioSession ──┘   └── Connectivity, Watchdog, Timers
 │                                   ▼
 └── ref.watch ── L2 StreamProviders ◀── playbackState / mediaItem / queue (BehaviorSubjects)
                                     └──▶ OS MediaSession (notification, lock screen, BT, Auto)
```

### Key data flows

1. **Cold start and resume:**
   - `bootstrap()` loads prefs, then `firstLaunchDate` (write-once), then `lastStation` snapshot, then `AudioService.init`, then `runApp`.
   - The home screen shows a big "Resume <station>" card from the snapshot, with no catalogue needed. One tap plays through the snapshot's cached resolved URL.
   - Catalogue refresh, the RB BG refresh and server discovery all run *after* the first frame and never block.
2. **Catalogue update:** remote 200 → validate → drift txn → `StationRepository` emits → `catalogProvider` → home sections rebuild; `SearchIndex` rebuilds its keys. Favourites and recent snapshots are refreshed lazily when their station appears in the new version.
3. **ICY:** ExoPlayer → just_audio → `NowPlayingParser` → handler `mediaItem` → OS surfaces + `nowPlayingProvider`.
4. **Network change:** connectivity → handler → state machine (immediate retry if reconnecting or buffering) → fresh `load()` → live edge.
5. **Sleep timer:** UI sets a deadline → `SleepTimer` (keepAlive, beside the engine, driven by `Clock`) → countdown stream to UI → at T−10 s, volume fade → `engine.stop()`. It is based on a wall-clock deadline, so it stays correct with the screen off (Dart timers keep running while the audio_service foreground service holds its wake lock).
6. **Favourite toggle:** UI → `LibraryRepository.toggle(station snapshot)` → drift → `favouritesProvider` (watch) → UI. The handler's queue and browse tree read the same repository.
7. **Share:** `StationId` + name + homepage → plain text via `share_plus`. Later this can become a GitHub Pages URL that deep-links to `/station/:id`.

---

## Android Auto readiness (v1.1): what to build in v1 so Auto is additive

Do these in v1, because they are cheap now and expensive to retrofit:

1. **Route every play through `playFromMediaId(StationId)`**, including from the UI.
2. **The handler holds repositories, not widgets** (Pattern 1). Auto can start the service with no activity, and the handler must answer `getChildren` from the drift or bundled catalogue with no network.
3. **Use stable, self-describing media IDs:** `station/curated:<id>`, `station/rb:<uuid>`, `node/favourites`, `node/recents`, `node/bg/national`, `node/bg/city/<cityId>`, `node/bg/genre/<genreId>`.
4. **Implement `MediaLibraryTree` as a pure function in v1**, with unit tests. In v1 wire only `getChildren(AudioService.recentRootId)`, which returns the last station. That gives Android 11+ system media-resumption for free.
5. **Let the queue reflect the play context** (favourites or the current list). That way next/previous on car Bluetooth and steering wheels changes station in v1, and Auto reuses it.
6. **SearchIndex is callable from the handler**, ready for `playFromSearch` and `search`.

Left for v1.1 research:
- `getChildren`/`getMediaItem`/`search`/`subscribeToChildren` wiring
- `androidBrowsableRootExtras` (content style)
- `automotive_app_desc.xml`
- Auto artwork: browse-item art may need a `content://` provider rather than `https` URLs, **VERIFY**
- Play's Auto quality review

**Platform caveat:** audio_service's Android side still uses the legacy `androidx.media` MediaSession and MediaBrowserService. Issue #942, "migrate to Media3", is still open. Android Auto supports this, but it is the main reason the `AudioEngine` seam exists. [GitHub issue #942 via WebFetch; LOW-MEDIUM]

---

## Suggested Build Order (dependencies → phases)

```
catalog/domain (Station, StationId)  ─┐
core/text (fold, translit, cp1251)   ─┤
core/clock, logging, http(UA)        ─┤
                                      ▼
playback/engine: StreamPlayer port → StreamResolver → NowPlayingParser → ReconnectPolicy
   → StateMachine → RadioAudioHandler → AudioServiceEngine → AudioEngine facade
                                      ▼
bootstrap (container + AudioService.init) → minimal UI (hard-coded Stations, mini-player)
                                      ▼
core/database (drift) → curated source (bundled → remote ETag) → RB ServerPool/client → merge
   → StationRepository → SearchIndex → BG home / World / search UI → go_router shell (3 branches)
                                      ▼
LibraryRepository (favs/recents + snapshots) → resume card → now-playing screen → SleepTimer
   → share → l10n completion (bg review) → theme
                                      ▼
hardening: fallback UX, error copy, report, a11y, perf, battery hint  → release
```

| Roadmap phase | Architecture that must exist by the end | Why here |
|---------------|------------------------------------------|----------|
| **1. Skeleton & engine** | `AudioEngine` facade + `StreamPlayer` port; state machine with **all** states; reconnect + watchdog + connectivity; `StreamResolver` (pls/m3u/HLS); `NowPlayingParser` incl. cp1251; interruption handling in the handler; `Station`/`StationId` real models (5 hard-coded); composition root; **gen-l10n scaffolding** (keys from day one, even if the BG copy is reviewed later); `firstLaunchDate` write-once; manifest + `network_security_config`; time-to-audio logging | Risk-first. Everything else is a client of the engine, and the state machine is the most expensive thing to retrofit. **Fallback-stream rotation belongs here**, not in Phase 4 hardening, because `Station.streams[]` and the rotation are part of the state machine. Phase 4 only polishes the UX. |
| **2. Catalogue** | drift DB + migrations; bundled → drift → remote ETag pipeline; schema + `tool/validate_catalog.dart` in CI; RB `ServerPool` + client; merge + aliasing; `SearchIndex`; go_router `StatefulShellRoute` with mini-player + `BannerSlot`; BG home / World | The repository must exist before library snapshots and before the browse tree. The shell comes here because this is the phase that first has several screens. |
| **3. Listening experience** | `LibraryRepository` (favourites/recents with snapshots, `watch`); last-station snapshot + resume card; now-playing screen; `SleepTimer` (pure, Clock-driven, tested); share; full BG/EN strings; theme; queue from `PlayContext`; `recentRootId` resumption | Depends on stable `StationId` and the repository from Phase 2. |
| **4. Hardening** | Error UX mapping for `PlaybackErrorKind`; report flow; battery-hint trigger (from the state machine: e.g. playback killed or stalled repeatedly with the screen off); a11y semantics; low-end perf (`select`, `const`, image cache sizes) | Needs every surface to exist. |
| **5. Release** | CI signing, AAB, Play forms | No new architecture. |
| **v1.1** | `MediaLibraryTree` → `getChildren`/`search`; widget / QS tile (talk to the handler via `AudioService`); song history (subscribe to the NowPlaying stream → drift) | Additive only, if the v1 rules above are respected. |

---

## Scaling Considerations

There is no backend, so "scale" means device load, third-party goodwill and catalogue hosting.

| Scale | Architecture adjustments |
|-------|--------------------------|
| 0–1k users | As designed. Raw GitHub or jsDelivr for the catalogue. Radio Browser calls are light (BG list ≤ 1×/24 h per device, clicks once per session). |
| 1k–100k users | Serve the catalogue **only** via jsDelivr, since raw.githubusercontent is rate-limited and not a CDN. Keep the ETag and ≥ 6 h refresh throttle, and add jitter so devices don't all fetch on the hour. Cache the RB BG list for 24 h. Consider shipping `rb-bg-snapshot.json` in the catalogue repo, generated by CI, so most devices never pull 1,000 BG stations from the community servers. |
| 100k+ | Catalogue deltas are unnecessary (the file stays small), but consider split files (`stations-bg.json` + `logos` manifest). Mirror frequently used station logos on GitHub Pages/jsDelivr instead of hot-linking station websites. Being a good Radio Browser citizen starts to matter: honour failover and never retry in tight loops. |

### Scaling priorities

1. **Device-side first bottleneck:** cold start and jank on low-end phones. Keep bootstrap minimal, parse JSON in `compute()`, lazy-open drift, cap image cache decode sizes (`cacheWidth`), and use `select` in playback-watching widgets.
2. **Ecosystem bottleneck:** Radio Browser mirror availability. The ServerPool failover plus the drift-cached BG list plus the bundled curated set mean an RB outage only degrades world search.

---

## Anti-Patterns

### Anti-Pattern 1: Playback logic in widgets or autoDispose providers
**What people do:** Put the reconnect loop or sleep timer in a `StatefulWidget` or an autoDispose Notifier.
**Why it's wrong:** It dies when the screen changes, the activity is destroyed or the app is backgrounded, which is exactly when reconnect matters.
**Do this instead:** Put it in the handler or keepAlive services built in bootstrap. Providers only mirror state.

### Anti-Pattern 2: UI calling just_audio directly, or two players
**What people do:** Call `AudioPlayer().setUrl()` from a screen "just for preview", or let the handler and the UI each own state.
**Why it's wrong:** The notification, lock screen and Bluetooth get out of sync with the app, focus handling is duplicated, and ghost audio results.
**Do this instead:** Have exactly one `StreamPlayer`, owned by the handler, and have everything go through `AudioEngine`.

### Anti-Pattern 3: Letting just_audio auto-handle interruptions in a live-radio state machine
**What people do:** Keep `handleInterruptions: true` (the default).
**Why it's wrong:** The player pauses and resumes itself, the state machine never sees it, resume plays stale buffer, and headset/notification state drifts.
**Do this instead:** Use `handleInterruptions: false` and route `audio_session` events through the state machine.

### Anti-Pattern 4: Treating `completed` or a single error as "stopped"
**What people do:** Show "Station ended" when ExoPlayer reports end-of-stream or an IO error.
**Why it's wrong:** Icecast disconnects and network flaps look exactly like that. The core value ("never stops on its own") fails.
**Do this instead:** For live stations, `completed` and errors trigger Reconnecting. Only an exhausted budget produces Error.

### Anti-Pattern 5: Blocking launch or playback on the network catalogue or RB discovery
**What people do:** `await fetchCatalogue()` before showing the home screen, or discover RB servers before playing.
**Why it's wrong:** It breaks the < 2 s cold start and the ≤ 3 s time-to-audio targets, and leaves a blank screen offline.
**Do this instead:** Bundled/drift first, network refresh after the first frame, and resume from a self-contained snapshot.

### Anti-Pattern 6: Unstable or ambiguous station identity
**What people do:** Key favourites by name or stream URL, or reuse RB uuids for curated stations without a namespace.
**Why it's wrong:** URLs change (that is the whole reason the catalogue exists), names get corrected, and favourites silently vanish.
**Do this instead:** Use namespaced `StationId`, curated ids that never change once published (enforced by `tool/validate_catalog.dart` against the previous version), an alias map, and snapshots.

### Anti-Pattern 7: Hard-coding a Radio Browser mirror or using `url` instead of `url_resolved`
**What people do:** Hard-code `https://de1.api.radio-browser.info` and play `station.url`.
**Why it's wrong:** It violates the client guidelines, single-mirror outages break search, and `url` is often a `.pls` wrapper.
**Do this instead:** Use the ServerPool (DNS + reverse, `/json/servers`, persisted fallback) and `url_resolved`, still passed through `StreamResolver` as a safety net.

### Anti-Pattern 8: Localised strings or `BuildContext` below the presentation layer
**What people do:** Throw `Exception(AppLocalizations.of(context).errorX)` from a repository, or build notification text in widgets.
**Why it's wrong:** The handler has no context when the UI is gone, and the language switch doesn't reach the notification.
**Do this instead:** The domain emits enums and codes, the UI maps them to text, and the handler gets `EngineStrings`.

### Anti-Pattern 9: Emitting a MediaItem per ICY packet
**Why it's wrong:** It causes needless notification redraws, battery drain and jank on low-end phones.
**Do this instead:** Parse, then distinct-until-changed, then emit.

### Anti-Pattern 10: Unscoped cleartext
**What people do:** Set `android:usesCleartextTraffic="true"` and forget about it.
**Why it's wrong:** The app's own endpoints (catalogue, RB) could silently fall back to http.
**Do this instead:**
- Keep a `network_security_config.xml` with explicit `domain-config`s for the curated stations' http hosts, generated or validated by the catalogue tool.
- Cleartext is a practical necessity for arbitrary worldwide RB stations. If the owner accepts `base-config cleartextTrafficPermitted="true"` for that reason, enforce `https` in code for every app-owned endpoint (the catalogue URL and the RB ServerPool reject `http`).
- Just_audio's header proxy runs on `127.0.0.1` over http. Passing `userAgent` may activate it, so localhost must be allowed either way. **VERIFY** in Phase 1.

This is a decision to log, not something to assume.

---

## Integration Points

### External services

| Service | Integration pattern | Notes |
|---------|---------------------|-------|
| Station stream servers (Icecast/Shoutcast/HLS) | just_audio → Media3 ExoPlayer via `StreamResolver` | Many are cp1251 in ICY, many are http, and some serve `.pls`/`.m3u`. Use a speaking `userAgent`. |
| Radio Browser API | `RadioBrowserClient` over `ServerPool` | DNS discovery + reverse lookup, `/json/servers` fallback, UA, `countrycode`, `stationuuid`, `url_resolved`, `/json/url/{uuid}` click, `/json/stations/byuuid?uuids=` to refresh favourite snapshots in batch |
| Curated catalogue host (jsDelivr / raw GitHub) | `CuratedCatalogRemote` with ETag | The CDN cache delay means urgent takedowns need a jsDelivr purge. Validate before replacing the cache, and never accept a lower `version`. |
| Android MediaSession / notification / Bluetooth | audio_service (legacy androidx.media) | Manifest: `AudioService` with `foregroundServiceType="mediaPlayback"`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (SDK 34+), `WAKE_LOCK`, `MediaButtonReceiver`. The activity extends `AudioServiceActivity`. [pub.dev audio_service via WebFetch] |
| Audio focus / becoming noisy | audio_session events → handler | `AudioSessionConfiguration.music()` |
| Connectivity | connectivity_plus → handler | Reports interface changes, not real reachability. The watchdog covers the gap. |
| Email / share / links | url_launcher (`mailto:` report with a prefilled station id, stream URL and app version), share_plus | No backend |

### Internal boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| UI ↔ playback | `AudioEngine` methods (commands) + streams (via L2 providers) | UI never imports `engine/` |
| AudioEngine ↔ RadioAudioHandler | Direct calls; `playFromMediaId`, `customAction` for things like sleep fade | Same isolate |
| Handler ↔ StreamPlayer | Port interface | The only just_audio contact point |
| Handler ↔ repositories | Plain Dart method calls + streams | Injected in bootstrap; no Riverpod inside the handler |
| Repositories ↔ drift | DAOs, `watch()` streams | Tables defined per feature, DB class in core |
| Catalogue ↔ Search | `SearchIndex.rebuild(Catalog)` on each catalogue emission | Keys folded once per version |
| Features ↔ features | Only through `domain/` types (e.g. library uses `catalog/domain/Station`) | No cross-feature `data/` or `presentation/` imports. Enforce with a simple import-lint test. |

---

## Sources

- pub.dev `audio_service` 0.18.19 page + changelog (main-isolate handler since 0.18, `IsolatedAudioHandler`, Android Auto APIs, manifest/FGS requirements, `androidStopForegroundOnPause`, AGP 9/SDK 35): https://pub.dev/packages/audio_service. WebFetch, seam tier LOW, primary source.
- audio_service wiki FAQ (activity destruction, main isolate, inter-isolate via `IsolatedAudioHandler`): https://github.com/ryanheise/audio_service/wiki/FAQ. WebFetch, LOW.
- audio_service issue #942 "Update Android implementation to use media3" (open): https://github.com/ryanheise/audio_service/issues/942. WebFetch, LOW.
- pub.dev `just_audio` 0.10.6 page + changelog (media3 ExoPlayer since 0.9.43, playlist API, `errorStream`, `icyMetadataStream`, HLS, header proxy + cleartext note, no documented .pls/.m3u): https://pub.dev/packages/just_audio. WebFetch, LOW, primary source.
- just_audio `AudioPlayer` constructor API docs (`handleInterruptions` semantics, `userAgent`, `useProxyForRequestHeaders`, `audioLoadConfiguration`): https://pub.dev/documentation/just_audio/latest/just_audio/AudioPlayer/AudioPlayer.html. WebFetch, LOW, primary source.
- Radio Browser client guidelines and API reference (DNS discovery, reverse lookup, SRV, `/json/servers`, UA, `countrycode`, `stationuuid`, `url_resolved`, `/json/url/{uuid}` counted once per day per IP, search params, `byuuid`): https://api.radio-browser.info/ and https://docs.radio-browser.info/. WebFetch, LOW, primary source.
- pub.dev `flutter_riverpod` 3.4.3, `go_router` 18.0.1 (feature-complete), `drift` (reactive queries, migrations): WebFetch, LOW.
- Reasoned (not independently verified this session, flagged VERIFY above): Media3 `IcyDecoder` UTF-8 → ISO-8859-1 fallback (basis for cp1251 repair); ExoPlayer default HTTP timeouts/retry counts (basis for StallWatchdog); jsDelivr branch cache duration; Android Auto browse-item artwork URI requirements; Bulgarian Transliteration Act 2009 table details (to be encoded as unit tests reviewed by the owner).

---
*Architecture research for: Flutter Android live internet radio (Bulgarian-first)*
*Researched: 2026-09-24*
