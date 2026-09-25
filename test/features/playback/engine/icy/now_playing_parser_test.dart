import 'package:flutter_test/flutter_test.dart';
import 'package:radio/core/text/icy_charset.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/now_playing.dart';
import 'package:radio/features/playback/engine/icy/now_playing_parser.dart';

final _station = Station(
  id: StationId.curated('bg-radio'),
  name: 'БГ Радио',
  nameLatin: 'BG Radio',
  streams: [
    StationStream(
      url: Uri.parse('http://play.global.audio/bgradio128'),
      kind: StreamKind.progressive,
    ),
  ],
);

NowPlaying? _parse(String? raw, {IcyCharset charset = IcyCharset.auto}) =>
    parseIcyTitle(raw, station: _station, charset: charset);

void main() {
  group('parseIcyTitle split', () {
    test("'Artist - Title' becomes artist and title", () {
      expect(
        _parse('Artist - Title'),
        const NowPlaying(
          artist: 'Artist',
          title: 'Title',
          text: 'Artist - Title',
        ),
      );
    });

    test('a title without " - " becomes a title only', () {
      expect(
        _parse('Only Title'),
        const NowPlaying(title: 'Only Title', text: 'Only Title'),
      );
    });

    test('only the first " - " splits', () {
      expect(
        _parse('Artist - Song - Radio Edit'),
        const NowPlaying(
          artist: 'Artist',
          title: 'Song - Radio Edit',
          text: 'Artist - Song - Radio Edit',
        ),
      );
    });

    test('a hyphen inside a word does not split', () {
      expect(
        _parse('Jay-Z'),
        const NowPlaying(title: 'Jay-Z', text: 'Jay-Z'),
      );
    });

    test("a dangling 'Artist - ' becomes a title only", () {
      expect(
        _parse('Artist - '),
        const NowPlaying(title: 'Artist', text: 'Artist'),
      );
    });

    test("a dangling ' - Title' becomes a title only", () {
      expect(
        _parse(' - Title'),
        const NowPlaying(title: 'Title', text: 'Title'),
      );
    });

    test('the same title parses to an equal value', () {
      final a = _parse('Artist - Title');
      final b = _parse('  Artist   -  Title ');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('parseIcyTitle junk filter', () {
    for (final (label, raw) in [
      ('null', null),
      ('empty', ''),
      ('whitespace', '  '),
      ('a lone dash', '-'),
      ('a lone separator', ' - '),
      ('the station name', 'БГ Радио'),
      ('the station name in another case', 'бг радио'),
      ('the Latin station name', 'BG Radio'),
      ('the Latin station name in another case', 'bg RADIO'),
      ('a www address', 'www.bgradio.bg'),
      ('an upper-case www address', 'WWW.BGRADIO.BG'),
      ('a URL', 'https://x.y'),
      ('a URL inside text', 'Listen at http://bgradio.bg now'),
      ('only control characters', '\u0000\u0007\u001F'),
    ]) {
      test('$label produces no now-playing value', () {
        expect(_parse(raw), isNull);
      });
    }

    test('the station name sent as cp1251 mojibake is still junk', () {
      expect(_parse('ÁÃ Ðàäèî'), isNull);
    });
  });

  group('parseIcyTitle repair and sanitising', () {
    test('a cp1251 mojibake title becomes Cyrillic artist and title', () {
      expect(
        _parse('Àðòèñò - Ïåñåí', charset: IcyCharset.cp1251),
        const NowPlaying(
          artist: 'Артист',
          title: 'Песен',
          text: 'Артист - Песен',
        ),
      );
    });

    test('cp1251 punctuation „ “ – survives the whole pipeline', () {
      expect(
        _parse(
          'Àðòèñò - \u0084Ïúðâà\u0093 \u0096 Âòîðà',
          charset: IcyCharset.cp1251,
        ),
        const NowPlaying(
          artist: 'Артист',
          title: '„Първа“ – Втора',
          text: 'Артист - „Първа“ – Втора',
        ),
      );
    });

    test('auto repairs an obvious cp1251 title too', () {
      expect(_parse('Àðòèñò - Ïåñåí')?.artist, 'Артист');
    });

    test('utf8 keeps the text as delivered', () {
      expect(
        _parse('Mötley Crüe - Kickstart My Heart', charset: IcyCharset.utf8),
        const NowPlaying(
          artist: 'Mötley Crüe',
          title: 'Kickstart My Heart',
          text: 'Mötley Crüe - Kickstart My Heart',
        ),
      );
    });

    test('a bidi override and a trailing newline are removed', () {
      expect(
        _parse('Artist - \u202ETitle\n'),
        const NowPlaying(
          artist: 'Artist',
          title: 'Title',
          text: 'Artist - Title',
        ),
      );
    });

    test('a huge title is clamped to 200 code points', () {
      final result = _parse('a' * 5000);
      expect(result?.text.runes.length, 200);
      expect(result?.title, 'a' * 200);
    });
  });
}
