import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/application/catalog_providers.dart';
import '../features/playback/application/playback_providers.dart';
import '../features/playback/domain/play_context.dart';
import '../features/playback/presentation/mini_player.dart';
import '../l10n/app_localizations.dart';

/// The Phase 1 station list with the bottom mini-player (D-06).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final stations = ref.watch(stationDirectoryProvider).all;
    final ids = [for (final s in stations) s.id];
    return Scaffold(
      appBar: AppBar(title: Text(l.stationListTitle)),
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
}
