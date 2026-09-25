import 'dart:async';

import '../../catalog/domain/station.dart';
import '../domain/audio_engine.dart';
import '../domain/engine_diagnostics.dart';
import '../domain/media_id.dart';
import '../domain/now_playing.dart';
import '../domain/play_context.dart';
import '../domain/playback_status.dart';
import 'radio_audio_handler.dart';

/// [AudioEngine] backed by the audio_service [RadioAudioHandler].
///
/// `play` goes through `playFromMediaId`, the same path Bluetooth, the
/// notification and (v1.1) Android Auto use, so everything that works from
/// the UI also works from the car.
class AudioServiceEngine implements AudioEngine {
  AudioServiceEngine(this._handler);

  final RadioAudioHandler _handler;

  @override
  Stream<PlaybackStatus> get status =>
      _replayLatest(() => _handler.status, _handler.statusStream);

  @override
  PlaybackStatus get currentStatus => _handler.status;

  @override
  Stream<Station?> get currentStation => _replayLatest(
    () => _handler.currentStation,
    _handler.currentStationStream,
  );

  @override
  Stream<NowPlaying?> get nowPlaying =>
      _replayLatest(() => _handler.nowPlaying, _handler.nowPlayingStream);

  @override
  Stream<EngineDiagnostics> get diagnostics =>
      _replayLatest(() => _handler.currentDiagnostics, _handler.diagnostics);

  @override
  Future<void> play(
    Station station, {
    PlayContext context = const PlayContext.single(),
    int startStreamIndex = 0,
  }) async {
    _handler.playContext = context;
    await _handler.playFromMediaId(StationMediaId(station.id).format(), {
      RadioAudioHandler.startStreamIndexExtra: startStreamIndex,
    });
  }

  @override
  Future<void> skipToNext() => _handler.skipToNext();

  @override
  Future<void> skipToPrevious() => _handler.skipToPrevious();

  @override
  Future<void> togglePause() async {
    if (_handler.playbackState.value.playing) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  @override
  Future<void> stop() => _handler.stop();

  /// Emits the current value on listen, then every later change.
  static Stream<T> _replayLatest<T>(T Function() latest, Stream<T> changes) =>
      Stream<T>.multi((controller) {
        controller.add(latest());
        final subscription = changes.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
      });
}
