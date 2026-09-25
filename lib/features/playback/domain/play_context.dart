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
  /// around at the ends (`+1` from the last is the first, `-1` from the
  /// first is the last). Null when there is nothing to move to: a single
  /// station, a station not in the list, or a one-station list.
  StationId? neighbour(StationId current, int delta) {
    final self = this;
    if (self is! ListPlayContext) return null;
    final ids = self.ids;
    final index = ids.indexOf(current);
    if (index < 0) return null;
    // Dart's % is never negative for a positive divisor, so -1 wraps.
    final next = ids[(index + delta) % ids.length];
    return next == current ? null : next;
  }
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
