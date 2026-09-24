# Online Radio App — Project Brief

> Input document for `/gsd-new-project --auto @docs/BRIEF.md` (GSD Core, github.com/open-gsd/gsd-core). Fill in §11 first.
> Owner: Ivo (solo developer, Bulgaria). Repo: https://github.com/ifchy/online-radio-app
> Status: greenfield, empty repository. Written 2026-09-24.

---

## 1. What we are building

A free Android app for listening to live internet radio, with **Bulgarian radio as the first-class experience** and worldwide stations as a secondary catalogue. It should be the fastest, most reliable way for someone in Bulgaria to open their phone and hear БНР Хоризонт, their local city station or their favourite music station — including in the car and with the screen off.

No ads, no accounts, no sign-up in v1. Ads may be introduced much later under strict rules (see §7). Android first; iOS may follow later from the same codebase.

## 2. Users and goals

**Primary users:** people in Bulgaria (and Bulgarians abroad) who listen to Bulgarian radio — commuters and drivers, people at work, older listeners used to FM radio, people on budget Android phones.

**Goals**
- Tap the app → hear the last station within ~3 seconds.
- Playback never stops on its own: screen off, app in background, network switching Wi-Fi ↔ mobile data, short signal loss.
- Finding any Bulgarian station is trivial: by name (Cyrillic or Latin), by city/region, by genre.
- Feels native, light and fast on low-end phones; small download.

**Quality targets (v1)**
- Median time-to-audio ≤ 3 s on 4G for a known-good station.
- 60 minutes of background playback with screen off on a physical device without dropouts or the OS killing the service.
- Automatic recovery after a network change within ~10 s.
- Crash-free sessions ≥ 99.5 %.
- Growth targets (installs, retention) to be set by the owner later.

## 3. Scope

### v1.0 — must have
**Playback**
- Background playback via a media foreground service; media notification and lock-screen controls.
- Bluetooth / wired headset buttons and car Bluetooth controls.
- Audio focus: pause or duck for calls and other apps; pause when headphones are unplugged ("becoming noisy").
- Auto-reconnect with backoff when the stream drops or the network changes; for live radio, reconnect to the live edge.
- Buffering/connecting states and clear, friendly error states.
- Support common stream types: MP3, AAC/HE-AAC (AAC+), HLS (`.m3u8`), and playlist wrappers (`.pls`, `.m3u`) resolved to the real stream URL. Many stations use plain `http://` streams — cleartext must be allowed for media, scoped as narrowly as practical.
- "Now playing" artist/title from ICY metadata when the station provides it.

**Stations**
- Curated, hand-verified Bulgarian catalogue (see §5), updatable without an app release.
- Worldwide search/browse through the Radio Browser API (see §5).
- Bulgaria home screen: national programmes (БНР Хоризонт, Христо Ботев and the БНР regional stations), by city/region (София, Пловдив, Варна, Бургас, Стара Загора, Сливен, Ямбол, …), by genre (pop, folk/попфолк, rock, jazz, classical, news/talk, …).
- Search that is case-, diacritic- and script-insensitive: "horizont" finds "Хоризонт", "бг радио" finds "BG Radio". Uses the official Bulgarian transliteration in both directions, plus light fuzzy matching.
- Station logos with a generated placeholder when missing.

**Personal**
- Favourites (local only), recently played, resume last station with one tap on launch.
- Sleep timer (15/30/45/60/90 min, end of current hour).
- Share a station (plain link/text — works in Viber, Messenger, etc.).

**App**
- UI in Bulgarian and English; Bulgarian by default when the device locale is `bg`.
- Light/dark theme following the system.
- Mini-player visible across screens + full "now playing" screen.
- "Report a broken station" (prefilled email or simple form — no backend).
- About screen, privacy policy link, open-source licences.
- Record the first-launch date locally from day one (needed for the future ads rule in §7; nothing else uses it in v1).

### v1.1 — should have (next milestone)
- Android Auto (browse favourites / Bulgarian categories / recents, play from the car screen).
- Home-screen widget (last station + play/pause) and a Quick Settings tile.
- Alarm clock: wake up to a chosen station.
- Data-saver mode: prefer lower-bitrate streams on mobile data; show approximate data used.
- Song history per station from ICY metadata + "search this song" (YouTube / Spotify / web).
- Chromecast.
- "Stations near me" (city-level, from coarse location or manual city choice).

### Later — could have
- iOS release (+ CarPlay) from the same codebase, once the Apple developer fee is justified.
- Wear OS controls.
- Equaliser.
- Ads and "remove ads" purchase (§7).

### Explicitly out of scope for v1
User accounts, cloud sync, backend server, recording streams, podcasts, social features, lyrics, iOS, any ads or analytics SDKs that track users.

## 4. Technology decisions

**Framework: Flutter (stable) + Dart 3, Android as the only v1 target.**

Why (decided after comparing React Native, Flutter and native Kotlin in Sept 2026):
- The audio layer is the product. React Native's leading audio library (react-native-track-player) moved to a commercial licence from v5 (≈ €99/month per commercial app); v4 is Apache-2.0 but stale on the New Architecture. `expo-audio` does background playback and lock-screen controls but has no Android Auto support.
- Flutter's `just_audio` + `audio_service` + `audio_session` are free (MIT), mature, use ExoPlayer/Media3 on Android, and cover background playback, media notification, ICY metadata, Android Auto and (later) iOS/CarPlay from one codebase.
- Native Kotlin + Media3 would be the best pure-Android option but means a full rewrite for iOS later.

**Stack (to be validated by phase research / package legitimacy gate)**
- Audio: `just_audio`, `audio_service`, `audio_session`. Wrap them behind our own `AudioEngine` interface so the engine can be replaced (e.g. by a native Media3 module) without touching UI code.
- State management: Riverpod.
- Navigation: go_router.
- Local data: drift (SQLite) for favourites, history and the cached catalogue; shared_preferences for simple settings.
- HTTP: `http` or `dio`.
- Localisation: `flutter_localizations` + ARB files (`bg`, `en`).
- Images: cached network images with placeholders.
- CI: GitHub Actions — `flutter analyze`, `flutter test`, build a signed release AAB on version tags.
- Min/target SDK: support older budget phones as far as the stack reasonably allows; target whatever API level Google Play currently requires.

**Hard constraints**
- Only free / permissively licensed dependencies that are compatible with a future ad-supported app. No commercially licensed SDKs.
- No backend in v1. Static files (catalogue, privacy policy) are hosted from the GitHub repo / GitHub Pages / a free CDN.
- Never commit signing keys, keystores or secrets (the repository is public).

## 5. Station data

**A. Curated Bulgarian catalogue (primary source for Bulgaria)**
- File `catalog/stations-bg.json` in this repo, with a `version` field and a JSON schema.
- Per station: stable `id`, `name` (Cyrillic), `nameLatin`, `streams[]` (url, codec, bitrate, priority — first is default, others are fallbacks), `logo`, `homepage`, `city`, `region`, `genres[]`, `network` (e.g. БНР), optional `radioBrowserUuid`.
- The app fetches the latest version on launch (with ETag/If-None-Match caching) from raw GitHub or jsDelivr, and ships a bundled snapshot for first launch and offline.
- Initial list built by hand in the catalogue phase: all БНР programmes, the major national commercial networks and the main regional/city stations. Every stream URL verified to play.
- Only official streams published by the stations themselves.

**B. Radio Browser API (worldwide + long tail)**
- Free, community-run directory (~60k stations, 240+ countries); data is public domain.
- Follow its client guidelines: discover servers dynamically (do not hard-code one mirror), send a descriptive `User-Agent`, use `stationuuid` as the ID, `countrycode` (not `country`), prefer `url_resolved`, and register a click when a station starts playing.
- Bulgarian results from Radio Browser are merged with the curated list; curated entries win on conflicts.

## 6. Non-functional requirements
- Performance: cold start to interactive UI < 2 s on a mid-range phone; smooth scrolling on low-end devices; keep APK/AAB small.
- Battery: no wake-locks when not playing; stop the foreground service when playback stops.
- OEM background-killing (Xiaomi, Samsung, Huawei battery optimisers): test on real devices; show a one-time, optional hint to exclude the app from battery optimisation if playback is killed.
- Android 13+ notification permission requested at the right moment (first play), with graceful behaviour if denied.
- Accessibility: TalkBack labels on all controls, large text support, sufficient contrast, big touch targets on the player.
- Privacy: no personal data collected in v1; no tracking. If crash reporting is added, disclose it in the Play Data safety form and privacy policy.
- Testing: unit tests for catalogue parsing, search/transliteration, reconnect logic and sleep timer; playback behaviour is verified manually on a **physical Android phone** (emulators are not sufficient for background audio).

## 7. Monetisation (future — constraints that apply now)
- v1 has **no ads**. Ads come only in a dedicated later milestone, once there is a meaningful user base.
- When ads arrive: **banner ads only**, shown only to users who have had the app for at least ~30 days (from the first-launch date stored in v1), never covering player controls, never on the full "now playing" screen.
- **Never**: interstitials, app-open ads, full-screen or rewarded video, audio ads that interrupt the stream.
- EEA/Bulgaria requires a Google-certified consent platform (e.g. Google's UMP SDK) before serving personalised ads.
- Complementary options: one-time "remove ads / support the app" in-app purchase; direct "featured station" partnerships with Bulgarian stations.
- v1 UI should leave room for a small banner area on browse screens later, but must not contain any ad code.

## 8. Distribution and compliance
- Google Play only in v1 (one-time developer registration fee).
- Personal Play accounts created after 13 Nov 2023 must run a closed test with ≥ 12 opted-in testers for 14 continuous days before production access. Organisation accounts are exempt — the owner may publish under his company (Идев ЕООД, requires a D-U-N-S number). **Owner decision pending.**
- Required: privacy policy URL (host on GitHub Pages), Data safety form, content rating, store listing in Bulgarian and English with screenshots, foreground-service (media playback) declaration.
- Station rights: the app only plays stations' own publicly offered streams and links to their websites. Honour removal requests promptly. Plan to contact the main Bulgarian stations for permission and logo use — also the start of future partnerships.

## 9. Suggested roadmap — milestone v1.0

1. **Walking skeleton & playback engine (risk first).** Flutter project, CI, `AudioEngine` abstraction, a hard-coded list of ~5 Bulgarian stations covering MP3, AAC+, HLS and a `.pls` URL. Background playback, media notification, lock screen, headset/Bluetooth buttons, audio focus, becoming-noisy, auto-reconnect, ICY now-playing. *Done when:* 60 min screen-off playback and recovery from a Wi-Fi→4G switch on a physical phone.
2. **Station catalogue.** Curated `stations-bg.json` + schema + remote update/caching + bundled snapshot; Radio Browser integration; Bulgaria home (national / by city / by genre), World browse; search with transliteration.
3. **Listening experience.** Favourites, recents, resume last station, mini-player + now-playing screen, sleep timer, share, BG/EN localisation, light/dark theme.
4. **Hardening & polish.** Fallback streams, error UX, broken-station reporting, low-end device performance, accessibility pass, battery-optimisation hint, app icon, splash, about/licences.
5. **Store release.** Signing, release AAB, privacy policy page, Data safety, store listing BG/EN, closed testing track, production rollout.

Then: milestone v1.1 (Android Auto, widget, alarm, data saver, song history, Chromecast), later milestone for ads + iOS.

## 10. Risks
- Stream URLs change or die → curated list with fallbacks, remote catalogue updates, in-app reporting.
- Rights / takedown requests from stations → official streams only, fast removal, proactive contact.
- Radio Browser data quality for Bulgaria is uneven → curated entries override it.
- Flutter audio plugins are maintained by a small team → keep them behind `AudioEngine`.
- OEM battery killers → real-device testing on popular brands in Bulgaria.
- Play review for media foreground service and (in v1.1) Android Auto quality requirements.

## 11. Open questions for the owner
Fill these in before running `/gsd-new-project --auto` — in `--auto` mode GSD will not ask, it will pick defaults.

- App name: _TBD_ (working title "Online Radio")
- Android package ID: _TBD_ (e.g. `bg.<yourdomain>.radio`) — used by `flutter create` in phase 1 and can never change after publishing.
- Publish as a personal account or as Идев ЕООД: _TBD_ (only matters for phase 5).
- Crash reporting in v1: _TBD_ — none, Firebase Crashlytics, or Sentry.
- GitHub repository: public (current) or private: _TBD_.

## 12. Working agreements
- Every phase leaves the app runnable; `flutter analyze` and `flutter test` must pass.
- Playback-related phases are verified by the owner on a physical Android phone.
- Bulgarian UI strings are reviewed by the owner (native speaker).
- Conventional commits; phase work lands via PRs.
