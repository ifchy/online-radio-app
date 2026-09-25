import 'package:flutter/services.dart';

import 'ports.dart';

/// RED scaffolding (01-13 Task 2): the channel calls arrive in GREEN.
class WifiLockChannel implements WifiLockPort {
  WifiLockChannel();

  static const channel = MethodChannel('bg.izk.radio/wifi_lock');

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}

  @override
  Future<bool> isHeld() async => false;
}
