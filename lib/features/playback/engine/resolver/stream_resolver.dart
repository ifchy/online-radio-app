import 'package:clock/clock.dart';

import '../../../../core/network/media_http_client.dart';
import '../../../catalog/domain/station.dart';
import '../ports.dart';

/// RED stub.
class HttpStreamResolver implements StreamResolver {
  HttpStreamResolver(
    this._client,
    this._clock, {
    this.ttl = const Duration(hours: 1),
    this.timeout = const Duration(seconds: 5),
    this.maxBytes = 65536,
    this.maxDepth = 3,
    this.maxCandidates = 10,
    this.maxRedirects = 5,
  });

  // ignore: unused_field
  final MediaHttpClient _client;
  // ignore: unused_field
  final Clock _clock;
  final Duration ttl;
  final Duration timeout;
  final int maxBytes;
  final int maxDepth;
  final int maxCandidates;
  final int maxRedirects;

  @override
  Future<List<ResolvedStream>> resolve(StationStream stream) async => const [];

  @override
  void invalidate(StationStream stream) {}
}
