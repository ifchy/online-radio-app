import '../../catalog/domain/station.dart';

final _segmentPattern = RegExp(r'^[a-z0-9-]+$');

/// Media ids shared by the phone UI, the media session and (v1.1) the
/// Android Auto browse tree.
///
/// Accepted forms:
/// - `station/curated:<id>`, `station/debug:<id>`
/// - `node/recents`, `node/favourites`, `node/bg/national`,
///   `node/bg/city/<id>`, `node/bg/genre/<id>`
sealed class MediaId {
  const MediaId();

  /// Parses [raw]. Anything outside the accepted forms throws
  /// [FormatException].
  static MediaId parse(String raw) {
    if (raw.startsWith('station/')) {
      final stationId = StationId.parse(raw.substring('station/'.length));
      if (stationId.namespace != StationNamespace.curated &&
          stationId.namespace != StationNamespace.debug) {
        throw FormatException('Unsupported station namespace', raw);
      }
      return StationMediaId(stationId);
    }
    if (raw.startsWith('node/')) {
      final path = raw.substring('node/'.length).split('/');
      if (!NodeMediaId._isValidPath(path)) {
        throw FormatException('Unknown media node', raw);
      }
      return NodeMediaId(path);
    }
    throw FormatException('Unknown media id', raw);
  }

  String format();

  @override
  bool operator ==(Object other) =>
      other is MediaId && other.format() == format();

  @override
  int get hashCode => format().hashCode;

  @override
  String toString() => format();
}

/// A playable station: `station/<namespace>:<key>`.
final class StationMediaId extends MediaId {
  const StationMediaId(this.stationId);

  final StationId stationId;

  @override
  String format() => 'station/${stationId.value}';
}

/// A browsable node: `node/<segment>/…`.
final class NodeMediaId extends MediaId {
  const NodeMediaId(this.path);

  const NodeMediaId.recents() : path = const ['recents'];
  const NodeMediaId.favourites() : path = const ['favourites'];
  const NodeMediaId.bgNational() : path = const ['bg', 'national'];
  NodeMediaId.bgCity(String id) : path = ['bg', 'city', id];
  NodeMediaId.bgGenre(String id) : path = ['bg', 'genre', id];

  final List<String> path;

  static bool _isValidPath(List<String> path) => switch (path) {
    ['recents'] || ['favourites'] || ['bg', 'national'] => true,
    ['bg', 'city' || 'genre', final id] => _segmentPattern.hasMatch(id),
    _ => false,
  };

  @override
  String format() => 'node/${path.join('/')}';
}
