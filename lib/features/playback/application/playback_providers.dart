import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../catalog/domain/station.dart';
import '../domain/audio_engine.dart';
import '../domain/engine_diagnostics.dart';
import '../domain/now_playing.dart';
import '../domain/playback_status.dart';

part 'playback_providers.g.dart';

/// The playback engine. Overridden in `bootstrap` (and in tests).
@Riverpod(keepAlive: true)
AudioEngine audioEngine(Ref ref) => throw UnimplementedError(
  'audioEngineProvider must be overridden in bootstrap',
);

/// Read-only mirror of the engine status.
@Riverpod(keepAlive: true)
Stream<PlaybackStatus> playbackStatus(Ref ref) =>
    ref.watch(audioEngineProvider).status;

/// Read-only mirror of the engine's current station.
@Riverpod(keepAlive: true)
Stream<Station?> currentStation(Ref ref) =>
    ref.watch(audioEngineProvider).currentStation;

/// Read-only mirror of the engine's now-playing value (ICY), or null.
@Riverpod(keepAlive: true)
Stream<NowPlaying?> nowPlaying(Ref ref) =>
    ref.watch(audioEngineProvider).nowPlaying;

/// Read-only mirror of the engine's diagnostics, for the debug panel (D-07).
/// In memory only: nothing reads this provider to store or send it.
@Riverpod(keepAlive: true)
Stream<EngineDiagnostics> diagnostics(Ref ref) =>
    ref.watch(audioEngineProvider).diagnostics;
