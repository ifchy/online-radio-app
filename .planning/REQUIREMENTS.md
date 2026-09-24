# Requirements: eRadioto

**Defined:** 2026-09-24
**Core Value:** Tap the app → hear the last Bulgarian station within ~3 seconds, and playback never stops on its own (screen off, background, network switches, short signal loss).

Source: `docs/BRIEF.md` + `.planning/research/SUMMARY.md` (auto mode: all table stakes + all brief v1.0 features; research-flagged table stakes included; unmentioned differentiators deferred).

## v1 Requirements

Requirements for initial release (milestone v1.0). Each maps to exactly one roadmap phase.

### Playback

- [ ] **PLAY-01**: User can keep listening with the screen off or the app in the background (media foreground service), and the service stops when the user stops playback
- [ ] **PLAY-02**: User can control playback (play/pause/stop, station name, now playing) from the media notification and lock screen
- [ ] **PLAY-03**: User can control playback with wired headset, Bluetooth headset and car Bluetooth buttons
- [ ] **PLAY-04**: User can skip to the next/previous station from media buttons (headset, steering wheel, notification), cycling through the list playback was started from (favourites by default), with the UI staying in sync
- [ ] **PLAY-05**: Playback ducks for navigation prompts, pauses for phone calls and other apps, and resumes after a transient interruption — unless the user had paused
- [ ] **PLAY-06**: Playback pauses when headphones are unplugged or Bluetooth audio disconnects ("becoming noisy")
- [ ] **PLAY-07**: After a stream drop, stall or Wi-Fi ↔ mobile data switch, playback automatically reconnects at the live edge within ~10 s, with backoff and a bounded retry budget, while the foreground service stays alive
- [ ] **PLAY-08**: When a station's primary stream fails, the app automatically tries its fallback streams in priority order
- [ ] **PLAY-09**: User sees clear connecting / buffering / reconnecting / live states and a friendly error state that distinguishes "no internet" from "station unreachable"
- [ ] **PLAY-10**: User stops and pauses (including sleep timer and becoming-noisy) are treated as deliberate — reconnect logic never restarts playback the user stopped
- [ ] **PLAY-11**: Resuming after a pause always rejoins the live stream (never stale buffered audio); no seek bar is shown for live radio

### Streams

- [ ] **STRM-01**: User can play MP3 and AAC/HE-AAC (AAC+) Icecast/Shoutcast streams
- [ ] **STRM-02**: User can play HLS (`.m3u8`) streams, including HLS served under non-`.m3u8` URLs
- [ ] **STRM-03**: User can play stations whose URL is a `.pls` or `.m3u` playlist (resolved to the real stream URL by the app)
- [ ] **STRM-04**: User can play plain `http://` streams in release builds, while all app-owned traffic (catalogue, Radio Browser API, logos) is HTTPS-only
- [ ] **STRM-05**: User sees "now playing" artist/title from ICY metadata when the station provides it, with correct Cyrillic (windows-1251 repair) and no stale title after switching stations

### Catalogue

- [ ] **CAT-01**: User gets a curated, hand-verified Bulgarian catalogue (all БНР programmes incl. regional, major national commercial networks, main regional/city stations) using only official streams
- [ ] **CAT-02**: The curated catalogue (`catalog/stations-bg.json` + JSON schema: stable id, Cyrillic + Latin names, `aliases[]`, prioritised `streams[]` with bitrate, logo, homepage, city, region, genres, network, optional `radioBrowserUuid`/`icyCharset`, `disabled`) is validated in CI (schema, id stability, rejected aggregator/token URLs)
- [ ] **CAT-03**: User gets catalogue updates without an app release (remote pointer + version-pinned payload with ETag caching and checksum verification), and the app works on first launch and offline from a bundled snapshot
- [ ] **CAT-04**: A station can be removed remotely (takedown kill-switch) — hiding both the curated entry and matching Radio Browser entries, overriding the bundled snapshot
- [ ] **CAT-05**: User can search and browse worldwide stations via the Radio Browser API, following its client guidelines (dynamic server discovery, descriptive User-Agent, `stationuuid`, `countrycode`, `url_resolved`, click registration on play)
- [ ] **CAT-06**: Bulgarian Radio Browser results are merged with the curated list without duplicates; curated entries win on conflicts and aggregator-tagged entries are hidden
- [ ] **CAT-07**: User sees station logos, with a generated placeholder when a logo is missing or not available over HTTPS

### Browse & Search

- [ ] **BRWS-01**: User can browse Bulgarian national programmes (БНР Хоризонт, Христо Ботев, БНР regional stations) on the Bulgaria home screen
- [ ] **BRWS-02**: User can browse Bulgarian stations by city/region (София, Пловдив, Варна, Бургас, Стара Загора, Сливен, Ямбол, …)
- [ ] **BRWS-03**: User can browse Bulgarian stations by genre (pop, folk/попфолк, rock, jazz, classical, news/talk, …)
- [ ] **SRCH-01**: User can find a station by name regardless of case, diacritics or script ("horizont" → "Хоризонт", "бг радио" → "BG Radio"), using the official Bulgarian transliteration in both directions
- [ ] **SRCH-02**: User can find stations using informal Latin typing (шльокавица: 4=ч, 6=ш, q=я, w=в, …), station aliases/nicknames, and minor typos (light fuzzy matching)

### Library (Personal)

- [ ] **LIB-01**: User can add/remove favourites (stored locally) and they keep working offline
- [ ] **LIB-02**: User can reorder favourites by drag-and-drop (order also drives next/previous station)
- [ ] **LIB-03**: User can see recently played stations
- [ ] **LIB-04**: User can resume the last station with one tap on launch (target: audio within ~3 s on 4G)
- [ ] **LIB-05**: User can set a sleep timer (15/30/45/60/90 min, end of current hour) that fades out and stops playback
- [ ] **LIB-06**: User can share a station as plain text/link (works in Viber, Messenger, etc.)

### App

- [ ] **APP-01**: User sees the UI in Bulgarian or English; Bulgarian by default when the device locale is `bg`
- [ ] **APP-02**: App follows the system light/dark theme
- [ ] **APP-03**: User sees a mini-player on all browse screens and can open a full "now playing" screen with large, driver-friendly controls
- [ ] **APP-04**: User can report a broken station (prefilled email with station id, stream, error type, app/Android version — no personal data, no backend)
- [ ] **APP-05**: User can open an About screen with privacy policy link and open-source licences
- [ ] **APP-06**: App records the first-launch date locally from the very first launch (reserved for the future ads rule; unused in v1)
- [ ] **APP-07**: Media controls work with notification permission denied on Android 13+; if a permission prompt is needed at all, it is asked at first play and denial degrades gracefully
- [ ] **APP-08**: If the OS kills playback, user sees a one-time, optional hint that opens battery-optimisation settings (never requests the exemption directly)
- [ ] **APP-09**: All controls have TalkBack labels, support large text, meet contrast guidelines, and player controls have large touch targets
- [ ] **APP-10**: App handles edge-to-edge display and predictive back (Android target SDK 36) with gesture and 3-button navigation
- [ ] **APP-11**: Browse screens reserve layout room for a future small banner area, with no ad code in v1

### Platform & Quality

- [ ] **PLAT-01**: App installs on Android 7.0+ (minSdk 24) and targets the API level Google Play requires (36)
- [ ] **PLAT-02**: Cold start to interactive UI < 2 s on a mid-range phone; smooth scrolling on low-end devices; small AAB
- [ ] **PLAT-03**: 60 minutes of screen-off background playback on a physical phone (incl. Xiaomi and Samsung) without dropouts or OS kills
- [ ] **PLAT-04**: CI runs `flutter analyze` + `flutter test` on every PR and builds a signed release AAB on version tags; no signing keys or secrets are ever committed
- [ ] **PLAT-05**: Unit tests cover catalogue parsing, playlist resolution, search/transliteration (owner-reviewed golden cases), reconnect logic and sleep timer
- [ ] **PLAT-06**: No wake-locks or foreground service when not playing; no personal data collected and no tracking SDKs

### Release

- [ ] **REL-01**: A closed test track runs on Google Play (≥ 12 opted-in testers for 14 continuous days if publishing as a personal account)
- [ ] **REL-02**: A privacy policy is hosted on GitHub Pages and the Data safety form matches a documented data-flow inventory
- [ ] **REL-03**: Store listing in Bulgarian and English with screenshots, content rating, generic name/icon (no station logos without permission), and the media-playback foreground-service declaration (with demo video)
- [ ] **REL-04**: App is released to production on Google Play via Play App Signing

## v2 Requirements

Deferred to milestone v1.1 or later. Tracked but not in the current roadmap.

### Car & Surfaces (v1.1)

- **AUTO-01**: User can browse favourites / Bulgarian categories / recents and play from the Android Auto car screen (first v1.1 item)
- **SURF-01**: Home-screen widget with last station + play/pause
- **SURF-02**: Quick Settings tile
- **SURF-03**: Chromecast playback

### Listening Extras (v1.1)

- **XTRA-01**: Alarm clock that wakes the user with a chosen station
- **XTRA-02**: Data-saver mode (prefer lower-bitrate streams on mobile data, show approximate data used)
- **XTRA-03**: Song history per station from ICY metadata + "search this song" (YouTube / Spotify / web)
- **XTRA-04**: "Stations near me" (city-level, coarse location or manual city)
- **XTRA-05**: Autoplay when car Bluetooth connects
- **XTRA-06**: Favourites export/import

### Later

- **LATER-01**: iOS release (+ CarPlay) from the same codebase
- **LATER-02**: Wear OS controls
- **LATER-03**: Equaliser
- **LATER-04**: Banner-only ads for users ≥ ~30 days (UMP consent in EEA) + one-time "remove ads / support" purchase; featured-station partnerships

## Out of Scope

| Feature | Reason |
|---------|--------|
| User accounts, cloud sync | No backend in v1; favourites stay local |
| Backend server | Static hosting only (GitHub / GitHub Pages / jsDelivr) |
| Recording streams | Rights risk; not core value |
| Podcasts, news articles, lyrics, social features | Not live radio; dilutes focus |
| iOS in v1 | Apple developer fee not yet justified |
| Any ads, analytics or tracking SDKs in v1 | Privacy and trust; ads only in a dedicated later milestone |
| Interstitial, app-open, full-screen/rewarded video, stream-interrupting audio ads | **Never** — #1 complaint about competitor apps |
| In-app popularity rankings ("Top 20") | Would require tracking |
| Globe/map-style browse UI | Doesn't serve the Bulgarian-first use case |
| Unofficial / aggregator stream URLs | Content rights — official station streams only |
| Commercially licensed SDKs (e.g. react-native-track-player v5, radio_player CC BY-NC-SA) | Licence incompatible with future ad-supported app |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAY-01 | Phase 1 | Pending |
| PLAY-02 | Phase 1 | Pending |
| PLAY-03 | Phase 1 | Pending |
| PLAY-04 | Phase 3 | Pending |
| PLAY-05 | Phase 1 | Pending |
| PLAY-06 | Phase 1 | Pending |
| PLAY-07 | Phase 1 | Pending |
| PLAY-08 | Phase 1 | Pending |
| PLAY-09 | Phase 4 | Pending |
| PLAY-10 | Phase 1 | Pending |
| PLAY-11 | Phase 1 | Pending |
| STRM-01 | Phase 1 | Pending |
| STRM-02 | Phase 1 | Pending |
| STRM-03 | Phase 1 | Pending |
| STRM-04 | Phase 1 | Pending |
| STRM-05 | Phase 1 | Pending |
| CAT-01 | Phase 2 | Pending |
| CAT-02 | Phase 2 | Pending |
| CAT-03 | Phase 2 | Pending |
| CAT-04 | Phase 2 | Pending |
| CAT-05 | Phase 2 | Pending |
| CAT-06 | Phase 2 | Pending |
| CAT-07 | Phase 2 | Pending |
| BRWS-01 | Phase 2 | Pending |
| BRWS-02 | Phase 2 | Pending |
| BRWS-03 | Phase 2 | Pending |
| SRCH-01 | Phase 2 | Pending |
| SRCH-02 | Phase 2 | Pending |
| LIB-01 | Phase 3 | Pending |
| LIB-02 | Phase 3 | Pending |
| LIB-03 | Phase 3 | Pending |
| LIB-04 | Phase 3 | Pending |
| LIB-05 | Phase 3 | Pending |
| LIB-06 | Phase 3 | Pending |
| APP-01 | Phase 3 | Pending |
| APP-02 | Phase 3 | Pending |
| APP-03 | Phase 3 | Pending |
| APP-04 | Phase 4 | Pending |
| APP-05 | Phase 4 | Pending |
| APP-06 | Phase 1 | Pending |
| APP-07 | Phase 1 | Pending |
| APP-08 | Phase 4 | Pending |
| APP-09 | Phase 4 | Pending |
| APP-10 | Phase 3 | Pending |
| APP-11 | Phase 2 | Pending |
| PLAT-01 | Phase 1 | Pending |
| PLAT-02 | Phase 4 | Pending |
| PLAT-03 | Phase 1 | Pending |
| PLAT-04 | Phase 1 | Pending |
| PLAT-05 | Phase 3 | Pending |
| PLAT-06 | Phase 1 | Pending |
| REL-01 | Phase 4 | Pending |
| REL-02 | Phase 4 | Pending |
| REL-03 | Phase 4 | Pending |
| REL-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 55 total
- Mapped to phases: 55
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-24*
*Last updated: 2026-09-24 after roadmap creation (traceability mapped, 4 phases)*
