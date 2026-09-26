import '../../catalog/domain/station.dart';
import '../engine/ports.dart' show PlayableKind;

/// One line of the engine's event log: an event and the state it led to.
final class DiagnosticEvent {
  const DiagnosticEvent(this.at, this.message);

  final DateTime at;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is DiagnosticEvent && other.at == at && other.message == message;

  @override
  int get hashCode => Object.hash(at, message);

  @override
  String toString() => '${at.toIso8601String()} $message';
}

/// What the engine is doing, for the debug panel (D-07).
///
/// Lives in memory only. It is never persisted or sent anywhere (the privacy
/// prohibition in 01-11): the event log names stations and stream indexes.
final class EngineDiagnostics {
  const EngineDiagnostics({
    required this.state,
    this.stationId,
    this.streamIndex,
    this.candidateIndex,
    this.url,
    this.kind,
    this.round = 0,
    this.reconnectAttempt = 0,
    this.nextRetryDelay,
    this.lastTimeToAudio,
    this.recentEvents = const [],
  });

  /// Before anything has happened.
  const EngineDiagnostics.initial() : this(state: 'Idle');

  /// The most events [recentEvents] holds.
  static const maxRecentEvents = 50;

  /// The engine state, e.g. `Connecting(stream 1, round 0)`.
  final String state;

  final StationId? stationId;

  /// The index in the station's streams being tried or played.
  final int? streamIndex;

  /// The index in the resolved candidates of that stream.
  final int? candidateIndex;

  /// The resolved URL being tried or played.
  final Uri? url;

  final PlayableKind? kind;

  /// Passes over the stream list in this session, from 0.
  final int round;

  /// Reconnect retries started in the current outage; 0 when there is none.
  final int reconnectAttempt;

  /// The backoff of the current reconnect wait; null unless Reconnecting.
  final Duration? nextRetryDelay;

  /// From the user's play to the first audio, for the last successful start.
  final Duration? lastTimeToAudio;

  /// The last [maxRecentEvents] events, oldest first, newest last.
  final List<DiagnosticEvent> recentEvents;
}
