/// Narrow ports between the playback handler and the platform plugins, so the
/// handler can be tested with fakes.
library;

/// How a resolved stream must be opened by the player.
enum PlayableKind { progressive, hls }

/// A stream endpoint ready for the player: playlists already resolved and the
/// kind decided (never guessed from the file extension).
final class ResolvedStream {
  const ResolvedStream(this.uri, this.kind);

  final Uri uri;
  final PlayableKind kind;

  @override
  bool operator ==(Object other) =>
      other is ResolvedStream && other.uri == uri && other.kind == kind;

  @override
  int get hashCode => Object.hash(uri, kind);

  @override
  String toString() => 'ResolvedStream(${kind.name}, $uri)';
}

enum PlayerProcessingState { idle, loading, buffering, ready, completed }

/// Every player event carries the generation of the load it belongs to, so
/// the handler can drop events from superseded loads.
final class PlayerSnapshot {
  const PlayerSnapshot({
    required this.generation,
    required this.state,
    required this.playing,
  });

  final int generation;
  final PlayerProcessingState state;
  final bool playing;

  @override
  String toString() =>
      'PlayerSnapshot(gen $generation, ${state.name}, playing: $playing)';
}

final class PlayerFailure {
  const PlayerFailure({
    required this.generation,
    required this.code,
    this.message,
  });

  final int generation;
  final int code;
  final String? message;

  @override
  String toString() => 'PlayerFailure(gen $generation, $code, $message)';
}

final class IcyTitle {
  const IcyTitle({required this.generation, this.title});

  final int generation;
  final String? title;
}

final class BufferedPosition {
  const BufferedPosition({required this.generation, required this.position});

  final int generation;
  final Duration position;
}

/// The audio player, reduced to what live radio needs.
abstract interface class StreamPlayer {
  Stream<PlayerSnapshot> get snapshots;
  Stream<PlayerFailure> get failures;
  Stream<IcyTitle> get icyTitles;
  Stream<BufferedPosition> get bufferedPositions;

  /// Stops any current transport, then opens [stream] at the live edge and
  /// starts playing. Events from this load carry [generation].
  Future<void> load(ResolvedStream stream, {required int generation});

  /// Stops the transport and releases the native player.
  Future<void> stop();

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

/// Audio focus as the handler needs it. Focus is requested by the player on
/// play; releasing it is the handler's job (just_audio never abandons focus).
abstract interface class AudioSessionPort {
  Future<void> release();
}
