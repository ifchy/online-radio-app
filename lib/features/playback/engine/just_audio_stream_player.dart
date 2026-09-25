import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'ports.dart';

/// [StreamPlayer] over just_audio (ExoPlayer on Android).
///
/// - No localhost header proxy: the User-Agent goes to ExoPlayer natively.
/// - Interruptions (focus loss, becoming noisy) are owned by the engine, not
///   by just_audio, so they cannot resume playback behind its back.
/// - The source type comes from the resolved kind, never from the extension.
class JustAudioStreamPlayer implements StreamPlayer {
  JustAudioStreamPlayer({required String userAgent})
    : _player = AudioPlayer(
        userAgent: userAgent,
        useProxyForRequestHeaders: false,
        handleInterruptions: false,
        handleAudioSessionActivation: true,
        audioLoadConfiguration: const AudioLoadConfiguration(
          androidLoadControl: AndroidLoadControl(
            bufferForPlaybackDuration: Duration(milliseconds: 1000),
            bufferForPlaybackAfterRebufferDuration: Duration(
              milliseconds: 2500,
            ),
          ),
        ),
      ) {
    _subscriptions.addAll([
      _player.playerStateStream.listen(
        (s) => _snapshots.add(
          PlayerSnapshot(
            generation: _generation,
            state: _mapState(s.processingState),
            playing: s.playing,
          ),
        ),
      ),
      _player.errorStream.listen(
        (e) => _failures.add(
          PlayerFailure(
            generation: _generation,
            code: e.code,
            message: e.message,
          ),
        ),
      ),
      _player.icyMetadataStream.listen(
        (m) => _icyTitles.add(
          IcyTitle(generation: _generation, title: m?.info?.title),
        ),
      ),
      _player.bufferedPositionStream.listen(
        (d) => _bufferedPositions.add(
          BufferedPosition(generation: _generation, position: d),
        ),
      ),
    ]);
  }

  final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  final _failures = StreamController<PlayerFailure>.broadcast();
  final _icyTitles = StreamController<IcyTitle>.broadcast();
  final _bufferedPositions = StreamController<BufferedPosition>.broadcast();

  /// Generation of the latest load; stamps every outgoing event.
  int _generation = 0;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PlayerFailure> get failures => _failures.stream;

  @override
  Stream<IcyTitle> get icyTitles => _icyTitles.stream;

  @override
  Stream<BufferedPosition> get bufferedPositions => _bufferedPositions.stream;

  @override
  Future<void> load(ResolvedStream stream, {required int generation}) async {
    // Stopping disposes the native player: fresh ICY state and the live edge.
    await stop();
    _generation = generation;
    final source = switch (stream.kind) {
      PlayableKind.hls => HlsAudioSource(stream.uri, tag: generation),
      PlayableKind.progressive => ProgressiveAudioSource(
        stream.uri,
        tag: generation,
      ),
    };
    try {
      await _player.setAudioSource(source, preload: false);
    } on PlayerInterruptedException {
      // Superseded by a newer load or a stop; that call owns the player now.
      return;
    }
    if (_generation != generation) return;
    // Never await play(): it completes only on pause, stop or completion.
    unawaited(_player.play());
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    await _snapshots.close();
    await _failures.close();
    await _icyTitles.close();
    await _bufferedPositions.close();
  }

  static PlayerProcessingState _mapState(ProcessingState state) =>
      switch (state) {
        ProcessingState.idle => PlayerProcessingState.idle,
        ProcessingState.loading => PlayerProcessingState.loading,
        ProcessingState.buffering => PlayerProcessingState.buffering,
        ProcessingState.ready => PlayerProcessingState.ready,
        ProcessingState.completed => PlayerProcessingState.completed,
      };
}
