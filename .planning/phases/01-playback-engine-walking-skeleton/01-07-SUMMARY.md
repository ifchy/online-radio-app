---
phase: 01-playback-engine-walking-skeleton
plan: 07
subsystem: playback
tags: [flutter, audio_service, media-session, notification, gen-l10n, shared_preferences, riverpod, fgs, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "playbackStateFor (the FGS table), mediaItemFor, RadioAudioHandler with _lastStation resume, bootstrap composition root, MediaId scheme, res/raw/keep.xml"
  - phase: 01-playback-engine-walking-skeleton (plan 03)
    provides: "resolveAppLocale, lookupAppLocalizations with the state* keys and notificationChannelName"
  - phase: 01-playback-engine-walking-skeleton (plan 04)
    provides: "RadioAudioHandler's StreamResolver constructor and the shared handler test file"
provides:
  - "EngineStrings (plain value object, fromLocalizations) for notification text below the UI"
  - "mediaItemFor(Station, PlaybackStatus, EngineStrings): station name as title, D-09 state text as displaySubtitle/artist"
  - "sameMediaItem(a, b): field-wise MediaItem comparison (MediaItem == compares only the id)"
  - "RadioAudioHandler republishes the media item from every status change, only when it differs"
  - "android/app/src/main/res/drawable/ic_stat_radio.xml notification small icon, kept in release by keep.xml"
  - "AudioServiceConfig with the localised channel name and androidNotificationIcon 'drawable/ic_stat_radio'"
  - "SettingsRepository (SharedPreferencesAsync + Clock): ensureFirstLaunchAt / firstLaunchAt, key first_launch_at"
  - "firstLaunchAtProvider (keepAlive, overridden in bootstrap)"
  - "media_session_mapping_test.dart, media_id_test.dart, settings_repository_test.dart"
affects: [01-08, 01-09, 01-11, phase-3-next-prev, v1.1-android-auto]

# Actuals (#2632)
actuals:
  tokens: 9669
  tasks: 2
  commits: 4
plan_head_before: fff0740d697f98ece476543606ce87068de52264

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Engine-side text comes from EngineStrings, built in bootstrap with lookupAppLocalizations(resolveAppLocale(PlatformDispatcher.instance.locale)); no BuildContext below presentation"
    - "_setStatus publishes the media item first, then PlaybackState, so the notification never shows a new state under an old subtitle"
    - "Media items are compared field by field (sameMediaItem) before republishing; MediaItem == is id-only"
    - "Every drawable audio_service looks up by name goes into res/raw/keep.xml's tools:keep list"
    - "Settings go through SharedPreferencesAsync; tests use InMemorySharedPreferencesAsync.empty()"

key-files:
  created:
    - lib/features/playback/domain/engine_strings.dart
    - lib/core/settings/settings_repository.dart
    - lib/core/settings/settings_repository.g.dart
    - android/app/src/main/res/drawable/ic_stat_radio.xml
    - test/features/playback/engine/media_session_mapping_test.dart
    - test/features/playback/domain/media_id_test.dart
    - test/core/settings/settings_repository_test.dart
  modified:
    - lib/features/playback/engine/media_session_mapping.dart
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/app/bootstrap.dart
    - android/app/src/main/res/raw/keep.xml
    - test/features/playback/engine/radio_audio_handler_test.dart
    - test/app/tracer_e2e_test.dart

key-decisions:
  - "The notification subtitle goes in both displaySubtitle and artist, so the notification and the lock screen show it whichever field the Android version reads. 01-08 puts the ICY text in the same place while Playing."
  - "Republishing is deduplicated with a field-wise sameMediaItem, because audio_service's MediaItem == compares only the id and would treat 'Connecting…' and 'Paused' as equal."
  - "ic_stat_radio is added to res/raw/keep.xml. audio_service resolves androidNotificationIcon by name, so release resource shrinking would strip it, as it did audio_service_* in 01-01."
  - "audio_service creates the notification channel only if it does not already exist. The channel name is therefore fixed by the device language on the first run after install, and phones that already ran a 01-01..01-06 build keep 'Playback' until the app is reinstalled or its data is cleared."
  - "An unreadable first_launch_at value reads as null and is replaced on the next ensureFirstLaunchAt, so a corrupt preference can never make bootstrap fail on every launch."

patterns-established:
  - "EngineStrings for any engine-side user-facing text (for example 01-09's reconnect text and Phase 4's error text)"
  - "Write-once preference: read, return if present, otherwise write the UTC ISO-8601 clock time"

requirements-completed: [PLAY-02, APP-06, APP-07, PLAY-01]

coverage:
  - id: D1
    description: "FGS table for all 8 PlaybackStatus variants: processingState, playing, control order (pause/play then stop), compact indices [0, 1] when controls exist, empty systemActions; Idle has no controls; Paused, PlaybackError and Idle report not-playing (no FGS); PlaybackError carries kind.name"
    requirement: APP-07
    verification:
      - kind: unit
        ref: "test/features/playback/engine/media_session_mapping_test.dart#playbackStateFor (the FGS table) (11 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "mediaItemFor with Bulgarian EngineStrings: the title is always the station name; subtitle/artist are Свързване…, Буфериране…, Повторно свързване…, Прекъснато, На пауза or Грешка for the six non-playing states, and none for Playing and Idle; the id is the station media ID; isLive is true; English strings on an English phone; channel name Възпроизвеждане / Playback"
    requirement: PLAY-02
    verification:
      - kind: unit
        ref: "test/features/playback/engine/media_session_mapping_test.dart#mediaItemFor (10 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The handler republishes the media item only when it changes: Playing -> Buffering -> Playing publishes three items and a repeated Playing snapshot publishes none; Pause shows 'Paused' and an error shows 'Error' under the station name; Stop clears the item; the recent root offers the last station with no subtitle"
    requirement: PLAY-02
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart#media item republishing (3 tests)"
        status: pass
      - kind: integration
        ref: "test/app/tracer_e2e_test.dart (all 8 steps, incl. _lastStation resume)"
        status: pass
    human_judgment: false
  - id: D4
    description: "MediaId: all 7 scheme forms round-trip through parse and format; 12 malformed ids ('', 'station/', 'station/xx:bg-radio', 'node/', 'node/unknown', 'foo/bar' and 6 more) throw FormatException"
    verification:
      - kind: unit
        ref: "test/features/playback/domain/media_id_test.dart (20 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "First-launch date (APP-06): the first call stores the clock's UTC time as ISO-8601 under first_launch_at; a later launch returns the original and leaves the string unchanged; local time is stored as UTC; an unreadable value reads as null and is replaced; firstLaunchAtProvider must be overridden; bootstrap awaits ensureFirstLaunchAt before AudioService.init; no legacy SharedPreferences singleton in lib/"
    requirement: APP-06
    verification:
      - kind: unit
        ref: "test/core/settings/settings_repository_test.dart (6 tests)"
        status: pass
      - kind: other
        ref: "plan 01-07 Task 2 grep/awk gate (key, SharedPreferencesAsync, no getInstance, ensureFirstLaunchAt before AudioService.init)"
        status: pass
    human_judgment: false
  - id: D6
    description: "On a phone set to Bulgarian: the notification and lock screen show the station name with 'Свързване…' while connecting and 'На пауза' while paused; the status bar shows a white radio icon, not a square, in a RELEASE build; the channel is listed as 'Възпроизвеждане' (after a fresh install)"
    requirement: PLAY-02
    verification: []
    human_judgment: true
    rationale: "The notification shade, lock screen, status-bar icon rendering, release resource shrinking and system channel settings exist only on a device (the plan's <human-check>). There is no Android SDK in the execution environment."

# Metrics
duration: 8min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 07: The notification speaks the listener's language, and the first launch is remembered Summary

**The media notification and lock screen now show the station name with the same localised state text as the mini-player (Свързване…, Буфериране…, Повторно свързване…, Прекъснато, На пауза, Грешка). The text comes from an `EngineStrings` value built in bootstrap without a `BuildContext`. The notification has a monochrome Material Symbols radio icon (kept in release builds) and a localised channel name. The item is republished only when it actually changes. The first-launch date is written once, in UTC, through `SharedPreferencesAsync`. The full FGS table and the media-ID scheme are locked by unit tests.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-25T16:17:06Z
- **Completed:** 2026-09-25T16:25:19Z
- **Tasks:** 2 of 2, both TDD (RED then GREEN; no refactor needed)
- **Files modified:** 13 (7 created, 6 modified)

## Accomplishments

- **PLAY-02 (D-09):** `mediaItemFor(station, status, strings)` keeps the station name as the title and puts the state text in `displaySubtitle` and `artist` for Connecting, Buffering, Reconnecting, Interrupted, Paused and PlaybackError. Playing and Idle have no subtitle; 01-08 adds the ICY text there.
- **Republish only on change (Anti-Pattern 9, T-07-03):** `RadioAudioHandler._setStatus` maps each status to its media item and sends it only when `sameMediaItem` says it differs. The item goes out before the `PlaybackState`, so the Connecting item is still published before the load (Pitfall G). `stop()` still clears the item.
- **Icon and channel:** `ic_stat_radio.xml` is a 24 dp flat-white vector of the Material Symbols "radio" glyph (Outlined, fetched from google/material-design-icons, Apache-2.0). `AudioServiceConfig` uses it as `androidNotificationIcon` and takes `androidNotificationChannelName` from `EngineStrings` ("Възпроизвеждане" / "Playback"). The channel id `bg.izk.radio.playback` and all other config values are unchanged.
- **APP-07 / PLAY-01 battery rule (T-07-01):** every one of the 8 FGS rows is unit-tested for processingState, playing, control order, compact indices `[0, 1]` and empty `systemActions`. Paused, PlaybackError and Idle report `playing: false`, and Idle has no controls.
- **Media IDs:** all 7 forms from RESEARCH Pattern 6 round-trip, and 12 malformed ids throw `FormatException`.
- **APP-06:** `SettingsRepository.ensureFirstLaunchAt()` follows RESEARCH lines 751-758 (key `first_launch_at`, UTC ISO-8601, write-once). Bootstrap now runs prefs → first launch → session → `AudioService.init` → container and overrides `firstLaunchAtProvider` for the 01-11 debug panel.
- **Tests:** the full suite has 242 tests (up from 192), and all pass. `flutter analyze` and `dart analyze` report no issues, and `build_runner build` leaves no diff. No test touches the network.
- **Left untouched, as required:** `RadioAudioHandler`'s `_lastStation` resume (tracer step 8 passes, and `getChildren(recentRootId)` now calls `mediaItemFor(last, Idle, strings)`), the `AudioService.asyncError` logging, and the existing `audio_service_*` entry in `keep.xml`, which only gains `ic_stat_radio`.

## Task Commits

1. **Task 1: The notification and lock screen show the localised state under the station name, with the eRadioto icon.** RED `49d5e16` (test), GREEN `d9886c2` (feat)
2. **Task 2: The first-launch date is recorded on the very first run and never overwritten.** RED `0f1c3ce` (test), GREEN `f8d0859` (feat)

**Plan metadata:** see the `docs(01-07): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `49d5e16`: 9 of 50 failed, all on assertions (subtitle `null` instead of the state text; no republish on status change) | `d9886c2` | not needed | `check tdd-red-evidence` returned RED_EVIDENCE_OK for 4 targets: the Connecting and Paused Bulgarian subtitles, the republish-only-on-change case and the Error subtitle |
| 2 | `0f1c3ce`: 4 of 4 failed, all on assertions (the stub returned year 0 or null) | `f8d0859` | not needed | RED_EVIDENCE_OK for 3 targets: first write, no overwrite, and null before the first run |

In Task 1's RED run, 41 tests passed. These are characterisation tests of behaviour that already existed, as the plan intends:
- the 11 FGS-table cases (01-01's `playbackStateFor`; the plan says it is unchanged)
- the 20 media-ID cases (01-01's `MediaId`)
- the Playing and Idle "no subtitle" cases and the channel-name case (01-03's ARB)
- the 5 existing resolver/handler cases, the stop/recent-root case and the tracer

As in 01-03 to 01-06, each RED run used `flutter test --reporter json`, converted into TAP for the checker. The RED commits contain only compile scaffolding:
- Task 1: `EngineStrings`, the new `mediaItemFor` signature ignoring status and strings, and the handler parameter with its bootstrap wiring.
- Task 2: a `SettingsRepository` stub with a temporary `ignore_for_file: unused_field`, which GREEN removed.

## Files Created/Modified

- `lib/features/playback/domain/engine_strings.dart`: `EngineStrings` and `EngineStrings.fromLocalizations`.
- `lib/features/playback/engine/media_session_mapping.dart`: the subtitle mapping and `sameMediaItem`. `playbackStateFor` is unchanged.
- `lib/features/playback/engine/radio_audio_handler.dart`: the `EngineStrings` parameter, plus `_setStatus`, which now publishes the deduplicated item.
- `lib/app/bootstrap.dart`: the first-launch step, `EngineStrings` from the platform locale, the localised channel name, the notification icon and the `firstLaunchAtProvider` override.
- `android/app/src/main/res/drawable/ic_stat_radio.xml`: the notification small icon.
- `android/app/src/main/res/raw/keep.xml`: `tools:keep` now also lists `@drawable/ic_stat_radio`.
- `lib/core/settings/settings_repository.dart` and `.g.dart`: `SettingsRepository` and `firstLaunchAtProvider`.
- Tests: `media_session_mapping_test.dart` (180 lines), `media_id_test.dart` (64 lines), `settings_repository_test.dart`. `radio_audio_handler_test.dart` gains the republishing group, and `tracer_e2e_test.dart` uses English `EngineStrings`.

## Decisions Made

See `key-decisions` in the frontmatter. The two with consequences outside the code:
- **Channel name on existing installs:** audio_service creates the notification channel only when it does not exist yet (`AudioService.java` `createChannel`, line 689-696). Android then keeps the name from the first run. On the owner's phone, which already has builds from 01-01 to 01-06, the channel stays "Playback" until the app is uninstalled or its data is cleared. Reinstall before the device check.
- **Icon in release builds:** without the `keep.xml` entry, release resource shrinking would strip `ic_stat_radio`. Only a release build on a device proves that it survives.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] The notification icon is kept in release builds**
- **Found during:** Task 1 (GREEN)
- **Issue:** audio_service resolves `androidNotificationIcon` by name at runtime, so release resource shrinking cannot see the reference and strips the drawable. 01-01's owner check found exactly this failure for `audio_service_*`. `keep.xml` is not in the plan's file list.
- **Fix:** Added `@drawable/ic_stat_radio` to `tools:keep` in `android/app/src/main/res/raw/keep.xml`, and documented it in the drawable's and the file's comments.
- **Files modified:** android/app/src/main/res/raw/keep.xml
- **Verification:** device-only (release build). There is no Android SDK here.
- **Committed in:** d9886c2

**2. [Rule 1 - Bug] Field-wise media-item comparison for "only when it differs"**
- **Found during:** Task 1 (GREEN)
- **Issue:** audio_service's `MediaItem ==` compares only `id`. Deduplicating with `==` would therefore never republish a subtitle change, for example from "Connecting…" to "Paused".
- **Fix:** `sameMediaItem` compares every field the notification shows: id, title, artist, album, the display fields, artUri, isLive and extras.
- **Files modified:** lib/features/playback/engine/media_session_mapping.dart
- **Verification:** the republishing tests pass (three items for Playing → Buffering → Playing, none for a repeat).
- **Committed in:** d9886c2

**3. [Rule 2 - Missing Critical] A corrupt first_launch_at cannot crash startup**
- **Found during:** Task 2 (GREEN)
- **Issue:** Bootstrap awaits `ensureFirstLaunchAt` before anything else. The plan's RESEARCH snippet uses `DateTime.parse`, so a corrupt stored value would throw on every launch and the app would never start.
- **Fix:** `firstLaunchAt()` uses `DateTime.tryParse(...)?.toUtc()`. An unreadable value reads as null, and the next `ensureFirstLaunchAt` replaces it. Readable values are still never overwritten.
- **Files modified:** lib/core/settings/settings_repository.dart, test/core/settings/settings_repository_test.dart
- **Verification:** the test "an unreadable stored value never breaks startup" passes.
- **Committed in:** f8d0859

**4. [Note] Additions beyond the plan's behaviour list**
- The handler tests also cover the Error subtitle, Stop clearing the item, and the recent root's item without a subtitle.
- The settings tests also cover local-time → UTC and the `firstLaunchAtProvider` override.
- The media-ID tests reject 6 more malformed forms than the plan lists.
- **Committed in:** 49d5e16, 0f1c3ce, f8d0859

---

**Total deviations:** 3 auto-fixed (2 Rule 2 missing-critical, 1 Rule 1 bug) plus 1 note.
**Impact on plan:** All three serve the plan's own truths: the icon must actually render in release, the republishing must actually happen, and the first launch must never block startup. There is no scope creep.

## Issues Encountered

- `dart format` on whole directories also reformats four files from 01-06 that this plan does not touch. Those changes were reverted and logged in `deferred-items.md`.

## Known Stubs

None. Playing has no subtitle by design; 01-08 adds the ICY now-playing text there.

## Threat Flags

None beyond the plan's threat model. T-07-01 (battery) and T-07-03 (notification spam) are mitigated and unit-tested. T-07-02 is accepted: only a local timestamp is stored, and it is never sent anywhere.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- 01-08 (now playing) can extend `mediaItemFor` to put the ICY text in the subtitle while Playing. `_setStatus`/`_publishMediaItem` already deduplicate, so republishing only on a NowPlaying change needs no new mechanism.
- 01-09 (reconnect) gets the Reconnecting and Interrupted subtitles for free, and the deduplication stops repeated Reconnecting attempts from redrawing the notification.
- 01-11 (debug panel) can read `firstLaunchAtProvider`.
- End-of-phase UAT (D6), on the owner's phone:
  1. **Uninstall first**, so the channel is created with the localised name.
  2. Install a **release** build with the phone set to Bulgarian.
  3. Play a station and watch the notification and lock screen: the title is the station name, with "Свързване…" under it while connecting. Pause it and check for "На пауза".
  4. Check that the status bar shows a white radio icon, not a white square.
  5. Open Settings → Apps → eRadioto → Notifications and check that the channel is "Възпроизвеждане".

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED
