import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_repository.dart';
import '../application/playback_providers.dart';
import '../domain/engine_diagnostics.dart';

/// What the engine is doing, for the owner's device checks (D-07).
///
/// Debug and profile builds only: `HomeScreen` is the only place that opens
/// it, behind `showDebugTools` (default `!kReleaseMode`, a compile-time
/// constant, so release builds drop it).
///
/// The labels are plain English on purpose. The panel never ships, so it is
/// outside the Bulgarian copy review.
///
/// Privacy: the panel only renders providers. It performs no I/O and never
/// stores, exports or sends the diagnostics (the 01-11 prohibition).
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  /// The event log, for tests.
  static const eventLogKey = Key('debug-panel-event-log');

  /// Shown for a field with nothing to show.
  static const _none = '—';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d =
        ref.watch(diagnosticsProvider).value ??
        const EngineDiagnostics.initial();
    final station = ref.watch(currentStationProvider).value;
    final firstLaunch = ref.watch(firstLaunchAtProvider);
    final theme = Theme.of(context);

    // The stream count is only known for the station the diagnostics are
    // about.
    final streamCount = station != null && station.id == d.stationId
        ? '${station.streams.length}'
        : _none;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Engine', style: theme.textTheme.titleMedium),
          Text('State: ${d.state}'),
          Text('Station: ${d.stationId?.value ?? _none}'),
          Text(
            'Stream: ${d.streamIndex ?? _none}/$streamCount '
            '(candidate ${d.candidateIndex ?? _none})',
          ),
          Text('URL: ${d.url ?? _none}'),
          Text('Kind: ${d.kind?.name ?? _none}'),
          Text('Round: ${d.round}'),
          Text('Reconnect attempt: ${d.reconnectAttempt}'),
          Text('Next retry in: ${_ms(d.nextRetryDelay)}'),
          Text('Time-to-audio: ${_ms(d.lastTimeToAudio)}'),
          Text('First launch: ${firstLaunch.toUtc().toIso8601String()}'),
          const SizedBox(height: 16),
          Text(
            'Events (newest first, max ${EngineDiagnostics.maxRecentEvents})',
            style: theme.textTheme.titleMedium,
          ),
          Column(
            key: eventLogKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final event in d.recentEvents.reversed)
                Text(
                  '${_time(event.at)} ${event.message}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _ms(Duration? duration) =>
      duration == null ? _none : '${duration.inMilliseconds} ms';

  /// `HH:mm:ss.SSS` in local time.
  static String _time(DateTime at) {
    final t = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }
}
