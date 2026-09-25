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
import '../domain/retry_budget.dart';
import 'ports.dart';
import 'reconnect_policy.dart';

/// Timings and limits of the state machine, in one place so they can be tuned
/// on a device (RESEARCH lines 336-341, Claude's discretion).
final class EngineTimings {
  const EngineTimings({
    this.connectTimeout = const Duration(seconds: 10),
    this.maxDeadOnArrivalRounds = 2,
    this.stallTimeout = const Duration(seconds: 8),
    this.stablePlayingReset = const Duration(seconds: 30),
  });

  /// How long one attempt (resolve plus load) may take to produce audio
  /// before the next candidate or stream is tried.
  final Duration connectTimeout;

  /// How many full passes over a station's streams are made before a station
  /// that never played is given up as dead (PLAY-08).
  final int maxDeadOnArrivalRounds;

  /// How long Playing may sit in Buffering before the stream is reloaded.
  final Duration stallTimeout;

  /// How long playback must be stable before the backoff and the retry
  /// budget reset.
  final Duration stablePlayingReset;
}

/// The timers the handler runs for the state machine. Plans 01-10 and 01-12
/// add more kinds.
enum TimerKind { connect, stall, backoff, stablePlaying, budget }

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
    this.budget = const RetryBudgetClock(),
    this.attempt = 0,
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

  /// The retry budget of the current outage (D-10).
  final RetryBudgetClock budget;

  /// Reconnect retries started in the current outage.
  final int attempt;

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
    RetryBudgetClock? budget,
    int? attempt,
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
    budget: budget ?? this.budget,
    attempt: attempt ?? this.attempt,
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

/// The reconnect give-up policy changed (D-10).
final class SetRetryBudget extends EngineEvent {
  const SetRetryBudget(this.preset);

  final RetryBudgetPreset preset;

  @override
  String toString() => 'SetRetryBudget(${preset.name})';
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

/// The reducer. [transition] is pure: the same state, event and time always
/// give the same result, and it never performs a side effect itself.
///
/// Rows (RESEARCH Pattern 2, ARCHITECTURE Pattern 3):
/// - UserPlay from any state: a new session at the live edge.
/// - Connecting: a failure of the current attempt (resolve failure, player
///   failure, a load that completes at once, or the connect timer) moves to
///   the next resolved candidate, then to the next stream. When rotation
///   comes back to the start stream a round ends; a station that never
///   played is given up after [EngineTimings.maxDeadOnArrivalRounds] rounds.
/// - Connecting + ready and playing: Playing, with time-to-audio recorded.
/// - Playing <-> Buffering on the player's buffering and ready states.
/// - Playing/Buffering + a failure or `completed`: Error(streamUnreachable).
///   Plan 01-10 replaces this row with Reconnecting.
/// - UserPause/UserStop from an active state: Paused/Idle, everything
///   stopped and focus released.
/// - Guards (PLAY-10): an event stamped with an older generation changes
///   nothing, and only UserPlay and UserResume start playback from Paused,
///   Idle or Error.
class PlaybackStateMachine {
  const PlaybackStateMachine({
    required this.policy,
    this.timings = const EngineTimings(),
  });

  final ReconnectPolicy policy;
  final EngineTimings timings;

  Transition transition(EngineState state, EngineEvent event, DateTime now) =>
      switch (event) {
        UserPlay(:final station, :final context, :final startStreamIndex) =>
          _start(
            state,
            station,
            context: context,
            startStreamIndex: startStreamIndex,
            now: now,
          ),
        UserResume() => _resume(state, now),
        UserPause() => _pause(state),
        UserStop() => _stop(state),
        Resolved() => _resolved(state, event),
        ResolveFailed(:final generation, :final reason) =>
          generation == state.generation && state.status is Connecting
              ? _nextStream(state, formatFailure: _isFormatFailure(reason))
              : _unchanged(state),
        PlayerStateChanged() => _playerStateChanged(state, event, now),
        PlayerFailed(:final generation) => _playerFailed(state, generation),
        TimerFired(:final kind, :final generation) =>
          kind == TimerKind.connect &&
                  generation == state.generation &&
                  state.status is Connecting
              ? _nextCandidate(state, formatFailure: false)
              : _unchanged(state),
        SetRetryBudget() => _unchanged(state),
      };

  static Transition _unchanged(EngineState state) =>
      Transition(state, const []);

  static const _stopEverything = <EngineCommand>[
    CancelAllTimers(),
    ClearNowPlaying(),
    StopTransport(),
    ReleaseFocus(),
  ];

  static bool _isActive(PlaybackStatus status) => switch (status) {
    Connecting() ||
    Playing() ||
    Buffering() ||
    Reconnecting() ||
    Interrupted() => true,
    Idle() || Paused() || PlaybackError() => false,
  };

  /// Nothing playable behind the URL: retrying elsewhere will not help.
  static bool _isFormatFailure(StreamResolutionFailure? reason) =>
      switch (reason) {
        StreamResolutionFailure.unsupportedScheme ||
        StreamResolutionFailure.notAPlaylist ||
        StreamResolutionFailure.empty => true,
        _ => false,
      };

  /// A new session on [station]: stop whatever plays, clear now-playing and
  /// resolve the start stream under a new generation. The handler publishes
  /// Connecting (playing: true, loading) before running these commands, so
  /// the foreground service starts from the user action (Pitfall G).
  Transition _start(
    EngineState state,
    Station station, {
    required PlayContext context,
    required int startStreamIndex,
    required DateTime now,
    int? lastWorkingStreamIndex,
  }) {
    final start =
        startStreamIndex >= 0 && startStreamIndex < station.streams.length
        ? startStreamIndex
        : 0;
    final generation = state.generation + 1;
    return Transition(
      EngineState(
        status: PlaybackStatus.connecting(
          station: station,
          streamIndex: start,
          round: 0,
        ),
        station: station,
        context: context,
        generation: generation,
        streamIndex: start,
        lastWorkingStreamIndex: lastWorkingStreamIndex,
        connectStartedAt: now,
        startStreamIndex: start,
      ),
      [
        const StopTransport(),
        const ClearNowPlaying(),
        StartTimer(TimerKind.connect, timings.connectTimeout, generation),
        Resolve(station.streams[start], generation),
      ],
    );
  }

  /// Resume is a fresh load at the live edge (PLAY-11), never a seek. After
  /// a pause it starts on the stream that last worked; after an error, on the
  /// stream the user started at.
  Transition _resume(EngineState state, DateTime now) => switch (state.status) {
    Paused(:final station) => _start(
      state,
      station,
      context: state.context,
      startStreamIndex: state.lastWorkingStreamIndex ?? state.startStreamIndex,
      now: now,
      lastWorkingStreamIndex: state.lastWorkingStreamIndex,
    ),
    PlaybackError(:final station) => _start(
      state,
      station,
      context: state.context,
      startStreamIndex: state.startStreamIndex,
      now: now,
      lastWorkingStreamIndex: state.lastWorkingStreamIndex,
    ),
    _ => _unchanged(state),
  };

  Transition _pause(EngineState state) {
    final station = state.station;
    if (station == null || !_isActive(state.status)) return _unchanged(state);
    return Transition(
      state.copyWith(
        status: PlaybackStatus.paused(station: station),
        generation: state.generation + 1,
        connectStartedAt: null,
      ),
      _stopEverything,
    );
  }

  Transition _stop(EngineState state) => Transition(
    state.copyWith(
      status: const PlaybackStatus.idle(),
      station: null,
      generation: state.generation + 1,
      candidates: const [],
      candidateIndex: 0,
      connectStartedAt: null,
    ),
    _stopEverything,
  );

  Transition _resolved(EngineState state, Resolved event) {
    if (event.generation != state.generation || state.status is! Connecting) {
      return _unchanged(state);
    }
    // The resolver never returns an empty list; if one ever did, nothing in
    // this stream is playable.
    if (event.candidates.isEmpty) {
      return _nextStream(state, formatFailure: true);
    }
    return Transition(
      state.copyWith(
        candidates: List.unmodifiable(event.candidates),
        candidateIndex: 0,
      ),
      [Load(event.candidates.first, state.generation)],
    );
  }

  Transition _playerStateChanged(
    EngineState state,
    PlayerStateChanged event,
    DateTime now,
  ) {
    if (event.generation != state.generation) return _unchanged(state);
    final readyAndPlaying =
        event.state == PlayerProcessingState.ready && event.playing;
    final completed = event.state == PlayerProcessingState.completed;
    switch (state.status) {
      case Connecting(:final station, :final streamIndex) when readyAndPlaying:
        final startedAt = state.connectStartedAt;
        return Transition(
          state.copyWith(
            status: PlaybackStatus.playing(
              station: station,
              streamIndex: streamIndex,
            ),
            everPlayed: true,
            lastWorkingStreamIndex: streamIndex,
            connectStartedAt: null,
          ),
          [
            const CancelTimer(TimerKind.connect),
            if (startedAt != null) RecordTimeToAudio(now.difference(startedAt)),
          ],
        );
      case Connecting() when completed:
        // A load that ends before any audio is as dead as a failed one.
        return _nextCandidate(state, formatFailure: false);
      case Playing(:final station, :final streamIndex)
          when event.state == PlayerProcessingState.buffering:
        return Transition(
          state.copyWith(
            status: PlaybackStatus.buffering(
              station: station,
              streamIndex: streamIndex,
            ),
          ),
          const [],
        );
      case Buffering(:final station, :final streamIndex) when readyAndPlaying:
        return Transition(
          state.copyWith(
            status: PlaybackStatus.playing(
              station: station,
              streamIndex: streamIndex,
            ),
          ),
          const [],
        );
      case Playing() || Buffering() when completed:
        // A live stream never ends: the server dropped us (Pitfall 2).
        return _toError(state, PlaybackErrorKind.streamUnreachable);
      case _:
        return _unchanged(state);
    }
  }

  Transition _playerFailed(EngineState state, int generation) {
    if (generation != state.generation) return _unchanged(state);
    return switch (state.status) {
      Connecting() => _nextCandidate(state, formatFailure: false),
      Playing() ||
      Buffering() => _toError(state, PlaybackErrorKind.streamUnreachable),
      _ => _unchanged(state),
    };
  }

  /// The current candidate failed: try the stream's next resolved candidate,
  /// or else the next stream.
  Transition _nextCandidate(EngineState state, {required bool formatFailure}) {
    final next = state.candidateIndex + 1;
    if (next >= state.candidates.length) {
      return _nextStream(state, formatFailure: formatFailure);
    }
    final generation = state.generation + 1;
    return Transition(
      state.copyWith(
        generation: generation,
        candidateIndex: next,
        onlyFormatFailures: state.onlyFormatFailures && formatFailure,
      ),
      [
        StartTimer(TimerKind.connect, timings.connectTimeout, generation),
        Load(state.candidates[next], generation),
      ],
    );
  }

  /// The current stream failed: invalidate its resolution and resolve the
  /// next one. When rotation reaches the start stream again a round ends; a
  /// station that never played is given up after the last allowed round
  /// (PLAY-08, T-09-02).
  Transition _nextStream(EngineState state, {required bool formatFailure}) {
    final station = state.station!;
    final failed = station.streams[state.streamIndex];
    final onlyFormatFailures = state.onlyFormatFailures && formatFailure;
    final nextIndex = (state.streamIndex + 1) % station.streams.length;
    final roundEnds = nextIndex == state.startStreamIndex;
    final nextRound = roundEnds ? state.round + 1 : state.round;
    if (roundEnds &&
        (state.everPlayed || nextRound >= timings.maxDeadOnArrivalRounds)) {
      // A station that played before is not dead on arrival: plan 01-10
      // turns this into Reconnecting.
      return _toError(
        state.copyWith(onlyFormatFailures: onlyFormatFailures),
        state.everPlayed
            ? PlaybackErrorKind.streamUnreachable
            : onlyFormatFailures
            ? PlaybackErrorKind.unsupportedFormat
            : PlaybackErrorKind.allStreamsFailed,
      );
    }
    final generation = state.generation + 1;
    return Transition(
      state.copyWith(
        status: PlaybackStatus.connecting(
          station: station,
          streamIndex: nextIndex,
          round: nextRound,
        ),
        generation: generation,
        streamIndex: nextIndex,
        candidateIndex: 0,
        round: nextRound,
        candidates: const [],
        onlyFormatFailures: onlyFormatFailures,
      ),
      [
        const StopTransport(),
        InvalidateResolution(failed),
        StartTimer(TimerKind.connect, timings.connectTimeout, generation),
        Resolve(station.streams[nextIndex], generation),
      ],
    );
  }

  /// Ends the session in [kind]: every timer cancelled, the failed stream's
  /// resolution dropped (the URL may be stale), the transport stopped and
  /// focus released, so the foreground service goes (T-09-02).
  Transition _toError(EngineState state, PlaybackErrorKind kind) {
    final stream = state.currentStream;
    return Transition(
      state.copyWith(
        status: PlaybackStatus.error(station: state.station!, kind: kind),
        generation: state.generation + 1,
        connectStartedAt: null,
      ),
      [
        const CancelAllTimers(),
        if (stream != null) InvalidateResolution(stream),
        const ClearNowPlaying(),
        const StopTransport(),
        const ReleaseFocus(),
      ],
    );
  }
}
