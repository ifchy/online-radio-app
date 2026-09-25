import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio/core/text/icy_charset.dart';
import 'package:radio/features/catalog/data/phase1_stations.dart';
import 'package:radio/features/catalog/data/station_directory.dart';
import 'package:radio/features/catalog/domain/station.dart';

/// The owner's D-02 table (01-05 Task 1): every stream the owner played in
/// VLC on 2026-09-25 and marked VERIFIED, in priority order. N-JOY and
/// Радио Витоша are excluded; see the owner-decision tests below.
const _ownerTable = <String, List<String>>{
  'curated:bnr-horizont': [
    'https://lb-hls.cdn.bg/2032/fls/Horizont.stream/playlist.m3u8',
    'https://e106-ts.cdn.bg/regstations/fls/Horizont.stream/playlist.m3u8',
  ],
  'curated:radio1': [
    'https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_1AAC_L.aac?dist=WEBSITEBG',
    'http://play.global.audio/radio1128?dist=WEBSITEBG',
    'http://play.global.audio/radio164?dist=WEBSITEBG',
  ],
  'curated:bg-radio': [
    'http://play.global.audio/bgradio128',
    'https://playerservices.streamtheworld.com/api/livestream-redirect/BG_RADIOAAC_L.aac?dist=WEBSITEBG',
    'http://play.global.audio/bgradio.aac',
  ],
  'curated:energy': [
    'https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ENERGYAAC_L.aac?dist=WEBSITEBG',
    'http://play.global.audio/nrj128',
    'http://play.global.audio/nrj64?dist=WEBSITEBG',
  ],
};

const _debugIds = [
  'debug:dead-primary',
  'debug:slow-primary',
  'debug:horizont-hls-sniff',
];

List<StationStream> _allStreams(Iterable<Station> stations) => [
  for (final s in stations) ...s.streams,
];

Station _byKey(StationDirectory d, String raw) {
  final station = d.byId(StationId.parse(raw));
  expect(station, isNotNull, reason: '$raw is not in the directory');
  return station!;
}

/// Dart files under lib/ whose source contains [needle].
Set<String> _libFilesContaining(String needle) => {
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File &&
        f.path.endsWith('.dart') &&
        f.readAsStringSync().contains(needle))
      f.path.replaceAll(r'\', '/'),
};

void main() {
  group('release list (includeDebug: false)', () {
    final release = StationDirectory.phase1(includeDebug: false);

    test('is the four owner-verified stations, national flagship first', () {
      expect(release.all.map((s) => s.id.value), [
        'curated:bnr-horizont',
        'curated:radio1',
        'curated:bg-radio',
        'curated:energy',
      ]);
      expect(release.all, phase1Stations);
    });

    test('contains only curated ids, all unique, each with a stream', () {
      final ids = release.all.map((s) => s.id).toList();
      expect(
        ids.every((id) => id.namespace == StationNamespace.curated),
        isTrue,
      );
      expect(ids.toSet(), hasLength(ids.length));
      for (final s in release.all) {
        expect(s.streams, isNotEmpty, reason: s.id.value);
      }
    });

    test('ships exactly the owner-verified streams, in priority order', () {
      for (final entry in _ownerTable.entries) {
        final station = _byKey(release, entry.key);
        expect(
          station.streams.map((s) => s.url.toString()),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('names every station in Cyrillic and Latin script', () {
      final names = {
        for (final s in release.all) s.id.value: (s.name, s.nameLatin),
      };
      expect(names, {
        'curated:bnr-horizont': ('БНР Хоризонт', 'BNR Horizont'),
        'curated:radio1': ('Радио 1', 'Radio 1'),
        'curated:bg-radio': ('БГ Радио', 'BG Radio'),
        'curated:energy': ('Радио Енерджи', 'Radio Energy'),
      });
    });

    test('БГ Радио keeps the tracer-verified direct MP3 as its primary', () {
      final primary = _byKey(release, 'curated:bg-radio').streams.first;
      expect(primary.url, Uri.parse('http://play.global.audio/bgradio128'));
      expect(primary.kind, StreamKind.progressive);
      expect(primary.codec, 'mp3');
    });

    test('Хоризонт plays over HLS only', () {
      final streams = _byKey(release, 'curated:bnr-horizont').streams;
      expect(streams.map((s) => s.kind), everyElement(StreamKind.hls));
    });

    test('covers MP3, AAC, HLS and plain http:// (D-03)', () {
      final streams = _allStreams(release.all);
      bool progressive(StationStream s, String codec) =>
          s.kind == StreamKind.progressive && s.codec == codec;
      expect(streams.any((s) => progressive(s, 'mp3')), isTrue);
      expect(streams.any((s) => progressive(s, 'aac')), isTrue);
      expect(streams.any((s) => s.kind == StreamKind.hls), isTrue);
      expect(streams.any((s) => s.url.scheme == 'http'), isTrue);
    });

    test(
      'has no .pls/.m3u wrapper: N-JOY was excluded by the owner on '
      '2026-09-25, so D-03 wrapper coverage is the 01-04 resolver tests only',
      () {
        final kinds = _allStreams(release.all).map((s) => s.kind);
        expect(kinds, isNot(contains(StreamKind.pls)));
        expect(kinds, isNot(contains(StreamKind.m3u)));
      },
    );

    test('marks no stream cp1251: the owner ran no byte probe (2026-09-25, '
        'option-a), so windows-1251 is covered by the 01-06 golden tests', () {
      expect(
        _allStreams(release.all).map((s) => s.icyCharset),
        everyElement(IcyCharset.auto),
      );
    });

    test('ships no excluded station and no owner-rejected source '
        '(N-JOY, Радио Витоша, stream.bnr.bg:8011)', () {
      final ids = release.all.map((s) => s.id.value);
      expect(ids, isNot(contains('curated:njoy')));
      expect(ids, isNot(contains('curated:vitosha')));
      final hosts = _allStreams(release.all).map((s) => s.url.host);
      expect(hosts, isNot(contains('stream.bnr.bg')));
      expect(hosts, isNot(contains('live.btvradio.bg')));
    });
  });

  group('debug list (includeDebug: true)', () {
    final release = StationDirectory.phase1(includeDebug: false);
    final debug = StationDirectory.phase1(includeDebug: true);

    test('adds exactly the debug stations after the release list', () {
      expect(debug.all.map((s) => s.id.value), [
        ...release.all.map((s) => s.id.value),
        ..._debugIds,
      ]);
    });

    test('debug and profile builds (not release) include them by default', () {
      // flutter test runs in debug mode, where kReleaseMode is false.
      expect(
        StationDirectory.phase1().all.map((s) => s.id.value),
        containsAll(_debugIds),
      );
    });

    test(
      'dead-primary: an .invalid primary, then Радио 1\'s first http MP3',
      () {
        final streams = _byKey(debug, 'debug:dead-primary').streams;
        expect(streams, hasLength(2));
        expect(streams[0].url.host, endsWith('.invalid'));
        expect(streams[0].kind, StreamKind.progressive);
        final radio1 = _byKey(release, 'curated:radio1').streams;
        expect(streams[1], radio1[1]);
        expect(streams[1].url.scheme, 'http');
        expect(streams[1].codec, 'mp3');
        expect(_allStreams(release.all), contains(streams[1]));
      },
    );

    test('slow-primary: a TEST-NET-1 primary, then БГ Радио\'s primary', () {
      final streams = _byKey(debug, 'debug:slow-primary').streams;
      expect(streams, hasLength(2));
      expect(streams[0].url.host, '192.0.2.1');
      expect(streams[0].kind, StreamKind.progressive);
      expect(streams[1], _byKey(release, 'curated:bg-radio').streams[0]);
    });

    test('HLS sniff: Хоризонт\'s primary HLS URL with kind unknown', () {
      final streams = _byKey(debug, 'debug:horizont-hls-sniff').streams;
      expect(streams, hasLength(1));
      expect(
        streams.single.url,
        _byKey(release, 'curated:bnr-horizont').streams[0].url,
      );
      expect(streams.single.kind, StreamKind.unknown);
    });

    test('every debug station is labelled as a test station', () {
      for (final raw in _debugIds) {
        expect(_byKey(debug, raw).name, startsWith('ТЕСТ: '), reason: raw);
      }
    });
  });

  group('source isolation (Pitfall I)', () {
    test('only station_directory.dart imports debug_stations.dart', () {
      expect(_libFilesContaining('debug_stations.dart'), {
        'lib/features/catalog/data/station_directory.dart',
      });
    });

    test('the dead-primary host appears only in debug_stations.dart', () {
      expect(_libFilesContaining('dead-primary.invalid'), {
        'lib/features/catalog/data/debug_stations.dart',
      });
    });
  });
}
