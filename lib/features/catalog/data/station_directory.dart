import '../domain/station.dart';
import 'phase1_stations.dart';

/// The stations the app knows about, with lookup by [StationId].
class StationDirectory {
  StationDirectory(List<Station> stations)
    : all = List.unmodifiable(stations),
      _byId = {for (final s in stations) s.id: s};

  factory StationDirectory.phase1({bool includeDebug = false}) =>
      StationDirectory(phase1Stations);

  final List<Station> all;
  final Map<StationId, Station> _byId;

  Station? byId(StationId id) => _byId[id];
}
