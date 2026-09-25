// RadioAudioHandler with the native player and audio session faked and a real
// HttpStreamResolver over a MockClient. Later plans extend this file.
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio/core/network/media_http_client.dart';
import 'package:radio/features/catalog/data/station_directory.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/engine_strings.dart';
import 'package:radio/features/playback/domain/media_id.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/engine/ports.dart';
import 'package:radio/features/playback/engine/radio_audio_handler.dart';
import 'package:radio/features/playback/engine/resolver/stream_resolver.dart';
import 'package:radio/l10n/app_localizations.dart';

import '../../../support/fakes.dart';

/// Delegates to a real resolver and records invalidations.
class _RecordingResolver implements StreamResolver {
  _RecordingResolver(this._inner);

  final StreamResolver _inner;
  final List<StationStream> invalidated = [];

  @override
  Future<List<ResolvedStream>> resolve(StationStream stream) =>
      _inner.resolve(stream);

  @override
  void invalidate(StationStream stream) {
    invalidated.add(stream);
    _inner.invalidate(stream);
  }
}

Station _station(String key, String url, StreamKind kind) => Station(
  id: StationId.debug(key),
  name: key,
  nameLatin: key,
  streams: [StationStream(url: Uri.parse(url), kind: kind)],
);

String _mediaId(Station station) => StationMediaId(station.id).format();

final _english = EngineStrings.fromLocalizations(
  lookupAppLocalizations(const Locale('en')),
);

void main() {
  final njoy = _station(
    'njoy',
    'http://radio.example/njoy.m3u',
    StreamKind.m3u,
  );
  final horizont = _station(
    'horizont',
    'http://radio.example/horizont.pls',
    StreamKind.pls,
  );
  final direct = _station(
    'direct',
    'http://play.example/direct128',
    StreamKind.progressive,
  );
  final directory = StationDirectory([njoy, horizont, direct]);

  late FakeStreamPlayer player;
  late FakeAudioSessionPort session;

  setUp(() {
    player = FakeStreamPlayer();
    session = FakeAudioSessionPort();
  });

  (RadioAudioHandler, _RecordingResolver) build(http.Client client) {
    final resolver = _RecordingResolver(
      HttpStreamResolver(
        MediaHttpClient(client, 'eRadioto/test'),
        const Clock(),
      ),
    );
    return (
      RadioAudioHandler(player, session, directory, resolver, _english),
      resolver,
    );
  }

  group('stream resolution', () {
    test(
      'an m3u station loads the first resolved candidate with its kind',
      () async {
        final (handler, _) = build(
          MockClient(
            (request) async => http.Response(
              '#EXTM3U\n'
              '#EXTINF:-1,N-JOY HLS\nhttp://cdn.example/njoy/index.m3u8\n'
              '#EXTINF:-1,N-JOY MP3\nhttp://cdn.example/njoy.mp3\n',
              200,
            ),
          ),
        );
        await handler.playFromMediaId(_mediaId(njoy));
        expect(player.loads, hasLength(1));
        expect(
          player.lastLoad.uri,
          Uri.parse('http://cdn.example/njoy/index.m3u8'),
        );
        expect(player.lastLoad.kind, PlayableKind.hls);
        expect(handler.status, isA<Connecting>());
      },
    );

    test('a failed resolve invalidates the stream and ends in '
        'PlaybackError(streamUnreachable), with nothing loaded', () async {
      final (handler, resolver) = build(
        MockClient((request) async => http.Response('gone', 404)),
      );
      await handler.playFromMediaId(_mediaId(njoy));
      expect(player.loads, isEmpty);
      expect(resolver.invalidated, [njoy.streams.first]);
      expect(
        handler.status,
        isA<PlaybackError>().having(
          (e) => e.kind,
          'kind',
          PlaybackErrorKind.streamUnreachable,
        ),
      );
      expect(handler.playbackState.value.playing, isFalse);
      expect(session.releaseCalls, greaterThanOrEqualTo(1));
    });

    test('a playlist with nothing playable ends in '
        'PlaybackError(unsupportedFormat)', () async {
      final (handler, resolver) = build(
        MockClient(
          (request) async => http.Response('file:///sdcard/x.mp3\n', 200),
        ),
      );
      await handler.playFromMediaId(_mediaId(njoy));
      expect(player.loads, isEmpty);
      expect(resolver.invalidated, [njoy.streams.first]);
      expect(
        handler.status,
        isA<PlaybackError>().having(
          (e) => e.kind,
          'kind',
          PlaybackErrorKind.unsupportedFormat,
        ),
      );
    });

    test(
      'a resolve that completes after a newer play() is never loaded',
      () async {
        final gate = Completer<void>();
        final (handler, _) = build(
          MockClient((request) async {
            if (request.url.path.endsWith('.pls')) {
              await gate.future;
              return http.Response(
                '[playlist]\nFile1=http://stale.example/horizont\n',
                200,
              );
            }
            return http.Response('not found', 404);
          }),
        );

        final slow = handler.playFromMediaId(_mediaId(horizont));
        // Let the first start publish Connecting and begin resolving.
        await pumpEventQueue();
        expect(handler.status, isA<Connecting>());

        await handler.playFromMediaId(_mediaId(direct));
        gate.complete();
        await slow;
        await pumpEventQueue();

        expect(player.loads.map((l) => l.uri), [
          Uri.parse('http://play.example/direct128'),
        ]);
        expect(handler.currentStation, direct);
        expect(handler.status, isA<Connecting>());
      },
    );

    test('a player failure invalidates the playing stream', () async {
      final (handler, resolver) = build(
        MockClient(
          (request) async =>
              http.Response('http://cdn.example/njoy.mp3\n', 200),
        ),
      );
      await handler.playFromMediaId(_mediaId(njoy));
      final generation = player.lastLoad.generation;
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: generation,
      );
      player.emitFailure(generation: generation);
      await pumpEventQueue();
      expect(resolver.invalidated, contains(njoy.streams.first));
      expect(handler.status, isA<PlaybackError>());
    });
  });
  group('media item republishing (Anti-Pattern 9, T-07-03)', () {
    test('the notification shows the station with its state text, '
        'republished only when the item changes', () async {
      final (handler, _) = build(
        MockClient((request) async {
          fail('Unexpected HTTP request for a progressive stream: $request');
        }),
      );
      final items = <MediaItem?>[];
      final sub = handler.mediaItem.listen(items.add);
      addTearDown(sub.cancel);

      await handler.playFromMediaId(_mediaId(direct));
      await pumpEventQueue();
      expect(handler.mediaItem.value?.title, 'direct');
      expect(handler.mediaItem.value?.displaySubtitle, 'Connecting…');
      final generation = player.lastLoad.generation;

      final before = items.length;
      // Playing -> Buffering -> Playing: three distinct items.
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: generation,
      );
      player.emitSnapshot(
        PlayerProcessingState.buffering,
        playing: true,
        generation: generation,
      );
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: generation,
      );
      await pumpEventQueue();
      expect(handler.status, isA<Playing>());
      final published = items.sublist(before);
      expect(published.map((i) => i?.displaySubtitle), [
        null,
        'Buffering…',
        null,
      ]);
      expect(published.map((i) => i?.title), everyElement('direct'));

      // A repeated Playing snapshot publishes nothing new.
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: generation,
      );
      await pumpEventQueue();
      expect(items.length, before + 3);

      // Pause shows "Paused" under the station name.
      await handler.pause();
      await pumpEventQueue();
      expect(handler.mediaItem.value?.title, 'direct');
      expect(handler.mediaItem.value?.displaySubtitle, 'Paused');
      expect(items.length, before + 4);
    });

    test('an error shows "Error" under the station name', () async {
      final (handler, _) = build(
        MockClient((request) async => http.Response('gone', 404)),
      );
      await handler.playFromMediaId(_mediaId(njoy));
      await pumpEventQueue();
      expect(handler.status, isA<PlaybackError>());
      expect(handler.mediaItem.value?.title, 'njoy');
      expect(handler.mediaItem.value?.displaySubtitle, 'Error');
    });

    test('stop clears the item, and the recent root offers the last station '
        'without a state subtitle', () async {
      final (handler, _) = build(
        MockClient((request) async {
          fail('Unexpected HTTP request for a progressive stream: $request');
        }),
      );
      await handler.playFromMediaId(_mediaId(direct));
      await handler.stop();
      expect(handler.mediaItem.value, isNull);
      final recent = await handler.getChildren(AudioService.recentRootId);
      expect(recent.map((i) => i.title), ['direct']);
      expect(recent.single.displaySubtitle, isNull);
    });
  });
}
