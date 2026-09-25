# Roadmap: eRadioto

## Overview

Milestone v1.0 takes an empty repository to a free, ad-free Android radio app on Google Play production. The order is risk-first because reliability is the product. Phase 1 builds the playback engine that keeps playing through screen-off, calls, network switches and dead streams, and proves it on physical phones. Phase 2 puts the curated Bulgarian catalogue, worldwide Radio Browser stations and Bulgarian-aware search on top of that engine. Phase 3 adds the personal listening layer: favourites, one-tap resume, the now-playing screen, sleep timer, BG/EN localisation, theming and Android 16 edge-to-edge. Phase 4 hardens the app, runs the Play closed test from its first day, and ends with the production release.

Granularity is coarse, so the work is grouped into 4 phases. The brief's separate "store release" phase is folded into Phase 4. Play requires the privacy policy, Data safety, content rating, store listing and media-playback FGS declaration before a closed-track build can be published. With the closed test starting on day one of Phase 4, those items have to land in Phase 4 anyway, and a separate release phase would only hold REL-04.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Playback Engine & Walking Skeleton** - Reliable background live-radio playback of ~5 hard-coded Bulgarian stations, verified on physical phones
- [ ] **Phase 2: Station Catalogue, Search & Browse** - Curated remotely updatable Bulgarian catalogue, Radio Browser worldwide, script-insensitive search, app shell
- [ ] **Phase 3: Listening Experience** - Favourites, recents, one-tap resume, now-playing screen, next/prev, sleep timer, share, BG/EN, theme, edge-to-edge
- [ ] **Phase 4: Hardening, Closed Testing & Store Release** - Error UX, reporting, battery hint, accessibility, performance, closed test from day one, production on Google Play

## Phase Details

### Phase 1: Playback Engine & Walking Skeleton

**Goal**: A user on a physical Android phone can start a Bulgarian station and it keeps playing on its own through screen-off, background, calls, headphone changes, network switches and dead primary streams. The live edge, correct Cyrillic now-playing and media controls all work.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Owner decisions**: ✓ resolved 2026-09-25 — package ID `bg.izk.radio`, app name "eRadioto"
**Requirements**: PLAY-01, PLAY-02, PLAY-03, PLAY-05, PLAY-06, PLAY-07, PLAY-08, PLAY-10, PLAY-11, STRM-01, STRM-02, STRM-03, STRM-04, STRM-05, APP-06, APP-07, PLAT-01, PLAT-03, PLAT-04, PLAT-06
**Success Criteria** (what must be TRUE):

  1. On a physical phone and in a **release** build, the user can play each of ~5 hard-coded Bulgarian stations. Together they cover MP3, AAC+, HLS (including HLS behind a non-`.m3u8` URL), a `.pls`/`.m3u` playlist URL and a plain `http://` stream. Now-playing shows correct Cyrillic artist/title (including a windows-1251 station) and clears when the user switches station.
  2. With the screen off, a station plays for 60 minutes on Xiaomi and Samsung phones without dropouts or an OS kill. The user can play, pause and stop from the notification, lock screen, wired headset, Bluetooth headset and car Bluetooth, and this still works with the Android 13+ notification permission denied. After the user stops, the notification disappears and no foreground service or wake-lock remains.
  3. After a Wi-Fi to 4G switch, an airplane-mode toggle or a stream drop, audio comes back at the live edge within about 10 s without the user doing anything. If the primary stream is dead, a fallback stream plays. Retries stop after a bounded budget instead of draining the battery.
  4. A phone call with the screen off pauses the radio, and it resumes after hang-up. Navigation prompts duck the audio. Unplugging headphones or disconnecting Bluetooth pauses it. Resuming after a 5-minute user pause plays live audio, not stale buffer. Nothing restarts playback that the user paused or stopped.
  5. The app installs on Android 7.0 (minSdk 24) through current Android (target 36). Every PR runs `flutter analyze` and `flutter test` in CI, version tags produce a signed release AAB, and no key or secret exists in the public repo. The first-launch date is stored on the very first run, and no tracking SDK is present.

**Plans**: 5/13 plans executed (8 waves)

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Walking skeleton tracer: tap БГ Радио → hear it screen-off in a release build with notification, lock-screen and headset controls (blocking owner gate)

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 01-02-PLAN.md — CI on every PR (analyze, dart analyze, test, codegen staleness, release-manifest checks) + signed AAB/APK on tags + explicit SDK levels; owner keystore + secrets (blocking)
- [x] 01-03-PLAN.md — BG/EN UI via gen-l10n and an accessible mini-player with state labels
- [x] 01-04-PLAN.md — .pls/.m3u and extension-less HLS stations play (StreamResolver); app-owned traffic HTTPS-only
- [x] 01-05-PLAN.md — Owner-verified six-station lineup with ordered fallback streams + debug-only test stations (D-02 blocking decision). 4 stations shipped: N-JOY and Витоша were excluded by the owner on 2026-09-25.
- [x] 01-06-PLAN.md — cp1251 repair, sanitiser and ICY title parser (pure, golden-tested)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 01-07-PLAN.md — Localised state text, icon and channel name on the notification; FGS-table and media-ID tests; first-launch date

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 01-08-PLAN.md — Correct Cyrillic now-playing on notification, lock screen and mini-player, never stale

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 01-09-PLAN.md — Fallback rotation (two dead-on-arrival rounds), next/previous within the list, engine diagnostics

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 01-10-PLAN.md — Drop/stall reconnect at the live edge with backoff and the RetryBudget presets (online budget)
- [ ] 01-11-PLAN.md — Debug/profile-only diagnostics panel with a per-stream switcher

**Wave 7** *(blocked on Wave 6 completion)*

- [ ] 01-12-PLAN.md — Wi-Fi↔4G and airplane-mode recovery, offline wait and offline budget (connectivity)

**Wave 8** *(blocked on Wave 7 completion)*

- [ ] 01-13-PLAN.md — Calls, ducking, unplug and other media apps handled like a radio; Wi-Fi lock; Stop leaves nothing running

**UI hint**: yes
**Notes**: This is the heaviest phase. It holds the explicit playback state machine (including `Interrupted(transient)`), the FGS policy, the stall watchdog, reconnect with backoff and jitter, fallback rotation, the `.pls`/`.m3u` resolver, cp1251 repair, the Wi-Fi lock check, the `PlayContext`/next-prev engine API and the media-ID scheme. `/gsd-plan-phase 1` should run with research (strong flag). Record the unlisted FGS demo video as soon as background playback works, because Play needs it for the declaration in Phase 4. If the phase proves too big for one verified increment, split it with `/gsd-phase --insert` into a skeleton part and a resilience part.

### Phase 2: Station Catalogue, Search & Browse

**Goal**: The user can find and play any Bulgarian station by network, city, genre or name typed in Cyrillic or Latin, and any worldwide station. The catalogue is fixed or taken down remotely without an app release, and the app still works offline on first launch.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: CAT-01, CAT-02, CAT-03, CAT-04, CAT-05, CAT-06, CAT-07, BRWS-01, BRWS-02, BRWS-03, SRCH-01, SRCH-02, APP-11
**Success Criteria** (what must be TRUE):

  1. On the Bulgaria home screen, the user can browse all БНР national and regional programmes, stations by city/region and stations by genre, and play any of them. All come from the hand-verified curated catalogue and use official streams only.
  2. The user finds the right station by typing "horizont", "бг радио", informal Latin (шльокавица such as "4" for ч and "6" for ш), a station nickname or a small typo. Worldwide stations come from Radio Browser, with no duplicates of curated Bulgarian stations and no aggregator-tagged entries.
  3. A fresh install launched in airplane mode shows a working Bulgarian catalogue from the bundled snapshot. A catalogue change pushed to the repo (a fixed stream URL or a new station) reaches an installed app on its next launch with no app update. A station disabled remotely disappears, including matching Radio Browser entries, even though it is in the bundled snapshot.
  4. A catalogue PR that breaks the schema, changes an existing station id, or adds a `dist=`/token/aggregator URL fails CI.
  5. Every station shows its logo or a generated placeholder, never a broken image. The mini-player stays visible across the browse tabs, and the browse screens keep an empty reserved banner area with no ad code.

**Plans**: TBD
**UI hint**: yes
**Notes**: Research flag is moderate: the pointer-file/jsDelivr version-pinned update design, the шльокавица table, Radio Browser merge/dedupe rules, and the city/genre taxonomies. The owner hand-curates stream URLs alongside development and reviews the search golden tests as a native speaker.

### Phase 3: Listening Experience

**Goal**: The app becomes the user's daily radio. Favourites, recents and one-tap resume are in place, next/previous follows the user's own order from the car, and the app has a full now-playing screen, sleep timer and sharing, in Bulgarian or English, light or dark, edge-to-edge on Android 16.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: PLAY-04, LIB-01, LIB-02, LIB-03, LIB-04, LIB-05, LIB-06, APP-01, APP-02, APP-03, APP-10, PLAT-05
**Success Criteria** (what must be TRUE):

  1. The user can add and remove favourites, drag them into a custom order and see recently played stations. All of this survives restarts and works offline.
  2. On launch, one tap on "Continue" plays the last station, with audio within about 3 s on 4G. Next/previous from the steering wheel, headset or notification steps through favourites in the user's order, and the app UI stays in sync.
  3. From the mini-player on any browse screen, the user opens a full now-playing screen with large, driver-friendly controls and a "НА ЖИВО" badge instead of a seek bar. A sleep timer (15/30/45/60/90 min or end of the hour) fades out and stops playback, and playback does not restart on its own afterwards.
  4. The user can share a station into Viber/Messenger as readable text with a link, never a raw stream URL. The UI is in Bulgarian on a `bg` device and English otherwise, with owner-reviewed strings, and follows the system light/dark theme.
  5. Content is drawn edge-to-edge with no overlap under both gesture and 3-button navigation, and predictive back behaves correctly. `flutter test` covers catalogue parsing, playlist resolution, search/transliteration golden cases, reconnect logic and the sleep timer (including DST changes).

**Plans**: TBD
**UI hint**: yes

### Phase 4: Hardening, Closed Testing & Store Release

**Goal**: A hardened, accessible, privacy-compliant app is live on Google Play production for anyone in Bulgaria. It has passed a real closed test that started on the first day of this phase.
**Mode:** mvp
**Depends on**: Phase 3
**Owner decisions required first**: personal Play account vs Идев ЕООД (the organisation needs a D-U-N-S number; a personal account needs 12 testers for 14 days), and crash reporting (none or Sentry). Both shape the privacy policy and the Data safety answers.
**Requirements**: PLAY-09, APP-04, APP-05, APP-08, APP-09, PLAT-02, REL-01, REL-02, REL-03, REL-04
**Success Criteria** (what must be TRUE):

  1. The user always sees a clear connecting, buffering, reconnecting or live state. When playback fails, a friendly message says whether the problem is "no internet" or "station unreachable". One tap on "Report broken station" opens a prefilled email with station id, stream, error type and app/Android version, and no personal data.
  2. After the OS kills playback on a Xiaomi or Samsung phone, the user sees a one-time, optional hint that opens the battery-optimisation settings list with OEM guidance. It never appears otherwise, and the app never requests the exemption directly.
  3. With TalkBack, every control is announced. The largest font size does not break layouts, contrast passes, and player controls have large touch targets. Cold start to interactive UI is under 2 s on a mid-range phone and scrolling is smooth on a low-end phone. The About screen shows the privacy policy link and open-source licences.
  4. On the first day of the phase, a closed test goes live on Google Play and runs with at least 12 opted-in testers for 14 continuous days (if the account is personal), including one tester abroad. The privacy policy is live on GitHub Pages, and the Data safety form matches the documented data-flow inventory.
  5. Anyone in Bulgaria can find and install the app from Google Play production. It has a BG/EN listing with screenshots, a generic name and icon (no station logos without permission), an honest content rating and an approved media-playback FGS declaration, and it is signed through Play App Signing.

**Plans**: TBD
**UI hint**: yes
**Notes**: Order inside the phase matters. Opening the closed track requires the privacy policy, Data safety, content rating, a draft store listing and the FGS declaration (with the Phase 1 video), so those are prepared first. The Phase 3 build goes to testers, and the hardening work ships as 2-3 closed builds with changelogs and a feedback log for the production-access questionnaire. Re-check the OEM device matrix on Android 15/16/17. The research flag is partial: current closed-testing questionnaire expectations and the Data safety definitions for Radio Browser search terms.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Playback Engine & Walking Skeleton | 5/13 | In Progress|  |
| 2. Station Catalogue, Search & Browse | 0/TBD | Not started | - |
| 3. Listening Experience | 0/TBD | Not started | - |
| 4. Hardening, Closed Testing & Store Release | 0/TBD | Not started | - |
