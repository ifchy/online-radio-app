---
phase: 01-playback-engine-walking-skeleton
plan: 05
subsystem: catalog
tags: [flutter, stations, streams, hls, aac, mp3, fallback, debug-stations, kReleaseMode, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "Station/StationId/StationStream/StreamKind with ordered streams[], StationDirectory, the tracer test"
  - phase: 01-playback-engine-walking-skeleton (plan 04)
    provides: "HttpStreamResolver: kind unknown is content-sniffed, so the debug HLS-sniff entry plays as HLS"
provides:
  - "phase1Stations: the five owner-verified release stations (curated:bnr-horizont, curated:radio1, curated:bg-radio, curated:energy, curated:njoy) with 12 official streams in priority order, each commented with its source and verifiedAt 2026-09-25"
  - "debugStations: debug:dead-primary, debug:slow-primary, debug:horizont-hls-sniff, whose fallbacks are read from phase1Stations"
  - "StationDirectory.phase1({bool includeDebug = !kReleaseMode}), which also gates on the const kReleaseMode so release builds never include the debug list"
  - "Station rejects an empty streams list with ArgumentError in every build mode"
  - "test/features/catalog/phase1_stations_test.dart (21 tests) and test/features/catalog/station_test.dart (10 tests)"
affects: [01-07, 01-08, 01-09, 01-13, phase-2-catalogue]

# Actuals (#2632)
actuals:
  tokens: 5290
  tasks: 2
  commits: 6
plan_head_before: d1c7c348c75171b6c76c510fa229a1e2f8c7f48b

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Debug-only data lives in its own file that only StationDirectory imports, behind `!kReleaseMode && includeDebug`"
    - "Test stations reuse the real stations' StationStream objects as fallbacks instead of repeating URL literals"
    - "Every shipped stream literal carries a `// Source: <page>; verifiedAt <date>` comment from the owner's D-02 table"
    - "UI tests that are not about the catalogue use a one-station StationDirectory fixture, not the live list"

key-files:
  created:
    - lib/features/catalog/data/debug_stations.dart
    - test/features/catalog/phase1_stations_test.dart
    - test/features/catalog/station_test.dart
  modified:
    - lib/features/catalog/data/phase1_stations.dart
    - lib/features/catalog/data/station_directory.dart
    - lib/features/catalog/domain/station.dart
    - test/features/playback/presentation/mini_player_test.dart

key-decisions:
  - "Phase 1 ships 5 stations, not 6: БНР Хоризонт, Радио 1, БГ Радио, Радио Енерджи and N-JOY. Радио Витоша is excluded because no official stream was found (option-c). No unofficial substitute is used (D-03)."
  - "N-JOY ships one stream, https://cdn.btv.bg/radio/njoy.mp3 (progressive MP3 on bTV's own CDN), which the owner verified on 2026-09-25. Its older live.btvradio.bg .m3u and MP3 endpoints are REJECTED, because neither played."
  - "БНР Хоризонт ships only its two bnr.bg-player HLS URLs (lb-hls.cdn.bg, then e106-ts.cdn.bg). The port-8011 AAC and MP3 mounts failed in VLC and were rejected."
  - "No release station uses a .pls/.m3u wrapper, so D-03 wrapper coverage (STRM-03) comes from the 01-04 resolver tests only. Candidate for later owner verification: http://play.global.audio/bgradio128.m3u (not added, unverified)."
  - "Non-.m3u8 HLS (option-a): covered by the 01-04 sniff tests plus the debug-only 'ТЕСТ: Хоризонт (HLS sniff)' entry, which uses Хоризонт stream 0 with kind unknown."
  - "windows-1251 (option-a): the owner ran no byte probe, so every stream is icyCharset auto. SC1's cp1251 clause is shown only by the 01-06 golden tests."
  - "StationDirectory.phase1 includes debug stations only when `!kReleaseMode && includeDebug`. That is const-false in release, so even includeDebug: true cannot ship them."

patterns-established:
  - "Owner-decision tests: when the owner removes a format, the data test asserts the reduced matrix and names the decision and date in its description"

requirements-completed: [STRM-01, STRM-02, STRM-03, STRM-04, STRM-05, PLAY-08]

coverage:
  - id: D1
    description: "Release list is exactly the five owner-verified stations (flagship first), with curated unique ids, at least one stream each, the owner's exact URLs in priority order, Cyrillic and Latin names, БГ Радио's tracer-verified MP3 as primary, and N-JOY's single https MP3 on cdn.btv.bg"
    requirement: PLAY-08
    verification:
      - kind: unit
        ref: "test/features/catalog/phase1_stations_test.dart#release list (includeDebug: false)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Reduced D-03 coverage matrix: MP3, AAC, HLS and plain http:// in release; no .pls/.m3u (N-JOY's .m3u rejected) and no cp1251 (no probe), each asserted with the owner decision and date; Витоша and the rejected hosts (live.btvradio.bg, stream.bnr.bg) never ship"
    requirement: STRM-01
    verification:
      - kind: unit
        ref: "test/features/catalog/phase1_stations_test.dart#covers MP3, AAC, HLS and plain http:// (D-03) / has no .pls/.m3u wrapper / marks no stream cp1251 / ships no excluded station"
        status: pass
    human_judgment: false
  - id: D3
    description: "Debug list adds exactly debug:dead-primary (.invalid, then Радио 1's first http MP3), debug:slow-primary (192.0.2.1, then БГ Радио's primary) and debug:horizont-hls-sniff (Хоризонт stream 0, kind unknown), included by default in debug/profile"
    requirement: PLAY-08
    verification:
      - kind: unit
        ref: "test/features/catalog/phase1_stations_test.dart#debug list (includeDebug: true)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Only station_directory.dart imports debug_stations.dart; dead-primary.invalid appears only in debug_stations.dart; the directory is gated on kReleaseMode"
    requirement: STRM-04
    verification:
      - kind: unit
        ref: "test/features/catalog/phase1_stations_test.dart#source isolation (Pitfall I)"
        status: pass
      - kind: other
        ref: "plan 01-05 Task 2 <verify> grep gate chain"
        status: pass
    human_judgment: false
  - id: D5
    description: "StationId parse/value round trip for every Phase 1 id; FormatException for unknown or missing namespace, empty key and characters outside [a-z0-9-]; Station with empty streams throws ArgumentError"
    verification:
      - kind: unit
        ref: "test/features/catalog/station_test.dart (10 tests)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Full suite green with the new list, including the 8-step tracer (БГ Радио found by text among 8 debug-build stations)"
    verification:
      - kind: integration
        ref: "flutter test (192 tests, All tests passed!) incl. test/app/tracer_e2e_test.dart"
        status: pass
      - kind: other
        ref: "flutter analyze && dart analyze (No issues found!)"
        status: pass
    human_judgment: false
  - id: D7
    description: "On the owner's phone: every release station plays within about 5 s (Хоризонт via HLS, N-JOY via cdn.btv.bg, at least one http:// station); in a debug build the ТЕСТ stations are listed and the HLS-sniff entry plays as HLS; a release build lists no ТЕСТ station"
    requirement: STRM-02
    verification: []
    human_judgment: true
    rationale: "Only a phone on the owner's network reaches the station servers, and only a release build proves the debug list is absent (plan <human-check>). The owner's VLC check covers the URLs, not the app."

# Metrics
duration: 10min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 05: The owner-verified Bulgarian stations with fallback streams Summary

**The station list now holds five owner-verified stations: БНР Хоризонт (2 HLS streams), then Радио 1, БГ Радио and Радио Енерджи (3 streams each), then N-JOY (1 https MP3 on bTV's own CDN). All 12 are official streams in priority order, covering MP3, AAC, HLS and plain http://. Debug and profile builds add dead-primary, slow-primary and Хоризонт HLS-sniff test stations, and a `kReleaseMode`-gated directory keeps them out of release builds.**

## Performance

- **Duration:** 10 min for this continuation (Task 2 plus the N-JOY correction). Task 1 was the owner's checkpoint on 2026-09-25.
- **Started:** 2026-09-25T16:03:51Z
- **Completed:** 2026-09-25T16:14:22Z
- **Tasks:** 2 of 2: Task 1 was the owner's decision, resolved; Task 2 was TDD (RED, then GREEN, then a RED/GREEN correction; no refactor needed)
- **Files modified:** 7 (3 created, 4 modified)

## Owner's D-02 Table (Task 1 resolution)

The owner played every URL in VLC on 2026-09-25 and captured the БНР URLs from bnr.bg's own player. Later that day the owner found and verified N-JOY's stream on bTV's CDN.

| Station (id) | # | URL | Kind / codec | icyCharset | Source | verifiedAt | Status |
|---|---|---|---|---|---|---|---|
| БНР Хоризонт `curated:bnr-horizont` | 0 | https://lb-hls.cdn.bg/2032/fls/Horizont.stream/playlist.m3u8 | hls | auto | bnr.bg player | 2026-09-25 | VERIFIED |
| | 1 | https://e106-ts.cdn.bg/regstations/fls/Horizont.stream/playlist.m3u8 | hls | auto | bnr.bg player | 2026-09-25 | VERIFIED |
| | — | http://stream.bnr.bg:8011/horizont.aac | — | — | research | 2026-09-25 | REJECTED (failed in VLC) |
| | — | http://stream.bnr.bg:8011/horizont.mp3 | — | — | research | 2026-09-25 | REJECTED (failed in VLC) |
| Радио 1 `curated:radio1` | 0 | https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_1AAC_L.aac?dist=WEBSITEBG | progressive / aac | auto | radio1.bg | 2026-09-25 | VERIFIED |
| | 1 | http://play.global.audio/radio1128?dist=WEBSITEBG | progressive / mp3 128 | auto | radio1.bg | 2026-09-25 | VERIFIED |
| | 2 | http://play.global.audio/radio164?dist=WEBSITEBG | progressive / mp3 64 | auto | radio1.bg | 2026-09-25 | VERIFIED |
| БГ Радио `curated:bg-radio` | 0 | http://play.global.audio/bgradio128 | progressive / mp3 128 | auto | bgradio.bg/live-stream | 2026-09-25 (also plays in the release build on the phone) | VERIFIED |
| | 1 | https://playerservices.streamtheworld.com/api/livestream-redirect/BG_RADIOAAC_L.aac?dist=WEBSITEBG | progressive / aac | auto | bgradio.bg/live-stream | 2026-09-25 | VERIFIED |
| | 2 | http://play.global.audio/bgradio.aac | progressive / aac | auto | bgradio.bg/live-stream | 2026-09-25 | VERIFIED |
| Радио Енерджи `curated:energy` | 0 | https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ENERGYAAC_L.aac?dist=WEBSITEBG | progressive / aac | auto | radioenergy.bg | 2026-09-25 | VERIFIED |
| | 1 | http://play.global.audio/nrj128 | progressive / mp3 128 | auto | radioenergy.bg | 2026-09-25 | VERIFIED |
| | 2 | http://play.global.audio/nrj64?dist=WEBSITEBG | progressive / mp3 64 | auto | radioenergy.bg | 2026-09-25 | VERIFIED |
| N-JOY `curated:njoy` | 0 | https://cdn.btv.bg/radio/njoy.mp3 | progressive / mp3 | auto | bTV's own CDN (found by the owner) | 2026-09-25 | VERIFIED |
| | — | http://live.btvradio.bg/njoy.mp3.m3u | — | — | research | 2026-09-25 | REJECTED (plays nothing) |
| | — | http://live.btvradio.bg/njoy.mp3 | — | — | research | 2026-09-25 | REJECTED (plays nothing) |
| Радио Витоша `curated:vitosha` | — | none found | — | — | — | 2026-09-25 | EXCLUDED: option-c |

Codec and bitrate follow the endpoint names in the research matrix. The owner did not report an ffprobe run, so HE-AAC versus LC is still unconfirmed for the StreamTheWorld `.aac` streams, and N-JOY's bitrate is unknown. No N-JOY homepage is set, because no official site URL was verified.

**Gap decisions:**
1. **Радио Витоша: option-c.** Phase 1 ships without it and uses no unofficial URL. Phase 2 curation can add it once an official stream is found.
2. **HLS behind a non-.m3u8 URL: option-a.** It is covered by the 01-04 resolver sniff tests and by the debug-only "ТЕСТ: Хоризонт (HLS sniff)" entry, which uses Хоризонт stream 0 with `kind: unknown`. On the phone, the resolver's content sniff must therefore pick HLS.
3. **windows-1251: option-a.** The owner ran no byte probe, so no stream is marked `cp1251`. The 01-06 golden tests cover cp1251, and SC1's cp1251 clause is shown by tests only.

**Consequence:** N-JOY's `.m3u` wrapper was rejected, and its verified stream is a direct MP3, so no release station uses a `.pls`/`.m3u` wrapper. The wrapper format (D-03, STRM-03) is covered by the 01-04 resolver tests only. A candidate for later owner verification is `http://play.global.audio/bgradio128.m3u`. It was **not** added because it is unverified.

## Accomplishments

- **Release list (D-01, D-04):** five stations, in the plan's display order with the national flagship first: БНР Хоризонт, Радио 1, БГ Радио, Радио Енерджи, N-JOY. Each carries the owner's verified streams in the owner's order, with the HTTPS StreamTheWorld AAC first where one exists. Each of the 12 stream literals has a `// Source: …; verifiedAt 2026-09-25` comment. The file header records the exclusions and rejections, without naming the rejected hosts.
- **Debug stations (D-05):**
  - `debug:dead-primary`: `https://dead-primary.invalid/stream.mp3`, then Радио 1's first http MP3 (`radio1128`).
  - `debug:slow-primary`: `http://192.0.2.1/stream.mp3`, then БГ Радио's `bgradio128`.
  - `debug:horizont-hls-sniff`: Хоризонт stream 0 with `kind: unknown`.
  - All fallbacks are looked up in `phase1Stations`, not repeated as literals.
- **Release isolation (Pitfall I):** `StationDirectory.phase1({bool includeDebug = !kReleaseMode})` appends the debug list only when `!kReleaseMode && includeDebug`. Only `station_directory.dart` imports `debug_stations.dart`. The 01-02 CI `strings` check on `libapp.so` backs this up in release builds.
- **Tests:** 31 new tests (21 in `phase1_stations_test.dart`, 10 in `station_test.dart`). The full suite of 192 tests passes, including all 8 tracer steps and `_lastStation` resumption. `flutter analyze` and `dart analyze` report no issues. No test touches the network.
- **Untouched, as required:** `android/app/src/main/res/raw/keep.xml`, `RadioAudioHandler`'s `_lastStation` resume, the `AudioService.asyncError` logging, and `lib/app/bootstrap.dart`.

## Task Commits

1. **Task 1: the owner verifies the stream URLs and decides the D-03 gaps.** This was a checkpoint:decision with the blocking-human gate. It was resolved by the owner on 2026-09-25 and produced no commit. The decision is recorded above.
2. **Task 2: the owner-verified stations and debug-only test stations with ordered fallback streams.**
   - RED `ad69fee` (test) and GREEN `2dd6a7c` (feat): the first version, with four stations.
   - Owner correction, adding N-JOY back: RED `44c3241` (test) and GREEN `68250a1` (feat).

**Plan metadata:** `8b2b058` (first SUMMARY) and `6717f62` (first STATE/ROADMAP/REQUIREMENTS update). The correction's docs commit follows this one.

## TDD Gate Compliance

| Step | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| Task 2 | `ad69fee`: 15 of 28 failed, all on assertions. | `2dd6a7c` | not needed | `check tdd-red-evidence` returned RED_EVIDENCE_OK for 5 targets: the station list, the empty-streams ArgumentError, the debug ids, import isolation, and the D-03 matrix |
| N-JOY correction | `44c3241`: 5 of 29 failed, all on assertions (the station list, exact streams, names, the N-JOY stream, and the id round trip) | `68250a1` | not needed | RED_EVIDENCE_OK for "is the five owner-verified stations, national flagship first" |

In the first RED run, 13 tests passed, in three groups:
- StationId characterisation (8): this behaviour already existed from 01-01; the plan asks only for its test.
- БГ Радио's primary (1): the tracer station was unchanged.
- The four reduced-matrix and one-station negatives (4): a one-station list satisfies "no wrapper", "no cp1251", "no excluded station" and "each station has a stream".

As in 01-03, 01-04 and 01-06, each RED run used `flutter test --reporter json`, converted into TAP for the checker. The first RED commit's only scaffolding was the ignored `includeDebug` parameter.

## Files Created/Modified

- `lib/features/catalog/data/phase1_stations.dart`: the five owner-verified stations, with 12 streams and their source/verifiedAt comments.
- `lib/features/catalog/data/debug_stations.dart` (new): the three debug test stations.
- `lib/features/catalog/data/station_directory.dart`: `phase1({includeDebug = !kReleaseMode})`, gated on `kReleaseMode`.
- `lib/features/catalog/domain/station.dart`: the empty-streams check is an ArgumentError in every mode; the redundant assert is removed.
- `test/features/catalog/phase1_stations_test.dart` (new): the release list, the reduced D-03 matrix, the debug list and source isolation.
- `test/features/catalog/station_test.dart` (new): StationId round trips and rejections, and the empty-streams rule.
- `test/features/playback/presentation/mini_player_test.dart`: uses a one-station БГ Радио fixture.

## Decisions Made

See `key-decisions` in the frontmatter. In short:
- 5 stations by owner decision: Витоша is excluded, and N-JOY ships via cdn.btv.bg.
- Хоризонт is HLS-only.
- The release data has no wrapper and no cp1251; both are covered by tests.
- The debug list is const-gated on `kReleaseMode`.

## Deviations from Plan

### Owner-decision deviations (recorded, not failures)

**1. Five stations instead of six**
- **Why:** The owner excluded Радио Витоша on 2026-09-25 (option-c: no official stream).
- **N-JOY:** The owner first excluded N-JOY (no research endpoint played), then later that day put it back with a newly verified stream, `https://cdn.btv.bg/radio/njoy.mp3`. The four-station version was already committed, so the correction landed as new commits (`44c3241`, `68250a1`) without rewriting history.
- **What changed:**
  - The tests assert the five ids, the owner's exact URL lists, and the reduced D-03 matrix. Each reduced-matrix test names the decision and date.
  - The plan's "N-JOY via its .m3u" human check now becomes "N-JOY via its direct https MP3".
  - The must-have truth about "a .pls or .m3u wrapper" in the release list is met by the 01-04 resolver tests only.
  - The artifact description "six-station release list" now reads five.
- **Files:** phase1_stations.dart, phase1_stations_test.dart, station_test.dart
- **Committed in:** ad69fee, 2dd6a7c, 44c3241, 68250a1

**2. Хоризонт ships HLS only, and N-JOY's stream differs from the plan**
- **Хоризонт:** The planned stream order was HLS, then 8011 AAC, then 8011 MP3. The owner rejected both 8011 mounts and verified a second HLS endpoint (e106-ts.cdn.bg) from bnr.bg's player instead.
- **N-JOY:** The plan specified the live.btvradio.bg `.m3u`, then the MP3. Both were rejected, and the station ships the single cdn.btv.bg MP3 instead.
- **Committed in:** 2dd6a7c, 68250a1

### Auto-fixed Issues

**3. [Rule 1 - Bug] The empty-streams check threw AssertionError, not ArgumentError, in debug builds**
- **Found during:** Task 2 (RED)
- **Issue:** `Station`'s initializer-list `assert(streams.isNotEmpty)` ran before the body's `ArgumentError`. With asserts enabled (debug builds and tests), the invariant therefore surfaced as an `AssertionError`, not the `ArgumentError` that 01-01 and this plan specify.
- **Fix:** Removed the assert. The body's `ArgumentError` now applies in every mode, and the generated freezed code is unaffected.
- **Files modified:** lib/features/catalog/domain/station.dart
- **Verification:** "a station with an empty streams list is rejected with ArgumentError" passes.
- **Committed in:** 2dd6a7c

**4. [Rule 2 - Missing Critical] The debug list cannot ship even if a caller passes includeDebug: true**
- **Found during:** Task 2 (GREEN)
- **Issue:** With only the default parameter `includeDebug = !kReleaseMode`, a release-mode caller passing `includeDebug: true` would ship the debug stations. Also, AOT dropping the debug list would depend on the compiler propagating a default argument (T-05-02).
- **Fix:** The condition is `!kReleaseMode && includeDebug`. That is const-false in release, so the `debugStations` reference is dead code there. The planned signature and default are unchanged.
- **Files modified:** lib/features/catalog/data/station_directory.dart
- **Verification:** the grep gates pass, and the debug and release directory tests pass.
- **Committed in:** 2dd6a7c

**5. [Rule 3 - Blocking] mini_player_test assumed the first station was БГ Радио**
- **Found during:** Task 2 (GREEN full-suite run)
- **Issue:** Four home-screen and mini-player tests used `StationDirectory.phase1().all.first` and expected one ListTile, a `ListPlayContext` of `[_station.id]`, and "БГ Радио" labels. The flagship Хоризонт is now first, and debug builds list 8 stations.
- **Fix:** The tests use БГ Радио by id and a one-station `StationDirectory([_station])` fixture. They cover the UI, not the catalogue.
- **Files modified:** test/features/playback/presentation/mini_player_test.dart
- **Verification:** the full suite passes (192 tests).
- **Committed in:** 2dd6a7c

---

**Total deviations:** 2 owner-decision deviations and 3 auto-fixed issues (1 Rule 1 bug, 1 Rule 2 missing-critical, 1 Rule 3 blocking).
**Impact on plan:** The owner decisions reduce the release lineup by one station and remove the on-device wrapper case. That coverage is now test-only, as recorded above. The auto-fixes tighten the plan's own invariants (T-05-02 and the 01-01 empty-streams rule). There is no scope creep.

## Issues Encountered

- The owner's N-JOY update arrived after the four-station version was committed. It was applied as a separate RED/GREEN pair, and this SUMMARY replaces the four-station one.
- The owner update listed the lineup as "Radio 1, БГ Радио, Energy, N-JOY, БНР Хоризонт" but also said "in the plan's order". The plan's display order puts the national flagship first, so the list ships as БНР Хоризонт, Радио 1, БГ Радио, Радио Енерджи, N-JOY. If the owner wants Хоризонт last, the fix is a one-line reorder of `phase1Stations` plus the order assertion in `phase1_stations_test.dart`.

## Known Stubs

None. The debug stations are intentional (D-05) and never reach release builds.

## Threat Flags

None beyond the plan's threat model.
- T-05-01 is mitigated by the owner's VLC verification and the per-stream source/verifiedAt comments. N-JOY's stream is on bTV's own CDN, and it is https.
- T-05-02 is mitigated by the const gate, the unit tests and the grep gates, with the 01-02 CI `strings` check as a backstop.
- T-05-03 (http:// media) is accepted: https streams are listed first where they exist.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- 01-09 (reconnect and rotation) has real ordered fallbacks for four stations (2 or 3 each). N-JOY has a single stream, so it has nothing to rotate to until more official endpoints are verified. The dead-primary and slow-primary debug stations exercise rotation on a phone.
- 01-08 (now playing) has no cp1251-marked stream. It passes `icyCharset: auto` for every release stream, so the 01-06 auto-detection handles any cp1251 titles.
- End-of-phase UAT (D7, and 01-04's D7):
  - In a release build, play all five stations for about 30 s each, including Хоризонт via HLS, N-JOY via cdn.btv.bg, and at least one http:// stream.
  - In a debug build, check that the ТЕСТ stations are listed and that the HLS-sniff entry plays as HLS.
  - Confirm that a release build lists no ТЕСТ station.
- Open for the owner, not blocking:
  - Verify `http://play.global.audio/bgradio128.m3u` if an on-device wrapper case is wanted.
  - Find an official Радио Витоша stream in Phase 2 curation.
  - Optionally add an N-JOY fallback and homepage.
  - Optionally run the cp1251 byte probe on БГ Радио.
  - Confirm the display order (see Issues Encountered).

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED
