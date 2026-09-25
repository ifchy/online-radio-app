import '../domain/station.dart';
import 'phase1_stations.dart';

/// Test stations for debug and profile builds only (D-05).
///
/// Only station_directory.dart may import this file, and only behind
/// `!kReleaseMode`, so AOT drops it from release builds (Pitfall I; CI checks
/// the release libapp.so). Each fallback is taken from a real station in
/// [phase1Stations], never repeated as a literal.
final List<Station> debugStations = [
  Station(
    id: StationId.debug('dead-primary'),
    name: 'ТЕСТ: мъртъв основен поток',
    nameLatin: 'TEST: dead primary stream',
    streams: [
      // RFC 6761 reserves .invalid, so DNS fails fast (NXDOMAIN).
      StationStream(
        url: Uri.parse('https://dead-primary.invalid/stream.mp3'),
        kind: StreamKind.progressive,
        codec: 'mp3',
      ),
      _real('radio1').streams
          .firstWhere((s) => s.url.scheme == 'http' && s.codec == 'mp3'),
    ],
  ),
  Station(
    id: StationId.debug('slow-primary'),
    name: 'ТЕСТ: бавен основен поток',
    nameLatin: 'TEST: slow primary stream',
    streams: [
      // RFC 5737 TEST-NET-1 is black-holed, which exercises the connect
      // timeout.
      StationStream(
        url: Uri.parse('http://192.0.2.1/stream.mp3'),
        kind: StreamKind.progressive,
        codec: 'mp3',
      ),
      _real('bg-radio').streams.first,
    ],
  ),
  Station(
    id: StationId.debug('horizont-hls-sniff'),
    name: 'ТЕСТ: Хоризонт (HLS sniff)',
    nameLatin: 'TEST: Horizont (HLS sniff)',
    streams: [
      // Kind unknown: the resolver must pick HLS from the playlist body, not
      // from the URL (owner gap decision option-a, 2026-09-25).
      StationStream(
        url: _real('bnr-horizont').streams.first.url,
        kind: StreamKind.unknown,
      ),
    ],
  ),
];

Station _real(String curatedKey) {
  final id = StationId.curated(curatedKey);
  return phase1Stations.firstWhere((s) => s.id == id);
}
