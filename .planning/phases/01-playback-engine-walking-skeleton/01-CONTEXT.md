# Phase 1: Playback Engine & Walking Skeleton - Context

**Gathered:** 2026-09-25
**Status:** Ready for planning

<domain>
## Phase Boundary

A runnable `bg.izk.radio` ("eRadioto") Flutter app. On a physical Android phone, in a release build, it plays a small hard-coded set of Bulgarian stations. Playback keeps going without the user's help through screen-off, background, calls, headset/Bluetooth changes, network switches and dead primary streams. The phase includes:

- the full `AudioEngine` facade, the state machine, reconnect/fallback, the `.pls`/`.m3u`/HLS resolver and ICY/cp1251 now-playing
- media notification, lock-screen and headset/car-Bluetooth controls
- gen-l10n scaffolding and the write-once first-launch date
- CI (analyze + test on every PR) and a signed AAB/APK on tags

Out of scope: the catalogue, search, browse screens, favourites, the now-playing screen, the sleep timer, friendly error UX, a settings screen and Android Auto.

Requirements: PLAY-01, 02, 03, 05, 06, 07, 08, 10, 11 · STRM-01..05 · APP-06, APP-07 · PLAT-01, 03, 04, 06.

</domain>

<decisions>
## Implementation Decisions

### Test station lineup
- **D-01:** The hard-coded set is **6 stations**: **Radio 1** and **BG Radio** (owner must-haves), **Радио Витоша**, **N-JOY**, **Energy** (owner's likely picks) and **БНР Хоризонт** (added as the flagship / core-value station).
- **D-02:** Stations and URLs are a mix. The owner named the stations, and the phase researcher finds each one's **official, publicly offered** stream endpoints. The owner confirms the URLs play and are official before execution relies on them.
- **D-03:** Format coverage comes from **the alternate endpoints these same stations publish**, not from extra stations. Across `Station.streams[]` the set must cover: MP3, AAC/HE-AAC, HLS (including HLS behind a non-`.m3u8` URL), a `.pls` or `.m3u` wrapper, a plain `http://` stream, and a windows-1251 ICY title. БНР Хоризонт is the expected HLS source. If research finds that a format is **not obtainable** from these 6 stations, flag it to the owner. Do not silently swap stations.
- **D-04:** Each station carries its real alternate streams as ordered `streams[]` (primary + fallbacks), so PLAY-08 rotation runs on real data.
- **D-05:** Add a **debug-only "dead primary" test station**: its first stream is a deliberately unreachable URL and its fallback is a real stream. It exists only in debug/profile builds and **must never ship in the release station list**.

### Skeleton screen
- **D-06:** The main screen is a **simple list of the 6 stations** (name + generic icon) with a **bottom mini-player**. The mini-player shows the station name, the now-playing text, play/pause and stop, and a state label. There's no design polish, because Phase 2/3 replace this UI. It still needs TalkBack labels and adequate touch targets.
- **D-07:** Add a **debug panel in debug/profile builds only**, hidden in release. It shows the current state-machine state, the stream URL/format in use and its index in `streams[]`, time-to-audio for the last start, the reconnect attempt / backoff delay, and a short recent-event log.
- **D-08:** **gen-l10n from day one with BG + EN ARB files** (`synthetic-package: false`, output in `lib/`). Bulgarian is the default on a `bg` device and English otherwise. The owner does the proper BG copy review in Phase 3, so Phase 1 strings are placeholders.
- **D-09:** When the player isn't simply playing, the mini-player shows a **short text state label**: "Свързване…" (connecting), "Буфериране…" (buffering), "Повторно свързване…" (reconnecting), "Грешка" (error). The friendly error UX (PLAY-09) comes in Phase 4.

### Give-up & resume rules
- **D-10:** Reconnect give-up is a **configurable `RetryBudget` policy inside the engine**, with three named presets:
  - `standard` (default): **3 min of failing while online / 10 min while offline**
  - `trip`: longer, around 5 min online / 30 min offline
  - `batterySaver`: shorter, around 1 min online / 5 min offline

  Phase 1 wires up only `standard`. Choosing the preset must be a single engine-level setting, so a future UI toggle needs no engine refactor. Research/planning may tune the exact trip/saver numbers. When the budget runs out, the app goes to Error: it releases focus, stops the FGS, and the notification shows the error with a play button.
- **D-11:** After a phone call (transient focus loss), **always auto-resume if the radio was playing**, no matter how long the call lasted. It resumes at the live edge. It never resumes if the user had paused or stopped (PLAY-10).
- **D-12:** The media notification and lock screen show **Play/Pause + Stop**. Pause keeps the media session and notification, and resume reloads at the live edge. Stop ends the session, removes the notification and stops the service. Leave room in the action layout for next/prev, which Phase 3 adds (PLAY-04).
- **D-13:** On pause: **drop the foreground service** (`androidStopForegroundOnPause: true`), **keep the notification**, which the user can swipe away. No wake-locks or Wi-Fi lock while paused. There is no auto-stop timer.

### CI, signing & device testing
- **D-14:** The owner has **no upload keystore yet**. The plan includes a **human checkpoint** with step-by-step instructions: create the upload keystore locally with `keytool`, back it up outside the repo, and add it to GitHub Actions secrets (base64 keystore, store/key passwords, alias). CI decodes it at build time. `.gitignore` must block `*.jks`, `*.keystore` and `key.properties`. Nothing secret is ever committed.
- **D-15:** Build delivery:
  - Tags and a manual `workflow_dispatch` build a **signed release AAB plus a signed release APK** and upload them as CI artifacts, so the owner can sideload the APK.
  - Every PR runs `flutter analyze` + `flutter test`.
  - The owner also iterates locally with `flutter run --release` / `--profile`.
- **D-16:** Physical test devices the owner has:
  - **a Xiaomi/Redmi/POCO**
  - **a Samsung Galaxy**
  - **a car with a Bluetooth head unit**
  - **a car with Android Auto**

  The owner has **no Android 7–9 device**, so the minSdk 24 install/launch check runs on an **API 24 emulator**. Background audio is verified only on the physical phones. Car testing in Phase 1 uses **plain Bluetooth**; if the Android Auto car is used, do it with projection disabled.
- **D-17:** **Commit generated code** (`*.g.dart`, `*.freezed.dart`, drift output). CI runs `build_runner build` and fails on `git diff --exit-code`, which catches stale generated files.

### Claude's Discretion
- Exact trip/batterySaver budget numbers, the backoff schedule, and the stall-watchdog and connect timeouts (start from `.planning/research/ARCHITECTURE.md` Pattern 3/4 and tune on device).
- The placeholder app icon and the skeleton's visual styling (Material 3 defaults are fine).
- Debug panel layout and log length.
- Whether the Phase 1 workflow also uploads a debug APK on PRs.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope & requirements
- `.planning/PROJECT.md` — core value, constraints (licensing, privacy, battery, accessibility, public repo), key decisions (package ID, app name)
- `.planning/REQUIREMENTS.md` — PLAY-*, STRM-*, APP-06/07, PLAT-01/03/04/06 wording
- `.planning/ROADMAP.md` §"Phase 1" — goal, 5 success criteria, notes (FGS demo video, split option)
- `docs/BRIEF.md` — original owner brief

### Stack & architecture (research, already decided)
- `.claude/CLAUDE.md` / `.planning/research/STACK.md` — pinned versions (Flutter 3.47.5, just_audio 0.10.6, audio_service 0.18.19, audio_session 0.2.4, Riverpod 3, etc.), `useProxyForRequestHeaders: false`, explicit `HlsAudioSource`/`ProgressiveAudioSource`, cleartext scoping, SDK 24/36, CI action versions
- `.planning/research/ARCHITECTURE.md` — composition root (Pattern 1), facade + `StreamPlayer` port (2), **state machine table (3)**, reconnect/watchdog (4), live-edge reload (5), StreamResolver (6), ICY flow (7), Phase 1 build-order row, anti-patterns
- `.planning/research/PITFALLS.md` — Pitfalls 1–7 (FGS lifecycle, live-vs-file, silent stalls, Wi-Fi starvation/OEM killers, cleartext, cp1251/stale titles, playlist resolution), 13 (secret leakage), 14 (audio_service mistakes)
- `.planning/research/SUMMARY.md` — consolidated research verdicts and gaps
- `.planning/research/FEATURES.md` — competitor/feature expectations (reference)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None. The repo is greenfield: only `docs/BRIEF.md`, `.gitignore` and planning files exist. Phase 1 runs `flutter create --org bg.izk --project-name radio` (or equivalent) to produce the package `bg.izk.radio`.

### Established Patterns
- None in code yet. The conventions come from research: a feature-first layout per `ARCHITECTURE.md` §"Recommended Project Structure", Riverpod 3 with codegen, `flutter_lints` + `riverpod_lint` under `plugins:`, and conventional commits.

### Integration Points
- The `AudioEngine` facade is the seam that every later phase (catalogue, library, UI, and Android Auto in v1.1) plugs into. The media-ID scheme and the `PlayContext`/next-prev API must be shaped now (ROADMAP notes), even though only the phone list uses them.

</code_context>

<specifics>
## Specific Ideas

- The owner wants the app to feel "radio-like": pause/resume always returns to live audio, and a long phone call must not lose the radio.
- The owner wants user-selectable **reconnect modes** in the future: "trip mode" (retries longer on drives with dead zones) and "battery saver" (gives up sooner). The engine must be ready for this (D-10).
- Record the **unlisted FGS demo video** as soon as background playback works (Play declaration in Phase 4).

</specifics>

<deferred>
## Deferred Ideas

- **User-facing Trip mode / Battery saver toggle** for the reconnect budget. This is a new UI capability needing a settings surface → Phase 3 (listening experience) or the v1.1 backlog. The engine presets land in Phase 1 (D-10).
- **Android Auto testing on the owner's Android Auto car** → v1.1 (Android Auto is out of v1 scope). The car is noted as the v1.1 test rig.

</deferred>

---

*Phase: 01-playback-engine-walking-skeleton*
*Context gathered: 2026-09-25*
