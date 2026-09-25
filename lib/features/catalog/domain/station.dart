import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/text/icy_charset.dart';

part 'station.freezed.dart';

/// Where a [StationId] comes from. Ids are namespaced so curated, debug and
/// (from Phase 2) Radio Browser stations can never collide.
enum StationNamespace {
  curated,
  debug,

  /// Reserved for Radio Browser stations (Phase 2).
  rb,
}

final _keyPattern = RegExp(r'^[a-z0-9-]+$');

/// Stable, namespaced station identity: `<namespace>:<key>`.
///
/// Once published, a curated key never changes: favourites, recents and media
/// ids store it.
@freezed
class StationId with _$StationId {
  StationId(this.namespace, this.key) {
    if (!_keyPattern.hasMatch(key)) {
      throw FormatException('Invalid station key', key);
    }
  }

  factory StationId.curated(String key) =>
      StationId(StationNamespace.curated, key);

  factory StationId.debug(String key) => StationId(StationNamespace.debug, key);

  /// Parses `<namespace>:<key>`. Throws [FormatException] for an unknown
  /// namespace or a key that does not match `^[a-z0-9-]+$`.
  factory StationId.parse(String raw) {
    final separator = raw.indexOf(':');
    if (separator <= 0) {
      throw FormatException('Missing station namespace', raw);
    }
    final namespaceName = raw.substring(0, separator);
    final namespace = StationNamespace.values
        .where((n) => n.name == namespaceName)
        .firstOrNull;
    if (namespace == null) {
      throw FormatException('Unknown station namespace', raw);
    }
    return StationId(namespace, raw.substring(separator + 1));
  }

  final StationNamespace namespace;
  final String key;

  /// The persisted form, `<namespace>:<key>`.
  String get value => '${namespace.name}:$key';
}

/// How a stream endpoint must be opened.
enum StreamKind { progressive, hls, pls, m3u, unknown }

/// One official endpoint of a station.
@freezed
class StationStream with _$StationStream {
  const StationStream({
    required this.url,
    required this.kind,
    this.codec,
    this.bitrateKbps,
    this.icyCharset = IcyCharset.auto,
  });

  final Uri url;
  final StreamKind kind;
  final String? codec;
  final int? bitrateKbps;
  final IcyCharset icyCharset;
}

/// A radio station. It has no single stream field: the engine always plays
/// `streams[i]`, primary first and then the fallbacks, in order (D-04).
@freezed
class Station with _$Station {
  Station({
    required this.id,
    required this.name,
    required this.nameLatin,
    required this.streams,
    this.homepage,
  }) : assert(streams.isNotEmpty, 'A station needs at least one stream') {
    if (streams.isEmpty) {
      throw ArgumentError.value(streams, 'streams', 'must not be empty');
    }
  }

  final StationId id;

  /// Display name in its native script (Cyrillic for Bulgarian stations).
  final String name;

  /// Latin-script name, used for search and non-Bulgarian locales.
  final String nameLatin;

  /// Ordered endpoints: the primary first, then the fallbacks.
  final List<StationStream> streams;

  /// The station's own website.
  final Uri? homepage;
}
