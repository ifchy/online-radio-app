import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import 'ports.dart';

/// The Wi-Fi lock through the app's own MethodChannel
/// (`MainActivity.kt`'s `WifiLockChannel`: `WIFI_MODE_FULL_HIGH_PERF`,
/// non-reference-counted, tag `eRadioto:stream`).
///
/// The channel is registered in `MainActivity.configureFlutterEngine`. When
/// the Dart engine is started by the media service with no activity (media
/// resumption after process death, Android Auto in v1.1) it is not
/// registered, so a [MissingPluginException] is a no-op, never a crash: the
/// playback just runs without the lock (RESEARCH "MainActivity.kt" gap; v1.1
/// moves the channel into an in-repo plugin). A [PlatformException] is
/// swallowed the same way, so a lock failure never stops playback.
class WifiLockChannel implements WifiLockPort {
  WifiLockChannel();

  static const channel = MethodChannel('bg.izk.radio/wifi_lock');

  @override
  Future<void> acquire() => _call<bool>('acquire');

  @override
  Future<void> release() => _call<bool>('release');

  @override
  Future<bool> isHeld() async => await _call<bool>('isHeld') ?? false;

  Future<T?> _call<T>(String method) async {
    try {
      return await channel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Wi-Fi lock $method failed: $e');
      return null;
    }
  }
}
