import 'dart:async';

import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/audio_engine.dart';
import 'package:radio/features/playback/domain/now_playing.dart';
import 'package:radio/features/playback/domain/play_context.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/engine/ports.dart';

/// A recorded [FakeEngine.play] call.
class PlayCall {
  const PlayCall(this.station, this.context);

  final Station station;
  final PlayContext context;
}

/// [AudioEngine] for widget tests: the test sets the status and current
/// station, and the fake records the commands it receives. It does not change
/// its own state when commanded; tests publish the engine's reaction with
/// [setStatus] / [setStation].
///
/// Every stream replays the latest value to a new listener, like the real
/// engine.
class FakeEngine implements AudioEngine {
  FakeEngine({PlaybackStatus status = const PlaybackStatus.idle()})
    : _status = status,
      _station = status.stationOrNull;

  PlaybackStatus _status;
  Station? _station;
  NowPlaying? _nowPlaying;
  final _statusChanges = StreamController<PlaybackStatus>.broadcast();
  final _stationChanges = StreamController<Station?>.broadcast();
  final _nowPlayingChanges = StreamController<NowPlaying?>.broadcast();

  final List<PlayCall> playCalls = [];
  int togglePauseCalls = 0;
  int stopCalls = 0;

  /// Publishes [status]; the current station is left as it is.
  void setStatus(PlaybackStatus status) {
    _status = status;
    _statusChanges.add(status);
  }

  /// Publishes [station] as the current station.
  void setStation(Station? station) {
    _station = station;
    _stationChanges.add(station);
  }

  /// Publishes [nowPlaying] as the current now-playing value.
  void setNowPlaying(NowPlaying? nowPlaying) {
    _nowPlaying = nowPlaying;
    _nowPlayingChanges.add(nowPlaying);
  }

  @override
  Stream<NowPlaying?> get nowPlaying =>
      _replayLatest(() => _nowPlaying, _nowPlayingChanges.stream);

  @override
  Stream<PlaybackStatus> get status =>
      _replayLatest(() => _status, _statusChanges.stream);

  @override
  PlaybackStatus get currentStatus => _status;

  @override
  Stream<Station?> get currentStation =>
      _replayLatest(() => _station, _stationChanges.stream);

  @override
  Future<void> play(
    Station station, {
    PlayContext context = const PlayContext.single(),
  }) async => playCalls.add(PlayCall(station, context));

  @override
  Future<void> togglePause() async => togglePauseCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  static Stream<T> _replayLatest<T>(T Function() latest, Stream<T> changes) =>
      Stream<T>.multi((controller) {
        controller.add(latest());
        final subscription = changes.listen(controller.add);
        controller.onCancel = subscription.cancel;
      });
}

/// One call log shared by the fakes, so tests can assert the global order of
/// player and audio-session calls.
class CallLog {
  final List<String> entries = [];

  void add(String entry) => entries.add(entry);
}

/// A recorded [FakeStreamPlayer.load] call.
class LoadCall {
  const LoadCall(this.uri, this.kind, this.generation);

  final Uri uri;
  final PlayableKind kind;
  final int generation;

  @override
  String toString() => 'LoadCall(${kind.name}, $uri, gen $generation)';
}

/// [StreamPlayer] that records calls and lets tests emit player events.
/// Events are delivered synchronously.
class FakeStreamPlayer implements StreamPlayer {
  FakeStreamPlayer([CallLog? log]) : log = log ?? CallLog();

  final CallLog log;
  final List<LoadCall> loads = [];
  int stopCalls = 0;
  final List<double> volumes = [];

  /// Runs at the start of every [load], before it is recorded; lets a test
  /// capture what had been published when the load began.
  void Function(ResolvedStream stream, int generation)? onLoad;

  final _snapshots = StreamController<PlayerSnapshot>.broadcast(sync: true);
  final _failures = StreamController<PlayerFailure>.broadcast(sync: true);
  final _icyTitles = StreamController<IcyTitle>.broadcast(sync: true);
  final _bufferedPositions = StreamController<BufferedPosition>.broadcast(
    sync: true,
  );

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PlayerFailure> get failures => _failures.stream;

  @override
  Stream<IcyTitle> get icyTitles => _icyTitles.stream;

  @override
  Stream<BufferedPosition> get bufferedPositions => _bufferedPositions.stream;

  LoadCall get lastLoad => loads.last;

  @override
  Future<void> load(ResolvedStream stream, {required int generation}) async {
    onLoad?.call(stream, generation);
    loads.add(LoadCall(stream.uri, stream.kind, generation));
    log.add('load');
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    log.add('stop');
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _failures.close();
    await _icyTitles.close();
    await _bufferedPositions.close();
  }

  void emitSnapshot(
    PlayerProcessingState state, {
    required bool playing,
    required int generation,
  }) => _snapshots.add(
    PlayerSnapshot(generation: generation, state: state, playing: playing),
  );

  void emitFailure({required int generation, int code = 0, String? message}) =>
      _failures.add(
        PlayerFailure(generation: generation, code: code, message: message),
      );

  void emitIcy(String? title, {required int generation}) =>
      _icyTitles.add(IcyTitle(generation: generation, title: title));

  void emitBuffered(Duration position, {required int generation}) =>
      _bufferedPositions.add(
        BufferedPosition(generation: generation, position: position),
      );
}

/// [AudioSessionPort] that counts focus releases.
class FakeAudioSessionPort implements AudioSessionPort {
  FakeAudioSessionPort([CallLog? log]) : log = log ?? CallLog();

  final CallLog log;
  int releaseCalls = 0;

  @override
  Future<void> release() async {
    releaseCalls++;
    log.add('release');
  }
}
