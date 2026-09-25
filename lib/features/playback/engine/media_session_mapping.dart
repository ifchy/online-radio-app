import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show mapEquals;

import '../../catalog/domain/station.dart';
import '../domain/engine_strings.dart';
import '../domain/media_id.dart';
import '../domain/playback_status.dart';

/// The FGS table (01-RESEARCH Pattern 2): how each [PlaybackStatus] is shown
/// to audio_service.
///
/// audio_service starts the foreground service when `playing` becomes true,
/// drops it when `playing` becomes false (androidStopForegroundOnPause), and
/// stops the service when processingState becomes idle. So every state that
/// must keep the service alive, including Reconnecting and Interrupted,
/// reports `playing: true`.
///
/// There is no seek anywhere (PLAY-11). Controls are kept in one place so
/// Phase 3 can insert previous/next.
PlaybackState playbackStateFor(PlaybackStatus status) {
  final (processingState, playing) = switch (status) {
    Idle() => (AudioProcessingState.idle, false),
    Connecting() => (AudioProcessingState.loading, true),
    Playing() => (AudioProcessingState.ready, true),
    Buffering() ||
    Reconnecting() ||
    Interrupted() => (AudioProcessingState.buffering, true),
    Paused() => (AudioProcessingState.ready, false),
    PlaybackError() => (AudioProcessingState.error, false),
  };
  final controls = switch (status) {
    Idle() => const <MediaControl>[],
    Paused() || PlaybackError() => const [MediaControl.play, MediaControl.stop],
    _ => const [MediaControl.pause, MediaControl.stop],
  };
  return PlaybackState(
    processingState: processingState,
    playing: playing,
    controls: controls,
    androidCompactActionIndices: controls.isEmpty ? null : const [0, 1],
    systemActions: const {},
    errorMessage: switch (status) {
      PlaybackError(:final kind) => kind.name,
      _ => null,
    },
  );
}

/// The media-session item for [station] in [status]: what the notification
/// and the lock screen show.
///
/// The title is always the station name. Under it goes the same state text
/// the mini-player shows (D-09) whenever the player is not simply playing.
/// Playing and Idle have no subtitle; plan 01-08 puts the ICY now-playing
/// text there while Playing.
MediaItem mediaItemFor(
  Station station,
  PlaybackStatus status,
  EngineStrings strings,
) {
  final stateText = _stateText(status, strings);
  return MediaItem(
    id: StationMediaId(station.id).format(),
    title: station.name,
    artist: stateText,
    displaySubtitle: stateText,
    isLive: true,
    extras: {'stationId': station.id.value},
  );
}

String? _stateText(PlaybackStatus status, EngineStrings strings) =>
    switch (status) {
      Connecting() => strings.connecting,
      Buffering() => strings.buffering,
      Reconnecting() => strings.reconnecting,
      Interrupted() => strings.interrupted,
      Paused() => strings.paused,
      PlaybackError() => strings.error,
      Playing() || Idle() => null,
    };

/// Whether [a] and [b] would show the same thing. `MediaItem ==` compares
/// only the id, so it cannot tell "Connecting…" from "Paused".
bool sameMediaItem(MediaItem? a, MediaItem? b) {
  if (a == null || b == null) return a == b;
  return a.id == b.id &&
      a.title == b.title &&
      a.artist == b.artist &&
      a.album == b.album &&
      a.displayTitle == b.displayTitle &&
      a.displaySubtitle == b.displaySubtitle &&
      a.displayDescription == b.displayDescription &&
      a.artUri == b.artUri &&
      a.isLive == b.isLive &&
      mapEquals(a.extras, b.extras);
}
