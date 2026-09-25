import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/playback/engine/resolver/m3u_parser.dart';
import 'package:radio/features/playback/engine/resolver/pls_parser.dart';

final _base = Uri.parse('https://radio.example/lists/station.pls');

void main() {
  group('parsePls', () {
    test('BOM, CRLF, mixed-case FileN keys and no NumberOfEntries', () {
      const body =
          '﻿[playlist]\r\n'
          'file1=http://a.example/one\r\n'
          'Title1=One\r\n'
          'File2=http://b.example/two\r\n'
          'FILE10=http://c.example/ten\r\n'
          'Version=2\r\n';
      expect(parsePls(body, _base), [
        Uri.parse('http://a.example/one'),
        Uri.parse('http://b.example/two'),
        Uri.parse('http://c.example/ten'),
      ]);
    });

    test('orders entries by the numeric FileN index, so File2 is before '
        'File10', () {
      const body =
          '[playlist]\n'
          'File10=http://x.example/10\n'
          'File2=http://x.example/2\n'
          'File1=http://x.example/1\n';
      expect(parsePls(body, _base), [
        Uri.parse('http://x.example/1'),
        Uri.parse('http://x.example/2'),
        Uri.parse('http://x.example/10'),
      ]);
    });

    test('keeps a duplicate URL once, at its first position', () {
      const body =
          '[playlist]\n'
          'File1=http://x.example/a\n'
          'File2=http://x.example/b\n'
          'File3=http://x.example/a\n';
      expect(parsePls(body, _base), [
        Uri.parse('http://x.example/a'),
        Uri.parse('http://x.example/b'),
      ]);
    });

    test('trims values and resolves relative entries against the base', () {
      const body =
          '[playlist]\n'
          'File1=  stream.mp3  \n'
          'File2=/root.aac\n';
      expect(parsePls(body, _base), [
        Uri.parse('https://radio.example/lists/stream.mp3'),
        Uri.parse('https://radio.example/root.aac'),
      ]);
    });
  });

  group('parseM3u', () {
    test('returns the non-# lines in order and skips #EXTINF', () {
      const body =
          '#EXTM3U\r\n'
          '#EXTINF:-1,Station One\r\n'
          'http://a.example/one\r\n'
          '\r\n'
          '#EXTINF:-1,Station Two\r\n'
          'http://b.example/two\r\n';
      expect(parseM3u(body, _base), [
        Uri.parse('http://a.example/one'),
        Uri.parse('http://b.example/two'),
      ]);
    });

    test('resolves a relative entry against the base and dedupes', () {
      const body =
          'live/stream.mp3\n'
          'http://a.example/one\n'
          'live/stream.mp3\n';
      final base = Uri.parse('https://cdn.example/redirected/list.m3u');
      expect(parseM3u(body, base), [
        Uri.parse('https://cdn.example/redirected/live/stream.mp3'),
        Uri.parse('http://a.example/one'),
      ]);
    });
  });

  group('isHlsPlaylist', () {
    test('true for #EXTM3U followed by an #EXT-X- tag', () {
      const body =
          '﻿\r\n#EXTM3U\r\n#EXT-X-VERSION:3\r\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=128000\r\nchunklist.m3u8\r\n';
      expect(isHlsPlaylist(body), isTrue);
    });

    test('false for a plain extended M3U', () {
      const body = '#EXTM3U\n#EXTINF:-1,One\nhttp://a.example/one\n';
      expect(isHlsPlaylist(body), isFalse);
    });

    test('false when #EXTM3U is not the first non-empty line', () {
      const body = 'http://a.example/one\n#EXTM3U\n#EXT-X-VERSION:3\n';
      expect(isHlsPlaylist(body), isFalse);
    });
  });
}
