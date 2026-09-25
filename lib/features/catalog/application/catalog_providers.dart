import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/station_directory.dart';

part 'catalog_providers.g.dart';

/// The known stations. Overridden in `bootstrap` so the UI and the playback
/// handler share one directory.
@Riverpod(keepAlive: true)
StationDirectory stationDirectory(Ref ref) => StationDirectory.phase1();
