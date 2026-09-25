import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'ports.dart';

/// [ConnectivityPort] over connectivity_plus, which follows the default
/// network (`registerDefaultNetworkCallback` on API 24+). The only file
/// allowed to import connectivity_plus.
///
/// - **Debounce:** the raw signal flaps during a Wi-Fi to mobile hand-over
///   (both up, then one, captive portals, VPN). Only a state that has held
///   for [debounce] is considered (T-12-02).
/// - **Online:** the result list holds anything but
///   [ConnectivityResult.none].
/// - **Network changed:** online on a different set of results than the last
///   set the device was online on (Wi-Fi to mobile, or airplane mode off on
///   another network). Going offline never counts as a change.
/// - A change is reported only when the online flag or the network set
///   differs from the last state seen, by [isOnline] or an earlier change.
///   Before either the port counts as online on an unknown network, so the
///   platform's first (current-state) event is reported only when offline.
class ConnectivityPortImpl implements ConnectivityPort {
  ConnectivityPortImpl(
    this._connectivity, {
    this.debounce = const Duration(milliseconds: 500),
  });

  final Connectivity _connectivity;

  /// How long the raw signal must be quiet before a change is reported.
  final Duration debounce;

  /// The last state seen.
  bool _online = true;

  /// The set of results the device was last online on; null until known.
  Set<ConnectivityResult>? _lastOnlineSet;

  StreamController<ConnectivityChange>? _controller;
  StreamSubscription<List<ConnectivityResult>>? _source;
  Timer? _pending;

  @override
  Stream<ConnectivityChange> get changes =>
      (_controller ??= StreamController<ConnectivityChange>.broadcast(
        onListen: _listen,
        onCancel: _cancel,
      )).stream;

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    _observe(results);
    return _isOnline(results);
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void _listen() {
    _source = _connectivity.onConnectivityChanged.listen((results) {
      _pending?.cancel();
      _pending = Timer(debounce, () {
        _pending = null;
        final change = _observe(results);
        if (change != null) _controller?.add(change);
      });
    });
  }

  Future<void> _cancel() async {
    _pending?.cancel();
    _pending = null;
    final source = _source;
    _source = null;
    await source?.cancel();
  }

  /// Adopts [results] as the state seen; returns the change it makes, or
  /// null when nothing differs.
  ConnectivityChange? _observe(List<ConnectivityResult> results) {
    final online = _isOnline(results);
    if (!online) {
      if (!_online) return null;
      _online = false;
      return const ConnectivityChange(online: false, networkChanged: false);
    }
    final set = results.toSet();
    final previous = _lastOnlineSet;
    final networkChanged =
        previous != null &&
        (previous.length != set.length || !previous.containsAll(set));
    final cameBack = !_online;
    _online = true;
    _lastOnlineSet = set;
    if (!cameBack && !networkChanged) return null;
    return ConnectivityChange(online: true, networkChanged: networkChanged);
  }
}
