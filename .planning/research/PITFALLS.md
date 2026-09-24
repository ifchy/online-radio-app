# Pitfalls Research

**Domain:** Flutter (Android-first) live internet radio app, Bulgarian-first catalogue, published on Google Play
**Researched:** 2026-09-24
**Confidence:** MEDIUM overall. Platform and Play rules were cross-checked against official Android and Play docs (MEDIUM, from the classify-confidence seam). Plugin behaviour comes from GitHub issues (LOW to MEDIUM). Radio Browser data-quality numbers were **measured live** against the API on 2026-09-24.

Tags used below: **[MEDIUM]** means cross-verified across sources. **[LOW]** means a single source or reasoning; validate it on a device before relying on it. **[MEASURED]** means observed directly with curl or the API during this research.

Phase numbering follows the brief: **P1** Walking skeleton & playback engine, **P2** Station catalogue, **P3** Listening experience, **P4** Hardening & polish, **P5** Store release.

---

## Critical Pitfalls

### Pitfall 1: Foreground-service lifecycle tied to "paused", which breaks resume, reconnect and audio focus in the background

**What goes wrong:**
Playback pauses, for example because of a phone call (transient audio focus loss), a network drop, or the user tapping pause. The app then drops the media foreground service (FGS) (`audio_service` defaults to `androidStopForegroundOnPause: true`). Later the app tries to resume from the background: the call ends, the reconnect timer fires, or focus is regained. Three things then go wrong:
- Android 12+ throws `ForegroundServiceStartNotAllowedException`, because starting an FGS from the background is not allowed (audio_service issue #996 describes exactly this with `AudioSession.interruptionEventStream`).
- Android 15+, for apps targeting 35+, returns `AUDIOFOCUS_REQUEST_FAILED` unless the app is the top app or running an FGS.
- On **Android 17 devices (all apps, whatever their targetSdk)**, background playback, focus requests and volume calls **fail silently** without a visible activity or a non-short FGS.

The result is that radio stops after a call or a tunnel and never comes back. That violates the core value directly.

**Why it happens:**
Developers model radio like a music player where "paused" means "idle". The defaults in audio_service and the sample code optimise for music apps. Emulators rarely reproduce the exceptions.

**How to avoid:**
- Define an explicit engine state machine: `stopped`, `connecting`, `playing`, `reconnecting`, `interrupted(transient)`, `pausedByUser`, `error`. The FGS stays up in `connecting`, `playing`, `reconnecting` and `interrupted`. It is released only in `stopped`, `error` (after retries are exhausted), and `pausedByUser` after a grace period.
- Follow Android 17's official guidance, which also works on older versions: start the `mediaPlayback` FGS from the foreground on user-initiated play, **keep it through transient failures (< ~10 min)**, stop it at the end, and restart only on an explicit user action. The notification, media buttons and Bluetooth all count as user interaction, so they are exempt.
- Cap the reconnect loop at about 10 minutes of trying. Then go to `error`, stop the FGS, and show "Tap to retry" in the notification before it is removed.
- Handle interruptions in one place only. Set `handleInterruptions: false` on just_audio if you handle `audio_session` events yourself, so two handlers don't race each other.

**Warning signs:** `ForegroundServiceStartNotAllowedException` or `mAllowStartForeground false` in logcat. Audio doesn't resume after a phone call with the screen off. `requestAudioFocus` returns FAILED. Playback resumes only after opening the app.

**Phase to address:** P1 (state machine plus FGS policy are the core of `AudioEngine`). Re-verify in P4 on Android 15/16/17 physical devices.

**Confidence:** [MEDIUM]. Official Android 12, 15 and 17 behaviour docs plus audio_service #996.

---

### Pitfall 2: Treating a live stream like a file (pause, "completed", HLS live window)

**What goes wrong:**
- **Pause then resume on an Icecast stream** plays stale audio (minutes behind), or fails. While paused, ExoPlayer keeps the socket open until its buffer fills, and then the server drops the slow client (Icecast disconnects listeners whose queue overflows). On resume the player errors out or plays the old buffer.
- **Server closes the connection** (source restart, server maintenance). For a progressive stream, ExoPlayer sees end-of-stream and just_audio reports `ProcessingState.completed`. Apps treat that as "track finished" and stop. audio_service may even stop the service.
- **HLS live** (e.g. cdn.bg for БНР regional stations): after a pause or network loss longer than the live window, you get `BehindLiveWindowException`. It must be handled by re-preparing at the default (live) position.

**Why it happens:** Every Flutter audio tutorial is about finite files. The just_audio API exposes seek, position and duration, which invite file semantics.

**How to avoid:**
- In `AudioEngine`, map "pause" on a live source to **stop the network plus remember the station**. Resume means re-set the source and play at the live edge. Optionally allow a short grace period (≤ 30 s) where you resume from the buffer.
- Treat `completed` on a live source as a *disconnect*: enter `reconnecting` immediately.
- On any `PlayerException` or behind-live-window error for HLS: `setAudioSource` again, which starts at the live edge by default. Never `seek(position)`.
- Hide seek bars, position and duration in the UI for live sources.

**Warning signs:** After a 5-minute pause, the news bulletin plays "late". The notification shows a finished state after a server hiccup. HLS stations fail after lunch-break pauses.

**Phase to address:** P1.

**Confidence:** [MEDIUM]. ExoPlayer #8675 and #1074 on BehindLiveWindow; Icecast slow-client behaviour; just_audio state model.

---

### Pitfall 3: Auto-reconnect that doesn't actually trigger (silent stalls, network switch)

**What goes wrong:**
- On a Wi-Fi to 4G switch, the old TCP socket often **doesn't error**. It just stops delivering bytes. ExoPlayer waits for its HTTP read timeout (8 s default), then retries its load a few times, then errors to idle. Total recovery time can go well past the 10 s target, or the player can sit in `buffering` forever.
- just_audio issue #117: with internet off, the state went `buffering` then `ready` with no audio. Errors are not always delivered on the playback-event stream (#518).
- Reconnect loops without backoff hammer a dead server. They drain battery and data, and can make a station operator block your User-Agent.

**Why it happens:** Developers rely on the player's own error events and on `connectivity_plus` events. Neither is a reliable signal. Connectivity events are also noisy: Wi-Fi and mobile both up, captive portals, VPN.

**How to avoid:**
- Add a **stall watchdog** in `AudioEngine`. If the state is `playing`/`buffering` and there has been no position or buffered-position progress for about 6–8 s, force a reconnect by re-setting the source.
- Also trigger on **default-network change** (debounced about 1 s). One short audible gap is better than a 20 s silence.
- Use exponential backoff with jitter: 0.5 s, 1 s, 2 s, 4 s … capped at 30 s, total cap about 10 min (see Pitfall 1). On each attempt, rotate through the station's fallback `streams[]`.
- Unit-test the reconnect policy as a pure Dart class with a fake clock. That is already in the brief's test plan. Keep the platform player out of it.

**Warning signs:** Recovery time in the Wi-Fi to 4G test is inconsistent (sometimes 5 s, sometimes never). The UI shows a buffering spinner indefinitely. The playback logs show no error events.

**Phase to address:** P1 (the brief's "done when" includes the Wi-Fi to 4G switch). P4 adds fallback-stream rotation.

**Confidence:** [MEDIUM]. just_audio #117, #518 and #1277; ExoPlayer default timeouts.

---

### Pitfall 4: Screen-off Wi-Fi starvation and OEM battery killers

**What goes wrong:**
- **Screen off on Wi-Fi:** without a Wi-Fi lock, Wi-Fi drops into power-save mode, the buffer starves, and playback stutters or stops. Media3 solves this with `setWakeMode(C.WAKE_MODE_NETWORK)`. It is **not confirmed that just_audio sets a network wake mode** on its internal ExoPlayer, and no just_audio option for it was found.
- **OEM killers:** Huawei, Xiaomi, OnePlus and Samsung (in that order on dontkillmyapp.com) kill or freeze even FGS apps. Samsung's "Sleeping apps / Deep sleeping apps" auto-sleeps apps unused for 3 days. MIUI/HyperOS "Battery saver" and "Autostart" settings do the same. Samsung says One UI 6+ honours properly-typed FGS for apps targeting Android 14+. That is a reason to get Pitfall 1 right.
- **Play policy trap:** the "fix" people reach for is `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` plus `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Google Play allows the direct request only for listed use cases. A radio app with a working media FGS is **not** one of them, and it risks rejection.

**How to avoid:**
- In P1, check whether just_audio holds a Wi-Fi lock (read its Android source, or run `adb shell dumpsys wifi | grep -i lock` while playing). If it doesn't, add a small platform-channel `WifiLock` (`WIFI_MODE_FULL_HIGH_PERF` or `FULL_LOW_LATENCY`). Acquire it while playing and release it on stop/pause. This also serves the brief's "no wake-locks when not playing".
- The battery-optimisation hint (P4) should **deep-link to the settings list** (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`) plus OEM-specific instructions (link to dontkillmyapp.com/xiaomi, /samsung, /huawei). It should **not** declare `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. Show it only after a detected unexpected kill (see below), never at first launch.
- Detect kills by persisting `wasPlaying=true` plus a timestamp heartbeat while playing. On the next launch, if `wasPlaying` is set and there was no clean stop, that was an OS kill. Only then offer the hint.
- Test matrix: at least one Xiaomi/Redmi (HyperOS), one Samsung A-series (One UI), and one Huawei if available. These are the dominant budget brands in Bulgaria. The emulator proves nothing here.

**Warning signs:** Playback dies after 5–30 min with the screen off on one brand only. It works while charging. Stutter happens only on Wi-Fi.

**Phase to address:** P1 (Wi-Fi lock plus the 60-minute screen-off test on a physical device). P4 (kill detection plus hint, OEM matrix).

**Confidence:** [MEDIUM] for OEM behaviour and Play policy. [LOW] for "just_audio has no Wi-Fi lock"; this must be verified.

---

### Pitfall 5: Cleartext config that is either too broad or too narrow

**What goes wrong:**
- **Too narrow:** the team allowlists specific domains in `network_security_config.xml`. The catalogue is later updated remotely with a new `http://` station on another host, and it fails silently until the next app release. That defeats "updatable without an app release". Measured in Radio Browser BG data: **173 of 344 stations resolve to `http://`, and 83 use raw IP-address hosts**, so a domain allowlist cannot cover the worldwide catalogue. [MEASURED]
- **Forgotten localhost:** just_audio's local proxy (used when you pass `headers:`, e.g. a User-Agent, or use caching/`StreamAudioSource`) is cleartext on `127.0.0.1`. It fails on Android 9+ if 127.0.0.1 isn't permitted (just_audio #254 and #984).
- **Logos:** Flutter's `dart:io` enforces the platform cleartext policy ("Insecure HTTP is not allowed by platform"). 25 of 184 BG favicons are `http://` [MEASURED], so those logos silently fall back to placeholders.

**How to avoid:**
- Be honest about the constraint. Set `base-config cleartextTrafficPermitted="true"` for media, and document why in the manifest comment and privacy policy.
- Enforce HTTPS **in app code** for everything the app itself controls: catalogue fetch, the Radio Browser API, the report form. Use a single HTTP client wrapper that rejects `http://` for non-media calls.
- Optionally upgrade `http://` logos to `https://` when the host supports it, cached per host.
- Add a unit or integration test that plays an `http://` stream from a host that is *not* in any list.

**Warning signs:** "Cleartext HTTP traffic to X not permitted" in logcat. Stations work in debug builds but not release builds (debug overlays differ). Logos are missing for a subset of stations.

**Phase to address:** P1 (manifest plus test with an http station). P2 (logo handling).

**Confidence:** [MEDIUM].

---

### Pitfall 6: Bulgarian "now playing" shows mojibake, stale titles or junk

**What goes wrong:**
- Media3's `IcyDecoder` decodes `StreamTitle` as UTF-8 and **falls back to ISO-8859-1**. Many Bulgarian Icecast/Shoutcast stations send **windows-1251**, so "Артист - Песен" shows as `Àðòèñò - Ïåñåí` in the app, the notification, the lock screen and the car display.
- just_audio issue #871: `icyMetadata` can **carry over from the previous station** after switching.
- HLS streams carry no ICY. Their now-playing arrives, if at all, as ID3 timed metadata, and just_audio doesn't surface it well (#732).
- Stations put junk in `StreamTitle`: the station name, the website, "Реклама", empty strings, `-`, or `Artist - ` with an empty title.
- Pushing every title change into `MediaItem` makes the notification and car display flicker and re-fetch artwork each time.

**How to avoid:**
- Add a charset repair step: if every code unit of the title is ≤ U+00FF and at least one is ≥ U+0080, re-encode it as Latin-1 bytes and decode as **windows-1251**. Dart has no built-in cp1251 codec; a 128-entry lookup table is enough. Add an optional per-station `icyCharset` field in `stations-bg.json` for cases the heuristic gets wrong.
- Clear the now-playing state on every source change, and ignore metadata events until the new source is ready.
- Normalise titles: trim, collapse separators, and drop values equal to the station name, a URL, or a blocklist entry. Update `MediaItem` only when the normalised text changes. Keep the artwork URI stable per station.

**Warning signs:** Latin-accented gibberish in the notification on Bulgarian stations. The previous station's song shows under the new station's logo.

**Phase to address:** P1 (charset repair plus clearing on switch, because the brief puts ICY in P1). P3 (display polish).

**Confidence:** [MEDIUM]. ExoPlayer #6753 and #10254; radio-garden/react-native-audio-browser #145; just_audio #871 and #732.

---

### Pitfall 7: Playlist and stream-URL resolution done naively (`.pls`, `.m3u`, ICY, redirects, Shoutcast)

**What goes wrong:**
- **`dart:io` `HttpClient` cannot parse Shoutcast v1's `ICY 200 OK` status line** and throws `HttpException`. OkHttp and ExoPlayer on Android tolerate it. If you probe or resolve streams in Dart, for example with a HEAD or GET to sniff the content type, many Shoutcast stations look "broken" even though they play fine.
- A GET on a live stream **never ends**. Probing code that reads the body hangs until timeout and wastes mobile data.
- `.pls` quirks: key case (`File1` vs `file1`), CRLF line endings, a BOM, missing `NumberOfEntries`, and several `FileN` entries (these are fallbacks, so keep them all). `.m3u` quirks: the file may be a plain URL list, an extended M3U (`#EXTM3U`/`#EXTINF`), or **actually HLS** served with a `.m3u` extension (it contains `#EXT-X-`). Relative URLs need resolving against the playlist URL.
- Redirects: ExoPlayer's `DefaultHttpDataSource` refuses **cross-protocol redirects** (http to https or back) by default. Whether just_audio enables them is unverified. CDN redirects are common: the cdn.bg Хоризонт HLS URL returned **302 to another host** [MEASURED]. Aggregators also redirect (streamtheworld `livestream-redirect`).
- Shoutcast v1 serves an HTML page instead of audio to User-Agents containing "Mozilla" unless the URL ends in `/;`. Don't send a browser-like User-Agent, and keep `/;` URLs as they are.

**How to avoid:**
- Resolve `.pls`/`.m3u` in Dart with a **tolerant parser** that has unit tests using real fixtures (CRLF, BOM, lowercase keys, relative URLs, HLS disguised as m3u). Fetch playlists with a size cap (64 KB) and a short timeout.
- Never probe audio streams from Dart. Let the player be the probe, and judge success by "received audio within N seconds".
- Prefer resolving playlists **at catalogue-build time** (in a CI script for `stations-bg.json`) so the app's `streams[]` holds direct URLs. Runtime resolution is then only the fallback for Radio Browser `url` values.
- Verify in P1 that an http to https redirecting stream plays. If not, configure cross-protocol redirects on the Android side (fork, plugin option, or engine swap: another reason for the `AudioEngine` seam).

**Warning signs:** Streams that play in VLC fail in the app. A `.pls` station works on one phone and not another (usually CRLF or BOM). The resolver times out.

**Phase to address:** P1 (the `.pls` fixture station is in the brief's walking skeleton). P2 (CI-side resolution for the catalogue).

**Confidence:** [MEDIUM] for the ICY/`dart:io` problem and Shoutcast `/;`. [LOW] for just_audio's redirect default, which must be verified.

---

### Pitfall 8: Radio Browser misuse and trusting its Bulgarian data

**What goes wrong (guidelines):** Hard-coding one mirror such as `de1.api.radio-browser.info` (mirrors come and go). No `User-Agent`. Using `country` (deprecated) instead of `countrycode`. Using `url` instead of `url_resolved`. Not calling the click endpoint, or calling it on every reconnect.

**What goes wrong (data), measured on 2026-09-24 for `countrycode=BG`:** [MEASURED]
- 344 stations. **35 have `lastcheckok=0`**. `hidebroken` defaults to **false**, so broken stations are returned unless you ask otherwise.
- **57 duplicate names** (e.g. "BNR Horizont" three times).
- **The "BNR Horizont" entries point to `play.global.audio/testb.aac?dist=RADIOPLAY`**, a third-party aggregator URL with a distribution tag. The official `stream.bnr.bg` entry is marked broken.
- Distribution/session tags such as `dist=onlineradiobox` (StreamTheWorld) and zeno.fm `zs=` tokens are baked into URLs.
- 160 stations have no favicon. 239 have no `state` (region). 191 have no language code. 291 have Latin-only names. 26 mix Cyrillic and Latin in one name. Some Turkish-hosted stations are tagged BG. 3 have an empty `url_resolved`. 9 have `ssl_error`.

**How to avoid:**
- Server discovery: resolve `all.api.radio-browser.info` (or fetch `/json/servers` from any known mirror), shuffle, fail over on error, and cache the list for a day. **Never block playback on discovery.**
- Send a User-Agent like `<AppName>/<version> (Android; +https://<pages-url>)`, the same one for API and stream requests.
- Always pass `hidebroken=true`. Key favourites and recents by `stationuuid`, namespaced (`rb:<uuid>` vs `bg:<curated-id>`).
- Call `/json/url/{uuid}` **once per user-initiated play**, never on reconnect or auto-resume, and fire-and-forget.
- Merge rules: curated entries win. De-duplicate RB entries that match a curated station (by `radioBrowserUuid`, then normalised name plus host). **Hide RB BG entries whose stream host is a known aggregator with a foreign `dist=` tag** (rights, see Pitfall 9).
- Cache search results briefly. Debounce search input (≥ 300 ms) so typing doesn't fire one request per keystroke.

**Warning signs:** Search for "Хоризонт" returns 5 variants, 2 of which are broken. The API stops responding and there is no fallback. The maintainers email about your traffic.

**Phase to address:** P2.

**Confidence:** [MEDIUM] for guidelines (official docs). [MEASURED] for data quality.

---

### Pitfall 9: Content rights — playing streams you are not entitled to redistribute

**What goes wrong:**
- Using aggregator URLs such as `?dist=RADIOPLAY` or `?dist=onlineradiobox`, which attribute your listeners to another app's distribution deal. Using tokenised URLs scraped from station web players. **Proxying, relaying or caching streams** through your own infrastructure (that becomes retransmission, not linking).
- Using station logos in the **store icon, screenshots or title**. Google Play's impersonation and IP policy says that "unofficial" disclaimers don't cure trademark use, and violations can lead to app suspension and account termination.
- Ignoring a takedown until the next release, when the station is in the bundled snapshot.

**How to avoid:**
- Catalogue rule enforced in CI: every `streams[].url` must come from the station's own site or player, or from its official streaming provider **without** third-party distribution tags. Record `source` (where the URL was found) and `verifiedAt` per stream.
- Add a `disabled: true` / `removed` mechanism in the remote catalogue that **also suppresses the bundled snapshot entry and matching RB entries**, so a takedown takes effect on next launch without a release. Include an RB-uuid blocklist in the same file.
- Store listing: generic app icon and name. No station logos or names like "БНР" in the title or short description. Screenshots use either stations that have given permission or generic or blurred logos.
- The app never touches audio bytes except through the player. No recording (already out of scope), no relays.
- Keep a takedown log and a public contact address in the privacy policy and the About screen.

**Warning signs:** URLs containing `dist=`, `token=`, `zs=`, `?sid=` from another app. A Play rejection citing "Impersonation" or "IP infringement".

**Phase to address:** P2 (catalogue rules plus kill-switch). P5 (listing assets). Contact the main stations during P2–P4 so permissions exist by P5.

**Confidence:** [MEDIUM] for Play policy. [LOW] for the legal characterisation of linking vs retransmission under EU law; this is not legal advice.

---

### Pitfall 10: Bulgarian search that only implements the 2009 law and misses how people actually type

**What goes wrong:**
- The **Закон за транслитерацията (ДВ бр. 19/2009)** maps: а-a, б-b, в-v, г-g, д-d, е-e, ж-**zh**, з-z, и-i, й-**y**, к-k, л-l, м-m, н-n, о-o, п-p, р-r, с-s, т-t, у-u, ф-f, х-**h**, ц-**ts**, ч-ch, ш-sh, щ-**sht**, ъ-**a**, ь-y, ю-**yu**, я-**ya**. There is one special rule: **"ия" at the end of a word becomes "ia"** (София = Sofia, България = Bulgaria). A search that only applies this table fails on how people really type:
  - ъ as `u`, `y`, `a` or `^`
  - щ as `sht`, `sh`, `6t` or `6`
  - ч as `ch` or `4`; ш as `sh` or `6`; ж as `zh` or `j`; ц as `ts` or `c`
  - я as `ya`, `ia`, `ja` or `q`; ю as `yu`, `iu` or `ju`
  - х as `h` or `kh`; й as `y`, `i` or `j`; в as `w` ("shlyokavitsa")
- Station names are also inconsistent in the data: "BNR Horizont", "БНР Хоризонт", "Хоризонт", "Horizont". Brands are Latin inside Cyrillic ("BG Радио", "bTV Radio"). **Cyrillic look-alike letters inside Latin words and vice versa** occur too: a Cyrillic "В" in "BG" never matches a typed Latin "B".
- **NFD-then-strip-diacritics destroys `й`**: it decomposes to `и` + combining breve and becomes `и`. The same happens to `ѝ`. Dart has no built-in Unicode normalisation.
- Transliterating the *query* only (not the index), or the index only, leaves half the matrix uncovered.

**How to avoid:**
- Normalise **both** the index and the query into one canonical *folded Latin skeleton*:
  - lowercase
  - map Cyrillic to Latin using the law's table
  - map homoglyphs (Cyrillic а/в/е/к/м/н/о/р/с/т/у/х and Latin look-alikes) to one form
  - fold common digraph variants (`sht` = `sh` + `t` path, `ts` = `c`, `zh` = `j`, `kh` = `h`, `ya` = `ia` = `ja` = `q`, `yu` = `iu` = `ju`, `4` = `ch`, `6` = `sh`, `w` = `v`)
  - collapse `ъ`-variants (`a`/`u`/`y`) to one wildcard class
  - strip punctuation and spaces
- Use an explicit character map, not NFD stripping (keeps `й` correct).
- Match on the skeleton with prefix and token match first, then a small edit distance (≤ 1 for short tokens, ≤ 2 for tokens of 6+ characters) as fallback. Rank curated before RB and exact-script before transliterated.
- Build a **golden test table** reviewed by the owner: `horizont`, `hristo botev`, `botev`, `bg radio`, `бг радио`, `radio 1`, `радио едно`, `darik`, `дарик`, `veselina`, `fm+`, `n-joy`, `енерджи`/`energy`, `шлагер`/`shlager`/`6lager`, `стара загора`/`stara zagora`, `софия`/`sofia`/`sofiya`, `ямбол`/`yambol`/`qmbol`.
- Also store `nameLatin` and `aliases[]` per curated station (e.g. "Радио 1" also as "Radio One" and "Радио Едно"). No algorithm finds "Energy" from "Енерджи" reliably without an alias.

**Warning signs:** "sofia" finds София but "sofiya" doesn't. "йо" cases fail. Users type Latin and get zero results.

**Phase to address:** P2 (search plus golden tests). Aliases are curated alongside the catalogue.

**Confidence:** [MEDIUM] for the law's table (bg.wikisource, slovored, ДВ). [LOW] for the informal typing variants; they come from common knowledge and need the owner to validate them as a native speaker.

---

### Pitfall 11: Play Console: wrong targetSdk, missing FGS declaration video, inaccurate Data safety

**What goes wrong:**
- **Since 31 Aug 2026, new apps and all updates must target API 36 (Android 16).** Extensions are possible only until 1 Nov 2026. Scaffolding with an older Flutter default or pinning 35 means the first upload is rejected. Targeting 36 also means **edge-to-edge is enforced with no opt-out** and **predictive back is on by default**. Both are visible UI changes to design for from P3, not discover in P5.
- The **`mediaPlayback` FGS declaration** (Policy > App content) requires a description, the user impact, **and a link to a video** showing the feature (start playback, go home, lock screen, controls). Teams leave the video to release day.
- **Data safety:** "collected" means *transmitted off the device*, including to third parties the app contacts directly. Search queries go to Radio Browser. The station click goes to Radio Browser. The device IP and User-Agent go to every stream host. Choosing Crashlytics or Sentry adds crash logs, diagnostics and device IDs. Declaring "No data collected" while a bundled SDK collects data leads to "Invalid Data safety form" rejections.
- The declared FGS type in the manifest (`android:foregroundServiceType="mediaPlayback"` plus `FOREGROUND_SERVICE_MEDIA_PLAYBACK`) must match the Play declaration and actual use.

**How to avoid:**
- In P1: set `targetSdk 36` explicitly in `android/app/build.gradle.kts` (don't rely on `flutter.targetSdkVersion` without checking it), and `minSdk 24`, which is the floor since Flutter 3.35.
- In P1: record the demo video as soon as background playback works, and upload it unlisted to YouTube. It becomes a regression artefact too.
- In P4: write a **data-flow inventory** (endpoint, data sent, purpose, third party?) and derive both the privacy policy and Data safety answers from it. A conservative reading is to declare "App activity > in-app search history" as collected, processed ephemerally and not shared, because of the Radio Browser searches. Confirm this with Play's current Data safety definitions.
- Content rating questionnaire: the app streams uncontrolled third-party audio. Answer honestly (user-accessible unrestricted content).

**Warning signs:** The build targets 35. Play Console shows "declare FGS types" warnings. Data safety says "no data" while Crashlytics is in `pubspec.yaml`.

**Phase to address:** P1 (targetSdk, manifest, FGS video). P4 (data-flow inventory). P5 (forms).

**Confidence:** [MEDIUM]. Play Console Help pages on target API and FGS, and Android 16 behaviour changes.

---

### Pitfall 12: Discovering the personal-account 12-testers × 14-days gate in the release phase

**What goes wrong:** Personal accounts created after 13 Nov 2023 need a closed test with **≥ 12 testers continuously opted in for 14 days** before they can *apply* for production. The application then includes a questionnaire (how testers were recruited, what feedback there was, what changed). It is frequently refused with "more testing required" when testers didn't actually use the app, or no builds were shipped during the test. Starting this in P5 adds 3–6+ weeks at the end of the project. Testers who opt out and back in reset their own 14-day clock.

**How to avoid:**
- **Decide personal vs Идев ЕООД before P4.** An organisation account is exempt but needs a D-U-N-S number, which also takes weeks.
- If personal: create the Play app and closed track **at the start of P4**, recruit 15–20 Bulgarian testers (margin for drop-outs), and ship 2–3 closed-test builds during the 14 days with changelogs driven by their feedback. Keep a feedback log for the questionnaire.
- The package ID must be final before the first upload. It can never change.

**Warning signs:** P5 starts and nobody is opted in. Testers joined via a link but never installed the app.

**Phase to address:** Decision before P4. Execution runs P4 into P5, in parallel with hardening.

**Confidence:** [MEDIUM]. Play Console Help 14151465 and community guides.

---

### Pitfall 13: Signing key or secret leakage from a public repository

**What goes wrong:** `key.properties`, `upload-keystore.jks`, a base64 keystore pasted into a workflow file, `google-services.json` (if Crashlytics is chosen), or `local.properties` gets committed. Or CI prints secrets through `set -x`/`echo`. Or a PR from a fork runs a workflow that has access to secrets. Git history keeps leaks even after deletion.

**How to avoid:**
- In P1, before the first Android build: add `.gitignore` entries for `*.jks`, `*.keystore`, `*.p12`, `key.properties`, `local.properties`, `google-services.json` and `**/secrets*`. Add a pre-commit or CI secret scan (gitleaks) and enable GitHub secret scanning and push protection on the repo.
- **Enrol in Play App Signing** so the key in CI is only the *upload* key, which can be reset through Play Console if it leaks. Keep an offline backup of the upload keystore and its passwords outside the repo.
- In CI: decode the keystore from a GitHub Actions secret into `$RUNNER_TEMP`, sign on tag builds only, and never run signing jobs on `pull_request` from forks (`pull_request_target` is a footgun).
- Debug and release keys stay separate. Never sign release builds with the debug key.

**Warning signs:** `git log --all -- '*.jks'` returns anything. The secret scanner flags a commit.

**Phase to address:** P1 (hygiene plus CI skeleton). P5 (release signing, Play App Signing).

**Confidence:** [MEDIUM].

---

### Pitfall 14: audio_service integration mistakes that look like engine bugs

**What goes wrong:**
- `MainActivity` doesn't extend `AudioServiceActivity` (or the FlutterFragmentActivity variant). The service and UI then end up with different Flutter engines, which causes duplicate players and a UI that doesn't reflect playback.
- `AudioService.init` is called more than once, or lazily from a widget. Notification taps and media buttons that arrive before init are lost.
- The notification doesn't dismiss after stop on Android 11+ (audio_service #599 and #751). Or it disappears about 1 min after pause, taking the controls with it (#292-style reports), so the user can't resume from the lock screen.
- Large network artwork is decoded into notification bitmaps. That causes OOM or `TransactionTooLargeException` on budget phones, and flicker on every title update.
- Two plugins both try to own the FGS, for example just_audio_background plus audio_service, or a second notification plugin. That causes `ForegroundServiceDidNotStartInTimeException`.

**How to avoid:**
- Use audio_service directly, **not** just_audio_background. You need the custom state machine anyway.
- Call `AudioService.init` exactly once in `main()` before `runApp`, and expose the handler through a Riverpod provider override.
- Set `artDownscaleWidth/Height` (about 256 px) and use station logos, not per-song art.
- Write explicit stop handling: `stop()` sets the idle state, then `super.stop()`. Test swipe-away, stop from the notification, and "task removed" (`onTaskRemoved` should stop if not playing).
- Pin plugin versions: just_audio 0.10.x (0.10.5+ disabled audio offload by default because of playback bugs; don't turn offload on) and audio_service 0.18.x. Read their changelogs on every bump.

**Warning signs:** Two sounds after a hot restart. The notification persists after stop. Lock-screen controls vanish after a pause.

**Phase to address:** P1.

**Confidence:** [MEDIUM]. GitHub issues and the pub.dev changelogs checked 2026-09-24. Both plugins were updated in about July 2026 for AGP 9 support; small maintainer team.

---

## Moderate Pitfalls

### Pitfall 15: Requesting POST_NOTIFICATIONS as if playback needed it

**What goes wrong:** The brief plans to request the Android 13+ notification permission on first play. Official docs say **"Notifications related to media sessions are exempt"**, so the media notification shows even if the permission is denied. The prompt adds friction at the exact moment of "tap to hear audio in ≤ 3 s", and a denial teaches nothing.
**Prevention:** In v1, **don't request POST_NOTIFICATIONS at all** unless a non-media notification exists. Sleep timer and errors can live in the media notification or UI. Verify on a physical Android 13+ device in P1 with the permission denied. If it is needed later (alarm in v1.1), request it in context, after playback has started. Never gate playback on it.
**Phase:** P1 verification. Revisit in the v1.1 alarm feature.
**Confidence:** [MEDIUM]. The official permission page quotes the exemption; still to be confirmed on a device with audio_service.

### Pitfall 16: Stale remote catalogue due to CDN caching

**What goes wrong:** jsDelivr branch URLs (`cdn.jsdelivr.net/gh/<user>/<repo>@main/...`) return **`Cache-Control: public, max-age=604800, s-maxage=43200`** [MEASURED]. A takedown or URL fix can take up to 12 h at the edge, and a cache-respecting HTTP client can hold it for **7 days**. `raw.githubusercontent.com` returns `max-age=300` with a strong ETag [MEASURED], but it is not a CDN contract and can rate-limit.
**Prevention:** Publish a tiny pointer file (`catalog/latest.json` → `{version, sha256, url}`) fetched from raw GitHub with `If-None-Match`. It points to an **immutable, version-pinned** jsDelivr URL (`@<tag or commit>`) for the payload. Verify the sha256 and the schema version before swapping. Fall back to the last good cache, then the bundled snapshot. Don't put an HTTP cache interceptor in front of the catalogue fetch.
**Phase:** P2.
**Confidence:** [MEASURED] headers. Design is [LOW] (recommendation).

### Pitfall 17: A missing or invalid catalogue bricks the app

**What goes wrong:** A malformed JSON push, schema change or truncated download leaves an empty home screen, or a crash on launch for every user at once.
**Prevention:** Validate against the JSON schema in CI on every catalogue PR. Also run a "stream smoke check" script in CI that tries each URL. In the app, parse defensively: drop invalid entries, and never replace a good cache with a worse one. Use a `minAppVersion` field so new schema fields don't break old clients.
**Phase:** P2.

### Pitfall 18: Time-to-audio > 3 s because of serial work on launch

**What goes wrong:** Resume-last-station waits for the catalogue fetch, Radio Browser DNS discovery, logo loading, or `.pls` resolution. HLS adds a playlist fetch and starts about 3 target durations behind the live edge (segments are 6–10 s), which makes the start slower. The default ExoPlayer buffering before playback is 2.5 s on top of the connect time.
**Prevention:** Persist the last station's *resolved* stream URL and start it from local storage before anything else. Prefer progressive Icecast MP3/AAC as `priority 1` when a station offers both, and keep HLS as fallback. Tune `AndroidLoadControl` (e.g. `bufferForPlaybackDuration` about 1–1.5 s) and measure the effect on rebuffering. Instrument time-to-audio locally (tap → first `playing` + `ready`) and show it in a debug overlay.
**Phase:** P1 (engine buffer config plus instrumentation). P3 (resume-on-launch path).

### Pitfall 19: Audio focus handling wrong for drivers and headsets

**What goes wrong:** Pausing on every transient loss, including navigation prompts, when ducking is expected. Not resuming after a call. Resuming after a *permanent* loss (the user opened Spotify), which is hostile. Becoming-noisy handling that pauses when *not* playing, or that doesn't fire for Bluetooth disconnects. Some car head units send PLAY on connect, so the radio starts unexpectedly.
**Prevention:** Transient loss with "can duck" → duck (let the system auto-duck when the attributes are `USAGE_MEDIA`/`CONTENT_TYPE_MUSIC`). Transient loss → `interrupted` (keep the FGS, auto-resume on gain within about 2 min). Permanent loss → `pausedByUser` semantics, no auto-resume. Becoming-noisy → pause only if playing. Accept media-button PLAY only if a station was playing in this process, or show it as resumable. Test with a real phone call, Google Maps navigation, a WhatsApp voice note, wired unplug, and BT disconnect.
**Phase:** P1.

### Pitfall 20: Geo-blocked and flaky Bulgarian streams for users abroad

**What goes wrong:** Bulgarians abroad are a target group, but some CDNs and stations geo-restrict or rate-limit by region. Streams on non-standard ports (e.g. `:8011`) are blocked by corporate or hotel firewalls. During this research the official `stream.bnr.bg:8011` URL **did not connect** from the test location, while the cdn.bg HLS URL did [MEASURED; cause unknown]. The user just sees "broken".
**Prevention:** Keep several fallbacks per station in `streams[]` (port-80/443 or HLS variants first for robustness). Error UX distinguishes "can't reach this stream" from "no internet". Include the country in the broken-station report. Have one tester abroad during the closed test.
**Phase:** P2 (fallback data). P4 (error UX, reporting).

### Pitfall 21: Low-end device performance and size

**What goes wrong:** Decoding full-size station logos in long lists causes jank and OOM on 2–3 GB RAM phones. SQLite native libraries plus several ABIs bloat the APK. Heavy splash or first-frame work delays cold start past 2 s.
**Prevention:** Always set `memCacheWidth`/`cacheWidth` for logos. Generate placeholders with cheap painting, not images. Ship an **AAB** (Play serves per-ABI splits; a minimal Flutter app is about 4–5 MB per ABI). Enable R8 plus resource shrinking and check that it doesn't strip plugin classes; test the *release* build. Keep `armeabi-v7a`, because many budget BG phones are 32-bit or Android Go. Profile on a real low-end device in `--profile` mode. Track AAB size in CI and fail on large regressions.
**Phase:** P4 (a CI size check can start in P1).

### Pitfall 22: Target-36 UI changes left to the end

**What goes wrong:** Edge-to-edge is enforced (content under the status and navigation bars, including the mini-player behind gesture nav). Predictive back is on by default, so custom `WillPopScope` flows break (use `PopScope`).
**Prevention:** Build the shell with `SafeArea` and inset-aware mini-player from P3. Test with 3-button and gesture navigation.
**Phase:** P3.

---

## Minor Pitfalls

### Pitfall 23: Sleep timer that dies with the UI or cuts abruptly
**What goes wrong:** A Dart `Timer` in a widget is lost when the activity is destroyed. The stop is abrupt, and the FGS stays up.
**Prevention:** Own the timer in the audio handler (the process survives with the FGS). Fade out the last 10–20 s. Stop means full stop and FGS release. "End of current hour" uses local wall-clock time, so cover DST in tests.
**Phase:** P3.

### Pitfall 24: Crash-free ≥ 99.5 % target with no way to measure it
**What goes wrong:** If the owner picks "no crash reporting", the metric seems unmeasurable.
**Prevention:** Play Console **Android vitals** reports crash and ANR rates without an SDK. It uses opted-in diagnostics and needs no Data safety entry for an SDK. Use it as the v1 baseline. Choosing Crashlytics or Sentry triggers Data safety and privacy-policy updates (Pitfall 11).
**Phase:** Decision before P4.

### Pitfall 25: Share links that nobody can open
**What goes wrong:** Sharing a raw stream URL (it opens a download in Viber) or an app deep link that doesn't exist.
**Prevention:** Share "Station name — homepage URL — Слушай в <App> (Play link)". Deep links wait for v1.1.
**Phase:** P3.

### Pitfall 26: Package ID and app name chosen casually
**What goes wrong:** The package ID is permanent. An app name containing a station brand ("БНР Радио …") triggers impersonation review.
**Prevention:** Owner decides before `flutter create` (already flagged in PROJECT.md). The name must be generic.
**Phase:** P1 gate.

### Pitfall 27: Android developer verification confusion
**What goes wrong:** Google's 2026 developer-verification rollout (Brazil, Indonesia, Singapore and Thailand from 30 Sep 2026; global in 2027) also covers sideloaded apps. Play-distributed apps are verified through the Play Console identity checks. The owner may worry about sideloading test APKs to testers.
**Prevention:** Distribute test builds through Play testing tracks (internal and closed), not APK files. ADB installs on the owner's phone are unaffected.
**Phase:** P5 (awareness only).
**Confidence:** [LOW].

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Calling just_audio directly from widgets, bypassing `AudioEngine` | Faster P1 demo | Can't swap to native Media3 when a plugin stalls; state logic is scattered | Never. The seam is a stated key decision |
| `usesCleartextTraffic="true"` with no in-code HTTPS enforcement for app-owned calls | One line | Catalogue and API calls could silently downgrade | Only with the HTTPS-enforcing client wrapper (Pitfall 5) |
| Resolving `.pls`/`.m3u` at runtime for curated stations | No CI script needed | Extra round trip on every play; more failure modes | OK for Radio Browser fallback; not for curated entries |
| Hard-coding one Radio Browser mirror | Simple | Breaks when that mirror goes down; violates guidelines | Never |
| Treating pause as a real pause on live streams | Matches the music-player sample | Stale audio and disconnects (Pitfall 2) | Only within a ≤ 30 s grace window |
| Skipping the golden transliteration tests | Saves an afternoon | Search regressions are invisible; they are the #1 "can't find my station" complaint | Never |
| Bundled snapshot with no remote kill-switch | Simpler catalogue code | Takedowns need an app release plus a 1–3 day review | Never (rights exposure) |
| No crash SDK in v1 | Privacy, simpler Data safety | Less detailed stack traces | Acceptable. Use Android vitals plus `flutter` symbols upload |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Radio Browser API | Fixed mirror, no UA, `country`, `url`, `hidebroken` unset, click on every reconnect | DNS/`/json/servers` discovery with failover; `App/ver` UA; `countrycode`, `url_resolved`, `hidebroken=true`; one click per user-initiated play |
| Icecast / Shoutcast servers | Probing with `dart:io` (breaks on `ICY 200 OK`, never-ending body); browser-like UA | Let the player probe; neutral app UA; keep `/;` suffixes; expect `Connection: close`, 403 when full, 404 during source restarts |
| HLS CDNs (cdn.bg etc.) | Assuming the URL is final; seeking after errors | Follow 302s; re-prepare at the live edge on errors; expect slower start |
| Aggregators (global.audio, streamtheworld, zeno.fm) | Copying URLs with `dist=`/session tokens from RB or other apps | Use the station's official URL or ask the station; flag and hide tagged URLs |
| GitHub raw / jsDelivr | Branch URLs behind an HTTP cache (7-day `max-age`) | Pointer file with ETag plus immutable version-pinned payload plus checksum |
| audio_service | `just_audio_background` plus custom handler; `init` in a widget; default stop-on-pause for radio | One handler, `init` in `main`, explicit FGS policy per state |
| Play Console | FGS declaration without video; Data safety as an afterthought | Record the video in P1; data-flow inventory in P4 |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Full-size logo decoding in lists | Jank, OOM on 2 GB phones | `cacheWidth`/`memCacheWidth`, small placeholders | Lists > ~50 logos on low-end devices |
| Notification artwork re-fetch on every ICY update | Flicker, battery and data use | Stable per-station art URI, downscale, update only on change | Stations updating titles every 10–30 s |
| Unthrottled search against RB | Laggy typing, API load | 300 ms debounce, cancel in-flight requests, local-first for BG | Every keystroke |
| Reconnect without backoff | Battery drain, server bans | Exponential backoff with jitter plus a total cap | Dead station at night with the screen off |
| Keeping the socket open while "paused" | Mobile data burn, then disconnect | Stop the network on pause for live streams | Pauses > 30 s |
| Big catalogue JSON parsed on the UI isolate | Launch jank | `compute()`/isolate parsing; keep the BG catalogue small (< 200 KB) | Catalogue > ~1 MB or low-end CPU |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Keystore or `key.properties` in the public repo, or leaked via CI logs | Anyone can sign updates (if app signing is not Google-managed) | Play App Signing, gitignore, gitleaks, secret scanning, no signing on fork PRs |
| Remote catalogue without integrity checks | A compromised repo or CDN pushes malicious stream or homepage URLs to all users | Pinned versions plus sha256 in the pointer file; schema validation; URL scheme allowlist (`http`, `https` only for streams; `https` for homepage and logo) |
| Opening station `homepage` URLs from untrusted RB data in a WebView | Phishing or JS injection surface | Open in an external browser (`url_launcher` external mode) only; no in-app WebView |
| Global cleartext without in-code enforcement for app-owned endpoints | Downgrade and MITM of the catalogue | HTTPS-only client for non-media calls |
| Rendering RB station names or tags without sanitising | Layout abuse (very long names, control chars, RTL overrides) | Strip control and bidi-override characters, clamp lengths |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Spinner forever during reconnect | "App is broken", user kills it | Visible states: "Свързване…", "Връзката прекъсна — опитваме отново (3)", "Станцията не отговаря" plus Retry / Try other stream |
| Showing broken RB stations in BG lists | Distrust of the whole catalogue | `hidebroken=true`, curated first, hide unverified RB BG duplicates |
| Battery-optimisation nag at first launch | Looks like malware, 1-star reviews | Show only after a detected OS kill, once, dismissible |
| Notification permission prompt on first play | Friction at the moment of value | Don't ask in v1 (media notifications are exempt) |
| Latin-only UI strings or machine-translated Bulgarian | Older listeners are put off | Owner reviews all BG strings; BG default on `bg` locale |
| Tiny player controls | Older users and drivers can't hit them | ≥ 48 dp targets, bigger primary play button, TalkBack labels |
| Seek bar or timer shown for live radio | Confusing, implies you can seek | Show a "НА ЖИВО" badge instead |

## "Looks Done But Isn't" Checklist

- [ ] **Background playback:** Works for 60 min screen-off on **Xiaomi and Samsung** physical devices, on Wi-Fi *and* 4G. Verify with `dumpsys wifi` that a Wi-Fi lock is held while playing and released on stop.
- [ ] **Reconnect:** Wi-Fi → 4G, 4G → Wi-Fi, airplane mode for 20 s, and elevator/tunnel (signal loss for 60 s) all recover without touching the phone, with the screen off, on Android 15+ (audio focus rule).
- [ ] **Phone call:** Radio resumes after a call ends with the screen off and the app backgrounded, and there is no `ForegroundServiceStartNotAllowedException` in logcat.
- [ ] **Live semantics:** Pause 5 min, resume, and it is at the live edge (compare with an FM radio or the station's web player). An HLS station survives a 10-min pause.
- [ ] **Server restart:** Killing the stream mid-play (simulate with a local Icecast or an `http` proxy that closes the socket) triggers reconnect, not "completed".
- [ ] **ICY:** Cyrillic titles display correctly on a windows-1251 station. The title is cleared on station switch. The HLS station shows the station name.
- [ ] **`.pls`/`.m3u`:** Fixtures with CRLF, BOM, lowercase keys, relative URLs and HLS-in-m3u pass unit tests.
- [ ] **Cleartext:** An `http://` station **not** in any allowlist plays in a **release** build.
- [ ] **Notification:** Dismisses after stop. Persists (with a working play button) while paused-by-interruption. Controls work from the lock screen and car Bluetooth.
- [ ] **Permission denied:** On Android 13+ with notifications denied, playback and the media controls still work.
- [ ] **Search:** Golden table passes (Latin, Cyrillic, shlyokavitsa, "ия"→"ia", й preserved).
- [ ] **Catalogue:** Corrupt remote JSON leaves the app on the last good or bundled data. A takedown flag removes the station, including matching RB entries, on next launch.
- [ ] **Radio Browser:** A UA header is present (check with a proxy). Kill the first mirror and search still works. One click call per user-initiated play.
- [ ] **Release build:** R8-shrunk AAB plays all stream types. Target 36. `foregroundServiceType="mediaPlayback"` is in the merged manifest.
- [ ] **Store:** FGS video uploaded. Data safety matches the data-flow inventory. No third-party logos in icon, title or screenshots without permission.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Keystore committed to public repo | MEDIUM (LOW if Play App Signing was on) | Rotate the upload key via Play Console → App integrity → "Request upload key reset"; purge history (`git filter-repo`) *and* treat the key as compromised anyway; rotate CI secrets |
| Takedown request from a station | LOW if the kill-switch exists, HIGH otherwise | Flip `disabled` in the remote catalogue (plus the RB uuid blocklist); reply within 24–48 h; remove from the next snapshot; log it |
| Play rejects the FGS declaration or Data safety | LOW | Fix the form or video and resubmit; the rejection email names the policy |
| Production access refused after closed test | MEDIUM (another 14+ days) | Recruit more engaged testers, ship 2–3 builds with changelogs, answer the questionnaire concretely |
| A just_audio or audio_service regression or abandonment | MEDIUM | Pin the previous version; if long-term, implement `AudioEngine` over a native Media3 `MediaSessionService` via platform channel |
| Mojibake discovered after launch | LOW | Add `icyCharset` to the affected stations in the remote catalogue; no release needed if the field is supported from v1 |
| Bad catalogue push | LOW | Revert the commit; the pointer file points to the previous immutable version; clients keep their last good cache |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1 FGS lifecycle vs pause, focus and reconnect | P1 (re-check P4) | Phone-call and tunnel tests on Android 15+/17 devices; no FGS exceptions in logcat |
| 2 Live-stream semantics | P1 | Pause 5 min → live edge; HLS 10-min pause; server-close → reconnect |
| 3 Reconnect watchdog and backoff | P1 (fallbacks P4) | Wi-Fi↔4G within 10 s; unit tests of the policy with a fake clock |
| 4 Wi-Fi lock and OEM killers | P1 (lock) / P4 (hint, OEM matrix) | 60 min screen-off on Xiaomi and Samsung; `dumpsys wifi` |
| 5 Cleartext scoping | P1 / P2 (logos) | http station outside any list plays in release |
| 6 ICY charset and staleness | P1 / P3 | cp1251 station shows correct Cyrillic |
| 7 Playlist and URL resolution | P1 / P2 (CI resolution) | Fixture unit tests; redirecting-stream test |
| 8 Radio Browser guidelines and data | P2 | Proxy capture: UA, mirror failover, click count |
| 9 Content rights and takedowns | P2 (catalogue rules, kill-switch) / P5 (assets) | CI rejects `dist=` URLs; kill-switch test |
| 10 Bulgarian search | P2 | Golden table reviewed by the owner |
| 11 targetSdk, FGS declaration, Data safety | P1 (target 36, video) / P4 (inventory) / P5 (forms) | Merged manifest check; form matches inventory |
| 12 12 testers × 14 days | Decision before P4; closed test starts in P4 | 12+ testers opted in ≥ 14 consecutive days, 2–3 builds shipped |
| 13 Signing leakage | P1 / P5 | gitleaks in CI; Play App Signing enabled |
| 14 audio_service integration | P1 | Swipe-away, stop, and lock-screen tests |
| 15 Notification permission | P1 | Denied-permission test on Android 13+ |
| 16–17 Catalogue caching and integrity | P2 | Corrupt payload and takedown tests |
| 18 Time-to-audio | P1 / P3 | Debug overlay median ≤ 3 s on 4G |
| 19 Audio focus and noisy | P1 | Call, Maps prompt, unplug, BT disconnect |
| 20 Geo and firewall | P2 / P4 | Tester abroad; fallback stream order |
| 21 Low-end performance and size | P4 (size check from P1) | Profile on a budget device; AAB size in CI |
| 22 Edge-to-edge and predictive back | P3 | Gesture and 3-button nav visual check |

## Sources

- Android: [Background audio hardening (Android 17)](https://developer.android.com/about/versions/17/changes/bg-audio); [Behavior changes, Android 15 (audio focus)](https://developer.android.com/about/versions/15/behavior-changes-15); [Behavior changes, Android 16](https://developer.android.com/about/versions/16/behavior-changes-16); [FGS background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start); [FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types); [Notification runtime permission (media-session exemption)](https://developer.android.com/develop/ui/views/notifications/notification-permission); [Doze and App Standby, battery-optimisation exemptions](https://developer.android.com/training/monitoring-device-state/doze-standby)
- Google Play: [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878); [FGS and full-screen intent declaration](https://support.google.com/googleplay/android-developer/answer/13392821); [Testing requirements for new personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465); [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469); [Impersonation policy](https://support.google.com/googleplay/android-developer/answer/9888374); [Developer verification](https://support.google.com/android-developer-console/answer/16561738)
- Plugins: [just_audio changelog](https://pub.dev/packages/just_audio/changelog); [audio_service changelog](https://pub.dev/packages/audio_service/changelog); just_audio issues [#117](https://github.com/ryanheise/just_audio/issues/117), [#254](https://github.com/ryanheise/just_audio/issues/254), [#518](https://github.com/ryanheise/just_audio/issues/518), [#732](https://github.com/ryanheise/just_audio/issues/732), [#871](https://github.com/ryanheise/just_audio/issues/871), [#984](https://github.com/ryanheise/just_audio/issues/984), [#1277](https://github.com/ryanheise/just_audio/issues/1277); audio_service issues [#599](https://github.com/ryanheise/audio_service/issues/599), [#751](https://github.com/ryanheise/audio_service/issues/751), [#996](https://github.com/ryanheise/audio_service/issues/996)
- ExoPlayer/Media3: [Non-UTF-8 ICY #6753](https://github.com/google/ExoPlayer/issues/6753), [#10254](https://github.com/google/ExoPlayer/issues/10254); [ICY charset discussion (radio-garden #145)](https://github.com/radio-garden/react-native-audio-browser/issues/145); [BehindLiveWindow #8675](https://github.com/google/ExoPlayer/issues/8675); [FGS did-not-start-in-time, androidx/media #112](https://github.com/androidx/media/issues/112)
- Radio Browser: [API docs and client guidelines](https://docs.radio-browser.info/); live query of `/json/stations/bycountrycodeexact/BG` on 2026-09-24 (measured statistics above)
- OEM killers: [dontkillmyapp.com](https://dontkillmyapp.com/), [Samsung page](https://dontkillmyapp.com/samsung)
- Streaming protocol quirks: [Shoutcast `/;` behaviour (Winamp forums)](https://forums.winamp.com/forum/shoutcast/shoutcast-technical-support/314295-streaming-url); [dart-lang/sdk #19939 (HttpClient strict parsing)](https://github.com/dart-lang/sdk/issues/19939); [OkHttp ICY support #386](https://github.com/square/okhttp/issues/386)
- Transliteration: [Закон за транслитерацията (bg.wikisource)](https://bg.wikisource.org/wiki/%D0%97%D0%B0%D0%BA%D0%BE%D0%BD_%D0%B7%D0%B0_%D1%82%D1%80%D0%B0%D0%BD%D1%81%D0%BB%D0%B8%D1%82%D0%B5%D1%80%D0%B0%D1%86%D0%B8%D1%8F%D1%82%D0%B0); [Словоред rules](https://slovored.com/transliteration/rules.html); [unorm_dart](https://pub.dev/packages/unorm_dart), [dart-lang/sdk #7611](https://github.com/dart-lang/sdk/issues/7611)
- Flutter: [minSdk 24 since 3.35 (flutter #170807)](https://github.com/flutter/flutter/issues/170807); [Build and release an Android app](https://docs.flutter.dev/deployment/android)
- Caching: live `curl -I` against raw.githubusercontent.com and cdn.jsdelivr.net on 2026-09-24 (measured headers)

---
*Pitfalls research for: Flutter Android live internet radio (Bulgarian-first), Google Play*
*Researched: 2026-09-24*
