import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import '../../../../core/network/media_http_client.dart';
import '../../../catalog/domain/station.dart';
import '../ports.dart';
import 'm3u_parser.dart';
import 'pls_parser.dart';

/// Content types that name a playlist, not audio, even though they start
/// with `audio/`.
const _playlistAudioTypes = {
  'audio/x-mpegurl',
  'audio/mpegurl',
  'audio/x-scpls',
  'audio/scpls',
};

const _redirectStatuses = {301, 302, 303, 307, 308};

/// Resolves catalogue streams into directly playable endpoints (RESEARCH
/// Pattern 4, ARCHITECTURE Pattern 6).
///
/// - The catalogue kind wins: `progressive` and `hls` are returned as they are,
///   with no network.
/// - `pls`, `m3u` and `unknown` are fetched once through [MediaHttpClient]
///   and inspected: an `audio/*` answer is a progressive stream (the body is
///   never read), an HLS body plays as HLS on the ORIGINAL URL, and a PLS or
///   M3U list yields its entries in order.
/// - Hard input limits: [timeout] for the whole resolution, [maxBytes] per
///   body (then the subscription is cancelled), [maxRedirects] per fetch,
///   [maxDepth] nested playlists, [maxCandidates] results, and only `http` /
///   `https` URLs ever reach the player.
/// - Results are cached in memory for [ttl] per stream URL, concurrent
///   resolutions of one URL share a single request, and [invalidate] drops
///   the cache entry after a playback failure.
///
/// Audio streams are never probed from Dart: `dart:io` rejects Shoutcast's
/// `ICY 200 OK` status line, and a live stream body never ends (Pitfall 7).
class HttpStreamResolver implements StreamResolver {
  HttpStreamResolver(
    this._client,
    this._clock, {
    this.ttl = const Duration(hours: 1),
    this.timeout = const Duration(seconds: 5),
    this.maxBytes = 65536,
    this.maxDepth = 3,
    this.maxCandidates = 10,
    this.maxRedirects = 5,
  });

  final MediaHttpClient _client;
  final Clock _clock;
  final Duration ttl;
  final Duration timeout;
  final int maxBytes;
  final int maxDepth;
  final int maxCandidates;
  final int maxRedirects;

  final Map<Uri, ({DateTime expiresAt, List<ResolvedStream> result})> _cache =
      {};
  final Map<Uri, Future<List<ResolvedStream>>> _inFlight = {};

  /// Bumped by [invalidate], so a resolution that was already running when
  /// its stream failed does not refill the cache with the stale result.
  final Map<Uri, int> _epochs = {};

  @override
  Future<List<ResolvedStream>> resolve(StationStream stream) async {
    final url = stream.url;
    if (!_isPlayableUrl(url)) {
      throw StreamResolutionException(
        StreamResolutionFailure.unsupportedScheme,
        '$url',
      );
    }
    switch (stream.kind) {
      case StreamKind.progressive:
        return [ResolvedStream(url, PlayableKind.progressive)];
      case StreamKind.hls:
        return [ResolvedStream(url, PlayableKind.hls)];
      case StreamKind.pls || StreamKind.m3u || StreamKind.unknown:
        break;
    }

    final cached = _cache[url];
    if (cached != null) {
      if (_clock.now().isBefore(cached.expiresAt)) return cached.result;
      _cache.remove(url);
    }

    final pending = _inFlight[url];
    if (pending != null) return pending;

    final epoch = _epochs[url] ?? 0;
    final future = _resolveFresh(url);
    _inFlight[url] = future;
    try {
      final result = await future;
      if ((_epochs[url] ?? 0) == epoch) {
        _cache[url] = (expiresAt: _clock.now().add(ttl), result: result);
      }
      return result;
    } finally {
      if (identical(_inFlight[url], future)) _inFlight.remove(url);
    }
  }

  @override
  void invalidate(StationStream stream) {
    final url = stream.url;
    _cache.remove(url);
    _inFlight.remove(url);
    _epochs[url] = (_epochs[url] ?? 0) + 1;
  }

  Future<List<ResolvedStream>> _resolveFresh(Uri url) async {
    final run = _Run(maxCandidates);
    try {
      final result = await _resolvePlaylist(url, 1, run).timeout(timeout);
      return List.unmodifiable(result);
    } on TimeoutException {
      throw const StreamResolutionException(StreamResolutionFailure.timeout);
    } finally {
      run.close();
    }
  }

  Future<List<ResolvedStream>> _resolvePlaylist(
    Uri url,
    int depth,
    _Run run,
  ) async {
    if (depth > maxDepth) {
      throw StreamResolutionException(StreamResolutionFailure.tooDeep, '$url');
    }
    final fetched = await _fetch(url, run);
    final String text;
    final Uri base;
    switch (fetched) {
      case _Audio():
        return [ResolvedStream(url, PlayableKind.progressive)];
      case _Body(:final body, :final finalUrl):
        text = body;
        base = finalUrl;
    }

    if (isHlsPlaylist(text)) {
      // ExoPlayer follows the redirects and picks the variant itself.
      return [ResolvedStream(url, PlayableKind.hls)];
    }
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('<') || text.contains('\u0000')) {
      throw StreamResolutionException(
        StreamResolutionFailure.notAPlaylist,
        '$url',
      );
    }
    final entries = text.toLowerCase().contains('[playlist]')
        ? parsePls(text, base)
        : parseM3u(text, base);

    final candidates = <ResolvedStream>[];
    StreamResolutionException? nestedFailure;
    void add(ResolvedStream candidate) {
      if (candidates.length < maxCandidates &&
          !candidates.contains(candidate)) {
        candidates.add(candidate);
      }
    }

    for (final entry in entries) {
      if (candidates.length >= maxCandidates) break;
      if (!_isPlayableUrl(entry)) continue;
      final path = entry.path.toLowerCase();
      if (path.endsWith('.m3u8')) {
        add(ResolvedStream(entry, PlayableKind.hls));
      } else if (path.endsWith('.pls') || path.endsWith('.m3u')) {
        if (!run.takeFetch()) continue;
        try {
          (await _resolvePlaylist(entry, depth + 1, run)).forEach(add);
        } on StreamResolutionException catch (e) {
          // One broken fallback entry must not sink the others.
          nestedFailure ??= e;
        }
      } else {
        add(ResolvedStream(entry, PlayableKind.progressive));
      }
    }

    if (candidates.isEmpty) {
      throw nestedFailure ??
          StreamResolutionException(StreamResolutionFailure.empty, '$url');
    }
    return candidates;
  }

  /// GETs [url], following at most [maxRedirects] redirects by hand so every
  /// hop is checked against the scheme allow-list and the final URL is known
  /// for resolving relative entries.
  Future<_Fetched> _fetch(Uri url, _Run run) async {
    var current = url;
    for (var redirects = 0; ; redirects++) {
      final request = http.Request('GET', current)..followRedirects = false;
      final http.StreamedResponse response;
      try {
        response = await _client.send(request);
      } catch (e) {
        throw StreamResolutionException(StreamResolutionFailure.network, '$e');
      }
      if (run.closed) {
        await _discard(response);
        throw const StreamResolutionException(StreamResolutionFailure.timeout);
      }

      final status = response.statusCode;
      final location = response.headers['location'];
      if (_redirectStatuses.contains(status) && location != null) {
        await _discard(response);
        if (redirects >= maxRedirects) {
          throw StreamResolutionException(
            StreamResolutionFailure.tooManyRedirects,
            '$url',
          );
        }
        final Uri next;
        try {
          next = current.resolve(location.trim());
        } on FormatException {
          throw StreamResolutionException(
            StreamResolutionFailure.network,
            'Bad redirect location: $location',
          );
        }
        if (!_isPlayableUrl(next)) {
          throw StreamResolutionException(
            StreamResolutionFailure.unsupportedScheme,
            '$next',
          );
        }
        current = next;
        continue;
      }

      if (status < 200 || status >= 300) {
        await _discard(response);
        throw StreamResolutionException(
          StreamResolutionFailure.httpStatus,
          '$status $current',
        );
      }

      if (_isAudio(response.headers['content-type'])) {
        // A live stream: never read its body.
        await _discard(response);
        return const _Audio();
      }
      final bytes = await _readCapped(response.stream, run);
      return _Body(utf8.decode(bytes, allowMalformed: true), current);
    }
  }

  Future<Uint8List> _readCapped(Stream<List<int>> stream, _Run run) {
    final completer = Completer<Uint8List>();
    final bytes = BytesBuilder(copy: false);
    late final StreamSubscription<List<int>> subscription;
    subscription = stream.listen(
      (chunk) {
        if (bytes.length + chunk.length > maxBytes) {
          run.untrack(subscription);
          unawaited(subscription.cancel());
          if (!completer.isCompleted) {
            completer.completeError(
              StreamResolutionException(
                StreamResolutionFailure.tooLarge,
                'more than $maxBytes bytes',
              ),
            );
          }
          return;
        }
        bytes.add(chunk);
      },
      onError: (Object e) {
        run.untrack(subscription);
        if (!completer.isCompleted) {
          completer.completeError(
            StreamResolutionException(StreamResolutionFailure.network, '$e'),
          );
        }
      },
      onDone: () {
        run.untrack(subscription);
        if (!completer.isCompleted) completer.complete(bytes.takeBytes());
      },
      cancelOnError: true,
    );
    run.track(subscription);
    return completer.future;
  }

  static Future<void> _discard(http.StreamedResponse response) =>
      response.stream.listen(null).cancel();

  static bool _isAudio(String? contentType) {
    if (contentType == null) return false;
    final mime = contentType.split(';').first.trim().toLowerCase();
    return mime.startsWith('audio/') && !_playlistAudioTypes.contains(mime);
  }

  static bool _isPlayableUrl(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

sealed class _Fetched {
  const _Fetched();
}

/// The server answered with an audio content type.
final class _Audio extends _Fetched {
  const _Audio();
}

/// A (capped) text body and the URL it came from after redirects.
final class _Body extends _Fetched {
  const _Body(this.body, this.finalUrl);

  final String body;
  final Uri finalUrl;
}

/// State shared by one resolution: the nested-fetch budget and the body
/// subscriptions to cancel when it times out.
final class _Run {
  _Run(this._fetchBudget);

  int _fetchBudget;
  bool closed = false;
  final Set<StreamSubscription<List<int>>> _live = {};

  bool takeFetch() {
    if (_fetchBudget <= 0) return false;
    _fetchBudget--;
    return true;
  }

  void track(StreamSubscription<List<int>> subscription) {
    if (closed) {
      unawaited(subscription.cancel());
    } else {
      _live.add(subscription);
    }
  }

  void untrack(StreamSubscription<List<int>> subscription) =>
      _live.remove(subscription);

  void close() {
    closed = true;
    for (final subscription in _live) {
      unawaited(subscription.cancel());
    }
    _live.clear();
  }
}
