---
gsd_state_version: "1.0"
milestone: v1.0
current_phase: 01
current_phase_name: Playback Engine & Walking Skeleton
status: executing
stopped_at: Completed 01-07-PLAN.md
last_updated: "2026-09-25T16:26:45.056Z"
last_activity: 2026-09-25
last_activity_desc: Completed 01-07 localised notification state text, icon, channel name and first-launch date
state_head: 1085ccf33e99440eec1e0546c12accedfd482ac0
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 13
  completed_plans: 6
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-24)

**Core value:** Tap the app → hear the last Bulgarian station within ~3 seconds, and playback never stops on its own (screen off, background, network switches, short signal loss).
**Current focus:** Phase 01 — Playback Engine & Walking Skeleton

## Current Position

Phase: 01 (Playback Engine & Walking Skeleton) — EXECUTING
Plan: 6 of 13 complete (01-01, 01-03, 01-04, 01-05, 01-06, 01-07); 01-02 (Wave 2) still open, waiting on the owner's keystore
Status: Ready to execute
Last activity: 2026-09-25 — Completed 01-07 localised notification state text, icon, channel name and first-launch date

Progress: [█████░░░░░] 46% (6/13 plans in Phase 01)

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: -
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*

**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 01 P01 | 2h 3m | 1 tasks | 53 files |
| Phase 01 P03 | 11 min | 2 tasks | 13 files |
| Phase 01 P04 | 13 min | 2 tasks | 14 files |
| Phase 01 P06 | 6 min | 2 tasks | 8 files |
| Phase 01 P05 | 6 min | 2 tasks | 7 files |
| Phase 01 P07 | 8 min | 2 tasks | 13 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Risk-first order, engine → catalogue → listening experience → hardening + release (coarse granularity, 4 phases)
- [Roadmap]: The brief's "store release" phase is folded into Phase 4, because the Play closed track needs the privacy policy, Data safety, content rating, listing and FGS declaration on day one of Phase 4
- [Roadmap]: Fallback-stream rotation lives in the Phase 1 state machine (not in hardening); user-facing error UX (PLAY-09) is in Phase 4
- [Roadmap]: Next/prev (PLAY-04) is user-complete in Phase 3 (needs favourites order); the engine API for it is shaped in Phase 1
- [Phase 01]: [01-01]: android/app/src/main/res/raw/keep.xml keeps @drawable/audio_service_* in release builds; never remove it (audio_service resolves icons by name, shrinking strips them, the Android 13+ Stop CustomAction then throws and the FGS never starts)
- [Phase 01]: [01-01]: Every release-only behaviour (shrinking, manifest, FGS, cleartext) must be verified on a physical device in a release build; unit tests and debug builds cannot catch it
- [Phase 01]: [01-01]: RadioAudioHandler keeps an in-memory last station: play() from Idle restarts it live and getChildren(recentRootId) returns it, so the Android media card resumes after Stop; persisted last-station comes later
- [Phase 01]: [01-01]: bootstrap.dart logs AudioService.asyncError, which audio_service otherwise swallows
- [Phase 01]: [01-01]: Completed while Playing/Buffering maps to PlaybackError(streamUnreachable) so no FGS runs without audio, until 01-09 adds reconnect
- [Phase 01]: [01-03]: The mini-player's play/pause shows Pause in every state where AudioEngine.togglePause pauses (Connecting/Playing/Buffering/Reconnecting/Interrupted), matching the notification; Play only in Paused and Error
- [Phase 01]: [01-03]: resolveAppLocale(Locale?) in lib/app/app.dart is the single locale rule (bg -> bg, else en); 01-07 builds notification strings with lookupAppLocalizations(resolveAppLocale(...)); all Phase 1 ARB keys exist, so later plans should not edit the ARB files
- [Phase 01]: [01-03]: Widget tests use FakeEngine and pump twice after an engine publish; ConsumerWidgets that return early watch all providers first
- [Phase 01]: [01-04]: Every catalogue stream goes through StreamResolver before StreamPlayer.load; progressive/hls skip the network, pls/m3u/unknown are fetched once with hard limits (5 s per resolution, 64 KB, 5 redirects, depth 3, 10 candidates, http/https only) and cached 1 h; invalidate() on every playback failure
- [Phase 01]: [01-04]: Both Dart clients follow redirects by hand (followRedirects=false) so every hop is scheme-checked and the hop cap is deterministic; MockClient cannot report final URLs or enforce maxRedirects
- [Phase 01]: [01-04]: MediaHttpClient is the only Dart client allowed to fetch http:// (media playlists); Phase 2 catalogue and Radio Browser traffic must use the HTTPS-only AppHttpClient; T-04-06 (block loopback/private playlist entries) is due in Phase 2
- [Phase 01]: [01-06]: parseIcyTitle runs repairCp1251 BEFORE sanitizeIcyText (reverse of RESEARCH Pattern 5) so cp1251 punctuation („ “ –, arriving as U+0080-U+009F) survives; 01-08 passes the playing stream's icyCharset and republishes only when the NowPlaying value changes
- [Phase 01]: [01-06]: sanitizeIcyText turns tab/LF/VT/FF/CR into spaces before collapsing and strips all other C0/DEL/C1 and bidi U+202A-202E/U+2066-2069; clamp is 200 code points by runes; a dangling ' - ' separator yields a title-only NowPlaying
- [Phase 01]: [01-05]: Phase 1 ships 5 owner-verified stations (БНР Хоризонт, Радио 1, БГ Радио, Радио Енерджи, N-JOY), verified 2026-09-25. Радио Витоша is excluded (no official stream, option-c). No unofficial substitute is used (D-03).
- [Phase 01]: [01-05]: N-JOY ships one stream, https://cdn.btv.bg/radio/njoy.mp3 (bTV's own CDN, verified by the owner 2026-09-25). The live.btvradio.bg .m3u and MP3 endpoints are REJECTED.
- [Phase 01]: [01-05]: БНР Хоризонт is HLS-only (lb-hls.cdn.bg, then e106-ts.cdn.bg, both from bnr.bg's player). The port-8011 AAC/MP3 mounts were REJECTED.
- [Phase 01]: [01-05]: No release station uses a .pls/.m3u wrapper or a cp1251 charset. Wrapper coverage (STRM-03) comes from the 01-04 resolver tests, and cp1251 from the 01-06 goldens. Non-.m3u8 HLS is covered by the debug-only "ТЕСТ: Хоризонт (HLS sniff)" entry (kind unknown).
- [Phase 01]: [01-05]: StationDirectory.phase1 appends debugStations only when `!kReleaseMode && includeDebug` (const-false in release). Only station_directory.dart may import debug_stations.dart.
- [Phase 01]: [01-07]: Engine-side text comes from EngineStrings (built in bootstrap via lookupAppLocalizations(resolveAppLocale(PlatformDispatcher.instance.locale))); mediaItemFor puts the D-09 state text in displaySubtitle and artist, the title is always the station name; 01-08 puts ICY text there while Playing
- [Phase 01]: [01-07]: RadioAudioHandler._setStatus publishes the media item (before PlaybackState) only when sameMediaItem says it changed; MediaItem == compares only the id, so never dedupe with ==
- [Phase 01]: [01-07]: ic_stat_radio (notification small icon, Material Symbols radio, Apache-2.0) is in res/raw/keep.xml; any new drawable audio_service looks up by name must be added there too
- [Phase 01]: [01-07]: audio_service creates the notification channel only once, so its name is fixed by the device language at first run; the owner must reinstall before checking 'Възпроизвеждане'
- [Phase 01]: [01-07]: first_launch_at is written once in UTC ISO-8601 via SharedPreferencesAsync before AudioService.init; an unreadable value reads as null so startup never fails; firstLaunchAtProvider is overridden in bootstrap

### Pending Todos

None yet.

### Blockers/Concerns

- ~~[Before Phase 1]: package ID + app name~~ — resolved 2026-09-25: `bg.izk.radio`, "eRadioto"
- [Before Phase 4]: Owner must decide personal account vs Идев ЕООД (D-U-N-S takes weeks) and crash reporting (none / Sentry)
- [Phase 1]: Needs physical-device verification (Xiaomi + Samsung, Android 15/16/17): 60 min screen-off, Wi-Fi→4G recovery ≤ ~10 s, resume after call, Wi-Fi lock, POST_NOTIFICATIONS-denied controls
- [Phase 1]: Record the unlisted FGS demo video as soon as background playback works (needed for the Play declaration in Phase 4)
- [Phase 1 → 2, owner decision 2026-09-25]: The station lineup has gaps.
  - Радио Витоша has no official stream (excluded, option-c). Re-add it only with a verified official URL.
  - N-JOY has a single stream (cdn.btv.bg), so it has no fallback.
  - No release station uses a .pls/.m3u wrapper; `http://play.global.audio/bgradio128.m3u` is an unverified candidate.
  - No stream is proven cp1251, because the byte probe was not run.
  - Display order to confirm: the owner's N-JOY message listed Хоризонт last, but the plan's order (Хоризонт first) was kept.
- [Phase 2]: Owner hand-curation of stream URLs and native-speaker review of the шльокавица table and search golden tests run alongside development

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-09-25T16:26:44.986Z
Stopped at: Completed 01-07-PLAN.md
Resume file: None
