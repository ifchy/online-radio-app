# Project Research Summary

**Project:** Online Radio (working title). A free Android app for live internet radio, Bulgarian-first.
**Domain:** Flutter (Android-first) live internet-radio player: background media playback, a curated Bulgarian catalogue, and worldwide stations through the Radio Browser API. Distributed on Google Play.
**Researched:** 2026-09-24
**Confidence:** MEDIUM overall. The stack is HIGH: it was verified against the registry, the plugin source code and a real release build. Runtime playback behaviour is MEDIUM because only a physical phone can confirm it.

---

## Executive Summary

This is a live-radio player, not a music player. The difference matters for almost every design decision. The product only works if audio keeps playing through the things Android does to a background app: screen off, a phone call, a switch from Wi-Fi to 4G, a server that drops the connection, and OEM battery killers. Well-built radio apps handle this with a small playback engine that has an **explicit state machine** and runs underneath the UI. The engine keeps the media foreground service (FGS) alive through temporary failures. It reconnects to the live edge by reloading the stream, never by resuming stale buffers. It never treats "completed" or a single error as "stopped". The market research confirms the opportunity. Bulgarian listeners are served almost entirely by ad-funded apps built from generic "Radio <Country>" templates. The two most common complaints about those apps are intrusive ads and playback that stops on its own. An ad-free app that keeps playing, with a hand-verified Bulgarian catalogue (including all БНР regional stations) and search that works in either Cyrillic or Latin, is a real niche.

**Keep the brief's stack, with specific corrections.** Use Flutter 3.47.5 with just_audio 0.10.6, audio_service 0.18.19 and audio_session 0.2.4, behind our own `AudioEngine` facade. Add Riverpod 3, go_router 18, drift, shared_preferences, `http` (not dio), and gen-l10n. The full dependency set was resolved and built as a release AAB with 16 KB-aligned native libraries. Set **minSdk 24 and targetSdk/compileSdk 36**. Neither is optional: 24 is Flutter's floor and 36 is Play's requirement since 2026-08-31. The plugins cover only part of what the app needs. The app itself must provide:
- a `.pls`/`.m3u` resolver
- explicit HLS source selection
- repair of Bulgarian now-playing titles sent in the windows-1251 (cp1251) encoding
- a stall watchdog
- rotation through each station's fallback streams
- a foreground-service policy that holds the service through interruptions

**The brief underestimates Phase 1.** It is the heaviest and riskiest phase. Most of the core-value work lives there, and it can only be verified on real phones (Xiaomi and Samsung at minimum).

The main risks, and how to mitigate them:
- **Losing the foreground service after a pause or call.** Android 12, 15 and 17 each add restrictions, so playback never comes back. Mitigation: an FGS-aware state machine.
- **Silent stalls after a network switch.** ExoPlayer's own timeouts exceed the 10 s recovery target. Mitigation: a watchdog plus immediate retry when connectivity changes.
- **Content rights and takedowns.** Radio Browser data contains aggregator URLs with distribution tags. Mitigation: catalogue CI rules plus a remote kill-switch.
- **Play Console gates discovered too late.** A personal account needs 12 testers opted in for 14 days; Play also requires the FGS declaration video and an accurate Data safety form. Mitigation: settle the account decision before Phase 4, start closed testing at the beginning of Phase 4, and record the FGS video in Phase 1.

---

## Key Findings

### Recommended Stack

The brief's stack holds up with targeted corrections (details in STACK.md). Versions were checked against pub.dev on 2026-09-24. The audio plugins' behaviour was read from their published 0.10.6 / 0.18.19 / 0.2.4 source archives rather than from READMEs. The complete dependency set was built as a release AAB on Flutter 3.47.5 / AGP 9.1 / JDK 17. The download per device will be well under 10 MB.

**Core technologies:**
- **Flutter 3.47.5 / Dart 3.13.4:** toolchain. go_router 18, Riverpod 3.4 and cached_network_image 4 already require Flutter 3.44 or later.
- **just_audio 0.10.6** (Media3 ExoPlayer 1.4.1): playback engine. It plays MP3, AAC/HE-AAC and HLS, exposes ICY metadata, and allows http↔https redirects.
  - Construct it as `AudioPlayer(useProxyForRequestHeaders: false, userAgent: ..., handleInterruptions: false)`. This avoids the cleartext localhost proxy and stops the plugin from pausing and resuming the player behind the state machine's back.
- **audio_service 0.18.19:** foreground service, MediaSession, notification, headset and Bluetooth buttons. It is the only permissively licensed option with a full browse tree, which Android Auto will need in v1.1. It still uses the legacy `androidx.media` library; the Media3 migration (#942) has been open since 2022. That is why the `AudioEngine` seam matters.
- **audio_session 0.2.4:** audio focus, ducking and becoming-noisy. Configure it once with `.music()`. Its minSdk of 24 sets the app's floor.
- **Riverpod 3.4 (codegen) + riverpod_lint 3.x:** DI and state. riverpod_lint no longer needs `custom_lint`. **Keep reconnect logic in the engine, not in Riverpod's automatic retry.**
- **go_router 18:** `StatefulShellRoute.indexedStack` gives a persistent mini-player plus a reserved banner slot.
- **drift 2.35 + drift_flutter:** favourites, recents, catalogue cache and migrations. **Do not add `sqlite3_flutter_libs`**; it is end-of-life, and `sqlite3` 3.x bundles SQLite through build hooks.
- **`http` 1.6 (not dio):** a few GET/ETag calls wrapped in one client that sets the User-Agent and **rejects `http://` for everything except media and playlist resolution**.
- **shared_preferences 2.5** (`SharedPreferencesWithCache`/`Async`), **flutter_localizations + gen-l10n** (`synthetic-package: false`), **cached_network_image 4.0.2** (MEDIUM: a new major version), **connectivity_plus**, **freezed/json_serializable**. Transliteration is **custom code**; no package handles it properly.
- **Crash reporting:** if the owner opts in, use **Sentry** (MIT, `sendDefaultPii: false`), not Crashlytics, which is proprietary and pulls in Firebase. With no SDK, Play's Android vitals is the baseline, but it sees only native crashes and ANRs, not Dart exceptions.

**Do not use:** `just_audio_background`, `radio_player` (CC BY-NC-SA licence), `media_kit`, `assets_audio_player`, `AudioSource.uri()` for station streams, the default proxied `AudioPlayer()`, a blanket `usesCleartextTraffic` with no guard in Dart, `permission_handler` just to request the notification permission, or any ads or analytics SDK.

### Expected Features

(Details in FEATURES.md.) Competitor features come from Google Play listings scraped in the BG, EN, DE and GB locales. Radio Browser's Bulgarian data quality was measured with a live query: 344 stations, half of them `http://`, 53 % with a logo, about 30 % with a region, and only 53 names in Cyrillic.

**Must have (table stakes):**
- Background playback with a media notification, lock-screen controls, headset/Bluetooth/car buttons, audio focus (duck for navigation prompts, resume after a call) and becoming-noisy handling
- Auto-reconnect that rejoins the live edge, with fallback streams and visible "Reconnecting…" and error states. A silent stop is the #2 complaint about competitors.
- MP3 / AAC / HE-AAC / HLS / `.pls` / `.m3u`, plus cleartext `http://` streams
- Time-to-audio of about 3 s, and one-tap resume of the last station
- ICY now-playing, with slogans and duplicate values filtered out
- **NEW (v1 candidate): next/previous station from media buttons** (steering wheel, headset, notification). It cycles through the list playback was started from, defaulting to favourites, and the UI must stay in sync. Competitor reviews show this going wrong.
- Favourites, **NEW (v1 candidate): drag-to-reorder favourites** (a user request; the order also drives next/prev in the car), and recents capped at about 30–50
- Browse by БНР network, city and genre. **This must come from the curated catalogue**, because Radio Browser's regions and tags cannot support it.
- Search that ignores script (Cyrillic or Latin), case and diacritics
- Sleep timer with fade-out, share, generated logo placeholders, system dark theme, Bulgarian/English UI, TalkBack support, large touch targets

**Should have (differentiators):**
- **No ads, no pop-ups, no account.** This answers the #1 complaint across the category, so the store listing should lead with it.
- **Reliability as a feature:** curated `streams[]` with priorities, automatic failover, and the last working URL remembered per station
- **Hand-verified Bulgarian catalogue, updatable remotely**, including all БНР regional stations. Fixing a dead URL takes hours, not a release.
- **Bulgarian-native search:** the official transliteration **plus informal Latin typing (шльокавица: 4=ч, 6=ш, q=я, w=в…)**, plus `aliases[]` and light fuzzy matching
- Driver-friendly now-playing screen: primary control ≥ 64 dp, high contrast, a "НА ЖИВО" badge instead of a seek bar
- One-tap "report broken station" (a prefilled email with diagnostics and no personal data)
- Optional, cheap: a "Lower quality on mobile data" toggle using curated bitrates. It can slip to v1.1.
- Serving Bulgarians abroad well (English UI, low bitrate, several fallback streams per station)

**Defer (v1.1 and later):**
- **Android Auto: make it the first v1.1 item.** Every popular Bulgarian competitor advertises it. Design the v1 media-ID browse tree now so adding Auto is purely additive.
- Widget, Quick Settings tile, alarm, Chromecast, full data-saver, song history, "stations near me", favourites export/import, autoplay when car Bluetooth connects
- v2+: banner-only ads for users of 30+ days with a permanent one-time IAP (never converted to a subscription), iOS/CarPlay, partnerships
- **Never:** interstitial, video or audio ads; accounts; podcasts or news; recording; a globe-style browse UI; in-app "Top 20" rankings (they would need tracking)

### Architecture Approach

(Details in ARCHITECTURE.md.) Two "heads" control and observe playback: the Flutter UI and the OS media session (notification, lock screen, Bluetooth, and Android Auto later). The UI can disappear at any time, so all playback logic lives in a long-lived `RadioAudioHandler`. It is created once in `main()` and receives repositories as plain Dart objects. The UI only sends commands and subscribes to state. audio_service 0.18 runs the handler in the main isolate, so Riverpod, drift and the handler share one `ProviderContainer` and need no isolate messaging. Every play request, including those from the UI, goes through `playFromMediaId(StationId)`. That gives one code path for UI, Bluetooth and (later) Android Auto. Dependencies point strictly downward. `features/playback/engine/` is the **only** folder that may import just_audio or audio_service, and CI should enforce that.

**Major components:**
1. **`AudioEngine` facade + `StreamPlayer` port.** The facade is the replaceability seam: a native Media3 engine could later sit behind it. The port is a narrow internal interface over just_audio, so the state machine can be unit-tested with a fake player.
2. **`PlaybackStateMachine` + `ReconnectPolicy` + `StallWatchdog` + `ConnectivityMonitor`.** Explicit states (idle, connecting, buffering, playing, paused, reconnecting, error). Backoff of 0, 1, 2, 4, 8, 15 and 30 s with jitter, rotating through fallback streams. A watchdog of about 8 s on buffering. Immediate retry when the network changes. The state machine emits commands and does no I/O itself, so it is pure Dart and tested with a fake clock.
3. **`StreamResolver`**: a tolerant `.pls`/`.m3u` parser with a size cap, sniffing for HLS disguised as `.m3u` (`#EXT-X-`), and a resolved-URL cache that is invalidated on error. It outputs `ProgressiveAudioSource` or `HlsAudioSource` explicitly.
4. **`NowPlayingParser`**: ICY title → artist/title, repair of cp1251 text garbled into Latin-1 (mojibake), junk and slogan filtering, and emitting only when the value changes. The station name stays in `MediaItem.title`.
5. **`StationRepository`**: three layers (bundled snapshot, drift cache, remote curated file), plus Radio Browser as the long tail. Curated entries always win. IDs are namespaced (`curated:<id>` / `rb:<uuid>`) with an alias map, and favourites and recents store station snapshots.
6. **`SearchIndex`**: one fold function applied to both the query and the index, producing a common Latin skeleton. Linear scan with ranking; no SQLite FTS. The handler can call it too (for "play from search" later).
7. **`LibraryRepository`, `SettingsRepository`, `SleepTimer`**: the sleep timer is driven by a clock and lives beside the engine, never in a widget. `firstLaunchDate` is written once.
8. **go_router shell**: the mini-player plus an empty `BannerSlot` on browse screens, and never on `/player`.

**Architecture conflict resolved.** ARCHITECTURE.md maps transient focus loss (a phone call) to `Paused` (`playing: false`). With `androidStopForegroundOnPause: true`, that drops the FGS, which is exactly what PITFALLS.md Pitfall 1 warns against. **Resolution:** add an `Interrupted(transient)` state that reports `playing: true` / buffering to audio_service, so the FGS stays up. Only a user pause, a permanent focus loss, a stop, or exhausted retries may release it.

### Critical Pitfalls

(All 27 are in PITFALLS.md.) The top six:

1. **Foreground-service lifecycle tied to "paused".** Android 12+ blocks restarting the FGS from the background, Android 15+ refuses audio focus, and Android 17 fails silently, so radio never returns after a call or a tunnel. *Avoid:* keep the FGS through connecting, reconnecting and transient interruptions. Cap retries (about 3 min while online, about 10 min while offline). Release the FGS only on a user stop, an error or a user pause. Test on Android 15, 16 and 17 hardware.
2. **Treating a live stream like a file.** Resuming plays stale audio, `completed` is read as "finished", and HLS throws `BehindLiveWindowException`. *Avoid:* pause stops the transport; resume and every reconnect do a fresh `load()` at the live edge; `completed` means reconnect; never seek; hide the position and duration UI.
3. **Reconnect that never fires.** After a Wi-Fi→4G switch the socket goes quiet without an error, and ExoPlayer's timeouts plus internal retries exceed 10 s. *Avoid:* an app-level stall watchdog, debounced retry on connectivity change, backoff with jitter, and rotation through fallback streams. All of it goes in Phase 1 and is unit-tested.
4. **Screen-off Wi-Fi starvation and OEM killers.** It is **unverified whether just_audio holds a Wi-Fi lock**. *Avoid:* check with `dumpsys wifi` in Phase 1 and add a platform-channel `WifiLock` if it is missing. The battery hint must **open the settings list (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`) plus dontkillmyapp.com guidance, and must never declare or request `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`**, because Play policy risks a rejection. Show the hint only after a detected OS kill, never at first launch.
5. **Garbled Bulgarian now-playing text.** Media3 decodes ICY as UTF-8 with an ISO-8859-1 fallback, so windows-1251 titles show as `Àðòèñò`. Metadata from the previous station can also carry over after a switch. *Avoid:* a cp1251 repair heuristic plus an optional per-station `icyCharset` field; clear now-playing whenever the source changes.
6. **Content rights, catalogue caching and integrity.** Radio Browser's "BNR Horizont" entries point to an aggregator URL tagged `dist=RADIOPLAY`. jsDelivr branch URLs are measured at `max-age` 7 days and `s-maxage` 12 h, so a takedown could be delayed by up to a week. *Avoid:* catalogue CI that rejects `dist=` and token URLs; a remote `disabled` kill-switch plus a Radio Browser uuid blocklist that also overrides the bundled snapshot; a **pointer file plus version-pinned payloads with a sha256 check**; never replacing a good cache with a worse one.

Also important:
- **Bulgarian search that implements only the 2009 transliteration law.** Stripping diacritics via Unicode decomposition (NFD) destroys й. Use an explicit character map and golden tests reviewed by the owner.
- **Play Console gates.** targetSdk 36, the FGS declaration video, Data safety derived from a data-flow inventory, and 12 testers for 14 days.
- **Secret leakage from the public repository.** Set up gitignore rules, gitleaks, push protection and Play App Signing in Phase 1.

---

## Implications for Roadmap

The brief's five-phase, risk-first order is right. Research changes **what goes inside** the phases more than the order. Two owner decisions gate the roadmap:
- **Before Phase 1 (`flutter create`):** the Android package ID (permanent) and a **generic** app name. A station brand in the name triggers Play's impersonation review.
- **Before Phase 4:** personal account vs. Идев ЕООД (see Phase 4), and whether to use crash reporting (none, or Sentry).

### Phase 1: Walking skeleton and playback engine (heavier than the brief implies)

**Rationale:** Reliability is the product. The state machine is the most expensive thing to retrofit, and every other feature is a client of the engine. Most of what matters here can only be verified on a physical device, so it has to start first.

**Delivers:**
- **Project and platform setup:**
  - `flutter create` with the final package ID
  - **minSdk 24 and targetSdk/compileSdk 36 set explicitly** in `build.gradle.kts`
  - manifest: `AudioService` with `foregroundServiceType="mediaPlayback"`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `MediaButtonReceiver`, and an activity that extends `AudioServiceActivity`
  - **`network_security_config.xml` with `base-config cleartextTrafficPermitted="true"`, paired with an HTTPS-only wrapped Dart `http.Client`** for all app-owned traffic (catalogue, Radio Browser, logos)
  - secret hygiene (gitignore rules, gitleaks, push protection), a CI skeleton running analyze and test with an AAB size check, and gen-l10n scaffolding
  - `firstLaunchDate` written once
- **Engine:**
  - the `AudioEngine` facade and `StreamPlayer` port, with the real `Station`/`StationId` models and 5 hard-coded stations
  - an **explicit state machine with every state, including `Interrupted(transient)`**, plus the **FGS policy that keeps the service up through reconnects and interruptions**
  - `ReconnectPolicy` with backoff, jitter and a retry budget
  - **`StallWatchdog`**, `ConnectivityMonitor`, and **fallback-stream rotation** (it lives in the state machine, not in the Phase 4 hardening)
  - **our own `.pls`/`.m3u` resolver** with fixture tests (CRLF, BOM, lowercase keys, relative URLs, HLS disguised as m3u)
  - **explicit HLS selection** (`HlsAudioSource` by catalogue hint, `.m3u8` or `#EXT-X-`)
  - **ICY parsing with cp1251 repair**, junk filtering, and clearing on station switch
  - `handleInterruptions: false`, with audio_session events routed through the state machine
  - `PlayContext`/queue and `skipToNext/Previous` in the engine API, so next/prev semantics are decided now
  - a Wi-Fi lock check (and a platform-channel lock if needed)
  - `AndroidLoadControl` buffer tuning and time-to-audio instrumentation
  - `MediaLibraryTree` ID scheme, with only `recentRootId` wired (this gives Android 11+ media resumption)
- **Minimal UI:** a station list and mini-player.
- **Artefact:** an unlisted **FGS demo video** recorded as soon as background playback works.

**Addresses:** background playback, notification and lock screen, Bluetooth and headset controls, audio focus and becoming-noisy, auto-reconnect and fallback, all stream types, ICY now-playing, the engine side of fast start.

**Avoids:** Pitfalls 1, 2, 3, 4 (Wi-Fi lock), 5, 6, 7, 11 (target SDK, video), 13, 14, 15, 18 and 19.

**Verify on device:**
- 60 minutes screen-off on Xiaomi and Samsung
- recovery within 10 s after Wi-Fi↔4G, airplane mode or a tunnel
- resume after a phone call with the screen off and no `ForegroundServiceStartNotAllowedException`
- pause 5 minutes, then resume at the live edge
- an `http://` station that is not in any list plays in a **release** build
- a cp1251 station shows correct Cyrillic
- **with the Android 13+ notification permission denied, the media notification and controls still work.** If they do, drop the brief's permission prompt.

**Splitting option:** if Phase 1 is too big for one verified increment, split it into **1A** (skeleton, manifest and SDK, resolver, ICY, happy-path playback, hygiene) and **1B** (state machine resilience: FGS policy, watchdog, reconnect, fallback, interruptions, OEM device matrix). Each half keeps the app runnable. If you split, renumber the later phases but **keep the closed-testing gate at the start of the hardening phase.**

### Phase 2: Station catalogue, search and browse shell

**Rationale:** Stable `StationId`s and the repository must exist before library snapshots, next/prev over favourites and the Android Auto browse tree. City, genre and БНР browsing can only come from curated data. This is the first phase with several screens, so the navigation shell belongs here.

**Delivers:**
- **drift database** with migrations, schema dumps and migration tests from the first schema onward.
- **`stations-bg.json` and its JSON Schema.** Add these fields **before** hand-curation starts:
  - `aliases[]`
  - optional `frequency`
  - `streams[]` with `bitrate` and `priority` **required**, plus a `type` hint and `source`/`verifiedAt` per stream
  - optional `icyCharset`
  - `radioBrowserUuid`
  - `disabled` (the kill-switch)
  - `minAppVersion`
  - a fixed **city and oblast taxonomy** and a **normalised Bulgarian genre taxonomy**, in Cyrillic with Latin keys
- **Catalogue CI:**
  - schema validation, id uniqueness, and id stability against the previous version
  - rejection of `dist=`/`token=`/`zs=` URLs
  - playlist resolution at build time, so curated `streams[]` hold direct URLs
  - a stream probe script (`tool/probe_streams.dart`)
- **Remote update:** a **small pointer file** (`latest.json` → `{version, sha256, url}`) fetched from raw GitHub with ETag, pointing to **version-pinned jsDelivr payloads**. The app verifies the checksum and schema before swapping; falls back to the last good cache, then the bundled snapshot; never blocks launch; and **the remote takedown kill-switch plus Radio Browser uuid blocklist also override the bundled snapshot**.
- **Radio Browser client:**
  - `ServerPool` with DNS/reverse lookup and `/json/servers` discovery, failover and a 24 h cache
  - User-Agent header, `countrycode`, `url_resolved`, `hidebroken=true`
  - one click registration per user-initiated play
  - merge rules where curated entries win, with de-duplication and hiding of aggregator-tagged entries
- **`SearchIndex`:**
  - the official 2009 transliteration table, including the word-final "-ия" → "ia" rule
  - informal Latin variants (шльокавица) and homoglyph folding, via an explicit map with no Unicode decomposition
  - aliases and light fuzzy matching
  - a debounced dual-script query fan-out to Radio Browser
  - **golden tests reviewed by the owner**
- **Screens:** the go_router `StatefulShellRoute` with mini-player and `BannerSlot`; Bulgaria Home (Continue → Favourites placeholder → БНР national and regional → By city → By genre); a World tab; logo handling (upgrade to https or use the generated placeholder, with `memCacheWidth`).

**Uses:** drift, `http`, json_serializable/freezed, path_provider, cached_network_image, diacritic.

**Implements:** `StationRepository`, `CuratedCatalogSource`, `RadioBrowserClient`/`ServerPool`, merge, `SearchIndex`, app shell.

**Avoids:** Pitfalls 8, 9, 10, 16, 17 and 20 (fallback data), plus Anti-Patterns 5, 6 and 7.

**Note:** the hand-curation of data (verifying official stream URLs and БНР regional stations, contacting the main stations about permissions) is owner work that runs alongside development. Plan time for it.

### Phase 3: Listening experience

**Rationale:** This phase depends on stable IDs and the repository from Phase 2. Most of it follows well-known patterns.

**Delivers:**
- `LibraryRepository`: favourites with **drag-to-reorder** and recents, with station snapshots and `watch()` streams
- **next/prev wired to the `PlayContext` queue**, following favourites order by default, with the UI kept in sync
- the last-station snapshot, including its resolved URL, and a "Continue" resume card
- a driver-friendly full now-playing screen with a "НА ЖИВО" badge
- `SleepTimer`: 15/30/45/60/90 minutes or end of the hour, fading out over the last 10–20 s, tested with a clock across DST changes, and treated as a user-initiated stop so reconnect does not "recover" from it
- share as plain text (station name, homepage and Play link; never a raw stream URL)
- complete BG/EN strings reviewed by the owner, and a system theme
- **edge-to-edge insets and predictive back (`PopScope`), required by target 36**, tested with gesture and 3-button navigation
- optionally, the "lower quality on mobile data" toggle

**Avoids:** Pitfalls 18 (resume path), 22, 23 and 25.

### Phase 4: Hardening, polish and start of closed testing

**Rationale:** Hardening needs every screen to exist. **The personal-account closed-testing gate (at least 12 testers opted in continuously for 14 days, then an application that can be refused) must start at the beginning of this phase, not in Phase 5.** Otherwise it adds 3–6 weeks at the end.

**Delivers:**
- Error UX for each `PlaybackErrorKind`, distinguishing "no internet" from "stream unreachable"
- "Report broken station" (a mailto with station id, stream URL, error type, app/Android version and country)
- **OS-kill detection** (a `wasPlaying` flag plus heartbeat), then a one-time battery hint that **opens the settings list plus OEM guidance and never requests the exemption directly**
- An OEM device matrix (Xiaomi/HyperOS, Samsung One UI, Huawei if available) and a re-check on Android 15, 16 and 17
- TalkBack, large text and contrast checks
- Low-end performance: profiling, `select`, image cache sizes, R8 release-build playback of every stream type, and keeping `armeabi-v7a`
- About screen, licences and privacy-policy link
- **A data-flow inventory** (Radio Browser receives search terms and click registrations; stream hosts receive IP address and User-Agent; plus the crash SDK if one is chosen), which later drives the privacy policy and Data safety answers
- **If the account is personal:** create the Play app and closed track on day one; recruit 15–20 Bulgarian testers, including one abroad; ship 2–3 closed builds with changelogs; keep a feedback log for the production-access questionnaire

**Avoids:** Pitfalls 4 (hint, matrix), 11 (inventory), 12, 20, 21 and 24.

**Decision needed before this phase:** personal account vs. Идев ЕООД. An organisation account skips the tester gate but needs a D-U-N-S number, which also takes weeks.

### Phase 5: Store release

**Rationale:** No new architecture. This phase is packaging and compliance.

**Delivers:**
- a signed AAB from CI, with **Play App Signing** so CI holds only the upload key; signing only on tag builds and never for PRs from forks
- a privacy policy on GitHub Pages
- the Data safety form, derived from the inventory
- the **`mediaPlayback` FGS declaration with the video recorded in Phase 1**
- an honest content rating
- a BG/EN store listing with a **generic icon and name and no station logos without permission**, leading with "Без реклами · Без регистрация · Всички БНР програми · Търсене на кирилица и латиница"
- the production-access application, then production rollout

**Avoids:** Pitfalls 9 (listing assets), 11, 13 and 27.

### Phase Ordering Rationale

- **Engine first.** Every feature is a client of `AudioEngine`. The FGS/state-machine policy and fallback rotation cannot be bolted on later without rewriting the handler. Phase 1 is also the only phase whose success depends on real-device behaviour, so starting there gives the longest runway for device-specific surprises.
- **Model first, data second.** The `Station`/`StationId` domain types are defined in Phase 1, even though the catalogue arrives in Phase 2, so nothing is re-typed later. Schema fields (`aliases[]`, required `bitrate`/`priority`, `disabled`, `icyCharset`) must exist before curation, or the curation pass has to be redone.
- **Repository before library.** Favourites and recents snapshots, next/prev over favourites order, and the v1.1 Android Auto tree all need stable namespaced IDs and the merged repository.
- **Store gates overlap with hardening.** The 14-day closed test is calendar time that should run in parallel with Phase 4 work, not after it.
- **Android Auto readiness costs little if done in v1:** every play goes through `playFromMediaId`, the handler holds repositories, media IDs are stable, `MediaLibraryTree` is pure, and the queue reflects the play context.

### Research Flags

Phases likely to need `/gsd-plan-phase --research-phase <N>`:
- **Phase 1: YES, strongly.** Items to verify on a device or in the plugin source:
  - whether just_audio holds a Wi-Fi lock, and whether a platform-channel `WifiLock` is needed
  - whether audio focus is still requested correctly with `handleInterruptions: false`
  - whether audio_service keeps the FGS through `Interrupted` on Android 15, 16 and 17
  - `AndroidLoadControl` values for the 3 s time-to-audio target
  - the cp1251 heuristic against real БНР and commercial streams
  - that no localhost proxy starts with `useProxyForRequestHeaders: false`
  - the POST_NOTIFICATIONS exemption with the permission denied
  - a Media3 1.10 override as a reserve option only
- **Phase 2: YES, moderately.** Items to settle in planning:
  - the pointer-file and version-pinned jsDelivr design (purge API, ETag behaviour, sha256 flow)
  - the informal-Latin (шльокавица) variant table, which needs native-speaker validation
  - the Radio Browser merge and dedupe heuristics and the aggregator blocklist
  - the city/oblast and genre taxonomies
  - how the kill-switch interacts with the bundled snapshot
- **Phase 4: PARTIAL.** Current Play closed-testing questionnaire expectations; Data safety definitions for third-party endpoints (Radio Browser search terms); OEM-specific dontkillmyapp guidance.
- **v1.1 Android Auto (future milestone): YES.** Artwork delivery (`content://` vs. https), content-style extras, and whether the legacy `MediaBrowserServiceCompat` passes current Auto quality review.

Phases with standard patterns (research can be skipped):
- **Phase 3:** favourites and recents in drift, sleep timer, share, l10n, theming and edge-to-edge are well documented. The sleep-timer and reconnect interplay is already specified.
- **Phase 5:** CI signing, Play App Signing and store-listing mechanics are well documented. Reuse the Phase 4 inventory.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Versions and licences come from the pub.dev API. Audio-plugin behaviour (ICY, HLS detection, redirects, User-Agent/proxy, minSdk, Media3 version) was read from the published source. The whole set was resolved and built as a release AAB with verified 16 KB alignment. MEDIUM only for cached_network_image 4.x (a fresh major version) and Android Auto readiness. |
| Features | MEDIUM | Competitor features are the developers' own marketing claims. Complaint themes come from small review samples, so the patterns are reliable but their frequency is not. Radio Browser BG data quality is HIGH (measured directly). The шльокавица variants rely on common knowledge and need owner validation. |
| Architecture | MEDIUM-HIGH | The patterns (main-isolate handler, facade plus port, explicit state machine, reload to reach the live edge) follow from documented plugin behaviour and established ExoPlayer practice. Watchdog timings, cp1251 recovery and interruption handling are marked VERIFY. One internal conflict (the FGS state during a transient interruption) is resolved above. |
| Pitfalls | MEDIUM | Platform and Play rules are cross-checked against official Android and Play docs. Plugin issues come from GitHub (LOW–MEDIUM). CDN headers and Radio Browser data were measured. The Wi-Fi lock gap, redirect behaviour and legal characterisation are LOW until verified. |

**Overall confidence:** MEDIUM. There is high confidence in *what* to build and with *which* tools. Confidence in runtime behaviour on real Android devices stays medium until Phase 1 is verified on devices.

### Gaps to Address

- **Wi-Fi lock (unverified).** Check just_audio's source or run `dumpsys wifi` in Phase 1, and add a platform-channel `WifiLock` if it is missing.
- **FGS through transient interruptions.** Confirm on Android 15, 16 and 17 devices that the `Interrupted` → `playing: true` mapping keeps the service alive and that focus is regained after a call.
- **Cleartext and Dart sockets: the research files disagree.** STACK.md, citing Flutter's reverted network-policy change (HIGH), says Dart sockets ignore the Network Security Config. PITFALLS.md says `dart:io` enforces it for logos. The design is the same either way: an HTTPS-only Dart client, with logos upgraded to https or replaced by a placeholder. Confirm the actual behaviour on a device so nothing is broken silently.
- **Cross-protocol redirects: minor conflict.** STACK.md read `setAllowCrossProtocolRedirects(true)` in just_audio's source (HIGH), while PITFALLS.md calls it unverified. Trust the source, and confirm with the cdn.bg 302 stream in Phase 1.
- **Localhost proxy.** STACK.md says none starts with `useProxyForRequestHeaders: false` (from the source); ARCHITECTURE.md says to verify. Confirm in Phase 1.
- **POST_NOTIFICATIONS.** The exemption is documented. Verify with the permission denied on a physical Android 13+ phone before removing the brief's "request on first play" requirement.
- **Resolved-URL cache TTL.** STACK.md suggests about 1 h and ARCHITECTURE.md about 7 days. Pick a value in Phase 1 planning. Whatever the TTL, invalidate on playback error.
- **Retry budget.** ARCHITECTURE.md suggests about 3 min while online and 10 min while offline; PITFALLS.md suggests about 10 min in total. Settle this in Phase 1 planning with battery in mind.
- **jsDelivr purge and ETag behaviour** for the pointer-file design, in Phase 2.
- **Шльокавица table and golden search tests** need the owner's native-speaker review in Phase 2.
- **Geo-blocking and port issues abroad.** `stream.bnr.bg:8011` failed from the test location while the cdn.bg HLS URL worked; the cause is unknown. Order fallback streams for robustness and include a tester abroad in the closed test.
- **Owner decisions still pending:** package ID and generic app name (block Phase 1); account type and crash reporting (block Phase 4); repository visibility (it is public, so secret hygiene is mandatory from Phase 1).
- **Content rights** (linking vs. retransmission under EU law) is LOW confidence and not legal advice. Contact the main stations during Phases 2–4.

---

## Sources

### Primary (HIGH confidence)
- pub.dev API: versions, licences, publishers and download counts for every package (2026-09-24)
- Published source archives of just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4, cached_network_image 4.0.2 and flutter_radio_player 4.1.0: ICY, HLS detection, data-source factory, proxy, minSdk, Media3 version
- A local probe on Flutter 3.47.5: full `pub get`, release AAB build, ELF 16 KB alignment check, Media3 1.10 override build
- Flutter docs: supported platforms, the reverted network-policy change, gen-l10n synthetic package removal, and the Flutter 3.47 template defaults
- Android docs: behaviour changes in 15, 16 and 17 (audio focus, edge-to-edge, predictive back, background audio hardening), FGS types and background-start limits, the notification permission's media-session exemption
- Play Console Help: target API level (API 36 from 2026-08-31), FGS declaration, testing requirements for personal accounts, Data safety, impersonation policy
- Measured directly: the Radio Browser BG dataset (344 stations; http, favicon, region, duplicate and aggregator statistics) and `curl -I` cache headers from jsDelivr and raw GitHub

### Secondary (MEDIUM confidence)
- Google Play listings and reviews of 8 Bulgarian and 4 international competitors (BG/EN/DE/GB locales)
- GitHub issues: just_audio #117, #254, #518, #732, #871, #984, #1277; audio_service #599, #751, #942, #996; ExoPlayer #6753, #10254, #8675
- Radio Browser API docs and client guidelines; the audio_service wiki FAQ
- The Bulgarian Transliteration Act (ДВ бр. 19/2009) via bg.wikisource and Словоред; dontkillmyapp.com

### Tertiary (LOW confidence, needs validation)
- Whether just_audio holds a Wi-Fi lock (not found in the source; verify on a device)
- Informal Latin (шльокавица) typing variants (common knowledge; owner to validate)
- Media3 `IcyDecoder` fallback behaviour as the basis for cp1251 repair; ExoPlayer default timeouts as the basis for the watchdog
- Android Auto artwork URI requirements and whether the legacy service passes review
- Linking vs. retransmission under EU law (not legal advice)
- Google's 2026 developer-verification rollout details

---
*Research completed: 2026-09-24*
*Ready for roadmap: yes*
