# Competitive Research — Online Radio Apps

> Researched 2026-09-25 for the Online Radio App (see `docs/BRIEF.md`).
> Download counts, ratings and "last updated" dates were read from Google Play listings in September 2026; they move over time.
> Nothing here is legal or financial advice.

---

## Key takeaways

1. **In Bulgaria, nobody offers "all Bulgarian radio, done well".** Each broadcaster group's app covers only its own stations: RADIOPLAY (9–11 stations), bTV Radiomate (5), БНР (its own programmes). The "all stations" apps are generic template apps by foreign developers, re-skinned for dozens of countries and full of ads.
2. **Users' main complaints are about reliability and ads, not missing features.** Reviews of Bulgarian apps mention ads "literally every minute" or popping up mid-song, playback pausing every minute or two, no artist/title on the lock screen, and Android Auto that is broken, removed or paywalled.
3. **Worldwide leaders all run the same model:** free with heavy ads (full-screen, video, audio pre-roll), plus a paid tier that removes the *app's* ads. TuneIn Premium also adds exclusive content (sports, commercial-free stations, audiobooks), which a small app can't match.
4. **Banner ads alone will earn very little.** People listen with the screen off, so screen time per listening hour is tiny, and Bulgarian ad rates are low (≈ $0.3–0.8 per 1,000 impressions). Competitors earn from full-screen and audio ads because banners don't pay.
5. **The best-fitting money strategy is B2B, not B2C.** Stations pay $29–99/month for white-label apps (RadioKing's public prices). You'll have a solid Bulgarian playback engine and catalogue; selling station-branded apps or featured placements to regional Bulgarian stations can beat banner income with a fraction of the audience.
6. **Licensing risk grows once you monetise.** A UK court ruled that TuneIn infringed copyright by linking, for profit, to foreign stations not licensed in the UK. Bulgarian stations streamed to listeners in Bulgaria are low risk. Monetised worldwide stations, and serving diaspora users in some countries, carry more.

---

## 1. Bulgaria

### 1.1 Broadcaster-owned apps

| App | Owner | Stations | Play stats | Notes |
|---|---|---|---|---|
| **RADIOPLAY** | RADIOPLAY MEDIA AD (formerly Fresh Media Bulgaria; "largest independent radio group", >2.5M listeners claimed) | Energy, BG Radio, Radio 1, Radio 1 Rock, Veronika, City, Nova, Avtoradio, Nova News, BG Estrada, Energy 90's | 100K+ downloads · 4.8★ (11.2K) · ads · updated Jun 2025 | Contact the studio, **record a musical greeting (поздрав)**. Reviews: pop-up ads mid-song; Android Auto removed in an update. **The strongest local competitor.** |
| **Radiomate** | bTV Media Group | N-JOY, bTV Radio, Jazz FM, Classic FM, Z-Rock | 1K+ · 3.2★ (37) · ads · last updated **Oct 2023** | Station switching, news headlines. Reviews: "useless", can't exit the app, no content descriptions. Appears unmaintained. |
| **БНР** | Bulgarian National Radio | Хоризонт, Христо Ботев, 9 regional stations (Sofia, Plovdiv, Varna, Burgas, Stara Zagora, Shumen, Blagoevgrad, Vidin, Kardzhali) | Launched **Dec 2025** (numbers not checked) | Live + podcasts + news + children's content in one app. Public broadcaster, no ads expected. |

No clear official app was found for Darik Radio or Radio Fresh (third-party single-station apps exist), nor for most smaller regional and city stations. They appear mainly inside aggregators or on their own websites.

### 1.2 "All Bulgarian stations" aggregator apps (Google Play)

| App (Play name) | Developer (country) | Downloads · rating | Model | Notable features | Top complaints |
|---|---|---|---|---|---|
| Радио Онлайн България: Live FM | Radio Expert (Serbia) | **500K+** · 4.8★ (33.4K) | Ads | By city/genre, favourites, history (last 50) | **Pauses every minute or two**, wants ad removal, bitrate choice, overloaded streams |
| Radio Bulgaria – radio online | APPMIND LDA (Portugal) | 100K+ · 4.9★ (11.6K) · updated Aug 2026 | Ads + IAP | Sleep timer, alarm, Chromecast, **song identification**, dark mode | **No artist/title for many stations, nothing on lock screen**, must open app to change station |
| Radio Bulgaria – Online radio stations | Hertzify SL / RadioFMapp (Spain) | 50K+ | Ads | 150+ stations, sleep timer, **Top 20**, search by city | Shares data with third parties; data can't be deleted |
| Radio Bulgaria – Radio FM | "Online Radios & Podcasts" (package `worldradios.bulgarie`) | 10K+ · 4.9★ (2.1K) · updated Sep 2026 | Ads | Alarm, sleep timer, Chromecast, **Android Auto**, **widget** | **Ads "literally every minute"**; wants dark mode and reorderable favourites |
| Radio Bulgaria – FM & Online | Creative Wolf B.V. (Netherlands) | 10K+ · 4.6★ (267) | Ads + paid version | 100+ stations, podcasts, alarm, sleep timer, Android Auto | **Paid "Car Mode" doesn't work with Android Auto after purchase** |

**Pattern:** these are template apps. The same developer publishes "Radio \<Country\>" for many countries, uses one generic station database, and monetises with dense ads. High ratings come partly from rating prompts, not quality; the written reviews tell a different story.

### 1.3 Websites

Bulgarian listening sites: radiosbg.com, bg-radio.org, online-radio-bg.com, bulgariafm.net, bg-radia.com, predavatel.com (live list). International: onlineradiobox.com (has a Bulgarian section and its own app, AdSense-funded), TuneIn, streema, surfmusic. They compete for web traffic, not app installs. They matter for your **store/SEO keywords** ("радио онлайн", "българско радио", station names).

### 1.4 Market size (limited data)

- Ipsos 2014 (commissioned by БНР and private networks): **65.7% of Bulgarians listen to radio daily** (4M+), 162 min/day on average. Only **9% listened via internet**; 83% used a traditional radio receiver; 37% listened while travelling. No newer public breakdown was found. Online and mobile listening is certainly much higher today, but that needs checking.
- RADIOPLAY, the largest local app, has 100K+ downloads. That sets a realistic ceiling for a niche Bulgarian radio app: **tens of thousands of installs, a few thousand daily users** if it's the best one.

### 1.5 The opening in Bulgaria

No existing app combines:
- **all** Bulgarian stations (БНР + RADIOPLAY group + bTV group + Darik + Fresh + regional),
- playback that doesn't stop, with artist/title on the lock screen,
- working **Android Auto**,
- few or no ads,
- a real Bulgarian UI and search (Cyrillic/Latin).

That is exactly what `BRIEF.md` describes. **Android Auto is currently a v1.1 item, but it's the feature most often broken in competitors.** Consider moving it into v1.0.

---

## 2. Worldwide

| App | Owner / origin | Scale | Money model | Standout features |
|---|---|---|---|---|
| **TuneIn** | TuneIn Inc. (US) | 100M+ downloads · 4.7★ (2.8M) · 100K+ stations, 197+ countries | Ads (banners + **audio ads**); **TuneIn Pro** one-time purchase removes banners; **TuneIn Premium** ≈ $9.99/mo (US) | Exclusive content: live sports (NFL, MLB, NHL, college), 100+ commercial-free music stations, audiobooks; CarPlay, Alexa, Google Home. Complaints: the same audio ad repeating for minutes. |
| **radio.net** (radio.de) | radio.de GmbH (Germany) | 10M+ · 4.6★ (373K) · 60K+ stations, 2M+ podcasts | Ads incl. **video ads before a station starts**; **Prime** subscription removes app ads (stations' own on-air ads remain) | Podcasts with offline downloads, Android Auto, Chromecast, sleep timer. Complaints: full-screen ads. |
| **myTuner** | Appgeneration (Portugal) | 10M+ · 4.5★ (335K) · 50K+ stations, 200 countries | Ads + subscription (a reviewer mentions ~$20/yr) | **Everywhere:** phones, web, smart TVs, Android Auto, CarPlay, watches, Alexa, Sonos, several car makers' systems. Complaints: **switched from lifetime ad-free to subscription**, and lifetime buyers now see ads again. |
| **Replaio** | Replaio sp. z o.o. (Poland) | 5M+ · 4.7★ (175K) · 50K+ stations | Ads + **one-time Premium** (no subscription): ad-free, widgets, home-screen station icons | Alarm with snooze, sleep timer, **equaliser**, **add your own stream URL**, **Bluetooth auto-start**, **stream quality per network (3G/LTE/Wi-Fi)**, Spotify playlist integration, Material You. Praised for fair pricing. |
| **Simple Radio** | Streema | (not checked) | Ads + Premium | Premium removes visual ads **and unlocks the sleep timer** (a basic feature behind a paywall). |
| **Radio Garden** | Radio Garden B.V. (NL; started as a non-profit research project, 2016) | 40K+ stations (2024) | Not documented | **Spin-the-globe discovery**, stations placed by city. **Banned in Turkey (2022)** after refusing licence fees; **UK users limited to UK stations since 2022**. |
| **Radioplayer** | Broadcaster-owned, non-profit (BBC, Global, Bauer…) | UK + 15 countries (latest: Slovenia 2023, Portugal 2026). **Not in Bulgaria** | Funded by broadcasters | Only licensed stations; hybrid FM/DAB/stream car adaptor; Sonos, Echo, CarPlay. |
| **RadioDroid**, **Transistor** | Open source (F-Droid) | Small | Free, donations | RadioDroid is built on the Radio Browser directory (your data source). Transistor is minimal. Shows the "no ads, privacy" niche. |
| **Radio Tuner: Online AM FM** | MacyMind | 1M+ · 3.9★ | Ads | "Now playing" info + **YouTube search for the current song**; auto pause/resume on calls. |
| iHeartRadio, Audacy | US broadcaster groups | Very large (US) | Ads + subscriptions | Own stations + podcasts; a model for broadcaster-owned platforms. Not relevant to Bulgaria. |

**Lessons from worldwide competitors**
- Scale players win on **catalogue size and platform reach** (TVs, cars, speakers). Don't compete there; compete on Bulgarian depth and quality.
- The **fairest-feeling model is Replaio's**: a one-time Premium purchase, a generous free tier, no forced subscription. myTuner's move from lifetime to subscription is the cautionary tale.
- **Don't paywall basics.** Sleep timer (Simple Radio) and Android Auto (Creative Wolf) behind paywalls produce angry reviews.
- Everyone says the same thing: the paid tier removes **the app's** ads, not the stations' own on-air ads.

---

## 3. Feature comparison vs. your plan

✅ = planned in BRIEF v1.0 · 🔜 = planned v1.1 / later · ➕ = not in the brief yet (proposal)

| Feature | Who has it | Your plan |
|---|---|---|
| Background playback, lock-screen & notification controls | All | ✅ |
| Artist/title (ICY) on lock screen | Most global; **missing in several BG apps** | ✅ |
| Auto-reconnect, no random pauses | Weak in BG apps | ✅ (a key differentiator) |
| Sleep timer | Almost all | ✅ |
| Favourites, recents, resume last | All | ✅ |
| Search by city / genre | Radio Expert, RadioFMapp | ✅ |
| Cyrillic ⇄ Latin search | Nobody mentions it | ✅ (differentiator) |
| Dark mode | Most (missing in some BG apps) | ✅ |
| **Android Auto** | Global leaders; **broken/removed/paywalled in BG** | 🔜 → ➕ **move to v1.0** |
| Alarm clock (wake to radio) | Most | 🔜 |
| Home-screen widget | Ribeyrotte app, Replaio (paid) | 🔜 |
| Chromecast | APPMIND, radio.net, myTuner | 🔜 |
| Stream quality per network / data saver | Replaio | 🔜 |
| Song history + "search this song" | Radio Tuner (YouTube search), APPMIND (song ID) | 🔜 |
| **Contact the studio / send a greeting (поздрав)** | RADIOPLAY (own stations only) | ➕ Cheap version: per-station phone / Viber / SMS / e-mail buttons from the catalogue |
| **Top / popular Bulgarian stations** | RadioFMapp (Top 20) | ➕ Could use Radio Browser click counts; no backend needed |
| **Add your own stream URL** | Replaio | ➕ Power-user feature, cheap |
| Equaliser | Replaio | 🔜 (later) |
| Bluetooth auto-start (car) | Replaio | ➕ Nice for drivers, pairs with Android Auto |
| Podcasts | БНР, radio.net, myTuner, Creative Wolf | Out of scope (keep it that way for v1; БНР already covers its own) |
| Globe / map discovery | Radio Garden | ➕ Optional fun "World" view, later |
| Smart TV, watch, smart speakers | myTuner, TuneIn | Later / not needed |

---

## 4. How radio apps make money

| Model | Examples | Fit with your "no annoying ads" stance |
|---|---|---|
| Full-screen / video ads (interstitials, before a station starts) | radio.net, BG template apps | ❌ Excluded by you. Also the #1 source of bad reviews. |
| Audio ads (pre-roll before stream, or inserted) | TuneIn, others via ad servers like Triton/AdsWizz | ⚠️ Pays best per listener, but intrusive. Inserting ads around stations' content invites objections unless stations agree. |
| Banner ads | Most free apps | ✅ Your planned approach (after ~30 days). Low income, see §5.1. |
| Subscription removing app ads (+ extras) | TuneIn Premium, radio.net Prime, myTuner | ⚠️ Works at scale. Small audiences rarely justify a subscription. |
| **One-time "Pro"/supporter purchase** | Replaio, TuneIn Pro | ✅ Liked by users, simple, no backend. |
| **B2B: station apps / white-label** | RadioKing ($29–99/mo per station), Aiir, Appgeneration | ✅✅ Best fit; see §5.2. |
| Exclusive content | TuneIn (sports, audiobooks) | ❌ Needs rights deals and money. |
| Donations | Open-source apps | ✅ Small but friendly. |
| Broadcaster funding / consortium | Radioplayer, БНР | Could become a **partnership** angle with Bulgarian groups later. |
| Data sharing with ad partners | Many template apps (per Play "Data safety") | ❌ Avoid: GDPR risk and trust damage. |

---

## 5. Money-making strategies for this app (ranked by fit)

### 5.1 First, a reality check on banners
Rough assumptions:
- Bulgarian AdMob rates of about **$0.3–0.8 per 1,000 impressions** (an indicative third-party figure, not official).
- About **3 banner impressions per user per day**, because people mostly listen with the screen off.
- About **70%** of daily users are past the 30-day threshold.

| Daily active users | Monthly banner income (rough) |
|---|---|
| 1,000 | ≈ $20–50 |
| 5,000 | ≈ $100–250 |
| 20,000 | ≈ $400–1,000 |

For scale: 5,000 daily users would already make you a serious Bulgarian radio app. Banners are worth adding eventually, but they won't carry the project.

### 5.2 Recommended mix

1. **B2B for Bulgarian stations (highest potential, fits Идев ЕООД)**
   - **Station-branded apps:** reuse your engine to publish white-label apps for regional stations that have none (many small and city stations). Maintenance is a monthly fee. RadioKing charges $29–99/month for similar apps, so **5 stations × €50/month ≈ €250/month**. That's roughly the banner income from ~5,000 daily users.
   - **Rescue abandoned apps:** bTV's Radiomate hasn't been updated since 2023 (3.2★). An existing broadcaster app with poor reviews is a sales opening.
   - **Featured placement:** a clearly labelled "Препоръчано" slot on the Bulgaria home screen, sold to stations, e.g. monthly. It's non-intrusive and relevant.
   - **Listener stats for partner stations:** anonymous, aggregated play counts per station. Stations rarely get good streaming numbers. This needs a small backend later, and privacy-safe design.
   - Partnerships also solve **rights, logos and stream stability**.

2. **One-time "Supporter" purchase (early, low effort)**
   - Something like €2.99–4.99, available from v1.0: "support the app", later also "no banners forever".
   - Keep it a **lifetime** purchase and honour it forever (the myTuner lesson).
   - Optional cosmetic extras (themes, custom app icon), never core features.

3. **Banners after 30 days (as planned)**, never on the player, never full-screen. Add EEA consent (Google UMP). Expect pocket money (§5.1).

4. **Direct local sponsorship** instead of (or in addition to) AdMob:
   - One sponsor per section or city ("Нощен таймер, предоставен от…", "Радиата в Ямбол — с подкрепата на…").
   - Local businesses pay flat monthly fees that beat programmatic ad rates. It's more sales work, but fits a regional app.

5. **Affiliate links on the song now playing** (small, user-friendly):
   - "Listen on Apple Music / YouTube Music / Deezer".
   - Apple's partner programme pays a one-time fee per new Apple Music subscriber (Bulgaria support to confirm).
   - Concert tickets for the artist is another option to explore with Bulgarian ticketing sites.

6. **Maybe later:** a short audio pre-roll when a station starts (the model TuneIn and radio.net use), **only** with partner stations' consent, and only if the audience is large. It conflicts with your "no annoying ads" principle, so treat it as a last resort.

### 5.3 What to avoid (seen in competitors' reviews)
- Ads "every minute", pop-ups mid-song, full-screen ads.
- Paywalling basics (sleep timer, Android Auto).
- Converting lifetime purchases into subscriptions.
- Sharing user data with third parties.

---

## 6. Licensing risks once you monetise

- **TuneIn v Warner Music (UK Court of Appeal, 2021):** linking to **UK-licensed** stations was fine. Linking **for profit** (own ads, "one-stop shop") to **foreign stations not licensed in the UK** infringed copyright. The reasoning comes from EU case law on "communication to the public", so similar arguments can be made in EU courts.
- **Radio Garden:** blocked in **Turkey** (2022, licence-fee demand); **UK users limited to UK stations** (2022).
- **What this means for you:**
  - Bulgarian stations' own official streams, played to listeners in Bulgaria → **low risk**; those stations hold Bulgarian licences.
  - The **worldwide catalogue** and **Bulgarians abroad** (e.g. in the UK) → more exposure once the app carries ads. Options: don't show ads while foreign stations are playing, geo-limit the world catalogue where needed, or get legal advice before monetising.
  - Written OK from partner stations (§5.2) is the cleanest protection for the Bulgarian core.

---

## 7. Suggested changes to BRIEF.md (not applied, owner to decide)

1. Move **Android Auto** from v1.1 into v1.0 (the biggest BG differentiator after reliability).
2. Add **station contact buttons** (phone / Viber / SMS / e-mail for greetings) via new catalogue fields.
3. Add **"Popular in Bulgaria"** (Radio Browser click counts) and **custom stream URL**.
4. Add a **one-time Supporter purchase** to v1.0 or v1.1, and a **"B2B / station partnerships"** line to the monetisation section.
5. Add the **licensing note** (§6) to the monetisation constraints.

---

## Sources

**Bulgaria**
- RADIOPLAY on Google Play — https://play.google.com/store/apps/details?id=bg.radioplay.app
- RADIOPLAY MEDIA rebrand (24 Часа, Mar 2022) — https://www.24chasa.bg/index.php/ozhivlenie/article/11136080
- RADIOPLAY MEDIA audience claim (24 Часа, Sep 2024, advertorial) — https://www.24chasa.bg/ozhivlenie/article/18792704
- Radiomate (bTV) on Google Play — https://play.google.com/store/apps/details?id=bg.btvradio.radiomate
- БНР new app announcement (Dec 2025) — https://bnr.bg/about-us/post/394890/bnr-predstavi-iztsyalo-obnoveni-saytove-i-novo-mobilno-prilozhenie
- Радио Онлайн България (Radio Expert) — https://play.google.com/store/apps/details?id=net.radioexpert.radio.bulgaria
- Radio Bulgaria (APPMIND) — https://play.google.com/store/apps/details?id=radio.bulgaria.play.online.free
- Radio Bulgaria (RadioFMapp / Hertzify) — https://play.google.com/store/apps/details?id=com.radiofmapp.bulgaria
- Radio Bulgaria – Radio FM — https://play.google.com/store/apps/details?id=com.worldradios.bulgarie
- Radio Bulgaria – FM & Online (Creative Wolf) — https://play.google.com/store/apps/details?id=com.radiosonline.radiofmbulgaria
- Online Radio Box app page — https://onlineradiobox.com/bg/fresh/app/
- Ipsos 2014 radio study (Chr.bg) — https://chr.bg/zhivot/prouchvane-65-7-ot-b-lgarite-slushat-radio.html

**Worldwide**
- TuneIn tiers (Free / Pro / Premium) — https://help.tunein.com/en/support/solutions/articles/151000172607-what-is-the-difference-between-pro-premium-and-free-
- TuneIn Premium price — https://subger.com/en/us/service/tunein-premium
- TuneIn on Google Play — https://play.google.com/store/apps/details?id=tunein.player
- radio.net on Google Play — https://play.google.com/store/apps/details?id=de.radio.android
- radio.net Prime — https://radio.zendesk.com/hc/en-us/articles/360020924139-What-is-the-benefit-of-radio-net-Prime
- myTuner on Google Play — https://play.google.com/store/apps/details?id=com.appgeneration.itunerfree
- myTuner (Wikipedia) — https://en.wikipedia.org/wiki/MyTuner_Radio
- Replaio on Google Play — https://play.google.com/store/apps/details?id=com.hv.replaio
- Simple Radio Premium — https://help.streema.com/docs/what-is-the-difference-between-simple-radio-free-and-its-premium-version/
- Radio Garden (Wikipedia) — https://en.wikipedia.org/wiki/Radio_Garden
- Radioplayer (Wikipedia) — https://en.wikipedia.org/wiki/Radioplayer
- RadioDroid on F-Droid — https://f-droid.org/packages/net.programmierecke.radiodroid2/
- Transistor on F-Droid — https://f-droid.org/packages/org.y20k.transistor/
- Radio Tuner: Online AM FM — https://play.google.com/store/apps/details?id=com.radiotuner

**Monetisation & legal**
- RadioKing station-app pricing — https://www.radioking.com/pricing-mobile-app
- Apple Services Performance Partners (commissions) — https://performance-partners.apple.com/commissions-payments
- AdMob eCPM by country (indicative, third-party) — https://www.thesrzone.com/2024/01/admob-ecpm-rates-by-country.html
- AdMob EEA consent requirements — https://support.google.com/admob/answer/13554116
- TuneIn v Warner Music, Court of Appeal 2021 (RPC) — https://www.rpclegal.com/thinking/entertainment/court-of-appeal-upholds-copyright-infringement-decision-against-digital-radio-aggregator/
