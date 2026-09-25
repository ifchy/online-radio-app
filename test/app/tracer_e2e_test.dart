// End-to-end tracer: HomeScreen -> AudioServiceEngine -> RadioAudioHandler ->
// StreamPlayer, with only the native player and audio session faked.
//
// Calling handler.play() / pause() / stop() / click() is exactly what the
// media notification, the lock screen and headset buttons do through
// audio_service.
import 'package:audio_service/audio_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:radio/app/app.dart';
import 'package:radio/core/network/media_http_client.dart';
import 'package:radio/features/catalog/application/catalog_providers.dart';
import 'package:radio/features/catalog/data/station_directory.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/application/playback_providers.dart';
import 'package:radio/features/playback/domain/engine_strings.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/engine/audio_service_engine.dart';
import 'package:radio/features/playback/engine/ports.dart';
import 'package:radio/features/playback/engine/radio_audio_handler.dart';
import 'package:radio/features/playback/engine/resolver/stream_resolver.dart';
import 'package:radio/l10n/app_localizations.dart';

import '../support/fakes.dart';

List<MediaAction> _actions(PlaybackState state) => [
  for (final c in state.controls) c.action,
];

void main() {
  testWidgets(
    'tapping БГ Радио plays it through every layer; notification, headset '
    'and facade controls pause, resume at the live edge and stop',
    (tester) async {
      final log = CallLog();
      final player = FakeStreamPlayer(log);
      final session = FakeAudioSessionPort(log);
      final directory = StationDirectory.phase1();
      // A progressive stream must never touch the network in Dart: the
      // resolver's client fails the test if it is ever called.
      final resolver = HttpStreamResolver(
        MediaHttpClient(
          MockClient((request) async {
            fail('Unexpected HTTP request for a progressive stream: $request');
          }),
          'eRadioto/test',
        ),
        const Clock(),
      );
      final strings = EngineStrings.fromLocalizations(
        lookupAppLocalizations(const Locale('en')),
      );
      final handler = RadioAudioHandler(
        player,
        session,
        directory,
        resolver,
        strings,
      );
      final engine = AudioServiceEngine(handler);
      final station = directory.byId(StationId.curated('bg-radio'))!;

      // What the media session showed at the moment each load began.
      final statesAtLoad = <PlaybackState>[];
      final itemsAtLoad = <MediaItem?>[];
      player.onLoad = (_, _) {
        statesAtLoad.add(handler.playbackState.value);
        itemsAtLoad.add(handler.mediaItem.value);
      };

      final stationEvents = <Station?>[];
      final stationSub = engine.currentStation.listen(stationEvents.add);
      addTearDown(stationSub.cancel);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioEngineProvider.overrideWithValue(engine),
            stationDirectoryProvider.overrideWithValue(directory),
          ],
          child: const RadioApp(),
        ),
      );

      // 1. Tap the station in the list.
      final tile = find.text(station.name);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pump();

      // 2. playing:true + loading was published before the load; the load is
      //    the station's first stream, as a progressive source.
      expect(player.loads, hasLength(1));
      expect(statesAtLoad.single.playing, isTrue);
      expect(statesAtLoad.single.processingState, AudioProcessingState.loading);
      expect(itemsAtLoad.single?.title, station.name);
      expect(log.entries, ['stop', 'load']);
      expect(player.lastLoad.uri, station.streams.first.url);
      expect(player.lastLoad.kind, PlayableKind.progressive);
      expect(handler.mediaItem.value?.title, station.name);
      expect(handler.mediaItem.value?.isLive, isTrue);
      expect(engine.currentStatus, isA<Connecting>());
      final gen1 = player.lastLoad.generation;

      // 3. The player reports audio -> Playing, with Pause + Stop and no seek.
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: gen1,
      );
      expect(engine.currentStatus, isA<Playing>());
      var state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.playing, isTrue);
      expect(_actions(state), [MediaAction.pause, MediaAction.stop]);
      expect(state.androidCompactActionIndices, [0, 1]);
      expect(state.systemActions, isEmpty);

      // 4. Notification Pause: the transport stops and focus is released.
      final stopsBeforePause = player.stopCalls;
      await handler.pause();
      await tester.pump();
      expect(player.stopCalls, stopsBeforePause + 1);
      expect(session.releaseCalls, 1);
      expect(engine.currentStatus, isA<Paused>());
      state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.playing, isFalse);
      expect(_actions(state), [MediaAction.play, MediaAction.stop]);
      expect(state.systemActions, isEmpty);

      // 5. Notification Play: a fresh load at the live edge, never a resume
      //    of buffered audio. Events from the old load change nothing.
      await handler.play();
      await tester.pump();
      expect(player.loads, hasLength(2));
      final gen2 = player.lastLoad.generation;
      expect(gen2, greaterThan(gen1));
      expect(player.lastLoad.uri, station.streams.first.url);
      expect(statesAtLoad.last.playing, isTrue);
      expect(statesAtLoad.last.processingState, AudioProcessingState.loading);
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: gen1,
      );
      player.emitFailure(generation: gen1);
      expect(engine.currentStatus, isA<Connecting>());
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.loading,
      );

      // 6. Headset button while playing -> Paused; facade togglePause ->
      //    another fresh load.
      player.emitSnapshot(
        PlayerProcessingState.ready,
        playing: true,
        generation: gen2,
      );
      expect(engine.currentStatus, isA<Playing>());
      await handler.click();
      await tester.pump();
      expect(engine.currentStatus, isA<Paused>());
      expect(handler.playbackState.value.playing, isFalse);
      expect(session.releaseCalls, 2);

      await engine.togglePause();
      await tester.pump();
      expect(player.loads, hasLength(3));
      expect(player.lastLoad.generation, greaterThan(gen2));
      expect(engine.currentStatus, isA<Connecting>());
      expect(handler.playbackState.value.playing, isTrue);

      // 7. Stop: processingState idle (audio_service stops the service and
      //    removes the notification), no controls, no current station.
      await engine.stop();
      await tester.pump();
      expect(engine.currentStatus, isA<Idle>());
      state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.idle);
      expect(state.playing, isFalse);
      expect(state.controls, isEmpty);
      expect(stationEvents.first, isNull);
      expect(stationEvents, contains(station));
      expect(stationEvents.last, isNull);

      // 8. Play from Android's media card after Stop (or a Bluetooth PLAY):
      //    the last station starts again with a fresh load; the recent root
      //    offers it for resumption.
      final recent = await handler.getChildren(AudioService.recentRootId);
      expect(recent.map((i) => i.title), [station.name]);
      final loadsBefore = player.loads.length;
      await handler.play();
      await tester.pump();
      expect(player.loads, hasLength(loadsBefore + 1));
      expect(player.lastLoad.uri, station.streams.first.url);
      expect(engine.currentStatus, isA<Connecting>());
      expect(handler.playbackState.value.playing, isTrue);
      expect(stationEvents.last, station);

      // Cleanup: step 8 is still connecting, and its 10 s connect timer
      // (01-09) must not outlive the test. Stop cancels every engine timer.
      await engine.stop();
      await tester.pump();
      expect(engine.currentStatus, isA<Idle>());
    },
  );
}
