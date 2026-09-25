import '../domain/station.dart';

/// The Phase 1 station list (D-01). The tracer ships one station; plan 01-05
/// replaces this list with the six owner-verified stations.
///
/// The БГ Радио stream is UNVERIFIED (01-RESEARCH A1) until the owner's
/// on-device check confirms it.
final List<Station> phase1Stations = [
  Station(
    id: StationId.curated('bg-radio'),
    name: 'БГ Радио',
    nameLatin: 'BG Radio',
    homepage: Uri.parse('https://www.bgradio.bg/'),
    streams: [
      StationStream(
        url: Uri.parse('http://play.global.audio/bgradio128'),
        kind: StreamKind.progressive,
        codec: 'mp3',
        bitrateKbps: 128,
      ),
    ],
  ),
];
