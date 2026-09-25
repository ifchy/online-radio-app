import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/catalog/application/catalog_providers.dart';
import '../features/playback/application/playback_providers.dart';
import '../features/playback/domain/play_context.dart';

/// The Phase 1 station list (D-06). Plan 01-03 adds the bottom mini-player
/// and moves every UI string into the ARB files.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationDirectoryProvider).all;
    final ids = [for (final s in stations) s.id];
    return Scaffold(
      // "eRadioto" is the same word in Bulgarian and English.
      appBar: AppBar(title: const Text('eRadioto')),
      body: ListView.builder(
        itemCount: stations.length,
        itemBuilder: (context, index) {
          final station = stations[index];
          return ListTile(
            leading: const Icon(Icons.radio),
            title: Text(station.name),
            subtitle: Text(station.nameLatin),
            onTap: () => ref
                .read(audioEngineProvider)
                .play(station, context: PlayContext.list(ids, source: 'home')),
          );
        },
      ),
    );
  }
}
