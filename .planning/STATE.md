---
gsd_state_version: "1.0"
milestone: v1.0
current_phase: 01
current_phase_name: Playback Engine & Walking Skeleton
status: executing
stopped_at: Completed 01-03-PLAN.md
last_updated: "2026-09-25T14:57:29.863Z"
last_activity: 2026-09-25
last_activity_desc: Completed 01-03 BG/EN localisation and accessible mini-player
state_head: 09d767728ee9fe04f2f5e62f2f4f576d8f7dd3ec
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 13
  completed_plans: 2
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-09-24)

**Core value:** Tap the app → hear the last Bulgarian station within ~3 seconds, and playback never stops on its own (screen off, background, network switches, short signal loss).
**Current focus:** Phase 01 — Playback Engine & Walking Skeleton

## Current Position

Phase: 01 (Playback Engine & Walking Skeleton) — EXECUTING
Plan: 2 of 13 complete (01-01, 01-03); 01-02 and the rest of Wave 2 still open
Status: Ready to execute
Last activity: 2026-09-25 — Completed 01-03 BG/EN localisation and accessible mini-player

Progress: [██░░░░░░░░] 15% (2/13 plans in Phase 01)

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

### Pending Todos

None yet.

### Blockers/Concerns

- ~~[Before Phase 1]: package ID + app name~~ — resolved 2026-09-25: `bg.izk.radio`, "eRadioto"
- [Before Phase 4]: Owner must decide personal account vs Идев ЕООД (D-U-N-S takes weeks) and crash reporting (none / Sentry)
- [Phase 1]: Needs physical-device verification (Xiaomi + Samsung, Android 15/16/17): 60 min screen-off, Wi-Fi→4G recovery ≤ ~10 s, resume after call, Wi-Fi lock, POST_NOTIFICATIONS-denied controls
- [Phase 1]: Record the unlisted FGS demo video as soon as background playback works (needed for the Play declaration in Phase 4)
- [Phase 2]: Owner hand-curation of stream URLs and native-speaker review of the шльокавица table and search golden tests run alongside development

## Deferred Items

Items acknowledged and deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| *(none)* | | | | |

## Session Continuity

Last session: 2026-09-25T14:57:15.025Z
Stopped at: Completed 01-03-PLAN.md
Resume file: None
