import '../../catalog/domain/station.dart';

/// The list a station was started from, so next/previous can move within it.
/// Skip logic lands in plan 01-09.
sealed class PlayContext {
  const PlayContext();

  /// A single station, with nothing to skip to.
  const factory PlayContext.single() = SinglePlayContext;

  /// A station started from an ordered list, e.g. the home list.
  const factory PlayContext.list(List<StationId> ids, {String source}) =
      ListPlayContext;
}

final class SinglePlayContext extends PlayContext {
  const SinglePlayContext();
}

final class ListPlayContext extends PlayContext {
  const ListPlayContext(this.ids, {this.source = ''});

  final List<StationId> ids;

  /// Where the list came from (e.g. `home`), for diagnostics.
  final String source;
}
