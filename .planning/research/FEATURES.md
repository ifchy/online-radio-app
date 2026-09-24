# Feature Research

**Domain:** Live internet radio player for Android (Bulgarian radio first, worldwide second)
**Researched:** 2026-09-24
**Confidence:** MEDIUM. Competitor features, ratings and review text were scraped directly from Google Play listings in the BG, GB, DE and EN locales on 2026-09-24. Bulgarian data quality was measured with a live Radio Browser query. The weak point is the review sample: Play only shows 3 to 4 "most relevant" reviews per locale, so complaint *patterns* are reliable but their *frequency* is not measured.

---

## Market Snapshot: What Bulgarians Use Today

| App (package) | Installs | Rating / reviews | Updated | Ads / IAP | Notes |
|---|---|---|---|---|---|
| **Радио Онлайн България: Live FM** (`net.radioexpert.radio.bulgaria`) | 500K+ | 4.7 / 33.4K | Apr 2026 | Ads + IAP | Market leader. Serbian developer (confirmed by a user review). Browse by city and genre, sorted by popularity. Recents hold the last 50. |
| **Radio Bulgaria FM online** (`com.radiolight.bulgarie`) | 100K+ | 4.9 / 21.1K | Sep 2026 | Ads + IAP | Generic country-template app family. Claims 400+ stations, Android Auto, Chromecast, widget, alarm, sleep timer. |
| **Radio Bulgaria – radio online** (`radio.bulgaria.play.online.free`) | 100K+ | 4.9 / 11.6K | Aug 2026 | Ads + IAP | Template app. Mixes in podcasts. Dark mode, alarm, sleep timer, Chromecast. |
| **BG Radio – Bulgarian Radios** (`com.crystalmissions.bgradio`) | 50K+ | 5.0 / 720 | Jan 2026 | Ads + IAP | The most Bulgaria-focused of the group. High/low quality choice, equaliser, alarm, Cast, Android Auto, ICY song info. Loyal users ("using it 4+ years"). |
| **Radio Bulgaria – Online radio** (`com.radiofmapp.bulgaria`) | 50K+ | 4.7 / 1.05K | Oct 2025 | Ads | Template app. Has an in-app "Top 20", find by city, favourites that can be sorted. |
| **Radio Bulgaria – Radio FM** (`com.worldradios.bulgarie`) | 10K+ | 4.9 / 2.12K | Sep 2026 | Ads + IAP | Template app. Alarm, widget, Cast, Android Auto, podcasts. |
| **BNR Bulgarian National Radio** (`bg.bnr.app`, official) | 1K+ | 4.1 / 27 | Jul 2026 | Google ads | News-first portal app with live streams, podcasts and kids' content. Very low adoption. |
| Radio Garden / TuneIn / myTuner / Simple Radio (global) | 10M–100M+ | 4.6–4.9 | 2025–26 | Ads + IAP/subscription | Worldwide, generic. BG coverage is shallow. Heavy ad complaints. |

**What this means (MEDIUM confidence):**
1. **The BG market is served almost entirely by generic "Radio <Country>" template apps from foreign app factories**, all of them ad-funded. None is a Bulgarian-native product with curated regional data, Bulgarian-aware search or an ad-free experience.
2. **The public broadcaster's own app barely registers** (1K+ installs). The БНР regional stations, which the brief lists as a first-class category, have no good home on Android.
3. **The competitor feature floor is higher than our v1 list.** The popular apps all advertise Android Auto, Chromecast, alarm and a widget. We defer all four to v1.1 (see Gap Flags).

---

## What Users Complain About (Play reviews, 2026)

Ordered by how often a theme came up across the sampled reviews and how severe it was:

| # | Complaint theme | Evidence (paraphrased; app) | Implication for us |
|---|---|---|---|
| 1 | **Intrusive ads**: pop-ups covering the station list and navigation buttons, "every minute", video/"multimedia" ads that **interrupt the stream** | radioexpert (3 of 3 BG-locale reviews), radiofmapp, worldradios, radio.bulgaria.play; Radio Garden, TuneIn, myTuner (repeating audio ads on the commute) | Being **ad-free in v1 is our strongest differentiator**. Keeping the future ads rule (banner only, never on the player, never audio) protects it. |
| 2 | **Playback stops by itself** after 1–5 minutes, even in the foreground | radioexpert (2 reviews, "saw other comments with this issue"), radio.bulgaria.play ("stops after 5 min"), Simple Radio | Our Core Value ("never stops on its own") targets the #2 pain point directly. |
| 3 | **Streams stutter or drop**, especially high-bitrate streams on mobile data; users ask for a lower-quality option | radiolight ("320k stutters on data… let the user decrease the bit rate"), radiofmapp ("some stations cut out"), German review asking for a better bitrate | Auto-reconnect and fallback streams are table stakes. Choosing quality from the curated `streams[]` is cheap and valued. |
| 4 | **Missing now-playing / lock-screen presence**: "doesn't show artist and song", "doesn't show on my lock screen, have to search for the app to stop it" | radio.bulgaria.play, BG Radio (missing song titles) | ICY metadata plus a proper MediaSession notification is table stakes. |
| 5 | **Car issues**: steering-wheel next/prev changes the station but the UI does not update; paid "car mode" does not make the app appear in Android Auto | radiolight, radiosonline (two 1-star refund reviews) | Media-button next/prev must work and keep the UI in sync. Android Auto must actually work when it ships. |
| 6 | **Small UX gaps**: cannot reorder favourites; no dark background | worldradios (both) | Cheap wins: drag-to-reorder favourites, system dark theme. |
| 7 | **Paid ad removal not honoured** (second device profile, a "lifetime" purchase later turned into a subscription) | radio.bulgaria.play, myTuner | For the later monetisation milestone, the one-time IAP must be honoured for good. Never convert it to a subscription. |
| 8 | **Official BNR app UX**: "search is ineffective", "no favourites", "not intuitive", "Google ads like apps from 10 years ago" | bg.bnr.app | A better way to listen to БНР (including regionals) is an open niche. |

Positive themes worth copying: "simple, easy, without interruption", "starts fast", "good system integration", "uses little data, great when abroad" (Bulgarians abroad are a real segment).

---

## Feature Landscape

### Table Stakes (Users Expect These)

Users take these for granted and punish their absence with 1-star reviews.

| Feature | Why Expected | Complexity | Notes |
|---|---|---|---|
| Background playback via a media foreground service | Every competitor has it. Its absence is the #2 complaint | MEDIUM | `audio_service`. Test against OEM battery killers (Xiaomi/Samsung/Huawei). Stop the service on pause or stop. |
| Media notification + lock-screen controls (play/pause/stop, station name, logo) | Complaint #4. Users otherwise cannot stop playback without opening the app | MEDIUM | MediaSession metadata must update on station change and on ICY title change. |
| Headset / Bluetooth / car Bluetooth play-pause | Drivers are a primary segment | LOW (given audio_service) | Also handle "becoming noisy" (headphones unplugged) and pause instead of blaring from the speaker. |
| **Next / previous station from media buttons** (headset, steering wheel, notification) | Drivers change stations from the steering wheel. Complaint #5 shows the UI must stay in sync | LOW–MEDIUM | **Not explicit in PROJECT.md.** Recommend: next/prev cycles through the list the station was started from (favourites by default, otherwise the current category list). Mini-player and now-playing must reflect the change. |
| Audio focus: pause for calls, duck or pause for navigation prompts and other apps, resume after a call | Drivers use Google Maps/Waze prompts. Competitors advertise "receive a call while using the app" | LOW–MEDIUM | `audio_session`. Resume automatically after transient loss (call, nav prompt), not after permanent loss. |
| Auto-reconnect on drop / network change, rejoining the live edge | Complaint #3. Wi-Fi to 4G handover when leaving home is the everyday case | MEDIUM–HIGH | Backoff, then fallback streams from the curated `streams[]`. Show "Reconnecting…", never a silent stop. |
| Fast start (≤ 3 s to audio) | Positive reviews praise "starts almost instantly" (BG Radio) | MEDIUM | Pre-resolve `.pls`/`.m3u`. Cache the resolved URL for the last station. |
| Now playing (artist – title) from ICY metadata | Complaint #4. BG Radio users call it out | LOW–MEDIUM | Only when provided. Many BG streams send the station slogan instead of a title, so filter out values that repeat the station name. |
| Favourites (one tap to add) | Universal | LOW | Local only (drift). |
| **Reorder favourites** | Explicit feature request (complaint #6). radiofmapp advertises "sort your favourites" | LOW | **Not explicit in PROJECT.md.** Drag-to-reorder. Order drives next/prev in the car. |
| Recently played | radioexpert keeps the last 50 | LOW | Cap at about 30–50. |
| Resume last station on launch (one tap) | Core Value | LOW | A big "Continue: БНР Хоризонт ▶" card at the top of Home. |
| Search by station name | Universal | MEDIUM (BG-specific, see below) | See "Bulgarian-specific table stakes". |
| Browse by genre and by city | radioexpert, the market leader, is built around city + genre | MEDIUM | Needs the curated data. Radio Browser alone cannot power it (see below). |
| Sleep timer | Every BG competitor has it | LOW | Fade out over the last ~10 s rather than cutting off abruptly. |
| Share station | Most competitors have it | LOW | Plain text plus homepage link, for Viber and Messenger. |
| Station logos with placeholder | Universal. Radio Browser has a favicon for only 53 % of BG stations | LOW–MEDIUM | Generated placeholder: initials on a colour hashed from the station id. |
| Dark theme | Explicit request (worldradios). Competitors advertise it | LOW | Follow the system. |
| Clear error states ("Station unavailable, try again / report") | Silent failure reads as "the app is broken" | LOW | Pair with "Report broken station". |
| Bulgarian UI | Local users, older users | LOW | Bulgarian by default for `bg` locale. The owner reviews all strings. |
| Works on budget / older phones | Primary segment | MEDIUM | Small AAB, smooth lists, no heavy animations or globe views. |

#### Bulgarian-specific table stakes

| Feature | Why Expected | Complexity | Notes |
|---|---|---|---|
| **Script-insensitive search (Cyrillic ↔ Latin)** | Station names are mixed ("BG Radio", "Радио Веселина", "N-JOY"). Only 53 of 344 Radio Browser BG names are in Cyrillic. Users type whichever keyboard is active | MEDIUM | Normalise both the query and the names to a Latin key using the Закон за транслитерацията table (х→h, ц→ts, ч→ch, ш→sh, щ→sht, ъ→a, ю→yu, я→ya, ж→zh, й→y), then case-fold and strip diacritics. |
| **Tolerance for informal Latin ("шльокавица")** | Many Bulgarians, especially older SMS-era users and the diaspora, type 4=ч, 6=ш, q=я, w=в, x=х, j=ж, c=ц, y/u/a=ъ, ia/ja=я, iu/ju=ю | MEDIUM | Normalise the query with an alternate map to several candidate keys, then match on any. Add light fuzzy matching (edit distance ≤ 1–2 on tokens ≥ 4 chars). Unit-test with real queries: "horizont", "hristo botev", "veselina", "6umen", "radio 1 rok", "бг радио", "енерджи". |
| **Aliases / common names** | People search "Хоризонт", "Ботев", "Радио 1", "NRJ", "Енерджи", "Дарик" | LOW | Add an `aliases[]` field to `stations-bg.json` (suggested schema addition). Cheap, and it covers what transliteration cannot, like "енерджи" to "NRJ". |
| **БНР as its own section** (Хоризонт, Христо Ботев, Радио София + regionals: Пловдив, Варна, Бургас, Стара Загора, Шумен, Благоевград, Видин, Кърджали) | The brief's first-class category. The official app is poorly rated and little used | LOW (data) | Group by the `network` field. |
| **City/region browse from curated data** | The market leader's core navigation | MEDIUM | Radio Browser BG data (measured 2026-09-24): only 105 of 344 stations have a `state`, with inconsistent values ("Sofia" / "Sofia City" / "Sofia - town", typos like "Blagoevgad"). **City browse must come from the curated catalogue.** Use a fixed list of 28 oblasts/major cities in Cyrillic with a Latin key. |
| **Normalised Bulgarian genre taxonomy** | Pop-folk is a major genre, and Radio Browser splits it into "chalga", "pop-folk", "pop folk" and "narodna". 105 of 344 BG stations have no tags at all | LOW (data) | Curated fixed set: Поп, Попфолк/Чалга, Народна, Рок, Денс/Електронна, Джаз, Класическа, Ретро/Златни хитове, Новини/Разговорно, Детско, Християнско… Merge Radio Browser tags only where they map cleanly. |
| **Plain `http://` stream support** | 173 of 344 Radio Browser BG `url_resolved` values are cleartext http (measured) | LOW–MEDIUM | Scope cleartext as narrowly as practical. Radio Browser URLs are arbitrary, so a domain allowlist cannot cover the worldwide catalogue. Expect `cleartextTrafficPermitted` for media. |

### Differentiators (Competitive Advantage)

These should align with the Core Value (fast, never stops, Bulgarian-first). Compete on these, not on feature count.

| Feature | Value Proposition | Complexity | Notes |
|---|---|---|---|
| **No ads, no pop-ups, no account, ever-uninterrupted audio** | Attacks complaint #1 in every competitor. The simplest possible pitch for the store listing: "Без реклами. Без регистрация." | LOW (it is a restraint) | Keep it true in v1. The later banner rule already protects the player. |
| **Reliability as a feature**: fallback streams, fast reconnect, survives Wi-Fi↔4G | Attacks complaint #2/#3. Competitors are generic templates and get stream failures in BG reviews | HIGH | Curated `streams[]` with priority, automatic failover, and the last-good URL remembered per station. |
| **Hand-verified Bulgarian catalogue incl. all БНР regionals, grouped properly** | Competitors list the same ~100–400 scraped stations with Latin names and generic genres | MEDIUM (ongoing data work) | Remote update without an app release is the real moat: dead URLs get fixed in hours, not in the next app update. |
| **Bulgarian-native search (transliteration + шльокавица + aliases)** | None of the competitors advertise it. The BNR app is criticised for "ineffective search" | MEDIUM | Visible in the first 10 seconds of use. Worth a screenshot in the listing. |
| **Driver-friendly now-playing screen** | Large play/stop and next/prev targets, high contrast, readable at a glance. Drivers and older users are primary segments | LOW–MEDIUM | Minimum 64 dp primary control, 48 dp secondary. Next/prev follows favourites order. |
| **"Report broken station" in one tap** | Turns failures into catalogue fixes and signals that someone cares. No competitor offers it visibly | LOW | Prefilled email with station id, stream URL tried, error type, app version, Android version and time. No PII. |
| **Quality choice per network** (prefer the lower-bitrate stream on mobile data) | An explicit user request (radiolight). BG Radio advertises high/low quality | LOW–MEDIUM | The data already exists in curated `streams[]` (bitrate). The minimal version is one toggle: "Lower quality on mobile data". The full data-saver with a usage counter stays in v1.1. |
| **Respectful future monetisation** (one-time "support / remove ads", honoured for good) | Complaint #7. Trust is a moat in a market full of ad-heavy apps | — (later milestone) | Not v1. Record the first-launch date now (already planned). |
| **Serves Bulgarians abroad well** | Reviews from DE/CH/UK users are frequent and warm. "Uses little data, great abroad" | LOW | English UI, low-bitrate option, no geo assumptions. The store listing should mention the diaspora. |
| Worldwide catalogue via Radio Browser (secondary) | Lets a BG user also play foreign stations without a second app | MEDIUM | Keep it clearly secondary: "Свят" tab, search, browse by country and top-clicked. Do not try to beat TuneIn or Radio Garden. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---|---|---|---|
| **Interstitial / pop-up / app-open / video / audio ads** | Revenue | Complaint #1 across the whole category. Destroys the differentiator | Already a "never" in PROJECT.md. Keep it that way. |
| **User accounts / cloud sync / login with Google** | One BNR review asks for Google login. Seen as "modern" | Needs a backend, privacy obligations and Data safety complexity. Near-zero value for a favourites list | Local favourites. Later option: export/import favourites as a file or share link. |
| **Podcasts / on-demand content** | Several template competitors bolted on podcasts | Dilutes "live radio, instantly". Big catalogue and UX surface. BINAR/BNR already covers BNR podcasts | Link to the station homepage. Stay live-only. |
| **News reading / articles** (BNR app style) | The official app does it | Drives the "not a good radio app" reviews on the BNR app | Link to the station website from the station screen. |
| **Recording streams** | RadioDroid has it | Rights risk, storage, Play policy exposure | Out of scope (already decided). |
| **Globe / map-based browsing** (Radio Garden) | Visually impressive | Heavy on budget phones. Useless for a Bulgaria-first audience that knows which city it wants | A simple city list. The v1.1 "stations near me" covers locality. |
| **In-app "Top 20 / most listened" rankings** | radiofmapp and radioexpert sort by popularity | Needs analytics or a backend, which conflicts with no-tracking v1. Radio Browser BG click counts are tiny (top station has 41 clicks), so they are meaningless | Editorial ordering in the curated catalogue (national → big commercial → regional). The order is set in JSON. |
| **Radio Browser voting / user-submitted stations inside the app** | Community spirit | Moderation burden. Uneven BG data would pollute the curated layer | "Report / suggest a station" by prefilled email. The owner curates. |
| **Autoplay when car Bluetooth connects** | Drivers like it; some apps offer it | Android 12+ restricts starting foreground services from the background. It needs a persistent receiver and is a battery and review risk. It also surprises users when it fires unexpectedly | Defer. Revisit with Android Auto in v1.1. v1: an opt-in "Start playing on app open" setting (off by default). |
| **Equaliser** | BG Radio has one | Device-specific audio-effect bugs. Little value on car and phone speakers | Later/never (already "later"). |
| **Lyrics, social, comments, chat** | Engagement | Not live radio. Licensing (lyrics). Moderation | Out of scope (already decided). |
| **Programme schedules / EPG for every station** | "What's on now" | No structured source for BG stations. Scraping is brittle | ICY now-playing only. Maybe БНР schedules later if an official feed exists. |
| **Hard-coding Radio Browser data for Bulgaria** | Quick catalogue | 43 duplicate names, odd URLs (e.g. BNR Horizont via a `testb.aac?dist=RADIOPLAY` URL), 50 % missing logos | Curated entries win, and Radio Browser fills only the long tail (already decided). |

---

## Feature Dependencies

```
AudioEngine (just_audio + audio_service + audio_session)
    ├──required by──> Background playback + media notification + lock screen
    │                     └──required by──> Headset/BT/car controls (play/pause)
    │                                            └──required by──> Next/prev station from media buttons
    │                                                                  └──requires──> Favourites ORDER (reorder)
    │                                                                                  + "current list" context
    ├──required by──> Audio focus / becoming-noisy
    ├──required by──> Auto-reconnect ──enhanced by──> Fallback streams (needs curated streams[] with priority)
    ├──required by──> ICY now-playing ──feeds──> Notification metadata, Now-playing screen
    │                                   └──later enables──> Song history + "search this song" (v1.1)
    └──required by──> Sleep timer (engine stop + fade)

Curated catalogue (stations-bg.json + schema: id, name, nameLatin, aliases[], streams[], city, region, genres[], network)
    ├──required by──> Bulgaria Home: БНР section (network), By city (city/region), By genre (normalised genres)
    ├──required by──> Search index (name + nameLatin + aliases + transliteration keys)
    ├──required by──> Fallback streams / quality choice (streams[].bitrate)
    ├──required by──> Report broken station (stable station id)
    └──required by──> Favourites/recents persistence (stable ids; RB stations keyed by stationuuid)

Radio Browser client (server discovery, User-Agent, click registration)
    └──required by──> World browse/search ──merged with──> curated BG (curated wins; dedupe via radioBrowserUuid)

Transliteration + шльокавица normaliser (pure Dart, unit-tested)
    └──required by──> Search (BG and World)

Favourites + Recents (drift)
    ├──required by──> Resume last station on launch
    ├──required by──> Next/prev in the car
    └──required by──> (v1.1) Android Auto browse tree, Widget, Quick Settings tile, Alarm

MediaSession / MediaBrowserService structure (audio_service)
    └──required by──> (v1.1) Android Auto  ── design the browse tree shape in v1 so v1.1 is additive

First-launch date (shared_preferences) ──required by──> (later) ads eligibility rule
Notification permission (Android 13+) ──requested at──> first play
```

### Dependency Notes

- **Next/prev from media buttons requires ordered favourites and a "current list" concept.** Decide in the playback phase what "next" means (recommendation: the list the user started playback from, defaulting to favourites). Otherwise it gets retrofitted later and the UI goes out of sync, as in the radiolight complaint.
- **City/genre browse and the БНР section require the curated catalogue, not Radio Browser.** The measured data shows Radio Browser cannot power them for BG. The catalogue phase must deliver the city/genre taxonomy together with the data.
- **Search quality depends on the schema.** Add `aliases[]` (and optionally `frequency` such as "91.9 FM", which older FM listeners use as an identifier) to the JSON schema *before* the hand-curation pass, or the pass has to be redone.
- **Fallback streams and quality choice depend on `streams[]` having `bitrate` and `priority`.** Already in the brief's schema. Make them required, not optional.
- **Android Auto (v1.1) depends on the v1 audio_service setup exposing a browse hierarchy.** Keep MediaItem ids stable (curated `id` / `stationuuid`) so the car browse tree, widget and alarm can reuse them.
- **The sleep timer conflicts with auto-reconnect** unless the timer's stop is marked as user-initiated. Otherwise the reconnect logic "recovers" from a deliberate stop. The same applies to "becoming noisy" and to a user pressing stop in the notification.
- **Audio-focus resume conflicts with a user pause.** Resume automatically only if playback was paused by *transient* focus loss, never after the user paused.

---

## MVP Definition

### Launch With (v1)

The PROJECT.md Active list is broadly right. Additions and clarifications are marked **NEW**.

- [ ] Background playback, media notification, lock screen, BT/headset/car controls, audio focus, becoming-noisy: table stakes, #2 complaint
- [ ] **NEW: Next/previous station via media buttons and notification**, cycling through the current list (favourites by default), with the UI kept in sync: drivers, steering wheel
- [ ] Auto-reconnect + fallback streams + clear connecting/error states: reliability is the product
- [ ] MP3 / AAC / HE-AAC / HLS / .pls / .m3u + cleartext http: 50 % of BG Radio Browser URLs are http
- [ ] ICY now-playing, with slogan/duplicate filtering: complaint #4
- [ ] Curated BG catalogue with remote update + bundled snapshot, **NEW: `aliases[]` field and a fixed normalised genre and city taxonomy**
- [ ] Bulgaria Home: Continue card → Favourites → БНР (national + regionals) → By city → By genre
- [ ] World tab via Radio Browser (search, by country)
- [ ] Search: case/diacritic/script-insensitive, official transliteration **+ шльокавица variants + aliases** + light fuzzy
- [ ] Favourites **with drag-to-reorder (NEW)**, recents, one-tap resume
- [ ] Sleep timer (15/30/45/60/90, end of hour) with fade-out
- [ ] Share station; report broken station (prefilled email with diagnostics)
- [ ] BG/EN UI, system dark theme, mini-player + large-control now-playing screen, TalkBack, large text
- [ ] **NEW (optional, low cost): "Lower quality on mobile data" toggle** using curated `streams[]` bitrates. Can slip to v1.1 if the catalogue phase runs long

### Add After Validation (v1.x / v1.1)

- [ ] **Android Auto**: the first v1.1 item. Every popular BG competitor advertises it, and drivers are a primary segment. Trigger: v1 released and stable.
- [ ] Home-screen widget + Quick Settings tile: competitors have a widget. Trigger: after Auto, reusing the same MediaItem ids.
- [ ] Alarm (wake to a station): offered by every BG competitor. Needs exact-alarm permission handling and a fallback tone if the stream fails.
- [ ] Chromecast: competitors have it. One user reports a 30 s Nest delay in BG Radio, so test Nest specifically.
- [ ] Full data-saver (bitrate + data counter); song history + "search this song".
- [ ] Stations near me (manual city choice first, coarse location second).
- [ ] Autoplay on car-Bluetooth connect: only if Android restrictions allow it cleanly. Evaluate alongside Android Auto.
- [ ] Favourites export/import (file/share link): the account-free answer to "I got a new phone".

### Future Consideration (v2+)

- [ ] Banner-only ads for users ≥ 30 days + a one-time "support/remove ads" IAP that stays permanent: trust first, and complaint #7 shows the cost of getting this wrong.
- [ ] iOS + CarPlay; Wear OS.
- [ ] Featured-station partnerships (needs a user base).
- [ ] БНР programme schedule, if an official structured feed exists.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|
| Background playback + notification + lock screen | HIGH | MEDIUM | P1 |
| Auto-reconnect + fallback streams | HIGH | HIGH | P1 |
| Audio focus / becoming noisy / BT controls | HIGH | LOW | P1 |
| Next/prev station via media buttons | HIGH (drivers) | LOW–MEDIUM | P1 |
| Curated BG catalogue + remote update | HIGH | MEDIUM | P1 |
| BG search (translit + шльокавица + aliases) | HIGH | MEDIUM | P1 |
| БНР / city / genre browse | HIGH | MEDIUM (data) | P1 |
| Favourites (+ reorder), recents, resume | HIGH | LOW | P1 |
| ICY now-playing | MEDIUM | LOW–MEDIUM | P1 |
| Sleep timer | MEDIUM | LOW | P1 |
| Report broken station | MEDIUM (and HIGH for catalogue quality) | LOW | P1 |
| World catalogue (Radio Browser) | MEDIUM | MEDIUM | P1 |
| Share station | LOW–MEDIUM | LOW | P1 |
| Lower quality on mobile data toggle | MEDIUM | LOW | P1/P2 |
| Android Auto | HIGH (drivers) | MEDIUM–HIGH | P2 (first in v1.1) |
| Widget / QS tile | MEDIUM | MEDIUM | P2 |
| Alarm | MEDIUM | MEDIUM | P2 |
| Chromecast | LOW–MEDIUM | MEDIUM | P2 |
| Song history / search this song | LOW–MEDIUM | LOW–MEDIUM | P2 |
| Equaliser, recording, podcasts, globe UI | LOW | MEDIUM–HIGH | P3 / never |

**Priority key:** P1 = must have for launch; P2 = should have, add when possible; P3 = nice to have, future consideration.

---

## Competitor Feature Analysis

| Feature | Радио Онлайн България (radioexpert, leader) | Radio Bulgaria FM online (radiolight) | BG Radio (crystalmissions) | БНР official app | Our approach |
|---|---|---|---|---|---|
| Ads | Yes. Pop-ups covering content, ads interrupting the stream (BG reviews) | Yes | Yes (users say not annoying) | Google ads | **None in v1. Banner-only later, never on the player** |
| Background / reliability | Reports of stopping every 1–5 min | "Keep app running in background" advice | Praised as stable and fast | n/a | Core Value. Measured targets (≤ 3 s, 60 min screen-off, ≤ 10 s recovery) |
| Browse | City + genre, sorted by popularity | Suggestions, search | List + favourites | БНР programmes only | БНР section + curated city + normalised genres + World tab |
| Search | Name | Name | Name | "Ineffective" (review) | Cyrillic/Latin/шльокавица/aliases/fuzzy |
| Favourites | Yes | Yes | Yes, sortable | **No** | Yes + drag reorder, drives car next/prev |
| Recents | Last 50 | Widget shows recent | n/a | n/a | Yes (~30–50) |
| Now playing (ICY) | n/a | n/a | Yes | n/a | Yes, with slogan filtering |
| Sleep timer / alarm | n/a / n/a | Yes / Yes | Yes / Yes | n/a | Sleep timer v1; alarm v1.1 |
| Android Auto / Cast / Widget | n/a | Yes / Yes / Yes | Yes / Yes / n/a | n/a | v1.1 (Auto first) |
| Quality choice | n/a | Requested by users, missing | High / low | n/a | "Lower quality on mobile data" (v1 if cheap) |
| Podcasts / news | No | No | No | Yes (news-first) | No, by design |
| Broken-station reporting | n/a | n/a | "We check streams regularly" | "No contacts found" (review) | One-tap prefilled report |

("n/a" = not advertised in the listing and not visible in reviews. It may still exist.)

International reference points: **Radio Garden** (globe discovery, users complain about ads and the missing "previous station" button), **TuneIn** (100M+, repeating audio ads on the commute are the top complaint), **myTuner** (a "lifetime" ad-free purchase later revoked or turned into a subscription), **Simple Radio** ("stops after a couple of minutes", "no control over Bluetooth" after going premium), **Transistor** (MIT, minimalist: Radio Browser search plus import of raw stream URLs and M3U/PLS; no discovery), **RadioDroid** (Radio Browser front-end with sleep timer, alarm and recording). The lesson across all of them: **the more ad-driven the app, the more reviews are about interruptions rather than features.**

---

## Gap Flags for the Roadmap

1. **Android Auto deferred while every popular BG competitor advertises it.** Drivers are a named primary segment. Car Bluetooth play/pause/next covers many cars, but Android Auto head units will not show the app. Recommendation: keep it v1.1, make it the **first** v1.1 item, and shape the v1 audio_service/MediaItem structure so Auto is additive.
2. **Next/prev station semantics are not in PROJECT.md.** Add them to the playback phase. They are cheap and highly visible to drivers.
3. **Catalogue schema should add `aliases[]` (and optionally `frequency`)** before hand-curation starts.
4. **The genre and city taxonomy is a design artefact of its own.** Decide the fixed lists (Bulgarian with Latin keys) in the catalogue phase. Radio Browser tags and states are too inconsistent to derive them from.
5. **Store listing positioning:** lead with "Без реклами · Без регистрация · Всички БНР програми · Търсене на кирилица и латиница". Every competitor's weakness is visible in its reviews.

---

## Sources

- Google Play listings (scraped 2026-09-24, BG/EN/DE/GB locales). Installs, ratings, update dates, descriptions and "most relevant" reviews:
  - [Радио Онлайн България: Live FM](https://play.google.com/store/apps/details?id=net.radioexpert.radio.bulgaria)
  - [Radio Bulgaria FM online](https://play.google.com/store/apps/details?id=com.radiolight.bulgarie)
  - [Radio Bulgaria – radio online](https://play.google.com/store/apps/details?id=radio.bulgaria.play.online.free)
  - [BG Radio – Bulgarian Radios](https://play.google.com/store/apps/details?id=com.crystalmissions.bgradio)
  - [Radio Bulgaria – Online radio](https://play.google.com/store/apps/details?id=com.radiofmapp.bulgaria)
  - [Radio Bulgaria – Radio FM](https://play.google.com/store/apps/details?id=com.worldradios.bulgarie)
  - [Radio Bulgaria – FM & Online](https://play.google.com/store/apps/details?id=com.radiosonline.radiofmbulgaria)
  - [BNR Bulgarian National Radio (official)](https://play.google.com/store/apps/details?id=bg.bnr.app)
  - [Radio Garden](https://play.google.com/store/apps/details?id=com.jonathanpuckey.radiogarden), [TuneIn](https://play.google.com/store/apps/details?id=tunein.player), [Simple Radio](https://play.google.com/store/apps/details?id=com.streema.simpleradio), [myTuner](https://play.google.com/store/apps/details?id=com.appgeneration.itunerfree)
- BNR app history: [БНР има вече и мобилно приложение за Android](https://bnr.bg/post/100358313/bnr-ima-veche-i-mobilno-prilojenie-za-android), [BINAR platform](https://binar.bg/)
- Open-source references: [Transistor (F-Droid)](https://f-droid.org/packages/org.y20k.transistor/), [Transistor (GitHub)](https://github.com/y20k/transistor), [RadioDroid (F-Droid)](https://f-droid.org/packages/net.programmierecke.radiodroid2/), [RadioDroid (GitHub)](https://github.com/segler-alex/RadioDroid)
- Radio Browser live query: `GET https://de1.api.radio-browser.info/json/stations/bycountrycodeexact/BG` (2026-09-24). 344 stations, 309 last-check OK, 184 with favicon, 105 with state, 105 untagged, 173 cleartext http, 43 duplicate names, 53 Cyrillic names.
- Transliteration: [Закон за транслитерацията (Уикиизточник)](https://bg.wikisource.org/wiki/%D0%97%D0%B0%D0%BA%D0%BE%D0%BD_%D0%B7%D0%B0_%D1%82%D1%80%D0%B0%D0%BD%D1%81%D0%BB%D0%B8%D1%82%D0%B5%D1%80%D0%B0%D1%86%D0%B8%D1%8F%D1%82%D0%B0), [Транслитерация на българските букви с латински (Уикипедия)](https://bg.wikipedia.org/wiki/%D0%A2%D1%80%D0%B0%D0%BD%D1%81%D0%BB%D0%B8%D1%82%D0%B5%D1%80%D0%B0%D1%86%D0%B8%D1%8F_%D0%BD%D0%B0_%D0%B1%D1%8A%D0%BB%D0%B3%D0%B0%D1%80%D1%81%D0%BA%D0%B8%D1%82%D0%B5_%D0%B1%D1%83%D0%BA%D0%B2%D0%B8_%D1%81_%D0%BB%D0%B0%D1%82%D0%B8%D0%BD%D1%81%D0%BA%D0%B8), [Шльокавица (Уикипедия)](https://bg.wikipedia.org/wiki/%D0%A8%D0%BB%D1%8C%D0%BE%D0%BA%D0%B0%D0%B2%D0%B8%D1%86%D0%B0)

**Confidence notes:** Competitor feature lists come from the developers' own descriptions (MEDIUM: marketing claims, not tested). Complaint themes are MEDIUM (primary review text from several locales and apps, small samples). Radio Browser data-quality figures are HIGH for 2026-09-24, as a direct API measurement from one mirror. The claim that "template app factories dominate" is an inference from package naming and near-identical descriptions (MEDIUM–LOW). The Android 12+ background foreground-service restriction on Bluetooth autoplay is from training knowledge and was not re-verified in this session (MEDIUM).

---
*Feature research for: Bulgarian-first Android internet radio*
*Researched: 2026-09-24*
