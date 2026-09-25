import '../../catalog/domain/station.dart';
import 'engine_diagnostics.dart';
import 'now_playing.dart';
import 'play_context.dart';
import 'playback_status.dart';
import 'retry_budget.dart';

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

  /// What the engine is doing, for the debug panel (D-07). In memory only.
  /// A new listener receives the latest value first.
  Stream<EngineDiagnostics> get diagnostics;

  /// Starts [station] at the live edge, from `streams[startStreamIndex]`
  /// (the debug panel's stream switcher); an invalid index starts at the
  /// primary. [context] is the list next/previous move within.
  Future<void> play(
    Station station, {
    PlayContext context = const PlayContext.single(),
    int startStreamIndex = 0,
  });

  /// Pauses when playing; otherwise resumes at the live edge.
  Future<void> togglePause();

  /// Stops playback, releases audio focus and removes the notification.
  Future<void> stop();

  /// Starts the next station of the list the current one was started from,
  /// wrapping at the end. Does nothing for a single station.
  Future<void> skipToNext();

  /// Starts the previous station of that list, wrapping at the start. Does
  /// nothing for a single station.
  Future<void> skipToPrevious();

  /// How long the engine keeps reconnecting after a drop before it gives up
  /// (D-10). The single engine-level setting behind a future "trip mode" /
  /// "battery saver" toggle; Phase 1 always uses
  /// [RetryBudgetPreset.standard]. A change applies to the outage in
  /// progress too.
  Future<void> setRetryBudget(RetryBudgetPreset preset);
}
