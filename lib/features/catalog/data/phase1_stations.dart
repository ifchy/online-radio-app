import '../domain/station.dart';

/// The Phase 1 release station list (D-01), national flagship first.
///
/// Every stream below was played in VLC by the owner on 2026-09-25 and marked
/// VERIFIED (D-02, plan 01-05 Task 1). Streams are in priority order (D-04):
/// the primary first, then the fallbacks. Only the stations' own official,
/// publicly offered endpoints may appear here; never an aggregator, relay or
/// re-streamer URL. `dist=WEBSITEBG` is the station group's own website tag.
///
/// Codec and bitrate come from the endpoint names (01-RESEARCH stream matrix);
/// they were not ffprobed. No stream is marked `IcyCharset.cp1251`, because
/// the owner did not run the ICY byte probe (gap decision option-a, 2026-09-25).
///
/// Excluded or rejected by owner decision on 2026-09-25 (D-03: no unofficial
/// substitute):
/// - Радио Витоша: no official stream was found (gap decision option-c).
/// - N-JOY's older bTV Radio Icecast endpoints (the .m3u wrapper and the
///   direct MP3): REJECTED, both played nothing in VLC. N-JOY ships with the
///   stream the owner verified on bTV's own CDN instead.
/// - БНР Хоризонт's port-8011 Icecast AAC and MP3 mounts: REJECTED, both
///   failed in VLC.
final List<Station> phase1Stations = [
  Station(
    id: StationId.curated('bnr-horizont'),
    name: 'БНР Хоризонт',
    nameLatin: 'BNR Horizont',
    homepage: Uri.parse('https://bnr.bg/horizont'),
    streams: [
      // Source: bnr.bg's own Хоризонт player; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse(
          'https://lb-hls.cdn.bg/2032/fls/Horizont.stream/playlist.m3u8',
        ),
        kind: StreamKind.hls,
      ),
      // Source: bnr.bg's own Хоризонт player; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse(
          'https://e106-ts.cdn.bg/regstations/fls/Horizont.stream/playlist.m3u8',
        ),
        kind: StreamKind.hls,
      ),
    ],
  ),
  Station(
    id: StationId.curated('radio1'),
    name: 'Радио 1',
    nameLatin: 'Radio 1',
    homepage: Uri.parse('https://www.radio1.bg/'),
    streams: [
      // Source: radio1.bg stream list; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse(
          'https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_1AAC_L.aac?dist=WEBSITEBG',
        ),
        kind: StreamKind.progressive,
        codec: 'aac',
      ),
      // Source: radio1.bg stream list; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse('http://play.global.audio/radio1128?dist=WEBSITEBG'),
        kind: StreamKind.progressive,
        codec: 'mp3',
        bitrateKbps: 128,
      ),
      // Source: radio1.bg stream list; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse('http://play.global.audio/radio164?dist=WEBSITEBG'),
        kind: StreamKind.progressive,
        codec: 'mp3',
        bitrateKbps: 64,
      ),
    ],
  ),
  Station(
    id: StationId.curated('bg-radio'),
    name: 'БГ Радио',
    nameLatin: 'BG Radio',
    homepage: Uri.parse('https://www.bgradio.bg/'),
    streams: [
      // Source: bgradio.bg/live-stream; verifiedAt 2026-09-25 (VLC), and
      // plays in the release build on the owner's phone (01-01 tracer).
      StationStream(
        url: Uri.parse('http://play.global.audio/bgradio128'),
        kind: StreamKind.progressive,
        codec: 'mp3',
        bitrateKbps: 128,
      ),
      // Source: bgradio.bg/live-stream; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse(
          'https://playerservices.streamtheworld.com/api/livestream-redirect/BG_RADIOAAC_L.aac?dist=WEBSITEBG',
        ),
        kind: StreamKind.progressive,
        codec: 'aac',
      ),
      // Source: bgradio.bg/live-stream; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse('http://play.global.audio/bgradio.aac'),
        kind: StreamKind.progressive,
        codec: 'aac',
      ),
    ],
  ),
  Station(
    id: StationId.curated('energy'),
    name: 'Радио Енерджи',
    nameLatin: 'Radio Energy',
    homepage: Uri.parse('https://www.radioenergy.bg/'),
    streams: [
      // Source: radioenergy.bg stream list; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse(
          'https://playerservices.streamtheworld.com/api/livestream-redirect/RADIO_ENERGYAAC_L.aac?dist=WEBSITEBG',
        ),
        kind: StreamKind.progressive,
        codec: 'aac',
      ),
      // Source: radioenergy.bg stream list; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse('http://play.global.audio/nrj128'),
        kind: StreamKind.progressive,
        codec: 'mp3',
        bitrateKbps: 128,
      ),
      // Source: radioenergy.bg stream list; verifiedAt 2026-09-25 (VLC).
      StationStream(
        url: Uri.parse('http://play.global.audio/nrj64?dist=WEBSITEBG'),
        kind: StreamKind.progressive,
        codec: 'mp3',
        bitrateKbps: 64,
      ),
    ],
  ),
  Station(
    id: StationId.curated('njoy'),
    name: 'N-JOY',
    nameLatin: 'N-JOY',
    streams: [
      // Source: bTV's own CDN (cdn.btv.bg), found by the owner;
      // verifiedAt 2026-09-25.
      StationStream(
        url: Uri.parse('https://cdn.btv.bg/radio/njoy.mp3'),
        kind: StreamKind.progressive,
        codec: 'mp3',
      ),
    ],
  ),
];
