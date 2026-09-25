/// The playback state machine (RESEARCH Pattern 2, ARCHITECTURE Pattern 3):
/// a pure reducer from (state, event, now) to (next state, commands).
///
/// Pure on purpose: no Flutter, plugin, timer or I/O imports. The handler
/// feeds it every input (user commands, player events, resolve results,
/// timer fires) and executes the commands it returns, so every transition can
/// be unit-tested without a device.
library;

import '../../catalog/domain/station.dart';
import '../domain/play_context.dart';
import '../domain/playback_status.dart';
import 'ports.dart';

/// Timings and limits of the state machine, in one place so they can be tuned
/// on a device (RESEARCH lines 336-341, Claude's discretion).
final class EngineTimings {
  const EngineTimings({
    this.connectTimeout = const Duration(seconds: 10),
    this.maxDeadOnArrivalRounds = 2,
  });

  /// How long one attempt (resolve plus load) may take to produce audio
  /// before the next candidate or stream is tried.
  final Duration connectTimeout;

  /// How many full passes over a station's streams are made before a station
  /// that never played is given up as dead (PLAY-08).
  final int maxDeadOnArrivalRounds;
}

/// The timers the handler runs for the state machine. Plans 01-10 and 01-12
/// add more kinds.
enum TimerKind { connect }

/// Everything the reducer knows. Immutable; [copyWith] builds the next one.
final class EngineState {
  const EngineState({
    required this.status,
    this.station,
    this.context = const PlayContext.single(),
    this.generation = 0,
    this.streamIndex = 0,
    this.candidateIndex = 0,
    this.round = 0,
    this.candidates = const [],
    this.everPlayed = false,
    this.lastWorkingStreamIndex,
    this.connectStartedAt,
    this.startStreamIndex = 0,
    this.onlyFormatFailures = true,
  });

  /// Nothing loaded, generation 0.
  const EngineState.initial() : this(status: const PlaybackStatus.idle());

  /// What the app, the notification and the lock screen show.
  final PlaybackStatus status;

  /// The station being played, paused or in error; null when idle.
  final Station? station;

  /// The list the station was started from (next/previous).
  final PlayContext context;

  /// Stamps every async request (resolve, load, timer). Results carrying an
  /// older generation are stale and change nothing (PLAY-10).
  final int generation;

  /// The index in `station.streams` being tried or played.
  final int streamIndex;

  /// The index in [candidates] being tried or played.
  final int candidateIndex;

  /// Passes over the stream list made in this session, from 0.
  final int round;

  /// The resolved endpoints of the current stream; empty while resolving.
  final List<ResolvedStream> candidates;

  /// Whether the station reached Playing since the user last started it.
  final bool everPlayed;

  /// The stream index that last reached Playing, kept across a pause.
  final int? lastWorkingStreamIndex;

  /// When the user started the current connect; null once playing.
  final DateTime? connectStartedAt;

  /// The stream index this session started at. A round ends when rotation
  /// comes back to it.
  final int startStreamIndex;

  /// Whether every failure in this session was a format failure (nothing
  /// playable in the stream or its playlist). Decides the error kind when the
  /// station is given up.
  final bool onlyFormatFailures;

  /// The stream being tried or played, or null when idle.
  StationStream? get currentStream => station?.streams[streamIndex];

  /// The resolved endpoint being tried or played, or null while resolving.
  ResolvedStream? get currentCandidate =>
      candidateIndex < candidates.length ? candidates[candidateIndex] : null;

  EngineState copyWith({
    PlaybackStatus? status,
    Object? station = _unset,
    PlayContext? context,
    int? generation,
    int? streamIndex,
    int? candidateIndex,
    int? round,
    List<ResolvedStream>? candidates,
    bool? everPlayed,
    Object? lastWorkingStreamIndex = _unset,
    Object? connectStartedAt = _unset,
    int? startStreamIndex,
    bool? onlyFormatFailures,
  }) => EngineState(
    status: status ?? this.status,
    station: identical(station, _unset) ? this.station : station as Station?,
    context: context ?? this.context,
    generation: generation ?? this.generation,
    streamIndex: streamIndex ?? this.streamIndex,
    candidateIndex: candidateIndex ?? this.candidateIndex,
    round: round ?? this.round,
    candidates: candidates ?? this.candidates,
    everPlayed: everPlayed ?? this.everPlayed,
    lastWorkingStreamIndex: identical(lastWorkingStreamIndex, _unset)
        ? this.lastWorkingStreamIndex
        : lastWorkingStreamIndex as int?,
    connectStartedAt: identical(connectStartedAt, _unset)
        ? this.connectStartedAt
        : connectStartedAt as DateTime?,
    startStreamIndex: startStreamIndex ?? this.startStreamIndex,
    onlyFormatFailures: onlyFormatFailures ?? this.onlyFormatFailures,
  );

  @override
  String toString() => describeStatus(status);
}

const Object _unset = Object();

/// A short, stable description of [status] for diagnostics.
String describeStatus(PlaybackStatus status) => switch (status) {
  Idle() => 'Idle',
  Connecting(:final streamIndex, :final round) =>
    'Connecting(stream $streamIndex, round $round)',
  Playing(:final streamIndex) => 'Playing(stream $streamIndex)',
  Buffering(:final streamIndex) => 'Buffering(stream $streamIndex)',
  Reconnecting(:final attempt) => 'Reconnecting(attempt $attempt)',
  Interrupted() => 'Interrupted',
  Paused() => 'Paused',
  PlaybackError(:final kind) => 'Error(${kind.name})',
};

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

/// An input to the state machine.
sealed class EngineEvent {
  const EngineEvent();
}

/// The user (UI, notification, headset, car) starts [station].
final class UserPlay extends EngineEvent {
  const UserPlay(
    this.station, {
    this.context = const PlayContext.single(),
    this.startStreamIndex = 0,
  });

  final Station station;
  final PlayContext context;
  final int startStreamIndex;

  @override
  String toString() =>
      'UserPlay(${station.id.value}, from stream $startStreamIndex)';
}

final class UserPause extends EngineEvent {
  const UserPause();

  @override
  String toString() => 'UserPause';
}

/// The user resumes a paused or failed station.
final class UserResume extends EngineEvent {
  const UserResume();

  @override
  String toString() => 'UserResume';
}

final class UserStop extends EngineEvent {
  const UserStop();

  @override
  String toString() => 'UserStop';
}

/// A [Resolve] command issued for [generation] produced [candidates].
final class Resolved extends EngineEvent {
  const Resolved(this.generation, this.candidates);

  final int generation;
  final List<ResolvedStream> candidates;

  @override
  String toString() =>
      'Resolved(gen $generation, ${candidates.length} candidates)';
}

/// A [Resolve] command issued for [generation] failed. [reason] is null for
/// an unexpected error.
final class ResolveFailed extends EngineEvent {
  const ResolveFailed(this.generation, this.reason);

  final int generation;
  final StreamResolutionFailure? reason;

  @override
  String toString() =>
      'ResolveFailed(gen $generation, ${reason?.name ?? 'unexpected'})';
}

/// The player's processing state for the load of [generation].
final class PlayerStateChanged extends EngineEvent {
  const PlayerStateChanged(
    this.generation,
    this.state, {
    required this.playing,
  });

  final int generation;
  final PlayerProcessingState state;
  final bool playing;

  @override
  String toString() =>
      'PlayerStateChanged(gen $generation, ${state.name}'
      '${playing ? ', playing' : ''})';
}

/// The player failed the load of [generation].
final class PlayerFailed extends EngineEvent {
  const PlayerFailed(this.generation, this.code);

  final int generation;
  final int code;

  @override
  String toString() => 'PlayerFailed(gen $generation, code $code)';
}

/// A [StartTimer] command for [generation] ran out.
final class TimerFired extends EngineEvent {
  const TimerFired(this.kind, this.generation);

  final TimerKind kind;
  final int generation;

  @override
  String toString() => 'TimerFired(${kind.name}, gen $generation)';
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

/// A side effect the handler performs, in list order, after a transition.
///
/// There is no seek command: live radio always restarts at the live edge
/// (PLAY-11).
sealed class EngineCommand {
  const EngineCommand();
}

/// Stop the network transport and release the native player.
final class StopTransport extends EngineCommand {
  const StopTransport();

  @override
  bool operator ==(Object other) => other is StopTransport;

  @override
  int get hashCode => (StopTransport).hashCode;

  @override
  String toString() => 'StopTransport';
}

/// Resolve [stream]; the result comes back as [Resolved] or [ResolveFailed]
/// stamped with [generation].
final class Resolve extends EngineCommand {
  const Resolve(this.stream, this.generation);

  final StationStream stream;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is Resolve &&
      other.stream == stream &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(Resolve, stream, generation);

  @override
  String toString() => 'Resolve(${stream.url}, gen $generation)';
}

/// Open [resolved] at the live edge; player events carry [generation].
final class Load extends EngineCommand {
  const Load(this.resolved, this.generation);

  final ResolvedStream resolved;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is Load &&
      other.resolved == resolved &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(Load, resolved, generation);

  @override
  String toString() => 'Load($resolved, gen $generation)';
}

/// Abandon audio focus (just_audio never does).
final class ReleaseFocus extends EngineCommand {
  const ReleaseFocus();

  @override
  bool operator ==(Object other) => other is ReleaseFocus;

  @override
  int get hashCode => (ReleaseFocus).hashCode;

  @override
  String toString() => 'ReleaseFocus';
}

/// Start (or restart) the [kind] timer; it fires [TimerFired] with
/// [generation] after [duration].
final class StartTimer extends EngineCommand {
  const StartTimer(this.kind, this.duration, this.generation);

  final TimerKind kind;
  final Duration duration;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is StartTimer &&
      other.kind == kind &&
      other.duration == duration &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(StartTimer, kind, duration, generation);

  @override
  String toString() => 'StartTimer(${kind.name}, $duration, gen $generation)';
}

final class CancelTimer extends EngineCommand {
  const CancelTimer(this.kind);

  final TimerKind kind;

  @override
  bool operator ==(Object other) => other is CancelTimer && other.kind == kind;

  @override
  int get hashCode => Object.hash(CancelTimer, kind);

  @override
  String toString() => 'CancelTimer(${kind.name})';
}

final class CancelAllTimers extends EngineCommand {
  const CancelAllTimers();

  @override
  bool operator ==(Object other) => other is CancelAllTimers;

  @override
  int get hashCode => (CancelAllTimers).hashCode;

  @override
  String toString() => 'CancelAllTimers';
}

/// Drop the cached resolution of [stream]: a failed URL may be stale.
final class InvalidateResolution extends EngineCommand {
  const InvalidateResolution(this.stream);

  final StationStream stream;

  @override
  bool operator ==(Object other) =>
      other is InvalidateResolution && other.stream == stream;

  @override
  int get hashCode => Object.hash(InvalidateResolution, stream);

  @override
  String toString() => 'InvalidateResolution(${stream.url})';
}

/// Clear the ICY now-playing line (01-08).
final class ClearNowPlaying extends EngineCommand {
  const ClearNowPlaying();

  @override
  bool operator ==(Object other) => other is ClearNowPlaying;

  @override
  int get hashCode => (ClearNowPlaying).hashCode;

  @override
  String toString() => 'ClearNowPlaying';
}

/// Record how long the user waited for audio (diagnostics, D-07).
final class RecordTimeToAudio extends EngineCommand {
  const RecordTimeToAudio(this.duration);

  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is RecordTimeToAudio && other.duration == duration;

  @override
  int get hashCode => Object.hash(RecordTimeToAudio, duration);

  @override
  String toString() => 'RecordTimeToAudio($duration)';
}

// ---------------------------------------------------------------------------
// The reducer
// ---------------------------------------------------------------------------

/// The result of one event: the next state and the commands to run, in order.
final class Transition {
  const Transition(this.next, this.commands);

  final EngineState next;
  final List<EngineCommand> commands;
}

class PlaybackStateMachine {
  const PlaybackStateMachine({this.timings = const EngineTimings()});

  final EngineTimings timings;

  Transition transition(EngineState state, EngineEvent event, DateTime now) =>
      Transition(state, const []);
}
