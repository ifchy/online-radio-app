import 'package:http/http.dart' as http;

const _redirectStatuses = {301, 302, 303, 307, 308};

/// HTTPS-only client for app-owned traffic: the catalogue and the Radio
/// Browser API from Phase 2 on (STRM-04, Pitfall 5).
///
/// The Android network security config allows cleartext for native media
/// sockets, but Dart sockets ignore it, so this wrapper is what keeps app
/// traffic on TLS:
/// - any URL that is not `https` with a host throws [ArgumentError] and
///   nothing is sent;
/// - redirects are followed by hand, only to `https` targets and at most
///   [maxRedirects] hops for GET and HEAD, so a redirect can never downgrade
///   a request to plain http;
/// - every request carries the eRadioto User-Agent and nothing else that
///   identifies the device.
///
/// Media playlists are the one exception and go through `MediaHttpClient`.
class AppHttpClient extends http.BaseClient {
  AppHttpClient(this._inner, this.userAgent);

  static const maxRedirects = 5;

  final http.Client _inner;
  final String userAgent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _checkHttps(request.url);
    request
      ..followRedirects = false
      ..headers['User-Agent'] = userAgent;
    var response = await _inner.send(request);

    final method = request.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD') return response;

    var current = request.url;
    for (var hops = 0; ; hops++) {
      final location = response.headers['location'];
      if (!_redirectStatuses.contains(response.statusCode) ||
          location == null) {
        return response;
      }
      await _discard(response);
      if (hops >= maxRedirects) {
        throw http.ClientException('Too many redirects', request.url);
      }
      final Uri next;
      try {
        next = current.resolve(location.trim());
      } on FormatException {
        throw http.ClientException('Bad redirect location: $location', current);
      }
      // Never follow a downgrade to http:// (or any other scheme).
      _checkHttps(next);

      final follow = http.Request(method, next)
        ..followRedirects = false
        ..headers.addAll(_headersFor(request.headers, current, next))
        ..headers['User-Agent'] = userAgent;
      current = next;
      response = await _inner.send(follow);
    }
  }

  @override
  void close() => _inner.close();

  static void _checkHttps(Uri url) {
    // Uri lower-cases the scheme, so HTTPS:// is accepted too.
    if (url.scheme != 'https' || url.host.isEmpty) {
      throw ArgumentError.value(
        url,
        'url',
        'AppHttpClient sends only absolute https URLs',
      );
    }
  }

  /// The original headers for the next hop, without credentials when the
  /// redirect leaves the host.
  static Map<String, String> _headersFor(
    Map<String, String> headers,
    Uri from,
    Uri to,
  ) {
    if (from.host == to.host) return headers;
    return {
      for (final MapEntry(:key, :value) in headers.entries)
        if (!const {'authorization', 'cookie'}.contains(key.toLowerCase()))
          key: value,
    };
  }

  static Future<void> _discard(http.StreamedResponse response) =>
      response.stream.listen(null).cancel();
}
