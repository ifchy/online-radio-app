import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/application/catalog_providers.dart';
import '../features/playback/application/playback_providers.dart';
import '../features/playback/domain/play_context.dart';
import '../features/playback/presentation/debug_panel.dart';
import '../features/playback/presentation/mini_player.dart';
import '../l10n/app_localizations.dart';

/// The Phase 1 station list with the bottom mini-player (D-06).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.showDebugTools = !kReleaseMode});

  final bool showDebugTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final stations = ref.watch(stationDirectoryProvider).all;
    final ids = [for (final s in stations) s.id];
    return Scaffold(
      appBar: AppBar(
        title: Text(l.stationListTitle),
        actions: [
          // Debug and profile builds only (D-07, T-11-01): showDebugTools
          // defaults to !kReleaseMode, a compile-time constant, so release
          // AOT drops this branch and the panel with it.
          if (showDebugTools)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug',
              onPressed: () => _openDebugPanel(context),
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          return Semantics(
            hint: l.playStationHint(station.name),
            child: ListTile(
              leading: const Icon(Icons.radio),
              title: Text(station.name),
              subtitle: Text(station.nameLatin),
              onTap: () => ref
                  .read(audioEngineProvider)
                  .play(
                    station,
                    context: PlayContext.list(ids, source: 'home'),
                  ),
            ),
          );
        },
      ),
      // Collapses to nothing while no station is current. MiniPlayer handles
      // the bottom inset itself.
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  static Future<void> _openDebugPanel(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.85,
          child: SafeArea(top: false, child: DebugPanel()),
        ),
      );
}
