import 'package:flutter/foundation.dart';

import '../domain/station.dart';
import 'debug_stations.dart';
import 'phase1_stations.dart';

/// The stations the app knows about, with lookup by [StationId].
class StationDirectory {
  StationDirectory(List<Station> stations)
    : all = List.unmodifiable(stations),
      _byId = {for (final s in stations) s.id: s};

  /// The Phase 1 list: the release stations, then the debug test stations
  /// when [includeDebug] is true (D-05).
  ///
  /// Release builds never include the debug stations, whatever the caller
  /// passes: [kReleaseMode] is a compile-time constant, so the condition
  /// folds to false and AOT drops the debug list from the snapshot
  /// (Pitfall I).
  factory StationDirectory.phase1({bool includeDebug = !kReleaseMode}) =>
      StationDirectory([
        ...phase1Stations,
        if (!kReleaseMode && includeDebug) ...debugStations,
      ]);

  final List<Station> all;
  final Map<StationId, Station> _byId;

  Station? byId(StationId id) => _byId[id];
}
