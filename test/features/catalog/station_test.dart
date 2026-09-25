import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/catalog/data/station_directory.dart';
import 'package:radio/features/catalog/domain/station.dart';

/// Every id Phase 1 ships or uses in debug builds (01-05).
const _phase1Ids = [
  'curated:bnr-horizont',
  'curated:radio1',
  'curated:bg-radio',
  'curated:energy',
  'curated:njoy',
  'debug:dead-primary',
  'debug:slow-primary',
  'debug:horizont-hls-sniff',
];

final _stream = StationStream(
  url: Uri.parse('https://example.org/stream.mp3'),
  kind: StreamKind.progressive,
);

void main() {
  group('StationId', () {
    test('parse and value round-trip every Phase 1 id', () {
      for (final raw in _phase1Ids) {
        final id = StationId.parse(raw);
        expect(id.value, raw);
        expect(StationId.parse(id.value), id);
      }
    });

    test('every id in the debug-inclusive directory round-trips', () {
      final ids = StationDirectory.phase1(includeDebug: true).all
          .map((s) => s.id.value)
          .toList();
      expect(ids, unorderedEquals(_phase1Ids));
      for (final raw in ids) {
        expect(StationId.parse(raw).value, raw);
      }
    });

    test('curated and debug factories produce namespaced values', () {
      expect(StationId.curated('bnr-horizont').value, 'curated:bnr-horizont');
      expect(StationId.debug('dead-primary').value, 'debug:dead-primary');
      expect(StationId.parse('curated:radio1'), StationId.curated('radio1'));
      expect(
        StationId.parse('debug:dead-primary'),
        isNot(StationId.curated('dead-primary')),
      );
    });

    test('parse rejects an unknown namespace', () {
      expect(() => StationId.parse('podcast:radio1'), throwsFormatException);
    });

    test('parse rejects a missing namespace', () {
      expect(() => StationId.parse('radio1'), throwsFormatException);
      expect(() => StationId.parse(':radio1'), throwsFormatException);
    });

    test('parse rejects an empty key', () {
      expect(() => StationId.parse('curated:'), throwsFormatException);
    });

    test('parse rejects keys with characters outside [a-z0-9-]', () {
      for (final raw in [
        'curated:BG-Radio',
        'curated:bg_radio',
        'curated:bg radio',
        'curated:радио',
        'curated:bg:radio',
        'debug:dead.primary',
      ]) {
        expect(() => StationId.parse(raw), throwsFormatException, reason: raw);
      }
    });

    test('the factories reject bad keys too', () {
      expect(() => StationId.curated(''), throwsFormatException);
      expect(() => StationId.debug('Dead'), throwsFormatException);
    });
  });

  group('Station', () {
    test(
      'a station with an empty streams list is rejected with ArgumentError',
      () {
        expect(
          () => Station(
            id: StationId.curated('empty'),
            name: 'Празна',
            nameLatin: 'Empty',
            streams: const [],
          ),
          throwsArgumentError,
        );
      },
    );

    test('a station with one stream keeps it as its primary', () {
      final station = Station(
        id: StationId.curated('one'),
        name: 'Едно',
        nameLatin: 'One',
        streams: [_stream],
      );
      expect(station.streams, [_stream]);
    });
  });
}
