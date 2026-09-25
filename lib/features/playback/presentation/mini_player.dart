import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/playback_providers.dart';
import '../domain/playback_status.dart';
import 'state_label.dart';

/// The bottom mini-player (D-06): the current station, its state label
/// (D-09), play/pause and stop. It has no seek bar and no position (PLAY-11):
/// live radio has neither.
///
/// It builds nothing while there is no current station, so it disappears
/// after Stop. Commands go straight to the engine; it keeps no state itself.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch both before returning early, so the status is already subscribed
    // (and current) on the first frame that has a station.
    final station = ref.watch(currentStationProvider).value;
    final status =
        ref.watch(playbackStatusProvider).value ?? const PlaybackStatus.idle();
    if (station == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = stateLabelFor(status, l);
    final pausable = _engineWouldPause(status);

    return Semantics(
      container: true,
      label: l.miniPlayerRegionLabel(station.name),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 4,
              top: 4,
              bottom: 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The region label already names the station.
                      ExcludeSemantics(
                        child: Text(
                          station.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      // Always present, so TalkBack announces the label when
                      // it appears or changes.
                      Semantics(
                        container: true,
                        liveRegion: true,
                        child: label == null
                            ? const SizedBox.shrink()
                            : Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: pausable ? l.actionPause : l.actionPlay,
                  icon: Icon(pausable ? Icons.pause : Icons.play_arrow),
                  onPressed: () => ref.read(audioEngineProvider).togglePause(),
                ),
                IconButton(
                  tooltip: l.actionStop,
                  icon: const Icon(Icons.stop),
                  onPressed: () => ref.read(audioEngineProvider).stop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether `AudioEngine.togglePause` pauses in [status]: in every state that
/// keeps the media session "playing" (the FGS table), not only [Playing].
/// The button then says what a tap does, matching the notification.
bool _engineWouldPause(PlaybackStatus status) => switch (status) {
  Connecting() ||
  Playing() ||
  Buffering() ||
  Reconnecting() ||
  Interrupted() => true,
  Idle() || Paused() || PlaybackError() => false,
};
