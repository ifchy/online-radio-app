import 'package:http/http.dart' as http;

/// HTTP client for media resolution (playlists). RED stub.
class MediaHttpClient extends http.BaseClient {
  MediaHttpClient(this._inner, this.userAgent);

  final http.Client _inner;
  final String userAgent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => _inner.close();
}
