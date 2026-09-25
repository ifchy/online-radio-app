import '../../catalog/domain/station.dart';

/// The list a station was started from, so next/previous can move within it.
sealed class PlayContext {
  const PlayContext();

  /// A single station, with nothing to skip to.
  const factory PlayContext.single() = SinglePlayContext;

  /// A station started from an ordered list, e.g. the home list.
  const factory PlayContext.list(List<StationId> ids, {String source}) =
      ListPlayContext;

  /// The station [delta] places after [current] in this list, wrapping
  /// around at the ends; null when there is nothing to move to.
  StationId? neighbour(StationId current, int delta) => null;
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
