import '../../catalog/domain/station.dart';
import 'now_playing.dart';
import 'play_context.dart';
import 'playback_status.dart';

/// The playback facade the app talks to. The implementation behind it
/// (audio_service + just_audio today) can be swapped without touching the UI.
///
/// Later plans add members to this interface; they do not change these.
abstract interface class AudioEngine {
  /// Playback status. A new listener receives the latest value first.
  Stream<PlaybackStatus> get status;

  PlaybackStatus get currentStatus;

  /// The station being played or paused, or null when idle. A new listener
  /// receives the latest value first.
  Stream<Station?> get currentStation;

  /// What the current station says is on air (its parsed ICY title), or null
  /// when there is nothing to show: no title yet, a junk title, an HLS
  /// station, or not playing. Cleared on every station start, pause, stop and
  /// failure. A new listener receives the latest value first.
  Stream<NowPlaying?> get nowPlaying;

  /// Starts [station] at the live edge.
  Future<void> play(
    Station station, {
    PlayContext context = const PlayContext.single(),
  });

  /// Pauses when playing; otherwise resumes at the live edge.
  Future<void> togglePause();

  /// Stops playback, releases audio focus and removes the notification.
  Future<void> stop();
}
