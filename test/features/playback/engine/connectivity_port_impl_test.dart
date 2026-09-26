// ConnectivityPortImpl over a fake connectivity_plus: the 500 ms debounce,
// the online rule and the network-changed rule (RESEARCH "Transition rules",
// ARCHITECTURE Pattern 4, T-12-02).
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/playback/engine/connectivity_port_impl.dart';
import 'package:radio/features/playback/engine/ports.dart';

import '../../../support/fakes.dart';

/// connectivity_plus with a scripted signal and current state.
class _FakeConnectivity implements Connectivity {
  final _raw = StreamController<List<ConnectivityResult>>.broadcast(sync: true);

  /// What [checkConnectivity] answers.
  List<ConnectivityResult> current = const [ConnectivityResult.wifi];

  bool get hasListener => _raw.hasListener;

  void send(List<ConnectivityResult> results) {
    current = results;
    _raw.add(results);
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _raw.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => current;
}

const _wifi = [ConnectivityResult.wifi];
const _mobile = [ConnectivityResult.mobile];
const _none = [ConnectivityResult.none];
const _debounce = Duration(milliseconds: 500);

void main() {
  late _FakeConnectivity raw;
  late ConnectivityPortImpl port;

  setUp(() {
    raw = _FakeConnectivity();
    port = ConnectivityPortImpl(raw);
  });

  /// Listens to the port inside the fakeAsync zone.
  List<ConnectivityChange> listen() {
    final events = <ConnectivityChange>[];
    final sub = port.changes.listen(events.add);
    addTearDown(sub.cancel);
    return events;
  }

  test('the default debounce is 500 ms', () {
    expect(port.debounce, _debounce);
  });

  group('isOnline', () {
    test('false for [none]', () async {
      raw.current = _none;
      expect(await port.isOnline(), isFalse);
    });

    test('true for [mobile], [wifi] and [wifi, vpn]', () async {
      for (final results in [
        _mobile,
        _wifi,
        [ConnectivityResult.wifi, ConnectivityResult.vpn],
      ]) {
        raw.current = results;
        expect(await port.isOnline(), isTrue, reason: '$results');
      }
    });
  });

  group('changes', () {
    test('[wifi] then [mobile] after the debounce: one change, online and '
        'network changed', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        raw.send(_mobile);
        async.elapse(_debounce);
        expect(events, [
          const ConnectivityChange(online: true, networkChanged: true),
        ]);
      });
    });

    test('[wifi] then [none]: offline', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        raw.send(_none);
        async.elapse(_debounce);
        expect(events, [
          const ConnectivityChange(online: false, networkChanged: false),
        ]);
      });
    });

    test('nothing is reported before the signal has been quiet for the '
        'debounce', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        raw.send(_none);
        async.elapse(_debounce - const Duration(milliseconds: 1));
        expect(events, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(events, hasLength(1));
      });
    });

    test('a burst of three changes within 500 ms: one change, for the last '
        'state', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        raw.send(_none);
        async.elapse(const Duration(milliseconds: 150));
        raw.send(_wifi);
        async.elapse(const Duration(milliseconds: 150));
        raw.send(_mobile);
        async.elapse(_debounce);
        expect(events, [
          const ConnectivityChange(online: true, networkChanged: true),
        ]);
      });
    });

    test('a flap that ends where it started reports nothing', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        raw.send(_none);
        async.elapse(const Duration(milliseconds: 100));
        raw.send(_wifi);
        async.elapse(_debounce * 2);
        expect(events, isEmpty);
      });
    });

    test('back on the same network after being offline: online, network '
        'not changed', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        raw.send(_none);
        async.elapse(_debounce);
        raw.send(_wifi);
        async.elapse(_debounce);
        expect(events, [
          const ConnectivityChange(online: false, networkChanged: false),
          const ConnectivityChange(online: true, networkChanged: false),
        ]);
      });
    });

    test('back on a different network after being offline (airplane mode '
        'on Wi-Fi, off on mobile data): online and network changed', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        raw.send(_none);
        async.elapse(_debounce);
        raw.send(_mobile);
        async.elapse(_debounce);
        expect(
          events.last,
          const ConnectivityChange(online: true, networkChanged: true),
        );
      });
    });

    test('the first signal only sets the baseline when it is online (the '
        'port starts online); an offline first signal is reported', () {
      fakeAsync((async) {
        final events = listen();
        raw.send(_wifi);
        async.elapse(_debounce);
        expect(events, isEmpty);
      });
      fakeAsync((async) {
        final other = _FakeConnectivity();
        port = ConnectivityPortImpl(other);
        final events = listen();
        other.send(_none);
        async.elapse(_debounce);
        expect(events, [
          const ConnectivityChange(online: false, networkChanged: false),
        ]);
      });
    });

    test('isOnline sets the baseline, so the platform echo of the same state '
        'is not reported', () {
      fakeAsync((async) {
        raw.current = _none;
        bool? online;
        unawaited(port.isOnline().then((v) => online = v));
        async.flushMicrotasks();
        expect(online, isFalse);
        final events = listen();
        raw.send(_none);
        async.elapse(_debounce);
        expect(events, isEmpty);
        raw.send(_mobile);
        async.elapse(_debounce);
        expect(events, [
          const ConnectivityChange(online: true, networkChanged: false),
        ]);
      });
    });

    test('the platform stream is listened to only while the port is', () {
      fakeAsync((async) {
        expect(raw.hasListener, isFalse);
        final sub = port.changes.listen((_) {});
        expect(raw.hasListener, isTrue);
        unawaited(sub.cancel());
        async.flushMicrotasks();
        expect(raw.hasListener, isFalse);
      });
    });

    test('a pending debounce is dropped when the listener cancels', () {
      fakeAsync((async) {
        final events = <ConnectivityChange>[];
        final sub = port.changes.listen(events.add);
        raw.send(_none);
        unawaited(sub.cancel());
        async.elapse(_debounce * 2);
        expect(events, isEmpty);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('FakeConnectivityPort', () {
    test('reports its online value and emits scripted changes', () async {
      final fake = FakeConnectivityPort(online: false);
      expect(await fake.isOnline(), isFalse);
      final events = <ConnectivityChange>[];
      final sub = fake.changes.listen(events.add);
      addTearDown(sub.cancel);
      fake.emit(online: true, networkChanged: true);
      expect(events, [
        const ConnectivityChange(online: true, networkChanged: true),
      ]);
      expect(await fake.isOnline(), isTrue);
      expect(fake.isOnlineCalls, 2);
    });
  });
}
