import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio/core/network/app_http_client.dart';
import 'package:radio/core/network/media_http_client.dart';
import 'package:radio/core/network/user_agent.dart';

const _expectedUserAgent =
    'eRadioto/1.2.3 (Android; +https://github.com/ifchy/online-radio-app)';

/// A MockClient that records every request it receives and answers from
/// [respond] (200 "ok" by default).
class _Recorder {
  _Recorder([http.Response Function(http.Request)? respond])
    : _respond = respond ?? ((_) => http.Response('ok', 200));

  final http.Response Function(http.Request) _respond;
  final List<http.Request> requests = [];

  MockClient get client => MockClient((request) async {
    requests.add(request);
    return _respond(request);
  });
}

http.Response Function(http.Request) _redirectChain(
  int hops, {
  String scheme = 'https',
}) => (request) {
  final step = int.parse(request.url.pathSegments.last);
  if (step < hops) {
    return http.Response(
      '',
      302,
      headers: {'location': '$scheme://api.example/hop/${step + 1}'},
    );
  }
  return http.Response('final', 200);
};

void main() {
  final userAgent = buildUserAgent('1.2.3');

  test('the User-Agent is exactly name, version, platform and project URL', () {
    expect(userAgent, _expectedUserAgent);
  });

  group('AppHttpClient', () {
    test('forwards https:// with the eRadioto User-Agent', () async {
      final recorder = _Recorder();
      final client = AppHttpClient(recorder.client, userAgent);
      final response = await client.get(Uri.parse('https://x.example/y'));
      expect(response.body, 'ok');
      expect(recorder.requests.single.url, Uri.parse('https://x.example/y'));
      expect(
        recorder.requests.single.headers['User-Agent'],
        _expectedUserAgent,
      );
    });

    test('accepts an upper-case HTTPS scheme', () async {
      final recorder = _Recorder();
      final client = AppHttpClient(recorder.client, userAgent);
      await client.get(Uri.parse('HTTPS://x.example/y'));
      expect(recorder.requests.single.url.scheme, 'https');
      expect(
        recorder.requests.single.headers['User-Agent'],
        _expectedUserAgent,
      );
    });

    for (final url in [
      'http://x.example/y',
      'ftp://x.example',
      '/relative/path',
      '',
      'https:///no-host',
    ]) {
      test('rejects "$url" and sends nothing', () async {
        final recorder = _Recorder();
        final client = AppHttpClient(recorder.client, userAgent);
        await expectLater(client.get(Uri.parse(url)), throwsArgumentError);
        expect(recorder.requests, isEmpty);
      });
    }

    test('does not follow a redirect to http://', () async {
      final recorder = _Recorder(_redirectChain(1, scheme: 'http'));
      final client = AppHttpClient(recorder.client, userAgent);
      await expectLater(
        client.get(Uri.parse('https://api.example/hop/0')),
        throwsArgumentError,
      );
      expect(recorder.requests.map((r) => r.url.scheme), ['https']);
      expect(recorder.requests.single.followRedirects, isFalse);
    });

    test('follows 5 https redirects for GET', () async {
      final recorder = _Recorder(_redirectChain(5));
      final client = AppHttpClient(recorder.client, userAgent);
      final response = await client.get(Uri.parse('https://api.example/hop/0'));
      expect(response.statusCode, 200);
      expect(response.body, 'final');
      expect(recorder.requests, hasLength(6));
      expect(recorder.requests.map((r) => r.headers['User-Agent']).toSet(), {
        _expectedUserAgent,
      });
    });

    test('follows https redirects for HEAD', () async {
      final recorder = _Recorder(_redirectChain(2));
      final client = AppHttpClient(recorder.client, userAgent);
      final response = await client.head(
        Uri.parse('https://api.example/hop/0'),
      );
      expect(response.statusCode, 200);
      expect(recorder.requests.map((r) => r.method).toSet(), {'HEAD'});
      expect(recorder.requests, hasLength(3));
    });

    test('throws after 5 redirects', () async {
      final recorder = _Recorder(_redirectChain(6));
      final client = AppHttpClient(recorder.client, userAgent);
      await expectLater(
        client.get(Uri.parse('https://api.example/hop/0')),
        throwsA(isA<http.ClientException>()),
      );
      expect(recorder.requests, hasLength(6));
    });

    test('returns a redirect to a POST unchanged', () async {
      final recorder = _Recorder(_redirectChain(1));
      final client = AppHttpClient(recorder.client, userAgent);
      final response = await client.post(
        Uri.parse('https://api.example/hop/0'),
      );
      expect(response.statusCode, 302);
      expect(recorder.requests, hasLength(1));
    });
  });

  group('MediaHttpClient', () {
    for (final url in [
      'http://radio.example/list.pls',
      'https://x.example/y',
    ]) {
      test('forwards $url with the eRadioto User-Agent', () async {
        final recorder = _Recorder();
        final client = MediaHttpClient(recorder.client, userAgent);
        await client.get(Uri.parse(url));
        expect(recorder.requests.single.url, Uri.parse(url));
        expect(
          recorder.requests.single.headers['User-Agent'],
          _expectedUserAgent,
        );
      });
    }

    for (final url in [
      'file:///sdcard/list.m3u',
      'content://media/external/audio/1',
      'relative/list.pls',
      'http:///no-host',
    ]) {
      test('rejects "$url" and sends nothing', () async {
        final recorder = _Recorder();
        final client = MediaHttpClient(recorder.client, userAgent);
        await expectLater(client.get(Uri.parse(url)), throwsArgumentError);
        expect(recorder.requests, isEmpty);
      });
    }
  });
}
