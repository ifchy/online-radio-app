// The media-ID scheme (01-RESEARCH Pattern 6) shared by the phone UI, the
// media session and (v1.1) the Android Auto browse tree.
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/media_id.dart';

void main() {
  group('round trip through parse and format', () {
    final forms = <String, MediaId>{
      'station/curated:bg-radio': StationMediaId(StationId.curated('bg-radio')),
      'station/debug:dead-primary': StationMediaId(
        StationId.debug('dead-primary'),
      ),
      'node/recents': const NodeMediaId.recents(),
      'node/favourites': const NodeMediaId.favourites(),
      'node/bg/national': const NodeMediaId.bgNational(),
      'node/bg/city/sofia': NodeMediaId.bgCity('sofia'),
      'node/bg/genre/pop-rock': NodeMediaId.bgGenre('pop-rock'),
    };

    for (final MapEntry(key: raw, value: id) in forms.entries) {
      test(raw, () {
        final parsed = MediaId.parse(raw);
        expect(parsed, id);
        expect(parsed.runtimeType, id.runtimeType);
        expect(parsed.format(), raw);
        expect(MediaId.parse(id.format()), id);
      });
    }

    test('a station id keeps its namespace and key', () {
      final parsed = MediaId.parse('station/curated:bnr-horizont');
      expect(
        parsed,
        isA<StationMediaId>().having(
          (m) => m.stationId,
          'stationId',
          StationId.curated('bnr-horizont'),
        ),
      );
    });
  });

  group('malformed ids are rejected', () {
    for (final raw in [
      '',
      'station/',
      'station/xx:bg-radio',
      'station/curated:',
      'station/curated:BG Radio',
      'node/',
      'node/unknown',
      'node/bg',
      'node/bg/city/',
      'node/bg/city/Sofia',
      'node/recents/extra',
      'foo/bar',
    ]) {
      test("'$raw' throws FormatException", () {
        expect(() => MediaId.parse(raw), throwsFormatException);
      });
    }
  });
}
