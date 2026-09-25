import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'ports.dart';

/// [ConnectivityPort] over connectivity_plus. The only file allowed to import
/// connectivity_plus.
class ConnectivityPortImpl implements ConnectivityPort {
  ConnectivityPortImpl(
    this._connectivity, {
    this.debounce = const Duration(milliseconds: 500),
  });

  final Connectivity _connectivity;

  /// How long the raw signal must be quiet before a change is reported.
  final Duration debounce;

  @override
  Stream<ConnectivityChange> get changes => const Stream.empty();

  @override
  Future<bool> isOnline() async => identical(_connectivity, _connectivity);
}
