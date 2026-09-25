import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio/core/network/media_http_client.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/engine/ports.dart';
import 'package:radio/features/playback/engine/resolver/stream_resolver.dart';

const _ua =
    'eRadioto/test (Android; +https://github.com/ifchy/online-radio-app)';

StationStream _stream(String url, StreamKind kind) =>
    StationStream(url: Uri.parse(url), kind: kind);

ResolvedStream _progressive(String url) =>
    ResolvedStream(Uri.parse(url), PlayableKind.progressive);

ResolvedStream _hls(String url) =>
    ResolvedStream(Uri.parse(url), PlayableKind.hls);

Matcher _failsWith(StreamResolutionFailure reason) => throwsA(
  isA<StreamResolutionException>().having((e) => e.reason, 'reason', reason),
);

/// A server made of canned responses keyed by URL. Records every request.
class _Server {
  final Map<String, http.Response Function()> routes = {};
  final List<Uri> requests = [];

  void text(String url, String body, {String? contentType}) {
    routes[url] = () => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': ?contentType},
    );
  }

  void redirect(String url, String location, {int status = 302}) {
    routes[url] = () =>
        http.Response('', status, headers: {'location': location});
  }

  MockClient get client => MockClient((request) async {
    requests.add(request.url);
    final route = routes[request.url.toString()];
    if (route == null) return http.Response('not found', 404);
    return route();
  });
}

void main() {
  late _Server server;
  late DateTime now;
  late HttpStreamResolver resolver;

  HttpStreamResolver build(http.Client inner, {Duration? timeout}) =>
      HttpStreamResolver(
        MediaHttpClient(inner, _ua),
        Clock(() => now),
        timeout: timeout ?? const Duration(seconds: 5),
      );

  setUp(() {
    server = _Server();
    now = DateTime.utc(2026, 9, 25, 12);
    resolver = build(server.client);
  });

  group('catalogue kind wins', () {
    test('progressive returns one progressive candidate, no request', () async {
      final result = await resolver.resolve(
        _stream('http://play.example/bg128', StreamKind.progressive),
      );
      expect(result, [_progressive('http://play.example/bg128')]);
      expect(server.requests, isEmpty);
    });

    test('hls returns one hls candidate, no request', () async {
      final result = await resolver.resolve(
        _stream('https://cdn.example/live/playlist', StreamKind.hls),
      );
      expect(result, [_hls('https://cdn.example/live/playlist')]);
      expect(server.requests, isEmpty);
    });

    test('a non-http(s) station URL is rejected before anything else', () {
      expect(
        resolver.resolve(
          _stream('rtsp://x.example/live', StreamKind.progressive),
        ),
        _failsWith(StreamResolutionFailure.unsupportedScheme),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('playlists', () {
    test(
      'a PLS yields its entries in FileN order; .m3u8 entries are hls',
      () async {
        server.text(
          'http://radio.example/listen.pls',
          '﻿[playlist]\r\nFile10=http://c.example/ten.m3u8\r\n'
              'file1=http://a.example/one\r\nFile2=http://b.example/two\r\n',
          contentType: 'audio/x-scpls',
        );
        final result = await resolver.resolve(
          _stream('http://radio.example/listen.pls', StreamKind.pls),
        );
        expect(result, [
          _progressive('http://a.example/one'),
          _progressive('http://b.example/two'),
          _hls('http://c.example/ten.m3u8'),
        ]);
      },
    );

    test(
      'an M3U relative entry resolves against the redirected playlist URL',
      () async {
        server.redirect(
          'http://radio.example/njoy.m3u',
          'https://cdn.example/redirected/njoy.m3u',
        );
        server.text(
          'https://cdn.example/redirected/njoy.m3u',
          '#EXTM3U\n#EXTINF:-1,N-JOY\nlive/njoy.mp3\n',
          contentType: 'audio/x-mpegurl',
        );
        final result = await resolver.resolve(
          _stream('http://radio.example/njoy.m3u', StreamKind.m3u),
        );
        expect(result, [
          _progressive('https://cdn.example/redirected/live/njoy.mp3'),
        ]);
        expect(server.requests, [
          Uri.parse('http://radio.example/njoy.m3u'),
          Uri.parse('https://cdn.example/redirected/njoy.m3u'),
        ]);
      },
    );

    test('an extension-less HLS body sniffed for kind unknown plays as hls on '
        'the ORIGINAL URL', () async {
      server.redirect(
        'https://cdn.example/horizont/live',
        'https://edge7.cdn.example/horizont/live?token=abc',
      );
      server.text(
        'https://edge7.cdn.example/horizont/live?token=abc',
        '#EXTM3U\n#EXT-X-VERSION:3\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=128000\nchunklist_b128000.m3u8\n',
        contentType: 'application/vnd.apple.mpegurl',
      );
      final result = await resolver.resolve(
        _stream('https://cdn.example/horizont/live', StreamKind.unknown),
      );
      expect(result, [_hls('https://cdn.example/horizont/live')]);
    });

    test('HLS served as .m3u is sniffed and played as hls', () async {
      server.text(
        'http://radio.example/hls.m3u',
        '#EXTM3U\n#EXT-X-TARGETDURATION:10\n#EXTINF:10,\nseg1.aac\n',
      );
      final result = await resolver.resolve(
        _stream('http://radio.example/hls.m3u', StreamKind.m3u),
      );
      expect(result, [_hls('http://radio.example/hls.m3u')]);
    });

    test(
      'drops file:, content:, javascript:, intent: and rtsp: entries',
      () async {
        server.text(
          'http://radio.example/mixed.m3u',
          'file:///sdcard/evil.mp3\n'
              'content://media/external/audio/1\n'
              'javascript:alert(1)\n'
              'intent://x#Intent;scheme=evil;end\n'
              'rtsp://x.example/live\n'
              'http://ok.example/stream\n',
        );
        final result = await resolver.resolve(
          _stream('http://radio.example/mixed.m3u', StreamKind.m3u),
        );
        expect(result, [_progressive('http://ok.example/stream')]);
      },
    );

    test('a playlist with no playable http(s) entry fails as empty', () {
      server.text(
        'http://radio.example/bad.pls',
        '[playlist]\nFile1=file:///etc/passwd\nFile2=content://x/y\n',
      );
      expect(
        resolver.resolve(
          _stream('http://radio.example/bad.pls', StreamKind.pls),
        ),
        _failsWith(StreamResolutionFailure.empty),
      );
    });

    test('an HTML page is not a playlist', () {
      server.text(
        'http://radio.example/page',
        '<!doctype html><html><body>Listen</body></html>',
        contentType: 'text/html',
      );
      expect(
        resolver.resolve(
          _stream('http://radio.example/page', StreamKind.unknown),
        ),
        _failsWith(StreamResolutionFailure.notAPlaylist),
      );
    });

    test('returns at most 10 candidates', () async {
      server.text(
        'http://radio.example/many.m3u',
        [for (var i = 1; i <= 15; i++) 'http://s$i.example/live'].join('\n'),
      );
      final result = await resolver.resolve(
        _stream('http://radio.example/many.m3u', StreamKind.m3u),
      );
      expect(result, [
        for (var i = 1; i <= 10; i++) _progressive('http://s$i.example/live'),
      ]);
    });

    test('nested playlists resolve up to depth 3', () async {
      server.text('http://r.example/1.m3u', 'http://r.example/2.pls\n');
      server.text(
        'http://r.example/2.pls',
        '[playlist]\nFile1=http://r.example/3.m3u\n',
      );
      server.text('http://r.example/3.m3u', 'http://r.example/audio.mp3\n');
      final result = await resolver.resolve(
        _stream('http://r.example/1.m3u', StreamKind.m3u),
      );
      expect(result, [_progressive('http://r.example/audio.mp3')]);
    });

    test('nesting deeper than 3 fails as tooDeep', () {
      server.text('http://r.example/1.m3u', 'http://r.example/2.m3u\n');
      server.text('http://r.example/2.m3u', 'http://r.example/3.m3u\n');
      server.text('http://r.example/3.m3u', 'http://r.example/4.m3u\n');
      server.text('http://r.example/4.m3u', 'http://r.example/audio.mp3\n');
      expect(
        resolver.resolve(_stream('http://r.example/1.m3u', StreamKind.m3u)),
        _failsWith(StreamResolutionFailure.tooDeep),
      );
    });

    test('a non-2xx playlist response fails as httpStatus', () {
      expect(
        resolver.resolve(
          _stream('http://radio.example/gone.pls', StreamKind.pls),
        ),
        _failsWith(StreamResolutionFailure.httpStatus),
      );
    });

    test('a connection error fails as network', () {
      final failing = build(
        MockClient((_) async => throw http.ClientException('refused')),
      );
      expect(
        failing.resolve(_stream('http://radio.example/x.pls', StreamKind.pls)),
        _failsWith(StreamResolutionFailure.network),
      );
    });
  });

  group('audio/* short-circuit', () {
    for (final kind in [StreamKind.unknown, StreamKind.m3u]) {
      test('an audio/mpeg answer for kind ${kind.name} is progressive on the '
          'original URL and the body is not read', () async {
        var cancelled = false;
        final body = StreamController<List<int>>(
          onCancel: () => cancelled = true,
        );
        // Looks like a playlist: if the resolver read it, the result would
        // differ.
        body.add(utf8.encode('[playlist]\nFile1=http://other.example/x\n'));
        final client = MockClient.streaming((request, _) async {
          return http.StreamedResponse(
            body.stream,
            200,
            headers: {'content-type': 'audio/mpeg'},
          );
        });
        final result = await build(client)
            .resolve(_stream('http://radio.example/live', kind));
        expect(result, [_progressive('http://radio.example/live')]);
        expect(cancelled, isTrue);
      });
    }

    test('audio/x-mpegurl is a playlist type and is parsed', () async {
      server.text(
        'http://radio.example/list',
        'http://a.example/one\n',
        contentType: 'audio/x-mpegurl',
      );
      final result = await resolver.resolve(
        _stream('http://radio.example/list', StreamKind.unknown),
      );
      expect(result, [_progressive('http://a.example/one')]);
    });
  });

  group('limits', () {
    test('an endless body over 65536 bytes fails as tooLarge and the '
        'subscription is cancelled', () async {
      var cancelled = false;
      late StreamController<List<int>> body;
      body = StreamController<List<int>>(
        onListen: () {
          for (var i = 0; i < 70; i++) {
            body.add(List<int>.filled(1024, 0x41));
          }
          // Never closed: the server keeps sending.
        },
        onCancel: () => cancelled = true,
      );
      final client = MockClient.streaming(
        (request, _) async => http.StreamedResponse(body.stream, 200),
      );
      await expectLater(
        build(client)
            .resolve(_stream('http://radio.example/huge.m3u', StreamKind.m3u)),
        _failsWith(StreamResolutionFailure.tooLarge),
      );
      expect(cancelled, isTrue);
    });

    test('no response within 5 s fails as timeout', () {
      fakeAsync((async) {
        final client = MockClient((_) => Completer<http.Response>().future);
        final slow = build(client);
        Object? error;
        slow
            .resolve(_stream('http://radio.example/slow.pls', StreamKind.pls))
            .then(
              (_) {},
              onError: (Object e) {
                error = e;
              },
            );
        async.elapse(const Duration(milliseconds: 4900));
        expect(error, isNull);
        async.elapse(const Duration(milliseconds: 200));
        expect(
          error,
          isA<StreamResolutionException>().having(
            (e) => e.reason,
            'reason',
            StreamResolutionFailure.timeout,
          ),
        );
      });
    });

    test('follows 5 redirects', () async {
      for (var i = 0; i < 5; i++) {
        server.redirect('http://r.example/$i', 'http://r.example/${i + 1}');
      }
      server.text('http://r.example/5', 'http://audio.example/live\n');
      final result = await resolver.resolve(
        _stream('http://r.example/0', StreamKind.unknown),
      );
      expect(result, [_progressive('http://audio.example/live')]);
      expect(server.requests, hasLength(6));
    });

    test('a 6th redirect fails as tooManyRedirects', () async {
      for (var i = 0; i < 6; i++) {
        server.redirect('http://r.example/$i', 'http://r.example/${i + 1}');
      }
      server.text('http://r.example/6', 'http://audio.example/live\n');
      await expectLater(
        resolver.resolve(_stream('http://r.example/0', StreamKind.unknown)),
        _failsWith(StreamResolutionFailure.tooManyRedirects),
      );
      expect(server.requests, hasLength(6));
    });

    test('a redirect to a non-http(s) scheme fails as unsupportedScheme', () {
      server.redirect('http://r.example/list.m3u', 'file:///sdcard/list.m3u');
      expect(
        resolver.resolve(_stream('http://r.example/list.m3u', StreamKind.m3u)),
        _failsWith(StreamResolutionFailure.unsupportedScheme),
      );
    });
  });

  group('cache', () {
    const url = 'http://radio.example/cached.pls';
    final stream = _stream(url, StreamKind.pls);

    setUp(() {
      server.text(url, '[playlist]\nFile1=http://a.example/one\n');
    });

    test('a second resolve within 1 h makes no request', () async {
      await resolver.resolve(stream);
      now = now.add(const Duration(minutes: 59));
      final second = await resolver.resolve(stream);
      expect(second, [_progressive('http://a.example/one')]);
      expect(server.requests, hasLength(1));
    });

    test('after 1 h the playlist is fetched again', () async {
      await resolver.resolve(stream);
      now = now.add(const Duration(hours: 1, seconds: 1));
      await resolver.resolve(stream);
      expect(server.requests, hasLength(2));
    });

    test('invalidate() forces a refetch', () async {
      await resolver.resolve(stream);
      resolver.invalidate(stream);
      await resolver.resolve(stream);
      expect(server.requests, hasLength(2));
    });

    test('two concurrent resolves of the same URL make one request', () async {
      final gate = Completer<void>();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        await gate.future;
        return http.Response('[playlist]\nFile1=http://a.example/one\n', 200);
      });
      final shared = build(client);
      final first = shared.resolve(stream);
      final second = shared.resolve(stream);
      gate.complete();
      final results = await Future.wait([first, second]);
      expect(requests, 1);
      expect(results[0], [_progressive('http://a.example/one')]);
      expect(results[1], results[0]);
      await shared.resolve(stream);
      expect(requests, 1);
    });
  });
}
