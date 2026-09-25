import 'dart:async';

import 'package:radio/features/playback/engine/ports.dart';

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
