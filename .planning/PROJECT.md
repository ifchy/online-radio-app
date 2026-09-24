# eRadioto

## What This Is

A free Android app for listening to live internet radio, with **Bulgarian radio as the first-class experience** and worldwide stations as a secondary catalogue. It aims to be the fastest, most reliable way for someone in Bulgaria to open their phone and hear БНР Хоризонт, their local city station or their favourite music station — including in the car and with the screen off. No ads, no accounts, no sign-up in v1. Android first; iOS may follow later from the same Flutter codebase.

## Core Value

Tap the app → hear the last Bulgarian station within ~3 seconds, and playback never stops on its own (screen off, background, network switches, short signal loss).

## Business Context

- **Customer**: People in Bulgaria and Bulgarians abroad who listen to Bulgarian radio — commuters/drivers, people at work, older FM-radio listeners, budget-Android users.
- **Revenue model**: None in v1 (free, no ads). Later: banner-only ads for users ≥ ~30 days old + one-time "remove ads / support" IAP + featured-station partnerships.
- **Success metric**: Reliability first — median time-to-audio ≤ 3 s on 4G, crash-free sessions ≥ 99.5 %. Growth targets (installs, retention) to be set by the owner later.
- **Strategy notes**: `docs/BRIEF.md` (source brief, 2026-09-24)

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Playback**
- [ ] Background playback via a media foreground service, with media notification and lock-screen controls
- [ ] Bluetooth / wired headset buttons and car Bluetooth controls
- [ ] Audio focus: pause or duck for calls and other apps; pause on headphone unplug ("becoming noisy")
- [ ] Auto-reconnect with backoff on stream drop or network change; live radio reconnects to the live edge
- [ ] Clear buffering/connecting states and friendly error states
- [ ] Stream types: MP3, AAC/HE-AAC (AAC+), HLS (`.m3u8`), and `.pls` / `.m3u` playlist wrappers resolved to the real stream URL; cleartext `http://` media allowed, scoped as narrowly as practical
- [ ] "Now playing" artist/title from ICY metadata when provided

**Stations**
- [ ] Curated, hand-verified Bulgarian catalogue (`catalog/stations-bg.json` + JSON schema), updatable without an app release (remote fetch with ETag caching + bundled snapshot)
- [ ] Worldwide search/browse through the Radio Browser API (following its client guidelines)
- [ ] Bulgaria home: national programmes (БНР Хоризонт, Христо Ботев, БНР regional), by city/region, by genre
- [ ] Search that is case-, diacritic- and script-insensitive (official Bulgarian transliteration both ways + light fuzzy matching)
- [ ] Station logos with generated placeholders when missing

**Personal**
- [ ] Favourites (local only), recently played, one-tap resume of last station on launch
- [ ] Sleep timer (15/30/45/60/90 min, end of current hour)
- [ ] Share a station as plain link/text

**App**
- [ ] UI in Bulgarian and English; Bulgarian by default when device locale is `bg`
- [ ] Light/dark theme following the system
- [ ] Mini-player across screens + full "now playing" screen
- [ ] "Report a broken station" (prefilled email or simple form, no backend)
- [ ] About screen, privacy policy link, open-source licences
- [ ] Record first-launch date locally from day one (for future ads rule)

**Release**
- [ ] Signed release AAB via CI, privacy policy on GitHub Pages, Data safety form, BG/EN store listing, closed testing → production on Google Play

### Out of Scope

- User accounts, cloud sync — no backend in v1; favourites stay local
- Backend server — static files only (GitHub / GitHub Pages / free CDN)
- Recording streams — rights risk, not core value
- Podcasts, social features, lyrics — not live radio; dilute focus
- iOS in v1 — Apple developer fee not yet justified; Flutter keeps the door open
- Any ads or tracking analytics SDKs in v1 — trust and privacy; ads come in a dedicated later milestone
- Interstitials, app-open, full-screen/rewarded video, stream-interrupting audio ads — **never**, even later
- Android Auto, widget, Quick Settings tile, alarm, data-saver, song history, Chromecast, "stations near me" — deferred to v1.1
- Wear OS, equaliser, CarPlay — later

## Context

- **Greenfield**: empty repo (`https://github.com/ifchy/online-radio-app`, currently public). Solo developer (Ivo), based in Bulgaria, native Bulgarian speaker.
- **Stream ecosystem**: many Bulgarian stations use plain `http://` Icecast/Shoutcast streams, some HLS; URLs change or die — hence curated list with fallback streams, remote catalogue updates and in-app reporting.
- **Radio Browser API**: free, community-run (~60k stations, public domain data). Must discover servers dynamically, send descriptive `User-Agent`, use `stationuuid`, `countrycode`, prefer `url_resolved`, register a click on play. Bulgarian data quality is uneven → curated entries win on conflicts.
- **Android realities**: OEM battery killers (Xiaomi, Samsung, Huawei) — test on real devices, optional one-time battery-optimisation hint. Android 13+ notification permission requested on first play. Media-playback foreground-service declaration needed for Play.
- **Quality targets (v1)**: median time-to-audio ≤ 3 s on 4G; 60 min screen-off background playback on a physical device without dropouts; recovery after network change within ~10 s; crash-free sessions ≥ 99.5 %; cold start < 2 s on mid-range phone; small APK/AAB.
- **Testing**: unit tests for catalogue parsing, search/transliteration, reconnect logic, sleep timer; playback verified manually on a **physical Android phone** (emulators insufficient for background audio).
- **Monetisation constraints that apply now**: v1 UI should leave room for a small banner area on browse screens later, but contain no ad code. First-launch date recorded from day one.

## Constraints

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

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter + Dart 3 over React Native / native Kotlin | Free, mature audio stack (just_audio/audio_service, ExoPlayer/Media3 underneath) covering background, notification, ICY, Android Auto and later iOS/CarPlay from one codebase | — Pending |
| Wrap audio plugins behind `AudioEngine` interface | Replaceability if plugins stagnate; isolates UI from engine | — Pending |
| Curated BG catalogue as static JSON in repo, Radio Browser for the rest | No backend; curated data beats uneven community data for Bulgaria | — Pending |
| Risk-first roadmap: playback engine before catalogue/UI | Audio reliability is the product; validate on real devices early | — Pending |
| No ads in v1; banner-only later, ≥ 30-day users, never interstitials | Trust, retention, respectful UX | — Pending |
| App name: **eRadioto** | Owner choice 2026-09-25. Generic ("the radio"), no station brand → clear of Play impersonation review. Search should also match "еРадиото"/"eradioto". Store title can add keywords, e.g. "eRadioto – Радио онлайн България". Trademark/Play availability check still to do before release | ✓ Decided |
| Android package ID: **`bg.izk.radio`** | Owner choice 2026-09-25. Neutral (independent of app name, so the name can still change); permanent once published. Used by `flutter create` in Phase 1 | ✓ Decided |
| Publish as personal account vs Идев ЕООД | Personal accounts need 12 testers × 14 days closed test; organisation needs D-U-N-S | — Pending (owner, blocks store release) |
| Crash reporting in v1 | Options: none / Firebase Crashlytics / Sentry; affects privacy policy + Data safety | — Pending (owner) |
| Repository visibility | Currently public; implies strict secret hygiene | — Pending (owner) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-25 after owner decided app name + package ID*
