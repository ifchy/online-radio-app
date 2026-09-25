// WifiLockChannel over the 'bg.izk.radio/wifi_lock' MethodChannel. Without a
// registered handler (the engine started by the service with no activity)
// every call is a no-op, never a crash.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/playback/engine/wifi_lock_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bg.izk.radio/wifi_lock');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('the channel name is bg.izk.radio/wifi_lock', () {
    expect(WifiLockChannel.channel.name, 'bg.izk.radio/wifi_lock');
  });

  test('acquire, release and isHeld invoke the matching methods', () async {
    final calls = <String>[];
    var held = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'acquire':
          held = true;
          return true;
        case 'release':
          held = false;
          return true;
        case 'isHeld':
          return held;
      }
      return null;
    });
    final lock = WifiLockChannel();
    await lock.acquire();
    expect(await lock.isHeld(), isTrue);
    await lock.release();
    expect(await lock.isHeld(), isFalse);
    expect(calls, ['acquire', 'isHeld', 'release', 'isHeld']);
  });

  test('no handler registered (MissingPluginException): acquire and release '
      'complete normally and isHeld is false', () async {
    final lock = WifiLockChannel();
    await expectLater(lock.acquire(), completes);
    await expectLater(lock.release(), completes);
    expect(await lock.isHeld(), isFalse);
  });

  test('a PlatformException is swallowed the same way', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'wifi', message: 'boom'),
    );
    final lock = WifiLockChannel();
    await expectLater(lock.acquire(), completes);
    await expectLater(lock.release(), completes);
    expect(await lock.isHeld(), isFalse);
  });

  test('a null isHeld answer counts as not held', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await WifiLockChannel().isHeld(), isFalse);
  });
}
