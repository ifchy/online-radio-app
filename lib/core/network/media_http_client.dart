import 'package:http/http.dart' as http;

/// HTTP client for media resolution: fetching `.pls`/`.m3u` playlists and
/// sniffing extension-less HLS.
///
/// It is the only Dart client allowed to fetch `http://` (STRM-04 media
/// carve-out): many stations publish their playlists only over plain http.
/// Everything else the app fetches goes through `AppHttpClient`, which is
/// HTTPS-only.
///
/// Rejects any URL that is not absolute `http`/`https` with a host, so a
/// playlist can never make the app open `file:`, `content:` or similar URIs.
/// Sends only the eRadioto User-Agent; no identifiers.
class MediaHttpClient extends http.BaseClient {
  MediaHttpClient(this._inner, this.userAgent);

  final http.Client _inner;
  final String userAgent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;
    // Uri lower-cases the scheme, so HTTP:// and Https:// are accepted too.
    if ((url.scheme != 'http' && url.scheme != 'https') || url.host.isEmpty) {
      throw ArgumentError.value(
        url,
        'request.url',
        'MediaHttpClient fetches only absolute http(s) URLs',
      );
    }
    request.headers['User-Agent'] = userAgent;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
