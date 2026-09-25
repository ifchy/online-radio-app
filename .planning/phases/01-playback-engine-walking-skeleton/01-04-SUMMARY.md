---
phase: 01-playback-engine-walking-skeleton
plan: 04
subsystem: playback
tags: [flutter, http, playlist, pls, m3u, hls, stream-resolver, https, security, tdd]

# Dependency graph
requires:
  - phase: 01-playback-engine-walking-skeleton (plan 01)
    provides: "StationStream/StreamKind, ResolvedStream/PlayableKind, StreamPlayer, RadioAudioHandler (generation guard, publish-before-load, _lastStation resumption), bootstrap composition root, buildUserAgent, FakeStreamPlayer/FakeAudioSessionPort"
provides:
  - "StreamResolver port with StreamResolutionException / StreamResolutionFailure (9 reasons) in engine/ports.dart"
  - "HttpStreamResolver: catalogue-kind routing, audio/* short-circuit, HLS sniff on the original URL, PLS/M3U parsing, nesting, and hard limits (5 s, 64 KB, 5 redirects, depth 3, 10 candidates, http/https only), 1 h cache, in-flight dedupe, invalidate"
  - "parsePls / parseM3u / isHlsPlaylist: tolerant playlist parsers (BOM, CRLF, key case, numeric FileN order, dedupe, relative URLs)"
  - "MediaHttpClient: the only Dart client allowed to fetch http:// (media playlists), http/https-only, eRadioto User-Agent"
  - "AppHttpClient: HTTPS-only client for app-owned traffic with manual https-only redirects (cap 5); Phase 2 entry point for the catalogue and Radio Browser"
  - "RadioAudioHandler resolves streams[0] before load, discards superseded resolutions, maps resolution failures to PlaybackError, invalidates the stream on resolve/player failure"
  - "bootstrap.dart builds MediaHttpClient(http.Client(), userAgent) and HttpStreamResolver(mediaClient, const Clock())"
  - "test/features/playback/engine/radio_audio_handler_test.dart: shared handler test file for later plans"
affects: [01-05, 01-06, 01-09, 01-13, phase-2-catalogue, phase-2-radio-browser]

# Actuals (#2632)
actuals:
  tokens: 14400
  tasks: 2
  commits: 4
plan_head_before: fadcb5cf6ce9d487ccd02d963351638842c2e121

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every catalogue stream goes through StreamResolver before StreamPlayer.load; the catalogue kind decides the source type, never the file extension"
    - "Redirects are followed by hand (followRedirects = false) in both Dart clients, so every hop is scheme-checked and the hop cap and final URL are deterministic"
    - "Resolver input limits live as constructor defaults (ttl 1 h, timeout 5 s, maxBytes 65536, maxDepth 3, maxCandidates 10, maxRedirects 5) so tests can shrink them"
    - "HTTP behaviour is tested with package:http/testing.dart MockClient / MockClient.streaming; no test touches the network"
    - "A resolve that completes after the generation moved on is dropped before load, the same rule as player events"

key-files:
  created:
    - lib/features/playback/engine/resolver/stream_resolver.dart
    - lib/features/playback/engine/resolver/pls_parser.dart
    - lib/features/playback/engine/resolver/m3u_parser.dart
    - lib/features/playback/engine/resolver/playlist_text.dart
    - lib/core/network/media_http_client.dart
    - lib/core/network/app_http_client.dart
    - test/features/playback/engine/resolver/stream_resolver_test.dart
    - test/features/playback/engine/resolver/playlist_parsers_test.dart
    - test/features/playback/engine/radio_audio_handler_test.dart
    - test/core/network/http_clients_test.dart
  modified:
    - lib/features/playback/engine/ports.dart
    - lib/features/playback/engine/radio_audio_handler.dart
    - lib/app/bootstrap.dart
    - test/app/tracer_e2e_test.dart

key-decisions:
  - "HttpStreamResolver and AppHttpClient follow redirects by hand instead of relying on followRedirects/maxRedirects. MockClient cannot report a final URL or enforce maxRedirects, and IOClient reports a redirect-limit breach only as a message-typed ClientException. The manual loop makes tooManyRedirects and the redirected base deterministic and checks every hop against the scheme allow-list."
  - "The resolver's 5 s timeout covers the whole resolution (all hops and nested playlists), not each request, so one slow chain cannot take 5 s per hop."
  - "A failing nested playlist entry is skipped, because the other entries are fallbacks. Its error is reported only when nothing playable is left, which is how tooDeep surfaces for a pure chain."
  - "A body that starts with '<' or contains NUL is notAPlaylist (maps to PlaybackError(unsupportedFormat)), so an HTML page is never parsed as an M3U of relative URLs."
  - "A non-http(s) station URL is rejected as unsupportedScheme even for kind progressive/hls, so nothing but http(s) ever reaches ExoPlayer."
  - "invalidate() also bumps a per-URL epoch and drops the in-flight entry, so a resolution already running when playback failed cannot refill the cache with the stale result."

patterns-established:
  - "Resolution failure mapping: unsupportedScheme/notAPlaylist/empty -> PlaybackError(unsupportedFormat); every other reason -> PlaybackError(streamUnreachable)"
  - "Handler failures (_fail) invalidate the current stream's resolution unless the caller already did"

requirements-completed: [STRM-02, STRM-03, STRM-04]

coverage:
  - id: D1
    description: "Tolerant PLS/M3U parsing: BOM, CRLF, file1/File2/FILE10 keys, numeric FileN order (File2 before File10), duplicates kept at their first position, #EXTINF skipped, relative entries resolved; isHlsPlaylist needs #EXTM3U first and an #EXT-X- tag"
    requirement: STRM-03
    verification:
      - kind: unit
        ref: "test/features/playback/engine/resolver/playlist_parsers_test.dart (9 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "HttpStreamResolver: progressive/hls with no request; PLS order with .m3u8 entries as hls; M3U relative entry against the redirected URL; extension-less HLS sniffed and played on the ORIGINAL URL; HLS served as .m3u; audio/* short-circuit without reading the body; audio/x-mpegurl parsed"
    requirement: STRM-02
    verification:
      - kind: unit
        ref: "test/features/playback/engine/resolver/stream_resolver_test.dart#catalogue kind wins, playlists, audio/* short-circuit"
        status: pass
    human_judgment: false
  - id: D3
    description: "Resolver limits and allow-list: 64 KB cap with subscription cancel (tooLarge), 5 s timeout, 5 redirects followed and a 6th rejected, redirect to file: rejected, depth 3 ok and 4 tooDeep, 10-candidate cap, file:/content:/javascript:/intent:/rtsp: dropped, empty and notAPlaylist, httpStatus and network errors"
    requirement: STRM-04
    verification:
      - kind: unit
        ref: "test/features/playback/engine/resolver/stream_resolver_test.dart#limits, playlists"
        status: pass
    human_judgment: false
  - id: D4
    description: "Resolver cache: no request within 1 h, refetch after 1 h, invalidate() forces a refetch, two concurrent resolves share one request and one cache entry"
    requirement: STRM-04
    verification:
      - kind: unit
        ref: "test/features/playback/engine/resolver/stream_resolver_test.dart#cache (4 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Handler wiring: an m3u station loads the first resolved candidate with its kind; a failed resolve invalidates and ends in PlaybackError(streamUnreachable); an empty playlist ends in PlaybackError(unsupportedFormat); a superseded resolve is never loaded; a player failure invalidates. The tracer (all 8 steps, incl. last-station resume) passes with a resolver whose client fails the test if called"
    requirement: STRM-03
    verification:
      - kind: unit
        ref: "test/features/playback/engine/radio_audio_handler_test.dart (5 tests)"
        status: pass
      - kind: integration
        ref: "test/app/tracer_e2e_test.dart"
        status: pass
    human_judgment: false
  - id: D6
    description: "AppHttpClient is HTTPS-only (uppercase HTTPS accepted; http, ftp, relative, empty and host-less rejected with zero requests; a redirect to http is not followed; at most 5 https redirects for GET/HEAD; POST redirects returned unchanged). MediaHttpClient allows http/https and rejects file:/content:/relative/host-less. Both send exactly the eRadioto User-Agent"
    requirement: STRM-04
    verification:
      - kind: unit
        ref: "test/core/network/http_clients_test.dart (19 tests)"
        status: pass
    human_judgment: false
  - id: D7
    description: "On the owner's phone (after 01-05 lands the curated stations): N-JOY (.m3u wrapper) and БНР Хоризонт (HLS) play in a release build, and the debug 'Хоризонт (HLS sniff)' entry (kind unknown) plays through the HLS source, all within about 5 s"
    requirement: STRM-02
    verification: []
    human_judgment: true
    rationale: "Real Icecast playlists and cdn.bg HLS redirects are reachable only from the owner's network and phone, and the stations arrive in plan 01-05 (the plan's <human-check>)."

# Metrics
duration: 13min
completed: 2026-09-25
status: complete
---

# Phase 1 Plan 04: Stations behind .pls/.m3u playlists and extension-less HLS play, and app-owned traffic is HTTPS-only Summary

**Every catalogue stream now passes through a Dart `HttpStreamResolver` before ExoPlayer sees it.**
- `.pls` and `.m3u` wrappers become their real stream URLs.
- HLS behind a URL that does not end in `.m3u8` is detected from the body and played through the HLS source on its original URL.
- Hard limits (5 s, 64 KB, 5 redirects, depth 3, 10 candidates, http/https only) keep a hostile playlist from hanging the app or reaching ExoPlayer.
- App-owned traffic gets an HTTPS-only `AppHttpClient` that also refuses redirects to http.

## Performance

- **Duration:** 13 min
- **Started:** 2026-09-25T14:58:39Z
- **Completed:** 2026-09-25T15:11:30Z
- **Tasks:** 2 of 2, both TDD (RED then GREEN; no refactor was needed)
- **Files modified:** 14 (10 created, 4 modified)

## Accomplishments

- **STRM-03, playlists:** `.pls` and `.m3u` stations resolve to their entries in playlist order.
  - The PLS parser handles a BOM, CRLF, any key case and a missing `NumberOfEntries`, and orders entries by FileN (File2 before File10).
  - Duplicates are kept at their first position, and relative entries resolve against the post-redirect playlist URL.
  - Nested `.pls`/`.m3u` entries are resolved recursively, up to depth 3.
- **STRM-02, HLS:** a body that starts with `#EXTM3U` and has an `#EXT-X-` tag is played as HLS on the original URL. This holds whatever the extension or kind (`unknown`, `.m3u`), and ExoPlayer keeps variant selection. An `audio/*` answer (not the mpegurl/scpls types) is progressive, and its body is never read.
- **STRM-04, Dart half:**
  - `MediaHttpClient` is the only Dart client that may fetch `http://`, and it accepts only absolute http(s) URLs.
  - `AppHttpClient` accepts only `https` with a host. It follows redirects for GET/HEAD by hand, only to https targets and at most 5 hops. It has no production caller yet; that starts in Phase 2 as planned.
  - Both clients send exactly `eRadioto/<version> (Android; +https://github.com/ifchy/online-radio-app)`.
- **Engine wiring:** `RadioAudioHandler._start` publishes Connecting, then awaits `resolver.resolve(streams[0])`.
  - A resolution overtaken by a newer play, pause or stop is dropped, and the player loads `candidates.first` with its kind.
  - A resolution failure invalidates the stream and becomes `PlaybackError`. The error kind is `unsupportedFormat` for unsupportedScheme, notAPlaylist or empty, and `streamUnreachable` otherwise.
  - Player failures, a failed `load()` and a live stream that "completes" also invalidate the stream's cached resolution.
- **Resolver cache:** results are cached for 1 h per URL. Concurrent resolves share one request, and `invalidate()` also stops a resolution that is already running from refilling the cache.
- **Tests:** 61 tests in the plan's scope (parsers 9, resolver 27, handler 5, HTTP clients 19, tracer 1), and 101 in the whole suite. `flutter analyze` and `dart analyze` report no issues. No test touches the network.
- **Owner-check fixes kept:** `android/app/src/main/res/raw/keep.xml` was not touched. `_lastStation` resumption works: tracer step 8 passes through the resolver, and `getChildren(recentRootId)` is unchanged. bootstrap still logs `AudioService.asyncError`.

## Task Commits

1. **Task 1: Stations behind a .pls/.m3u playlist or an extension-less HLS URL play.** RED `4f8597c` (test), GREEN `441faa9` (feat)
2. **Task 2: App-owned traffic can never go over plain http, and both clients identify as eRadioto.** RED `ed3725a` (test), GREEN `97063da` (feat)

**Plan metadata:** see the `docs(01-04): complete ...` commit.

## TDD Gate Compliance

| Task | RED | GREEN | REFACTOR | Evidence |
|------|-----|-------|----------|----------|
| 1 | `4f8597c`: 39 of 42 failed (38 on assertions; 1 hit `lastLoad` on an empty load list because the stub never loaded). The 3 passes were the two negative HLS-sniff cases, which a `false` stub satisfies, and the unchanged tracer. | `441faa9` | not needed | `check tdd-red-evidence` -> RED_EVIDENCE_OK for 5 targets: FileN order, the extension-less HLS sniff, the 64 KB cap, the superseded resolve and the m3u handler load |
| 2 | `ed3725a`: 11 of 19 failed, all on assertions. The 8 passes were the `MediaHttpClient` cases (done in Task 1; the plan says "no behaviour change" for it in Task 2), the `buildUserAgent` value (from 01-01) and "POST redirect unchanged" (trivially true for a pass-through stub). | `97063da` | not needed | RED_EVIDENCE_OK for 4 targets: reject http://, no redirect to http, the 5-hop https redirects, and the https User-Agent |

As in 01-03, each RED run used `flutter test --reporter json`, converted line for line into TAP for the checker. Each RED commit contains only the compile scaffolding the tests need: the port types, stubs returning empty results, the new constructor parameter and the bootstrap wiring. The failures are therefore assertions, not compile errors.

## Files Created/Modified

- `lib/features/playback/engine/ports.dart`: adds `StreamResolver`, `StreamResolutionException` and `StreamResolutionFailure`.
- `lib/features/playback/engine/resolver/stream_resolver.dart`: `HttpStreamResolver` (routing, manual redirects, capped reads, sniffing, limits, cache, dedupe).
- `lib/features/playback/engine/resolver/pls_parser.dart`: `parsePls`.
- `lib/features/playback/engine/resolver/m3u_parser.dart`: `parseM3u` and `isHlsPlaylist`.
- `lib/features/playback/engine/resolver/playlist_text.dart`: BOM/CRLF line splitting and resolve-plus-dedupe, shared by both parsers.
- `lib/core/network/media_http_client.dart`: the http/https-only media client with the User-Agent.
- `lib/core/network/app_http_client.dart`: the HTTPS-only app client with https-only manual redirects.
- `lib/features/playback/engine/radio_audio_handler.dart`: a `StreamResolver` constructor parameter, resolve-before-load, the superseded-resolve guard, failure mapping and invalidation.
- `lib/app/bootstrap.dart`: builds `MediaHttpClient` and `HttpStreamResolver` and passes the resolver to the handler.
- `test/features/playback/engine/resolver/*`: parser and resolver tests (MockClient, MockClient.streaming, fakeAsync, a fake Clock).
- `test/features/playback/engine/radio_audio_handler_test.dart`: the new shared handler test file.
- `test/core/network/http_clients_test.dart`: tests for both clients and the exact User-Agent.
- `test/app/tracer_e2e_test.dart`: passes a resolver whose MockClient fails the test if it is ever called.

## Decisions Made

- **Redirects are followed by hand in both Dart clients.** See Deviation 1.
- **One 5 s deadline covers the whole resolution**, not each request. A slow redirect chain or nested playlist cannot add 5 s per hop.
- **A broken fallback entry does not sink the others.** A nested playlist that fails is skipped. Its error surfaces only when nothing playable is left, which is how `tooDeep` appears for a pure chain.
- **HTML and binary bodies are `notAPlaylist`.** Without this, an HTML error page would be parsed as an M3U of relative URLs and handed to ExoPlayer.
- **The station URL itself is scheme-checked.** A `progressive`/`hls` entry with an `rtsp:` or `file:` URL is rejected before the player.
- **`invalidate()` is race-safe.** It bumps a per-URL epoch and drops the in-flight entry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Manual redirect following instead of `followRedirects = true, maxRedirects = 5`**
- **Found during:** Task 1 (RED, while designing the redirect tests)
- **Issue:**
  - `MockClient` re-wraps every response as a plain `StreamedResponse`, so it can never report the final (post-redirect) URL through `BaseResponseWithUrl`, and it ignores `maxRedirects`.
  - The real `IOClient` reports a redirect-limit breach only as a `ClientException` whose one distinguishing feature is its message text.
  - So the plan's "M3U relative URL against the redirected base" and "too many redirects → tooManyRedirects" cases could not be tested or classified reliably with the plan's approach.
- **Fix:** `HttpStreamResolver._fetch` sends with `followRedirects = false`.
  - It follows 301/302/303/307/308 itself, up to `maxRedirects` (5), resolving each `Location` against the current URL.
  - Each hop must be http(s) with a host, otherwise the failure is `unsupportedScheme`.
  - The final hop's URL is the base for relative entries.
  - The limit and the truth ("5 redirects") are unchanged, and each hop now gets the allow-list check as well (T-04-02).
- **Files modified:** lib/features/playback/engine/resolver/stream_resolver.dart
- **Verification:** the tests "follows 5 redirects", "a 6th redirect fails as tooManyRedirects", "a redirect to a non-http(s) scheme fails as unsupportedScheme" and "M3U relative entry resolves against the redirected playlist URL" pass.
- **Committed in:** 441faa9

**2. [Rule 2 - Missing Critical] Resolution-wide deadline and nested-fetch budget**
- **Found during:** Task 1 (GREEN)
- **Issue:** With a 5 s timeout per request and up to 10 entries per playlist, the worst case at depth 3 was about 111 fetches and more than 9 minutes before failing. That breaks the "a slow server cannot hang the app" truth (T-04-01, T-04-04).
- **Fix:**
  - The 5 s timeout wraps the whole resolution, and on timeout every live body subscription is cancelled.
  - Nested playlist fetches share a budget of `maxCandidates` (10) per resolution.
- **Files modified:** lib/features/playback/engine/resolver/stream_resolver.dart
- **Verification:** the timeout test (fakeAsync: nothing at 4.9 s, `timeout` at 5.1 s) and the depth tests pass.
- **Committed in:** 441faa9

**3. [Rule 2 - Missing Critical] HTML/binary bodies rejected as notAPlaylist; station URL scheme-checked**
- **Found during:** Task 1 (GREEN)
- **Issue:**
  - An HTML error page served with 200 would have been parsed as M3U lines. `<html>` resolved against the base becomes an http URL, and that garbage would have been handed to ExoPlayer.
  - A catalogue `progressive` entry with a non-http(s) URL would also have reached the player unchecked.
- **Fix:** A body starting with `<` or containing NUL is `notAPlaylist`, which maps to `PlaybackError(unsupportedFormat)`. `resolve()` rejects a non-http(s) or host-less station URL as `unsupportedScheme` for every kind.
- **Files modified:** lib/features/playback/engine/resolver/stream_resolver.dart
- **Verification:** the tests "an HTML page is not a playlist" and "a non-http(s) station URL is rejected before anything else" pass.
- **Committed in:** 441faa9

**4. [Rule 1 - Bug] Race-safe invalidate and single invalidation on resolve failure**
- **Found during:** Task 1 (GREEN)
- **Issue:**
  - A resolution that was still in flight when `invalidate()` ran would afterwards have written its stale result into the cache.
  - Separately, the handler's resolve-failure path would have invalidated twice: once explicitly and once inside `_fail`.
- **Fix:**
  - `invalidate()` bumps a per-URL epoch and removes the in-flight entry. A completion stores its result only if the epoch is unchanged.
  - `_fail` takes `invalidate: false` on the resolve-failure path, which has already invalidated.
  - Player failures, a failed `load()` and a live stream that "completes" all invalidate through `_fail`.
- **Files modified:** lib/features/playback/engine/resolver/stream_resolver.dart, lib/features/playback/engine/radio_audio_handler.dart
- **Verification:** the handler tests assert exactly one invalidation on a failed resolve and one on a player failure.
- **Committed in:** 441faa9

**5. [Note] Small additions**
- `audio/scpls` is treated as a playlist type alongside the three the plan names.
- A cross-host redirect in `AppHttpClient` drops the `Authorization` and `Cookie` headers.
- `playlist_text.dart` was added as a shared helper for both parsers; it is not in the plan's file list.
- Bootstrap wiring landed in the RED commit so that commit still analyses cleanly. Its content is exactly the planned wiring.

---

**Total deviations:** 4 auto-fixed (1 Rule 3 blocking, 2 Rule 2 missing-critical, 1 Rule 1 bug) plus 1 note.
**Impact on plan:** All four serve the plan's own truths and threat mitigations (T-04-01, T-04-02, T-04-04). There is no scope creep: rotation across candidates and `streams[]` still belongs to 01-09, and the handler loads only `candidates.first`.

## Issues Encountered

None. Both GREEN implementations passed their suites on the first full run, apart from one `prefer_initializing_formals` lint, which was fixed before commit.

## Known Stubs

None. `AppHttpClient` has no production caller yet by design; the plan makes it the Phase 2 entry point for the catalogue and Radio Browser, and it is fully implemented and tested.

## Threat Flags

None beyond the plan's threat model. As accepted in T-04-06, the resolver does not block loopback or private-range playlist entries. Revisit that in Phase 2, when Radio Browser URLs reach the resolver.

## User Setup Required

None. No external service configuration is required.

## Next Phase Readiness

- 01-05 (curated stations) can set `kind: m3u` for N-JOY's wrapper and `kind: unknown` for the debug "Хоризонт (HLS sniff)" entry. The resolver handles both.
- 01-09 (reconnect and rotation) receives the full ordered `List<ResolvedStream>` from `resolve()` and can rotate across candidates and `streams[]`. `invalidate()` is already called on every failure path.
- For the end-of-phase UAT (D7): on the owner's phone, after 01-05, play N-JOY and Хоризонт in a release build, and the HLS-sniff entry in a debug build. All three should start within about 5 s.
- Phase 2: route the catalogue and Radio Browser fetches through `AppHttpClient`, and add loopback/private-range blocking to the resolver (T-04-06).

---
*Phase: 01-playback-engine-walking-skeleton*
*Completed: 2026-09-25*

## Self-Check: PASSED
