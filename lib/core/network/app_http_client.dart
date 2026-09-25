import 'package:http/http.dart' as http;

/// HTTPS-only client for app-owned traffic. RED stub.
class AppHttpClient extends http.BaseClient {
  AppHttpClient(this._inner, this.userAgent);

  final http.Client _inner;
  final String userAgent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => _inner.close();
}
