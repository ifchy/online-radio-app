import 'package:freezed_annotation/freezed_annotation.dart';

import '../../catalog/domain/station.dart';

part 'playback_status.freezed.dart';

/// Why playback ended in an error. The UI maps these to localised text; the
/// domain never holds user-facing strings.
enum PlaybackErrorKind {
  offline,
  streamUnreachable,
  unsupportedFormat,
  allStreamsFailed,
  unknown,
}

/// The engine's playback state. The media-session mapping for every variant
/// lives in `media_session_mapping.dart` (the FGS table).
@freezed
sealed class PlaybackStatus with _$PlaybackStatus {
  const PlaybackStatus._();

  /// Nothing loaded; no foreground service.
  const factory PlaybackStatus.idle() = Idle;

  /// Opening `station.streams[streamIndex]`; [round] counts passes over the
  /// stream list.
  const factory PlaybackStatus.connecting({
    required Station station,
    required int streamIndex,
    required int round,
  }) = Connecting;

  const factory PlaybackStatus.playing({
    required Station station,
    required int streamIndex,
  }) = Playing;

  const factory PlaybackStatus.buffering({
    required Station station,
    required int streamIndex,
  }) = Buffering;

  /// Waiting to retry after a drop. [nextAttemptAt] is null while
  /// [waitingForNetwork] is true.
  const factory PlaybackStatus.reconnecting({
    required Station station,
    required int attempt,
    DateTime? nextAttemptAt,
    @Default(false) bool waitingForNetwork,
  }) = Reconnecting;

  /// Transient audio-focus loss (e.g. a phone call); resumes on focus gain.
  const factory PlaybackStatus.interrupted({required Station station}) =
      Interrupted;

  const factory PlaybackStatus.paused({required Station station}) = Paused;

  const factory PlaybackStatus.error({
    required Station station,
    required PlaybackErrorKind kind,
  }) = PlaybackError;

  /// The station this status is about, or null when [Idle].
  Station? get stationOrNull => switch (this) {
    Idle() => null,
    Connecting(:final station) ||
    Playing(:final station) ||
    Buffering(:final station) ||
    Reconnecting(:final station) ||
    Interrupted(:final station) ||
    Paused(:final station) ||
    PlaybackError(:final station) => station,
  };
}
