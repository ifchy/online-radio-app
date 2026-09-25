---
phase: 01-playback-engine-walking-skeleton
plan: 03
subsystem: ui
tags: [flutter, gen-l10n, arb, localisation, riverpod, accessibility, talkback, mini-player]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "AudioEngine, PlaybackStatus (8 variants), playbackStatusProvider/currentStationProvider/audioEngineProvider, StationDirectory, RadioApp and HomeScreen shell"
provides:
  - "gen-l10n setup (l10n.yaml, flutter generate: true) with committed generated AppLocalizations in lib/l10n/"
  - "All 14 Phase 1 ARB keys in bg and en, including the D-09 state labels and notificationChannelName for 01-07"
  - "resolveAppLocale(Locale?) in lib/app/app.dart: bg -> bg, anything else -> en (reusable outside the widget tree)"
  - "stateLabelFor(PlaybackStatus, AppLocalizations): exhaustive D-09 label mapping"
  - "MiniPlayer: accessible bottom player (station, live-region state label, play/pause, stop, no seek)"
  - "Localised HomeScreen (stationListTitle, playStationHint tile hints) with the MiniPlayer as bottomNavigationBar"
  - "FakeEngine test double (settable replaying status/station, records play/togglePause/stop)"
affects: [01-07, 01-09, phase-3-ui, phase-3-bg-copy-review]

# Actuals (#2632)
actuals:
  tokens: 9600
  tasks: 2
  commits: 4
plan_head_before: fb05b3dee8c01f1328b327c5b23303d5f67de0f8

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "gen-l10n output committed in lib/l10n/, imported only as package:radio/l10n/app_localizations.dart (or relative); no synthetic flutter_gen package, no synthetic-package key"
    - "Locale rule lives in one pure function (resolveAppLocale) that MaterialApp and non-widget code both call"
    - "Presentation maps sealed PlaybackStatus with exhaustive switches, so a new variant is a compile error"
    - "A ConsumerWidget that returns early watches all its providers before the early return"
    - "State labels sit in an always-present Semantics(container: true, liveRegion: true) so TalkBack announces changes"
    - "Widget tests: after publishing an engine change, pump twice (the provider gets the event, then the next frame rebuilds)"
    - "Widget tests pass ProviderScope(overrides: ...) straight to pumpWidget; riverpod_lint flags overrides built in a helper"

key-files:
  created:
    - l10n.yaml
    - lib/l10n/app_en.arb
    - lib/l10n/app_bg.arb
    - lib/l10n/app_localizations.dart
    - lib/l10n/app_localizations_en.dart
    - lib/l10n/app_localizations_bg.dart
    - lib/features/playback/presentation/state_label.dart
    - lib/features/playback/presentation/mini_player.dart
    - test/features/playback/presentation/mini_player_test.dart
  modified:
    - pubspec.yaml
    - lib/app/app.dart
    - lib/app/home_screen.dart
    - test/support/fakes.dart

key-decisions:
  - "The mini-player's play/pause button shows Pause (and a tap pauses) in every state where AudioEngine.togglePause pauses: Connecting, Playing, Buffering, Reconnecting and Interrupted, matching the notification controls. It shows Play only in Paused and Error. The plan's 'actionPause while playing' is read as the media-session playing flag, so TalkBack never announces Play for a tap that pauses."
  - "The station name Text inside the mini-player is excluded from semantics; the region label 'Сега звучи: <station>' already names it, so TalkBack does not read it twice."
  - "MaterialApp takes its title from appTitle via onGenerateTitle and resolves locale with localeResolutionCallback, so only the device's first preferred language counts (D-08)."
  - "Bulgarian ARB values are placeholders for the owner's Phase 3 copy review (D-08); the keys are final, and later plans should not need to edit the ARB files for Phase 1 strings."

patterns-established:
  - "Exhaustive sealed-status switches in presentation (stateLabelFor, _engineWouldPause)"
  - "FakeEngine for any widget test that needs the AudioEngine; it records commands and never changes its own state"

requirements-completed: [PLAY-11]

coverage:
  - id: D1
    description: "resolveAppLocale maps bg/bg_BG to Bulgarian and en_US/de/null to English; lookupAppLocalizations returns every phase key with the exact bg and en text"
    requirement: PLAY-11
    verification:
      - kind: unit
        ref: "test/features/playback/presentation/mini_player_test.dart#localisation (4 tests)"
        status: pass
      - kind: other
        ref: "plan 01-03 Task 1 grep gate (generate: true, D-09 labels, channel name, resolver, generated file, no flutter_gen, no deprecated gen-l10n option)"
        status: pass
    human_judgment: false
  - id: D2
    description: "HomeScreen shows the localised AppBar title and per-tile TalkBack hint in bg and en, plays the tapped station from the home list, and has the MiniPlayer at the bottom"
    verification:
      - kind: automated_ui
        ref: "test/features/playback/presentation/mini_player_test.dart#home screen (4 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "MiniPlayer shows the exact D-09 label for all 8 PlaybackStatus variants in bg and en, in a live region under a labelled region; builds nothing without a station; Pause/Play call togglePause once, Stop calls stop once and the player disappears; no seek bar, progress or position text (PLAY-11)"
    requirement: PLAY-11
    verification:
      - kind: automated_ui
        ref: "test/features/playback/presentation/mini_player_test.dart#mini-player state label + mini-player controls (28 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "MiniPlayer passes androidTapTargetGuideline, labeledTapTargetGuideline and textContrastGuideline in Playing, Reconnecting and Paused, and a long name at 2x text scale on a 360 dp phone throws no overflow with both controls still tappable"
    verification:
      - kind: automated_ui
        ref: "test/features/playback/presentation/mini_player_test.dart#mini-player accessibility (4 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "On a real phone: Bulgarian UI on a bg device and English otherwise; with TalkBack every control is announced meaningfully, the state label is announced when it changes, and the mini-player disappears after Stop"
    verification: []
    human_judgment: true
    rationale: "Switching the device locale and real TalkBack announcement behaviour need a physical device (the plan's <human-check>); harvest into the end-of-phase UAT."

# Metrics
duration: 11min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 03: The app speaks Bulgarian or English, and an accessible mini-player controls playback Summary

**gen-l10n with all 14 Phase 1 keys in Bulgarian and English, a `resolveAppLocale` rule (bg -> Bulgarian, else English), and a TalkBack-ready bottom `MiniPlayer`. The player shows the station, a live-region state label for every `PlaybackStatus`, and play/pause and stop through the engine, with no seek bar.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-09-25T14:44:58Z
- **Completed:** 2026-09-25T14:56:07Z
- **Tasks:** 2 of 2 (both TDD: RED then GREEN, no refactor needed)
- **Files modified:** 13

## Accomplishments

- **Localisation (D-08):** `l10n.yaml` has no `synthetic-package` key, and `flutter: generate: true` is set.
  - `app_en.arb` has an `@description` for every key. `app_bg.arb` holds the Bulgarian placeholders.
  - The generated `AppLocalizations` files are committed.
  - `RadioApp` registers the delegates, supports bg and en, and resolves the locale through `resolveAppLocale`.
- **Every Phase 1 key exists now.** That includes `notificationChannelName` ("Възпроизвеждане" / "Playback") for 01-07, plus `stateInterrupted` and `statePaused` (RESEARCH Open Question 6).
- **Mini-player (D-06, D-09, PLAY-11):**
  - It shows the station name, and a state label in an always-present live region.
  - Its region is labelled "Сега звучи: <station>".
  - Play/pause and stop are 48 dp IconButtons with tooltips.
  - Text is one line with an ellipsis, and nothing has a fixed height.
  - It builds nothing when there is no station.
- **Home screen:** it has a localised title and a "Пусни <station>" hint on each tile, and the mini-player is its `bottomNavigationBar`.
- **Tests:** `FakeEngine` was added, and `mini_player_test.dart` has 40 tests. The whole suite (41 tests, including the unedited tracer test and its step 8) passes, and `flutter analyze` and `dart analyze` are clean.

## Task Commits

1. **Task 1: Bulgarian/English resolution and all phase strings.** RED `b2b1ef7` (test), GREEN `d79a465` (feat)
2. **Task 2: Localised station list and accessible mini-player.** RED `ab2233a` (test), GREEN `09d7677` (feat)

**Plan metadata:** see the `docs(01-03): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `b2b1ef7`: the 2 Bulgarian targets failed on assertions (resolver stub returned en; empty bg ARB fell back to English) | `d79a465` | not needed | `check tdd-red-evidence` -> RED_EVIDENCE_OK for both targets |
| 2 | `ab2233a`: 33 of 40 failed on assertions (stub MiniPlayer built nothing, stub label returned null, unlocalised HomeScreen) | `09d7677` | not needed | RED_EVIDENCE_OK for 4 representative targets (home title/hint, Connecting bg label, Pause command, guidelines) |

`flutter test` has no TAP reporter, so each RED run used `--reporter json`, converted line for line into TAP for the checker. Each RED commit also contains the minimal scaffolding the tests need to compile (config, the English template ARB, and stubs), so the failures are assertions rather than compile errors.

## Files Created/Modified

- `l10n.yaml` configures gen-l10n: arb-dir `lib/l10n`, template `app_en.arb`, non-nullable getter.
- `lib/l10n/app_en.arb` and `lib/l10n/app_bg.arb` hold the 14 phase keys. `app_en.arb` is the template with descriptions and placeholders.
- `lib/l10n/app_localizations*.dart` are the generated, committed localisations (D-17).
- `lib/app/app.dart` has `resolveAppLocale` and the `RadioApp` delegates, supported locales and locale resolution.
- `lib/app/home_screen.dart` has the localised title, the tile hints and the `MiniPlayer` at the bottom.
- `lib/features/playback/presentation/state_label.dart` has `stateLabelFor`, an exhaustive D-09 mapping.
- `lib/features/playback/presentation/mini_player.dart` holds `MiniPlayer` and `_engineWouldPause`.
- `test/support/fakes.dart` adds `FakeEngine` and `PlayCall`. `FakeStreamPlayer` and `FakeAudioSessionPort` are unchanged.
- `test/features/playback/presentation/mini_player_test.dart` holds the localisation, home-screen, label, control and accessibility groups.

## Decisions Made

- **Pause/Play follows what the engine does.** The button says Pause and pauses in Connecting, Playing, Buffering, Reconnecting and Interrupted, which are exactly the states where `togglePause` pauses and the notification shows Pause. It says Play in Paused and Error.
- **The station name is read once.** The name `Text` is excluded from semantics because the region label already contains it.
- **The live region is always present.** The label sits in a `Semantics(container: true, liveRegion: true)` that exists even when there is no label. Without `container`, it merged into the region node and lost its live-region flag.
- **The locale rule lives in one place.** `resolveAppLocale` is a top-level pure function, so 01-07's bootstrap can build notification strings with `lookupAppLocalizations(resolveAppLocale(PlatformDispatcher.instance.locale))`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The first frame with a station showed the Idle button and no label**
- **Found during:** Task 2 (GREEN)
- **Issue:** `MiniPlayer.build` returned early when there was no station, before it watched `playbackStatusProvider`. The status provider was therefore only subscribed once a station appeared, so that first frame showed Idle: a Play button and no label. TalkBack would briefly announce the wrong control.
- **Fix:** Both providers are watched before the early return.
- **Files modified:** lib/features/playback/presentation/mini_player.dart
- **Verification:** The 16 label tests and the Pause-offer tests pass.
- **Committed in:** 09d7677

**2. [Rule 1 - Bug] The live-region label merged into the region node**
- **Found during:** Task 2 (GREEN)
- **Issue:** A plain `Semantics(liveRegion: true)` merged into the mini-player's container node, so the state label had no live-region node of its own and TalkBack would not announce changes.
- **Fix:** Added `container: true`. A semantics-tree dump confirms a separate `isLiveRegion` node with the label, between the region label and the buttons.
- **Files modified:** lib/features/playback/presentation/mini_player.dart
- **Verification:** The "label is a live region" test passes.
- **Committed in:** 09d7677

**3. [Rule 1 - Clarification] The Pause tooltip covers every state where the engine pauses**
- **Found during:** Task 2
- **Issue:** The plan says the tooltip is actionPause "while the status reports playing". The engine's `togglePause` also pauses in Connecting, Buffering, Reconnecting and Interrupted. Showing Play in those states would mislabel the button.
- **Fix:** An exhaustive `_engineWouldPause` switch. Tests assert Pause in those four states and Play in Paused and Error.
- **Files modified:** lib/features/playback/presentation/mini_player.dart, test/features/playback/presentation/mini_player_test.dart
- **Committed in:** ab2233a (tests), 09d7677 (implementation)

**4. [Rule 3 - Blocking] Test-harness adjustments**
- `containsSemantics` is deprecated in Flutter 3.47, so the tests use `isSemantics`.
- riverpod_lint (`scoped_providers_should_specify_dependencies`) flagged a `ProviderScope` with overrides built in a helper. It is now passed straight to `pumpWidget`, as in the tracer test.
- In the Scaffold's bottom slot, a collapsed mini-player has full width and zero height, so the no-station test checks the height.
- **Committed in:** ab2233a

---

**Total deviations:** 4 auto-fixed (3 Rule 1, 1 Rule 3).
**Impact on plan:** All were needed for correct TalkBack behaviour or a clean analyzer. There is no scope creep.

## Issues Encountered

- After an engine publish, the widgets update one frame later: the provider gets the event, then the next frame rebuilds. The tests use a `_settle` helper that pumps twice. On a device this delay is a single frame.

## Known Stubs

None. The Bulgarian ARB values are the planned placeholders awaiting the owner's Phase 3 copy review (D-08). They are real strings in use, not stubs.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- 01-07 can use `notificationChannelName`, the `state*` keys and `resolveAppLocale` for the notification channel and subtitle without editing the ARB files.
- Any widget test that needs the engine can use `FakeEngine`.
- For end-of-phase UAT (D5): check the device locale switch (bg/en), then use TalkBack to walk through the list and the mini-player while a station connects, plays, pauses and stops.
- 01-01's `keep.xml` and the `_lastStation` media resumption are untouched, and tracer step 8 still passes.

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED
