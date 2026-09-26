/// Narrow ports between the playback handler and the platform plugins, so the
/// handler can be tested with fakes.
library;

import '../../catalog/domain/station.dart';

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

/// An audio-focus change, as the engine sees it (RESEARCH Pattern 1 mapping
/// table).
enum FocusChange {
  /// Focus lost for a while, e.g. a phone call (AUDIOFOCUS_LOSS_TRANSIENT).
  transientLoss,

  /// Focus lost for good, e.g. another media app started (AUDIOFOCUS_LOSS).
  /// No gain ever follows it.
  permanentLoss,

  /// Another app plays briefly over us, e.g. a navigation prompt
  /// (AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK).
  duckBegin,

  /// The ducking app is done (AUDIOFOCUS_GAIN after a duck).
  duckEnd,

  /// Focus is back after a transient loss (AUDIOFOCUS_GAIN after a pause).
  gainAfterPause,
}

/// Audio focus as the handler needs it. Focus is requested by the player on
/// play; releasing it is the handler's job (just_audio never abandons focus).
///
/// The engine is the single owner of focus and becoming-noisy events:
/// just_audio runs with `handleInterruptions: false` (ARCHITECTURE
/// Anti-Pattern 3).
abstract interface class AudioSessionPort {
  /// Abandons audio focus.
  Future<void> release();

  /// Focus changes while the app holds (or held) a focus request.
  Stream<FocusChange> get focusChanges;

  /// Headphones unplugged or Bluetooth audio disconnected
  /// (ACTION_AUDIO_BECOMING_NOISY). Only delivered while focus is held.
  Stream<void> get becomingNoisy;
}

/// A debounced network-state change (RESEARCH "Transition rules",
/// ARCHITECTURE Pattern 4).
final class ConnectivityChange {
  const ConnectivityChange({
    required this.online,
    required this.networkChanged,
  });

  /// Whether any network is up.
  final bool online;

  /// Whether the device moved to a different set of networks than the last
  /// one it was online on (for example Wi-Fi to mobile data). Always false
  /// when [online] is false.
  final bool networkChanged;

  @override
  bool operator ==(Object other) =>
      other is ConnectivityChange &&
      other.online == online &&
      other.networkChanged == networkChanged;

  @override
  int get hashCode => Object.hash(online, networkChanged);

  @override
  String toString() =>
      'ConnectivityChange(${online ? 'online' : 'offline'}'
      '${networkChanged ? ', network changed' : ''})';
}

/// Network state as the handler needs it. Until told otherwise the network
/// counts as online.
abstract interface class ConnectivityPort {
  /// Debounced changes: emitted only when the online flag or the network set
  /// differs from the last state seen (by [isOnline] or an earlier change).
  Stream<ConnectivityChange> get changes;

  /// Whether any network is up now.
  Future<bool> isOnline();
}

/// The Wi-Fi lock that keeps the Wi-Fi radio awake with the screen off
/// (PLAT-03). just_audio holds none, so the engine takes one itself, and
/// only while audio is live or recovering (PLAT-06, T-13-01).
abstract interface class WifiLockPort {
  Future<void> acquire();

  Future<void> release();

  Future<bool> isHeld();
}

/// Turns a catalogue [StationStream] into directly playable endpoints.
///
/// Neither just_audio nor ExoPlayer parses `.pls`/`.m3u` wrappers, and the
/// source type must never be guessed from the file extension, so every stream
/// passes through here before [StreamPlayer.load].
abstract interface class StreamResolver {
  /// The playable candidates for [stream], in playlist order (they are
  /// fallbacks). Never empty: a stream with nothing playable throws
  /// [StreamResolutionException].
  Future<List<ResolvedStream>> resolve(StationStream stream);

  /// Forgets any cached resolution of [stream], so the next [resolve]
  /// fetches again. Called when playback of a resolved URL fails.
  void invalidate(StationStream stream);
}

/// Why a stream could not be resolved.
enum StreamResolutionFailure {
  /// The URL, a redirect target or every playlist entry is not http(s).
  unsupportedScheme,

  /// The playlist server answered with a non-2xx status.
  httpStatus,

  /// No complete answer within the resolver's time limit.
  timeout,

  /// The playlist body is larger than the byte cap.
  tooLarge,

  /// Playlists nest deeper than the depth limit.
  tooDeep,

  /// More redirects than the redirect limit.
  tooManyRedirects,

  /// The playlist has no playable http(s) entry.
  empty,

  /// The body is not a playlist (HTML, binary data).
  notAPlaylist,

  /// The connection failed.
  network,
}

final class StreamResolutionException implements Exception {
  const StreamResolutionException(this.reason, [this.detail]);

  final StreamResolutionFailure reason;
  final String? detail;

  @override
  String toString() => detail == null
      ? 'StreamResolutionException(${reason.name})'
      : 'StreamResolutionException(${reason.name}: $detail)';
}
