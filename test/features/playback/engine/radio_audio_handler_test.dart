// RadioAudioHandler with the native player and audio session faked and a real
// HttpStreamResolver over a MockClient. Later plans extend this file.
import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio/core/network/media_http_client.dart';
import 'package:radio/core/text/icy_charset.dart';
import 'package:radio/features/catalog/data/station_directory.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/engine_diagnostics.dart';
import 'package:radio/features/playback/domain/engine_strings.dart';
import 'package:radio/features/playback/domain/media_id.dart';
import 'package:radio/features/playback/domain/now_playing.dart';
import 'package:radio/features/playback/domain/play_context.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/domain/retry_budget.dart';
import 'package:radio/features/playback/engine/audio_service_engine.dart';
import 'package:radio/features/playback/engine/ports.dart';
import 'package:radio/features/playback/engine/radio_audio_handler.dart';
import 'package:radio/features/playback/engine/reconnect_policy.dart';
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

Station _station(
  String key,
  String url,
  StreamKind kind, {
  IcyCharset charset = IcyCharset.auto,
}) => Station(
  id: StationId.debug(key),
  name: key,
  nameLatin: key,
  streams: [
    StationStream(url: Uri.parse(url), kind: kind, icyCharset: charset),
  ],
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
  final cyrillic = _station(
    'cyrillic',
    'http://play.example/cp1251',
    StreamKind.progressive,
    charset: IcyCharset.cp1251,
  );
  final directory = StationDirectory([njoy, horizont, direct, cyrillic]);

  late FakeStreamPlayer player;
  late FakeAudioSessionPort session;
  late FakeConnectivityPort connectivity;

  setUp(() {
    player = FakeStreamPlayer();
    session = FakeAudioSessionPort();
    connectivity = FakeConnectivityPort();
  });

  (RadioAudioHandler, _RecordingResolver) build(http.Client client) {
    final resolver = _RecordingResolver(
      HttpStreamResolver(
        MediaHttpClient(client, 'eRadioto/test'),
        const Clock(),
      ),
    );
    final handler = RadioAudioHandler(
      player,
      session,
      directory,
      resolver,
      _english,
      connectivity,
    );
    addTearDown(handler.dispose);
    return (handler, resolver);
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

    test('a failed resolve invalidates the stream; after two rounds the '
        'station ends in PlaybackError(allStreamsFailed), with nothing '
        'loaded', () async {
      final (handler, resolver) = build(
        MockClient((request) async => http.Response('gone', 404)),
      );
      await handler.playFromMediaId(_mediaId(njoy));
      expect(player.loads, isEmpty);
      // One stream, two dead-on-arrival rounds (PLAY-08).
      expect(resolver.invalidated, [njoy.streams.first, njoy.streams.first]);
      expect(
        handler.status,
        isA<PlaybackError>().having(
          (e) => e.kind,
          'kind',
          PlaybackErrorKind.allStreamsFailed,
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
      expect(resolver.invalidated, [njoy.streams.first, njoy.streams.first]);
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

    test('a player failure invalidates the playing stream and reconnects '
        '(PLAY-07)', () async {
      final (handler, resolver) = build(
        MockClient(
          (request) async =>
              http.Response('http://cdn.example/njoy.mp3\n', 200),
        ),
      );
      await handler.playFromMediaId(_mediaId(njoy));
      final statuses = <PlaybackStatus>[];
      final sub = handler.statusStream.listen(statuses.add);
      addTearDown(sub.cancel);
      final generation = player.lastLoad.generation;
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: generation,
      );
      player.emitFailure(generation: generation);
      await pumpEventQueue();
      expect(statuses.map((s) => s.runtimeType), [
        Playing,
        Reconnecting,
        Connecting,
      ]);
      expect(resolver.invalidated, contains(njoy.streams.first));
      // The immediate retry is a fresh load of the same stream.
      expect(handler.status, isA<Connecting>());
      expect(player.loads, hasLength(2));
      expect(player.lastLoad.generation, greaterThan(generation));
      expect(handler.playbackState.value.playing, isTrue);
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

  group('now playing (ICY, STRM-05 / PLAY-02)', () {
    /// A handler whose stations are all progressive, so nothing is fetched.
    RadioAudioHandler noHttpHandler() => build(
      MockClient((request) async {
        fail('Unexpected HTTP request for a progressive stream: $request');
      }),
    ).$1;

    /// Starts [station] and reports it ready; returns the load's generation.
    Future<int> startPlaying(RadioAudioHandler handler, Station station) async {
      await handler.playFromMediaId(_mediaId(station));
      final generation = player.lastLoad.generation;
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: generation,
      );
      await pumpEventQueue();
      expect(handler.status, isA<Playing>());
      return generation;
    }

    test('a Cyrillic ICY title shows under the station name on the '
        'notification, and the engine publishes it', () async {
      final handler = noHttpHandler();
      final generation = await startPlaying(handler, direct);

      player.emitIcy('Артист - Песен', generation: generation);
      await pumpEventQueue();

      final item = handler.mediaItem.value!;
      expect(item.title, 'direct');
      expect(item.displaySubtitle, 'Артист - Песен');
      expect(item.artist, 'Артист');
      const expected = NowPlaying(
        artist: 'Артист',
        title: 'Песен',
        text: 'Артист - Песен',
      );
      expect(handler.nowPlaying, expected);
      expect(await AudioServiceEngine(handler).nowPlaying.first, expected);
    });

    test(
      'mojibake from a windows-1251 stream is published as Cyrillic',
      () async {
        final handler = noHttpHandler();
        final generation = await startPlaying(handler, cyrillic);

        player.emitIcy('Àðòèñò - Ïåñåí', generation: generation);
        await pumpEventQueue();

        expect(handler.mediaItem.value?.title, 'cyrillic');
        expect(handler.mediaItem.value?.artist, 'Артист');
        expect(handler.mediaItem.value?.displaySubtitle, 'Артист - Песен');
        expect(handler.nowPlaying?.artist, 'Артист');
      },
    );

    test('the charset comes from the stream that is playing: cp1251 repairs '
        'a short mojibake that an auto stream leaves alone', () async {
      final handler = noHttpHandler();
      var generation = await startPlaying(handler, cyrillic);
      player.emitIcy('Rock Àç', generation: generation);
      await pumpEventQueue();
      expect(handler.nowPlaying?.text, 'Rock Аз');

      generation = await startPlaying(handler, direct);
      player.emitIcy('Rock Àç', generation: generation);
      await pumpEventQueue();
      expect(handler.nowPlaying?.text, 'Rock Àç');
      expect(handler.mediaItem.value?.displaySubtitle, 'Rock Àç');
    });

    group('never stale, never junk (Pitfall E, Pitfall 6, T-08-03)', () {
      /// Plays [direct] with the title 'Артист - Песен' showing.
      Future<(RadioAudioHandler, int, List<NowPlaying?>)>
      playingWithTitle() async {
        final handler = noHttpHandler();
        final emitted = <NowPlaying?>[];
        final sub = handler.nowPlayingStream.listen(emitted.add);
        addTearDown(sub.cancel);
        final generation = await startPlaying(handler, direct);
        player.emitIcy('Артист - Песен', generation: generation);
        await pumpEventQueue();
        expect(handler.mediaItem.value?.displaySubtitle, 'Артист - Песен');
        return (handler, generation, emitted);
      }

      test('switching station clears the title at once, and a late title '
          'from the previous station is ignored', () async {
        final (handler, oldGeneration, emitted) = await playingWithTitle();

        await handler.playFromMediaId(_mediaId(cyrillic));
        // Cleared before the new station is even ready.
        expect(handler.status, isA<Connecting>());
        expect(emitted.last, isNull);
        expect(handler.nowPlaying, isNull);

        final generation = player.lastLoad.generation;
        player.emitSnapshot(
          PlayerProcessingState.ready,
          playing: true,
          generation: generation,
        );
        await pumpEventQueue();
        expect(handler.status, isA<Playing>());
        expect(handler.mediaItem.value?.title, 'cyrillic');
        expect(handler.mediaItem.value?.displaySubtitle, isNull);
        expect(handler.mediaItem.value?.artist, isNull);

        // The previous station's title arrives late: it is dropped.
        player.emitIcy('Артист - Песен', generation: oldGeneration);
        await pumpEventQueue();
        expect(handler.nowPlaying, isNull);
        expect(handler.mediaItem.value?.displaySubtitle, isNull);
      });

      test(
        'an ICY title that arrives before the load is ready is ignored',
        () async {
          final handler = noHttpHandler();
          await handler.playFromMediaId(_mediaId(direct));
          final generation = player.lastLoad.generation;

          // The native player can replay the previous source's ICY state
          // right after a load, stamped with the new generation.
          player.emitIcy('Стара - Песен', generation: generation);
          await pumpEventQueue();
          expect(handler.nowPlaying, isNull);

          player.emitSnapshot(
            PlayerProcessingState.ready,
            playing: true,
            generation: generation,
          );
          await pumpEventQueue();
          expect(handler.status, isA<Playing>());
          expect(handler.nowPlaying, isNull);
          expect(handler.mediaItem.value?.displaySubtitle, isNull);

          // After ready, titles of this load are shown.
          player.emitIcy('Нова - Песен', generation: generation);
          await pumpEventQueue();
          expect(handler.mediaItem.value?.displaySubtitle, 'Нова - Песен');
        },
      );

      test(
        'the same title delivered twice publishes the media item once',
        () async {
          final handler = noHttpHandler();
          final generation = await startPlaying(handler, direct);
          final items = <MediaItem?>[];
          final sub = handler.mediaItem.skip(1).listen(items.add);
          addTearDown(sub.cancel);
          final emitted = <NowPlaying?>[];
          final nowSub = handler.nowPlayingStream.listen(emitted.add);
          addTearDown(nowSub.cancel);

          player.emitIcy('Артист - Песен', generation: generation);
          player.emitIcy('Артист - Песен', generation: generation);
          // Differs only in whitespace, which the parser collapses.
          player.emitIcy('  Артист  -  Песен ', generation: generation);
          await pumpEventQueue();

          expect(items, hasLength(1));
          expect(items.single?.displaySubtitle, 'Артист - Песен');
          expect(emitted, hasLength(1));
        },
      );

      test('pause clears now-playing', () async {
        final (handler, _, emitted) = await playingWithTitle();

        await handler.pause();
        await pumpEventQueue();

        expect(emitted.last, isNull);
        expect(handler.nowPlaying, isNull);
        expect(handler.mediaItem.value?.displaySubtitle, 'Paused');
        expect(handler.mediaItem.value?.artist, 'Paused');

        // Resuming is a fresh load: no title until the station sends one.
        await handler.play();
        final generation = player.lastLoad.generation;
        player.emitSnapshot(
          PlayerProcessingState.ready,
          playing: true,
          generation: generation,
        );
        await pumpEventQueue();
        expect(handler.status, isA<Playing>());
        expect(handler.mediaItem.value?.displaySubtitle, isNull);
      });

      test('stop clears now-playing', () async {
        final (handler, _, emitted) = await playingWithTitle();

        await handler.stop();
        await pumpEventQueue();

        expect(emitted.last, isNull);
        expect(handler.nowPlaying, isNull);
        expect(handler.mediaItem.value, isNull);
      });

      test('a player failure clears now-playing while reconnecting', () async {
        final (handler, generation, emitted) = await playingWithTitle();

        player.emitFailure(generation: generation);
        expect(handler.status, isA<Reconnecting>());
        expect(handler.mediaItem.value?.displaySubtitle, 'Reconnecting…');
        await pumpEventQueue();

        expect(emitted.last, isNull);
        expect(handler.nowPlaying, isNull);
        // Reconnecting, or already its immediate retry: never the old title.
        expect(
          handler.mediaItem.value?.displaySubtitle,
          isIn(['Reconnecting…', 'Connecting…']),
        );
        expect(handler.playbackState.value.playing, isTrue);
      });

      for (final (label, junk) in [
        ("'-'", '-'),
        ('an empty title', ''),
        ('no title at all', null),
        ('the station name', 'direct'),
        ('a URL', 'https://radio.example/live'),
      ]) {
        test('$label after a real title clears the line, never showing '
            "'null'", () async {
          final (handler, generation, emitted) = await playingWithTitle();
          final items = <MediaItem?>[];
          final sub = handler.mediaItem.listen(items.add);
          addTearDown(sub.cancel);

          player.emitIcy(junk, generation: generation);
          await pumpEventQueue();

          expect(emitted.last, isNull);
          expect(handler.nowPlaying, isNull);
          expect(handler.mediaItem.value?.title, 'direct');
          expect(handler.mediaItem.value?.displaySubtitle, isNull);
          expect(handler.mediaItem.value?.artist, isNull);
          for (final item in items) {
            expect(item?.displaySubtitle, isNot(contains('null')));
            expect(item?.artist, isNot(contains('null')));
          }
        });
      }
    });
  });

  group('fallback rotation (PLAY-08, PLAY-10), under fakeAsync', () {
    StationStream progressive(String url) =>
        StationStream(url: Uri.parse(url), kind: StreamKind.progressive);

    final dead = progressive('https://dead-primary.invalid/stream.mp3');
    final good = progressive('http://good.example/live128');
    final deadPrimary = Station(
      id: StationId.debug('dead-primary'),
      name: 'ТЕСТ: мъртъв основен поток',
      nameLatin: 'TEST: dead primary',
      streams: [dead, good],
    );
    final allDead = Station(
      id: StationId.debug('all-dead'),
      name: 'Мъртва',
      nameLatin: 'Martva',
      streams: [
        progressive('http://a.example/1'),
        progressive('http://b.example/2'),
        progressive('http://c.example/3'),
      ],
    );
    final oneStream = Station(
      id: StationId.debug('one-stream'),
      name: 'Един поток',
      nameLatin: 'Edin potok',
      streams: [progressive('https://only.example/njoy.mp3')],
    );
    final playlistStream = StationStream(
      url: Uri.parse('http://radio.example/slow.m3u'),
      kind: StreamKind.m3u,
    );
    final playlist = Station(
      id: StationId.debug('playlist'),
      name: 'Плейлист',
      nameLatin: 'Playlist',
      streams: [playlistStream],
    );
    final rotationDirectory = StationDirectory([
      deadPrimary,
      allDead,
      oneStream,
      playlist,
    ]);

    late FakeStreamResolver resolver;

    /// Builds the handler inside the fakeAsync zone, so its timers are fake.
    RadioAudioHandler handlerWith() {
      resolver = FakeStreamResolver();
      final handler = RadioAudioHandler(
        player,
        session,
        rotationDirectory,
        resolver,
        _english,
        connectivity,
      );
      addTearDown(handler.dispose);
      return handler;
    }

    List<Uri> loadedUris() => [for (final l in player.loads) l.uri];

    void ready(FakeAsync async) {
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: player.lastLoad.generation,
      );
      async.flushMicrotasks();
    }

    test('the media session says playing/loading with "Connecting…" before '
        'the stream is resolved (Pitfall G)', () {
      fakeAsync((async) {
        final handler = handlerWith();
        final published = <(bool, AudioProcessingState, String?)>[];
        resolver.onResolve = (_) => published.add((
          handler.playbackState.value.playing,
          handler.playbackState.value.processingState,
          handler.mediaItem.value?.displaySubtitle,
        ));
        unawaited(handler.playFromMediaId(_mediaId(deadPrimary)));
        async.flushMicrotasks();
        expect(published, [
          (true, AudioProcessingState.loading, 'Connecting…'),
        ]);
      });
    });

    test('dead primary: stream 1 is loaded at once, with a new generation, '
        'and Playing follows its ready snapshot', () {
      fakeAsync((async) {
        final handler = handlerWith();
        unawaited(handler.playFromMediaId(_mediaId(deadPrimary)));
        async.flushMicrotasks();
        expect(loadedUris(), [dead.url]);
        final first = player.lastLoad.generation;

        player.emitFailure(generation: first);
        async.flushMicrotasks();
        expect(loadedUris(), [dead.url, good.url]);
        expect(player.lastLoad.generation, greaterThan(first));
        expect(
          handler.status,
          PlaybackStatus.connecting(
            station: deadPrimary,
            streamIndex: 1,
            round: 0,
          ),
        );
        // The foreground service stays up while rotating.
        expect(handler.playbackState.value.playing, isTrue);
        expect(resolver.invalidated, [dead]);

        ready(async);
        expect(
          handler.status,
          PlaybackStatus.playing(station: deadPrimary, streamIndex: 1),
        );
        async.elapse(const Duration(minutes: 1));
        expect(player.loads, hasLength(2));
        expect(handler.status, isA<Playing>());
      });
    });

    test('dead primary that fails to resolve: stream 1 is loaded', () {
      fakeAsync((async) {
        final handler = handlerWith();
        resolver.script(
          dead.url,
          const ResolveScript(
            error: StreamResolutionException(StreamResolutionFailure.network),
          ),
        );
        unawaited(handler.playFromMediaId(_mediaId(deadPrimary)));
        async.flushMicrotasks();
        expect(loadedUris(), [good.url]);
        ready(async);
        expect(
          handler.status,
          PlaybackStatus.playing(station: deadPrimary, streamIndex: 1),
        );
      });
    });

    test('slow primary: no audio within 10 s moves to stream 1', () {
      fakeAsync((async) {
        final handler = handlerWith();
        unawaited(handler.playFromMediaId(_mediaId(deadPrimary)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 9900));
        expect(loadedUris(), [dead.url]);
        expect(handler.mediaItem.value?.displaySubtitle, 'Connecting…');

        async.elapse(const Duration(milliseconds: 200));
        expect(loadedUris(), [dead.url, good.url]);
        expect(
          handler.status,
          PlaybackStatus.connecting(
            station: deadPrimary,
            streamIndex: 1,
            round: 0,
          ),
        );
        expect(handler.playbackState.value.playing, isTrue);
        ready(async);
        expect(
          handler.status,
          PlaybackStatus.playing(station: deadPrimary, streamIndex: 1),
        );
      });
    });

    test('all streams dead: exactly two rounds, then '
        'PlaybackError(allStreamsFailed) with focus released and no '
        'foreground service', () {
      fakeAsync((async) {
        final handler = handlerWith();
        player.onLoad = (_, generation) =>
            scheduleMicrotask(() => player.emitFailure(generation: generation));
        unawaited(handler.playFromMediaId(_mediaId(allDead)));
        async.flushMicrotasks();

        expect(loadedUris(), [
          for (var round = 0; round < 2; round++)
            for (final s in allDead.streams) s.url,
        ]);
        expect(player.loads.map((l) => l.generation).toSet(), hasLength(6));
        expect(
          handler.status,
          PlaybackStatus.error(
            station: allDead,
            kind: PlaybackErrorKind.allStreamsFailed,
          ),
        );
        final state = handler.playbackState.value;
        expect(state.playing, isFalse);
        expect(state.processingState, AudioProcessingState.error);
        expect(session.releaseCalls, 1);
        expect(handler.mediaItem.value?.displaySubtitle, 'Error');

        // Nothing is retried afterwards.
        async.elapse(const Duration(minutes: 5));
        expect(player.loads, hasLength(6));
      });
    });

    test('a one-stream station (N-JOY) is loaded twice, then errors', () {
      fakeAsync((async) {
        final handler = handlerWith();
        player.onLoad = (_, generation) =>
            scheduleMicrotask(() => player.emitFailure(generation: generation));
        unawaited(handler.playFromMediaId(_mediaId(oneStream)));
        async.flushMicrotasks();
        expect(player.loads, hasLength(2));
        expect(handler.status, isA<PlaybackError>());
        async.elapse(const Duration(minutes: 5));
        expect(player.loads, hasLength(2));
      });
    });

    test('a late failure, snapshot or connect timer from a superseded load '
        'changes nothing', () {
      fakeAsync((async) {
        final handler = handlerWith();
        unawaited(handler.playFromMediaId(_mediaId(deadPrimary)));
        async.flushMicrotasks();
        final first = player.lastLoad.generation;
        async.elapse(const Duration(seconds: 1));
        player.emitFailure(generation: first);
        async.flushMicrotasks();
        final second = player.lastLoad.generation;
        expect(loadedUris(), [dead.url, good.url]);

        player.emitSnapshot(
          PlayerProcessingState.ready,
          playing: true,
          generation: first,
        );
        player.emitFailure(generation: first);
        async.flushMicrotasks();
        expect(
          handler.status,
          PlaybackStatus.connecting(
            station: deadPrimary,
            streamIndex: 1,
            round: 0,
          ),
        );
        expect(player.loads, hasLength(2));

        // The first attempt's timer would have fired at 10 s; the second
        // attempt has its own, due at 11 s.
        async.elapse(const Duration(milliseconds: 9500));
        expect(player.loads, hasLength(2));
        async.elapse(const Duration(milliseconds: 600));
        expect(player.loads, hasLength(3));
        expect(player.lastLoad.uri, dead.url);
        expect(player.lastLoad.generation, greaterThan(second));
        expect(
          handler.status,
          PlaybackStatus.connecting(
            station: deadPrimary,
            streamIndex: 0,
            round: 1,
          ),
        );
      });
    });

    for (final (label, command, expected) in [
      (
        'pause',
        (RadioAudioHandler h) => h.pause(),
        PlaybackStatus.paused(station: playlist),
      ),
      ('stop', (RadioAudioHandler h) => h.stop(), const PlaybackStatus.idle()),
    ]) {
      test('$label while connecting: a resolve result landing afterwards '
          'never loads, and the connect timer is gone (PLAY-10)', () {
        fakeAsync((async) {
          final handler = handlerWith();
          final gate = Completer<void>();
          resolver.script(
            playlistStream.url,
            ResolveScript(
              gate: gate.future,
              candidates: [
                ResolvedStream(
                  Uri.parse('http://cdn.example/late.mp3'),
                  PlayableKind.progressive,
                ),
              ],
            ),
          );
          unawaited(handler.playFromMediaId(_mediaId(playlist)));
          async.flushMicrotasks();
          expect(handler.status, isA<Connecting>());

          unawaited(command(handler));
          async.flushMicrotasks();
          expect(handler.status, expected);
          expect(session.releaseCalls, 1);
          expect(handler.playbackState.value.playing, isFalse);

          gate.complete();
          async.flushMicrotasks();
          expect(player.loads, isEmpty);
          expect(handler.status, expected);

          async.elapse(const Duration(minutes: 1));
          expect(player.loads, isEmpty);
          expect(handler.status, expected);
        });
      });
    }

    test('diagnostics: state, the stream in use, time-to-audio and a '
        '50-entry event log, newest last (D-07)', () {
      fakeAsync((async) {
        final handler = handlerWith();
        final emitted = <EngineDiagnostics>[];
        final sub = handler.diagnostics.listen(emitted.add);
        addTearDown(sub.cancel);

        unawaited(handler.playFromMediaId(_mediaId(deadPrimary)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1500));
        player.emitFailure(generation: player.lastLoad.generation);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        ready(async);

        final d = handler.currentDiagnostics;
        expect(d.state, 'Playing(stream 1)');
        expect(d.stationId, deadPrimary.id);
        expect(d.streamIndex, 1);
        expect(d.candidateIndex, 0);
        expect(d.url, good.url);
        expect(d.kind, PlayableKind.progressive);
        expect(d.round, 0);
        expect(d.reconnectAttempt, 0);
        expect(d.nextRetryDelay, isNull);
        expect(d.lastTimeToAudio, const Duration(milliseconds: 2500));
        expect(d.recentEvents.first.message, startsWith('UserPlay'));
        expect(d.recentEvents.last.message, contains('PlayerStateChanged'));
        expect(d.recentEvents.last.message, endsWith('Playing(stream 1)'));
        expect(emitted, isNotEmpty);
        expect(emitted.last.state, 'Playing(stream 1)');

        for (var i = 0; i < 30; i++) {
          player.emitSnapshot(
            PlayerProcessingState.buffering,
            playing: true,
            generation: player.lastLoad.generation,
          );
          ready(async);
        }
        final log = handler.currentDiagnostics.recentEvents;
        expect(log, hasLength(EngineDiagnostics.maxRecentEvents));
        expect(log.last.message, endsWith('Playing(stream 1)'));
        expect(log[log.length - 2].message, endsWith('Buffering(stream 1)'));
        expect(
          log.map((e) => e.at).toList(),
          orderedEquals([...log.map((e) => e.at)]..sort()),
        );
      });
    });
  });

  group('next/previous and the start stream (PLAY-03, D-12)', () {
    StationStream progressive(String url) =>
        StationStream(url: Uri.parse(url), kind: StreamKind.progressive);
    Station station(String key, int streams) => Station(
      id: StationId.debug(key),
      name: key,
      nameLatin: key,
      streams: [
        for (var i = 0; i < streams; i++)
          progressive('http://$key.example/stream$i'),
      ],
    );

    final a = station('a', 1);
    final b = station('b', 1);
    final c = station('c', 3);
    final list = PlayContext.list([a.id, b.id, c.id], source: 'home');

    late FakeStreamResolver resolver;
    late RadioAudioHandler handler;
    late AudioServiceEngine engine;

    setUp(() {
      resolver = FakeStreamResolver();
      handler = RadioAudioHandler(
        player,
        session,
        StationDirectory([a, b, c]),
        resolver,
        _english,
        connectivity,
      );
      addTearDown(handler.dispose);
      engine = AudioServiceEngine(handler);
    });

    group('PlayContext.neighbour', () {
      test('wraps within a list both ways', () {
        expect(list.neighbour(c.id, 1), a.id);
        expect(list.neighbour(a.id, -1), c.id);
        expect(list.neighbour(a.id, 1), b.id);
        expect(list.neighbour(b.id, -1), a.id);
      });

      test('is null for a single station, a station not in the list and a '
          'one-station list', () {
        const single = PlayContext.single();
        expect(single.neighbour(a.id, 1), isNull);
        expect(single.neighbour(a.id, -1), isNull);
        expect(PlayContext.list([a.id, b.id]).neighbour(c.id, 1), isNull);
        expect(PlayContext.list([a.id]).neighbour(a.id, 1), isNull);
      });
    });

    test('skipToNext from the last station of the list starts the first, '
        'with the same list', () async {
      await engine.play(c, context: list);
      await handler.skipToNext();
      expect(handler.currentStation, a);
      expect(handler.status, isA<Connecting>());
      expect(player.lastLoad.uri, a.streams.first.url);

      // Still the same list: previous from the first goes back to the last.
      await handler.skipToPrevious();
      expect(handler.currentStation, c);
      expect(player.lastLoad.uri, c.streams.first.url);
    });

    test('headset and car next/previous buttons step through the list '
        '(MediaButton.next/previous)', () async {
      await engine.play(a, context: list);
      await handler.click(MediaButton.next);
      expect(handler.currentStation, b);
      await handler.click(MediaButton.previous);
      await handler.click(MediaButton.previous);
      expect(handler.currentStation, c);
    });

    test('the engine facade skips too', () async {
      await engine.play(b, context: list);
      await engine.skipToNext();
      expect(handler.currentStation, c);
      await engine.skipToPrevious();
      expect(handler.currentStation, b);
    });

    test('with a single station, next and previous do nothing', () async {
      await engine.play(b);
      final loads = player.loads.length;
      await handler.skipToNext();
      await handler.skipToPrevious();
      expect(player.loads, hasLength(loads));
      expect(handler.currentStation, b);
    });

    test('the notification keeps Pause and Stop only, with no skip action '
        '(D-12)', () async {
      await engine.play(a, context: list);
      await handler.skipToNext();
      final state = handler.playbackState.value;
      expect(
        [for (final c in state.controls) c.action],
        [MediaAction.pause, MediaAction.stop],
      );
      expect(state.systemActions, isEmpty);
    });

    test('play(station, startStreamIndex: 2) starts on streams[2]', () async {
      await engine.play(c, startStreamIndex: 2);
      expect(player.loads.map((l) => l.uri), [c.streams[2].url]);
      expect(
        handler.status,
        PlaybackStatus.connecting(station: c, streamIndex: 2, round: 0),
      );
    });

    test('playFromMediaId without extras starts on streams[0]', () async {
      await handler.playFromMediaId(_mediaId(c));
      expect(player.loads.map((l) => l.uri), [c.streams.first.url]);
    });

    for (final (label, extras) in [
      ('an out-of-range index', <String, dynamic>{'startStreamIndex': 7}),
      ('a negative index', <String, dynamic>{'startStreamIndex': -1}),
      ('a non-integer value', <String, dynamic>{'startStreamIndex': '2'}),
    ]) {
      test('playFromMediaId with $label starts on streams[0]', () async {
        await handler.playFromMediaId(_mediaId(c), extras);
        expect(player.loads.map((l) => l.uri), [c.streams.first.url]);
      });
    }

    test('playFromMediaId with extras startStreamIndex 1 starts on '
        'streams[1]', () async {
      await handler.playFromMediaId(_mediaId(c), {'startStreamIndex': 1});
      expect(player.loads.map((l) => l.uri), [c.streams[1].url]);
    });

    test('engine.diagnostics replays the latest diagnostics', () async {
      await engine.play(c, startStreamIndex: 1);
      final latest = await engine.diagnostics.first;
      expect(latest.stationId, c.id);
      expect(latest.streamIndex, 1);
    });
  });

  group('the retry budget setting (D-10)', () {
    RadioAudioHandler handlerWith({RetryBudgetPreset? initial}) {
      final handler = initial == null
          ? RadioAudioHandler(
              player,
              session,
              directory,
              FakeStreamResolver(),
              _english,
              connectivity,
            )
          : RadioAudioHandler(
              player,
              session,
              directory,
              FakeStreamResolver(),
              _english,
              connectivity,
              initialRetryBudget: initial,
            );
      addTearDown(handler.dispose);
      return handler;
    }

    test('the handler starts with the standard preset', () {
      expect(handlerWith().retryBudget, RetryBudgetPreset.standard);
    });

    test('initialRetryBudget seeds the preset', () {
      expect(
        handlerWith(initial: RetryBudgetPreset.trip).retryBudget,
        RetryBudgetPreset.trip,
      );
    });

    test('engine.setRetryBudget reaches the handler', () async {
      final handler = handlerWith();
      final engine = AudioServiceEngine(handler);
      await engine.setRetryBudget(RetryBudgetPreset.batterySaver);
      expect(handler.retryBudget, RetryBudgetPreset.batterySaver);
      await engine.setRetryBudget(RetryBudgetPreset.trip);
      expect(handler.retryBudget, RetryBudgetPreset.trip);
    });

    test('FakeEngine records setRetryBudget', () async {
      final fake = FakeEngine();
      await fake.setRetryBudget(RetryBudgetPreset.batterySaver);
      expect(fake.retryBudgetCalls, [RetryBudgetPreset.batterySaver]);
    });
  });

  group(
    'reconnect after a drop (PLAY-07, PLAY-10, PLAY-11), under fakeAsync',
    () {
      StationStream progressive(String url) =>
          StationStream(url: Uri.parse(url), kind: StreamKind.progressive);

      final primary = progressive('http://primary.example/live');
      final fallback = progressive('http://fallback.example/live');
      final twoStreams = Station(
        id: StationId.debug('two'),
        name: 'Два потока',
        nameLatin: 'Dva potoka',
        streams: [primary, fallback],
      );
      final only = progressive('https://only.example/live.mp3');
      final oneStream = Station(
        id: StationId.debug('one'),
        name: 'Един поток',
        nameLatin: 'Edin potok',
        streams: [only],
      );
      final other = Station(
        id: StationId.debug('other'),
        name: 'Друга',
        nameLatin: 'Druga',
        streams: [progressive('http://other.example/live')],
      );
      final reconnectDirectory = StationDirectory([
        twoStreams,
        oneStream,
        other,
      ]);

      late FakeStreamResolver resolver;
      late AudioServiceEngine engine;

      /// Built inside the fakeAsync zone; no jitter, so every backoff is its
      /// base delay.
      RadioAudioHandler handlerWith() {
        resolver = FakeStreamResolver();
        final handler = RadioAudioHandler(
          player,
          session,
          reconnectDirectory,
          resolver,
          _english,
          connectivity,
          reconnectPolicy: ReconnectPolicy(Random(0), jitter: 0),
        );
        addTearDown(handler.dispose);
        engine = AudioServiceEngine(handler);
        return handler;
      }

      void ready(FakeAsync async) {
        player.emitSnapshot(
          PlayerProcessingState.ready,
          playing: true,
          generation: player.lastLoad.generation,
        );
        async.flushMicrotasks();
      }

      /// Starts [station] and lets it reach Playing.
      RadioAudioHandler playing(FakeAsync async, Station station) {
        final handler = handlerWith();
        unawaited(handler.playFromMediaId(_mediaId(station)));
        async.flushMicrotasks();
        ready(async);
        expect(handler.status, isA<Playing>());
        return handler;
      }

      /// From now on every load fails right away.
      void everyLoadFails() => player.onLoad = (_, generation) =>
          scheduleMicrotask(() => player.emitFailure(generation: generation));

      test('a stall: 8 s of Buffering reloads at the live edge, with a new '
          'generation, and Playing follows', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          final first = player.lastLoad.generation;
          final stops = player.stopCalls;
          player.emitSnapshot(
            PlayerProcessingState.buffering,
            playing: true,
            generation: first,
          );
          async.flushMicrotasks();
          expect(handler.status, isA<Buffering>());
          async.elapse(const Duration(milliseconds: 7900));
          expect(player.loads, hasLength(1));

          async.elapse(const Duration(milliseconds: 200));
          expect(player.loads, hasLength(2));
          expect(player.lastLoad.uri, only.url);
          expect(player.lastLoad.generation, greaterThan(first));
          expect(player.stopCalls, greaterThan(stops));
          expect(handler.status, isA<Connecting>());
          expect(handler.playbackState.value.playing, isTrue);
          // A stall is not a bad URL.
          expect(resolver.invalidated, isEmpty);
          ready(async);
          expect(handler.status, isA<Playing>());
        });
      });

      test('Buffering that recovers within 8 s reloads nothing', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          final g = player.lastLoad.generation;
          player.emitSnapshot(
            PlayerProcessingState.buffering,
            playing: true,
            generation: g,
          );
          async.elapse(const Duration(seconds: 7));
          ready(async);
          async.elapse(const Duration(minutes: 1));
          expect(player.loads, hasLength(1));
          expect(handler.status, isA<Playing>());
        });
      });

      test('completed while Playing -> Reconnecting: the notification stays '
          '(playing true, "Reconnecting…"), then a fresh load', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          final g = player.lastLoad.generation;
          player.emitSnapshot(
            PlayerProcessingState.completed,
            playing: false,
            generation: g,
          );
          async.flushMicrotasks();
          expect(handler.status, isA<Reconnecting>());
          final state = handler.playbackState.value;
          expect(state.playing, isTrue);
          expect(state.processingState, AudioProcessingState.buffering);
          expect(handler.mediaItem.value?.displaySubtitle, 'Reconnecting…');
          expect(resolver.invalidated, [only]);
          expect(session.releaseCalls, 0);

          async.elapse(Duration.zero);
          expect(player.loads, hasLength(2));
          expect(handler.status, isA<Connecting>());
          expect(handler.playbackState.value.playing, isTrue);
        });
      });

      test('the retry starts at the stream that last worked', () {
        fakeAsync((async) {
          final handler = handlerWith();
          unawaited(handler.playFromMediaId(_mediaId(twoStreams)));
          async.flushMicrotasks();
          player.emitFailure(generation: player.lastLoad.generation);
          async.flushMicrotasks();
          ready(async);
          expect(
            handler.status,
            PlaybackStatus.playing(station: twoStreams, streamIndex: 1),
          );

          player.emitFailure(generation: player.lastLoad.generation);
          async.elapse(Duration.zero);
          expect(player.lastLoad.uri, fallback.url);
          // It fails too: rotation moves on to the primary at once.
          player.emitFailure(generation: player.lastLoad.generation);
          async.flushMicrotasks();
          expect(player.lastLoad.uri, primary.url);
          expect(player.loads, hasLength(4));
        });
      });

      test('backoff per attempt (0, 1, 2, 4, 8, 15, 30 s), diagnostics show '
          'the attempt and the delay, and standard gives up after 3 min '
          'online: Error(streamUnreachable), focus released, no foreground '
          'service, nothing retried afterwards', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          final dropAt = async.elapsed;
          final loadTimes = <Duration>[];
          everyLoadFails();
          final onLoad = player.onLoad!;
          player.onLoad = (stream, generation) {
            loadTimes.add(async.elapsed - dropAt);
            onLoad(stream, generation);
          };

          player.emitFailure(generation: player.lastLoad.generation);
          async.flushMicrotasks();
          expect(handler.currentDiagnostics.reconnectAttempt, 0);
          expect(handler.currentDiagnostics.nextRetryDelay, Duration.zero);

          async.elapse(const Duration(seconds: 2));
          // Retries at 0 and 1 s; the next waits 2 s (attempt 2).
          expect(handler.status, isA<Reconnecting>());
          expect(handler.currentDiagnostics.reconnectAttempt, 2);
          expect(
            handler.currentDiagnostics.nextRetryDelay,
            const Duration(seconds: 2),
          );
          expect(handler.currentDiagnostics.state, 'Reconnecting(attempt 2)');

          async.elapse(const Duration(minutes: 3) - const Duration(seconds: 2));
          expect(loadTimes, [
            for (final s in [0, 1, 3, 7, 15, 30, 60, 90, 120, 150])
              Duration(seconds: s),
          ]);
          expect(
            handler.status,
            PlaybackStatus.error(
              station: oneStream,
              kind: PlaybackErrorKind.streamUnreachable,
            ),
          );
          final state = handler.playbackState.value;
          expect(state.playing, isFalse);
          expect(state.processingState, AudioProcessingState.error);
          expect(session.releaseCalls, 1);
          expect(handler.currentDiagnostics.nextRetryDelay, isNull);

          async.elapse(const Duration(minutes: 10));
          expect(loadTimes, hasLength(10));
          expect(handler.status, isA<PlaybackError>());
        });
      });

      test('30 s of stable Playing resets the backoff and the budget', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          // Outage 1: 2 min 30 s of failing, then the stream comes back.
          everyLoadFails();
          player.emitFailure(generation: player.lastLoad.generation);
          async.elapse(
            const Duration(seconds: 150) - const Duration(seconds: 1),
          );
          player.onLoad = null;
          async.elapse(const Duration(seconds: 1));
          expect(handler.status, isA<Connecting>());
          ready(async);
          expect(handler.status, isA<Playing>());
          async.elapse(const Duration(seconds: 31));

          // Outage 2 starts from attempt 0 (an immediate retry) with a full
          // 3 min budget.
          everyLoadFails();
          final before = player.loads.length;
          player.emitFailure(generation: player.lastLoad.generation);
          async.elapse(Duration.zero);
          expect(player.loads.length, before + 1);
          async.elapse(const Duration(minutes: 2, seconds: 59));
          expect(handler.status, isNot(isA<PlaybackError>()));
          async.elapse(const Duration(seconds: 1));
          expect(handler.status, isA<PlaybackError>());
        });
      });

      test('a drop within 30 s of recovering continues the backoff', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          player.emitFailure(generation: player.lastLoad.generation);
          async.elapse(Duration.zero);
          ready(async);
          async.elapse(const Duration(seconds: 10));
          final before = player.loads.length;
          player.emitFailure(generation: player.lastLoad.generation);
          async.flushMicrotasks();
          expect(
            handler.status,
            isA<Reconnecting>().having((r) => r.attempt, 'attempt', 1),
          );
          async.elapse(const Duration(milliseconds: 900));
          expect(player.loads.length, before);
          async.elapse(const Duration(milliseconds: 200));
          expect(player.loads.length, before + 1);
        });
      });

      test('setRetryBudget(batterySaver) during Playing: the next outage gives '
          'up after 1 min online', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          unawaited(engine.setRetryBudget(RetryBudgetPreset.batterySaver));
          async.flushMicrotasks();
          expect(handler.retryBudget, RetryBudgetPreset.batterySaver);
          expect(handler.status, isA<Playing>());

          everyLoadFails();
          player.emitFailure(generation: player.lastLoad.generation);
          async.elapse(const Duration(seconds: 59));
          expect(handler.status, isNot(isA<PlaybackError>()));
          async.elapse(const Duration(seconds: 1));
          expect(
            handler.status,
            PlaybackStatus.error(
              station: oneStream,
              kind: PlaybackErrorKind.streamUnreachable,
            ),
          );
          expect(handler.playbackState.value.playing, isFalse);
        });
      });

      for (final (label, command, expected) in [
        (
          'pause',
          (RadioAudioHandler h) => h.pause(),
          PlaybackStatus.paused(station: oneStream),
        ),
        (
          'stop',
          (RadioAudioHandler h) => h.stop(),
          const PlaybackStatus.idle(),
        ),
      ]) {
        test('$label during Reconnecting: nothing restarts playback '
            'afterwards (PLAY-10)', () {
          fakeAsync((async) {
            final handler = playing(async, oneStream);
            everyLoadFails();
            player.emitFailure(generation: player.lastLoad.generation);
            async.elapse(const Duration(seconds: 2));
            expect(handler.status, isA<Reconnecting>());
            final loads = player.loads.length;

            unawaited(command(handler));
            async.flushMicrotasks();
            expect(handler.status, expected);
            expect(handler.playbackState.value.playing, isFalse);
            expect(session.releaseCalls, 1);

            async.elapse(const Duration(minutes: 10));
            expect(player.loads, hasLength(loads));
            expect(handler.status, expected);
          });
        });

        test('$label while a retry is resolving: the result never loads', () {
          fakeAsync((async) {
            final handler = playing(async, oneStream);
            final gate = Completer<void>();
            resolver.script(only.url, ResolveScript(gate: gate.future));
            player.emitFailure(generation: player.lastLoad.generation);
            async.elapse(Duration.zero);
            expect(handler.status, isA<Connecting>());
            expect(player.loads, hasLength(1));

            unawaited(command(handler));
            async.flushMicrotasks();
            gate.complete();
            async.elapse(const Duration(minutes: 10));
            expect(player.loads, hasLength(1));
            expect(handler.status, expected);
          });
        });
      }

      test('another station during Reconnecting wins: only it loads', () {
        fakeAsync((async) {
          final handler = playing(async, oneStream);
          everyLoadFails();
          player.emitFailure(generation: player.lastLoad.generation);
          async.elapse(const Duration(seconds: 2));
          expect(handler.status, isA<Reconnecting>());
          player.onLoad = null;
          final loads = player.loads.length;

          unawaited(handler.playFromMediaId(_mediaId(other)));
          async.flushMicrotasks();
          ready(async);
          expect(
            handler.status,
            PlaybackStatus.playing(station: other, streamIndex: 0),
          );
          async.elapse(const Duration(minutes: 10));
          expect(player.loads, hasLength(loads + 1));
          expect(player.lastLoad.uri, other.streams.single.url);
          expect(handler.status, isA<Playing>());
        });
      });
    },
  );
  group('network changes and offline periods (PLAY-07, PLAY-10, D-10), '
      'under fakeAsync', () {
    final only = StationStream(
      url: Uri.parse('https://only.example/live.mp3'),
      kind: StreamKind.progressive,
    );
    final station = Station(
      id: StationId.debug('net'),
      name: 'Мрежа',
      nameLatin: 'Mrezha',
      streams: [only],
    );
    final netDirectory = StationDirectory([station]);

    late FakeStreamResolver resolver;

    /// Built inside the fakeAsync zone; no jitter.
    RadioAudioHandler handlerWith() {
      resolver = FakeStreamResolver();
      final handler = RadioAudioHandler(
        player,
        session,
        netDirectory,
        resolver,
        _english,
        connectivity,
        reconnectPolicy: ReconnectPolicy(Random(0), jitter: 0),
      );
      addTearDown(handler.dispose);
      return handler;
    }

    void ready(FakeAsync async) {
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: player.lastLoad.generation,
      );
      async.flushMicrotasks();
    }

    RadioAudioHandler playing(FakeAsync async) {
      final handler = handlerWith();
      async.flushMicrotasks();
      unawaited(handler.playFromMediaId(_mediaId(station)));
      async.flushMicrotasks();
      ready(async);
      expect(handler.status, isA<Playing>());
      return handler;
    }

    void emit(FakeAsync async, {required bool online, bool changed = false}) {
      connectivity.emit(online: online, networkChanged: changed);
      async.flushMicrotasks();
    }

    void buffered(FakeAsync async, int ms) {
      player.emitBuffered(
        Duration(milliseconds: ms),
        generation: player.lastLoad.generation,
      );
      async.flushMicrotasks();
    }

    Matcher waiting() => isA<Reconnecting>().having(
      (r) => r.waitingForNetwork,
      'waitingForNetwork',
      isTrue,
    );

    test('the handler asks isOnline once at start and seeds the state: '
        'offline at start, a drop waits for the network', () {
      fakeAsync((async) {
        connectivity.online = false;
        final handler = playing(async);
        expect(connectivity.isOnlineCalls, 1);
        player.emitFailure(generation: player.lastLoad.generation);
        async.elapse(const Duration(minutes: 1));
        expect(handler.status, waiting());
        expect(player.loads, hasLength(1));
      });
    });

    test('airplane mode: offline, the drop waits without retrying and the '
        'notification stays up; back online -> a fresh load at once, then '
        'Playing', () {
      fakeAsync((async) {
        final handler = playing(async);
        emit(async, online: false);
        expect(handler.status, isA<Playing>());
        player.emitFailure(generation: player.lastLoad.generation);
        async.flushMicrotasks();
        expect(handler.status, waiting());
        final state = handler.playbackState.value;
        expect(state.playing, isTrue);
        expect(state.processingState, AudioProcessingState.buffering);
        expect(handler.mediaItem.value?.displaySubtitle, 'Reconnecting…');
        expect(handler.currentDiagnostics.nextRetryDelay, isNull);

        async.elapse(const Duration(minutes: 1));
        expect(player.loads, hasLength(1));
        expect(session.releaseCalls, 0);

        final stops = player.stopCalls;
        emit(async, online: true);
        expect(player.loads, hasLength(2));
        expect(player.lastLoad.uri, only.url);
        expect(handler.status, isA<Connecting>());
        expect(handler.playbackState.value.playing, isTrue);
        expect(player.stopCalls, greaterThanOrEqualTo(stops));
        ready(async);
        expect(handler.status, isA<Playing>());
      });
    });

    test('Wi-Fi to 4G while Playing: buffered position stuck for 5 s -> an '
        'immediate reload', () {
      fakeAsync((async) {
        final handler = playing(async);
        buffered(async, 4000);
        emit(async, online: true, changed: true);
        async.elapse(const Duration(milliseconds: 4900));
        expect(player.loads, hasLength(1));
        async.elapse(const Duration(milliseconds: 200));
        expect(player.loads, hasLength(2));
        expect(handler.status, isA<Connecting>());
        expect(handler.playbackState.value.playing, isTrue);
      });
    });

    test('Wi-Fi to 4G while Playing: audio still arriving -> nothing is '
        'reloaded', () {
      fakeAsync((async) {
        final handler = playing(async);
        buffered(async, 4000);
        emit(async, online: true, changed: true);
        async.elapse(const Duration(seconds: 2));
        buffered(async, 6000);
        async.elapse(const Duration(minutes: 1));
        expect(player.loads, hasLength(1));
        expect(handler.status, isA<Playing>());
      });
    });

    test('a network change while Reconnecting retries at once (no waiting '
        'for the backoff)', () {
      fakeAsync((async) {
        final handler = playing(async);
        player.onLoad = (_, generation) =>
            scheduleMicrotask(() => player.emitFailure(generation: generation));
        player.emitFailure(generation: player.lastLoad.generation);
        async.elapse(const Duration(seconds: 3));
        // Retries at 0 and 1 s failed; the next waits 4 s.
        expect(handler.status, isA<Reconnecting>());
        final loads = player.loads.length;
        player.onLoad = null;
        emit(async, online: true, changed: true);
        expect(player.loads, hasLength(loads + 1));
        ready(async);
        expect(handler.status, isA<Playing>());
      });
    });

    test('standard offline budget: 10 min offline -> Error(offline), focus '
        'released, playing false (no foreground service), nothing after', () {
      fakeAsync((async) {
        final handler = playing(async);
        emit(async, online: false);
        player.emitFailure(generation: player.lastLoad.generation);
        async.elapse(const Duration(minutes: 9, seconds: 59));
        expect(handler.status, waiting());
        expect(player.loads, hasLength(1));

        async.elapse(const Duration(seconds: 1));
        expect(
          handler.status,
          PlaybackStatus.error(
            station: station,
            kind: PlaybackErrorKind.offline,
          ),
        );
        final state = handler.playbackState.value;
        expect(state.playing, isFalse);
        expect(state.processingState, AudioProcessingState.error);
        expect(session.releaseCalls, 1);

        // Coming back online later starts nothing (PLAY-10).
        emit(async, online: true, changed: true);
        async.elapse(const Duration(minutes: 10));
        expect(player.loads, hasLength(1));
        expect(handler.status, isA<PlaybackError>());
      });
    });

    test('idempotency: the stall timer and a network change in the same '
        'tick start exactly one fresh connection', () {
      fakeAsync((async) {
        playing(async);
        player.emitSnapshot(
          PlayerProcessingState.buffering,
          playing: true,
          generation: player.lastLoad.generation,
        );
        async.flushMicrotasks();
        // Fires at the same fake instant as the 8 s stall timer.
        Timer(
          const Duration(seconds: 8),
          () => connectivity.emit(online: true, networkChanged: true),
        );
        async.elapse(const Duration(seconds: 8));
        async.elapse(const Duration(seconds: 1));
        expect(player.loads, hasLength(2));
      });
    });

    test('online while Connecting does not restart the connection', () {
      fakeAsync((async) {
        final handler = handlerWith();
        async.flushMicrotasks();
        final gate = Completer<void>();
        resolver.script(only.url, ResolveScript(gate: gate.future));
        unawaited(handler.playFromMediaId(_mediaId(station)));
        async.flushMicrotasks();
        expect(handler.status, isA<Connecting>());
        emit(async, online: true, changed: true);
        emit(async, online: false);
        emit(async, online: true);
        gate.complete();
        async.flushMicrotasks();
        expect(player.loads, hasLength(1));
        expect(resolver.resolveCalls, hasLength(1));
      });
    });

    for (final (label, command) in [
      ('pause', (RadioAudioHandler h) => h.pause()),
      ('stop', (RadioAudioHandler h) => h.stop()),
    ]) {
      test('after a user $label, connectivity events start nothing '
          '(PLAY-10)', () {
        fakeAsync((async) {
          final handler = playing(async);
          unawaited(command(handler));
          async.flushMicrotasks();
          final status = handler.status;
          emit(async, online: false);
          emit(async, online: true);
          emit(async, online: true, changed: true);
          async.elapse(const Duration(minutes: 15));
          expect(player.loads, hasLength(1));
          expect(handler.status, status);
          expect(handler.playbackState.value.playing, isFalse);
        });
      });
    }

    test('pause while waiting for the network cancels the offline budget: '
        'still Paused 15 min later, no error', () {
      fakeAsync((async) {
        final handler = playing(async);
        emit(async, online: false);
        player.emitFailure(generation: player.lastLoad.generation);
        async.elapse(const Duration(minutes: 1));
        expect(handler.status, waiting());
        unawaited(handler.pause());
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 15));
        expect(handler.status, PlaybackStatus.paused(station: station));
        emit(async, online: true, changed: true);
        async.elapse(const Duration(minutes: 1));
        expect(player.loads, hasLength(1));
      });
    });

    test('buffered positions do not flood the diagnostics log; connectivity '
        'changes are logged', () {
      fakeAsync((async) {
        final handler = playing(async);
        for (var i = 1; i <= 100; i++) {
          buffered(async, i * 500);
        }
        emit(async, online: false);
        final messages = [
          for (final e in handler.currentDiagnostics.recentEvents) e.message,
        ];
        expect(messages.where((m) => m.contains('BufferedPosition')), isEmpty);
        expect(messages.last, startsWith('ConnectivityChanged(offline)'));
      });
    });
  });

  group('calls, navigation prompts, unplugging and other media apps '
      '(PLAY-05, PLAY-06, PLAY-10, D-11), under fakeAsync', () {
    final first = StationStream(
      url: Uri.parse('https://focus.example/primary.mp3'),
      kind: StreamKind.progressive,
    );
    final second = StationStream(
      url: Uri.parse('https://focus.example/fallback.mp3'),
      kind: StreamKind.progressive,
    );
    final station = Station(
      id: StationId.debug('focus'),
      name: 'Фокус',
      nameLatin: 'Fokus',
      streams: [first, second],
    );
    final focusDirectory = StationDirectory([station]);

    /// Built inside the fakeAsync zone; no jitter.
    RadioAudioHandler handlerWith() {
      final handler = RadioAudioHandler(
        player,
        session,
        focusDirectory,
        FakeStreamResolver(),
        _english,
        connectivity,
        reconnectPolicy: ReconnectPolicy(Random(0), jitter: 0),
      );
      addTearDown(handler.dispose);
      return handler;
    }

    void ready(FakeAsync async) {
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: player.lastLoad.generation,
      );
      async.flushMicrotasks();
    }

    /// Playing on the fallback stream (so the resume must use stream 1).
    RadioAudioHandler playing(FakeAsync async) {
      final handler = handlerWith();
      async.flushMicrotasks();
      unawaited(
        handler.playFromMediaId(_mediaId(station), {
          RadioAudioHandler.startStreamIndexExtra: 1,
        }),
      );
      async.flushMicrotasks();
      ready(async);
      expect(handler.status, isA<Playing>());
      expect(player.lastLoad.uri, second.url);
      return handler;
    }

    void focus(FakeAsync async, FocusChange change) {
      session.emitFocus(change);
      async.flushMicrotasks();
    }

    void noisy(FakeAsync async) {
      session.emitNoisy();
      async.flushMicrotasks();
    }

    for (final minutes in [1, 15]) {
      test('a $minutes-minute call: Interrupted with the transport stopped, '
          'focus kept and the notification up; after hang-up a fresh load of '
          'the last working stream, then Playing', () {
        fakeAsync((async) {
          final handler = playing(async);
          final stops = player.stopCalls;
          focus(async, FocusChange.transientLoss);
          expect(handler.status, PlaybackStatus.interrupted(station: station));
          expect(player.stopCalls, stops + 1);
          expect(session.releaseCalls, 0);
          final state = handler.playbackState.value;
          expect(state.playing, isTrue);
          expect(state.processingState, AudioProcessingState.buffering);
          expect(handler.mediaItem.value?.displaySubtitle, 'Interrupted');

          async.elapse(Duration(minutes: minutes));
          expect(handler.status, isA<Interrupted>());
          expect(player.loads, hasLength(1));

          focus(async, FocusChange.gainAfterPause);
          expect(player.loads, hasLength(2));
          expect(player.lastLoad.uri, second.url);
          expect(
            player.lastLoad.generation,
            greaterThan(player.loads.first.generation),
          );
          expect(handler.status, isA<Connecting>());
          expect(handler.playbackState.value.playing, isTrue);
          ready(async);
          expect(handler.status, isA<Playing>());
          expect(session.releaseCalls, 0);
        });
      });
    }

    test('network changes during a call reload nothing', () {
      fakeAsync((async) {
        final handler = playing(async);
        focus(async, FocusChange.transientLoss);
        connectivity.emit(online: false);
        async.flushMicrotasks();
        connectivity.emit(online: true, networkChanged: true);
        async.elapse(const Duration(minutes: 5));
        expect(handler.status, isA<Interrupted>());
        expect(player.loads, hasLength(1));
      });
    });

    test('another media app (permanent loss): Paused, focus released, '
        'playing false; a later gain does not resume', () {
      fakeAsync((async) {
        final handler = playing(async);
        focus(async, FocusChange.permanentLoss);
        expect(handler.status, PlaybackStatus.paused(station: station));
        expect(session.releaseCalls, 1);
        expect(handler.playbackState.value.playing, isFalse);
        focus(async, FocusChange.gainAfterPause);
        async.elapse(const Duration(minutes: 10));
        expect(player.loads, hasLength(1));
        expect(handler.status, isA<Paused>());
      });
    });

    test('unplugging headphones (becoming noisy): Paused, focus released; '
        'nothing resumes it', () {
      fakeAsync((async) {
        final handler = playing(async);
        noisy(async);
        expect(handler.status, PlaybackStatus.paused(station: station));
        expect(session.releaseCalls, 1);
        expect(handler.playbackState.value.playing, isFalse);
        focus(async, FocusChange.gainAfterPause);
        connectivity.emit(online: true, networkChanged: true);
        async.elapse(const Duration(minutes: 10));
        expect(player.loads, hasLength(1));
        expect(handler.status, isA<Paused>());
      });
    });

    test('Bluetooth disconnect during a call: Paused, and hang-up does not '
        'resume', () {
      fakeAsync((async) {
        final handler = playing(async);
        focus(async, FocusChange.transientLoss);
        noisy(async);
        expect(handler.status, isA<Paused>());
        expect(session.releaseCalls, 1);
        focus(async, FocusChange.gainAfterPause);
        async.elapse(const Duration(minutes: 1));
        expect(player.loads, hasLength(1));
      });
    });

    test('a navigation prompt ducks to 0.3 and restores 1.0 without '
        'stopping playback', () {
      fakeAsync((async) {
        final handler = playing(async);
        final stops = player.stopCalls;
        focus(async, FocusChange.duckBegin);
        expect(player.volumes, [0.3]);
        expect(handler.status, isA<Playing>());
        focus(async, FocusChange.duckEnd);
        expect(player.volumes, [0.3, 1.0]);
        expect(handler.status, isA<Playing>());
        expect(player.stopCalls, stops);
        expect(player.loads, hasLength(1));
      });
    });

    test('pause during a duck restores full volume for the next play', () {
      fakeAsync((async) {
        final handler = playing(async);
        focus(async, FocusChange.duckBegin);
        unawaited(handler.pause());
        async.flushMicrotasks();
        expect(player.volumes, [0.3, 1.0]);
      });
    });

    test('pause during a call: Paused with focus released', () {
      fakeAsync((async) {
        final handler = playing(async);
        focus(async, FocusChange.transientLoss);
        unawaited(handler.pause());
        async.flushMicrotasks();
        expect(handler.status, PlaybackStatus.paused(station: station));
        expect(session.releaseCalls, 1);
        focus(async, FocusChange.gainAfterPause);
        expect(player.loads, hasLength(1));
      });
    });

    test('stop during a call: Idle, the service stops', () {
      fakeAsync((async) {
        final handler = playing(async);
        focus(async, FocusChange.transientLoss);
        unawaited(handler.stop());
        async.flushMicrotasks();
        expect(handler.status, const PlaybackStatus.idle());
        expect(
          handler.playbackState.value.processingState,
          AudioProcessingState.idle,
        );
        focus(async, FocusChange.gainAfterPause);
        expect(player.loads, hasLength(1));
      });
    });

    for (final (label, command) in [
      ('pause', (RadioAudioHandler h) => h.pause()),
      ('stop', (RadioAudioHandler h) => h.stop()),
    ]) {
      test('after a user $label, gain, noisy and online events start nothing '
          '(PLAY-10)', () {
        fakeAsync((async) {
          final handler = playing(async);
          unawaited(command(handler));
          async.flushMicrotasks();
          final status = handler.status;
          focus(async, FocusChange.gainAfterPause);
          noisy(async);
          connectivity.emit(online: false);
          async.flushMicrotasks();
          connectivity.emit(online: true, networkChanged: true);
          async.elapse(const Duration(minutes: 15));
          expect(player.loads, hasLength(1));
          expect(handler.status, status);
          expect(handler.playbackState.value.playing, isFalse);
        });
      });
    }

    test('in PlaybackError, gain, noisy and online events start nothing '
        '(PLAY-10)', () {
      fakeAsync((async) {
        final handler = handlerWith();
        async.flushMicrotasks();
        player.onLoad = (_, generation) =>
            scheduleMicrotask(() => player.emitFailure(generation: generation));
        unawaited(handler.playFromMediaId(_mediaId(station)));
        async.flushMicrotasks();
        expect(handler.status, isA<PlaybackError>());
        player.onLoad = null;
        final loads = player.loads.length;
        focus(async, FocusChange.gainAfterPause);
        noisy(async);
        connectivity.emit(online: true, networkChanged: true);
        async.elapse(const Duration(minutes: 15));
        expect(player.loads, hasLength(loads));
        expect(handler.status, isA<PlaybackError>());
      });
    });
  });
}
