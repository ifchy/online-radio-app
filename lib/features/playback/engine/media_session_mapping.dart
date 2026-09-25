import 'package:audio_service/audio_service.dart';

import '../../catalog/domain/station.dart';
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

/// The media-session item for [station]. Plan 01-07 adds the state subtitle.
MediaItem mediaItemFor(Station station) => MediaItem(
  id: StationMediaId(station.id).format(),
  title: station.name,
  isLive: true,
  extras: {'stationId': station.id.value},
);
