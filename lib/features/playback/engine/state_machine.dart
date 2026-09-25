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
    this.flowCheckDelay = const Duration(seconds: 5),
    this.connectivityDebounce = const Duration(milliseconds: 500),
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

  /// How long after a network change while Playing the buffered position
  /// must have advanced; if it has not, the stream is reloaded at once
  /// instead of waiting for the buffer to drain (RESEARCH A13: tune on a
  /// device).
  final Duration flowCheckDelay;

  /// How long the raw connectivity signal must be quiet before a change is
  /// reported (the ConnectivityPort adapter's debounce, T-12-02).
  final Duration connectivityDebounce;
}

/// The timers the handler runs for the state machine.
enum TimerKind {
  /// One connect attempt ([EngineTimings.connectTimeout]).
  connect,

  /// The stall watchdog while Buffering ([EngineTimings.stallTimeout]).
  stall,

  /// The wait before a reconnect retry ([ReconnectPolicy.delayFor]).
  backoff,

  /// Stable playback after an outage ([EngineTimings.stablePlayingReset]).
  stablePlaying,

  /// What is left of the retry budget ([RetryBudgetClock.remaining]).
  budget,

  /// The flow check after a network change while Playing
  /// ([EngineTimings.flowCheckDelay]).
  flowCheck,
}

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
    this.lastBuffered,
    this.flowCheckBaseline,
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

  /// The latest buffered position the player reported, with the generation
  /// of the load it belongs to.
  final ({int generation, Duration position})? lastBuffered;

  /// The buffered position when the flow check was armed; null when no check
  /// is pending or nothing had been buffered yet.
  final Duration? flowCheckBaseline;

  /// Whether the network is up, as last reported. The budget clock owns the
  /// flag, so the two can never disagree.
  bool get online => budget.online;

  /// The buffered position of the current load, or null when it has
  /// reported none.
  Duration? get currentBufferedPosition {
    final buffered = lastBuffered;
    return buffered != null && buffered.generation == generation
        ? buffered.position
        : null;
  }

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
    Object? lastBuffered = _unset,
    Object? flowCheckBaseline = _unset,
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
    lastBuffered: identical(lastBuffered, _unset)
        ? this.lastBuffered
        : lastBuffered as ({int generation, Duration position})?,
    flowCheckBaseline: identical(flowCheckBaseline, _unset)
        ? this.flowCheckBaseline
        : flowCheckBaseline as Duration?,
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

/// The network went up, went down or changed (from the debounced
/// ConnectivityPort).
final class ConnectivityChanged extends EngineEvent {
  const ConnectivityChanged({
    required this.online,
    this.networkChanged = false,
  });

  final bool online;
  final bool networkChanged;

  @override
  String toString() =>
      'ConnectivityChanged(${online ? 'online' : 'offline'}'
      '${networkChanged ? ', network changed' : ''})';
}

/// The player's buffered position for the load of [generation] (the flow
/// check's signal that audio is still arriving).
///
/// Named apart from the port's `BufferedPosition` value, which the handler
/// turns into this event.
final class BufferedPositionChanged extends EngineEvent {
  const BufferedPositionChanged(this.generation, this.position);

  final int generation;
  final Duration position;

  @override
  String toString() =>
      'BufferedPositionChanged(gen $generation, ${position.inMilliseconds} ms)';
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

/// The reducer. [transition] is pure: it never performs a side effect, and
/// the same state, event and time always give the same result, except for
/// the jitter the [policy] draws from its injected `Random` (tests seed it or
/// set its jitter to 0).
///
/// Rows (RESEARCH Pattern 2 and "Transition rules", ARCHITECTURE Patterns 3
/// and 4):
/// - UserPlay from any state: a new session at the live edge; every timer
///   of the old one is cancelled.
/// - Connecting: a failure of the current attempt (resolve failure, player
///   failure, a load that completes at once, or the connect timer) moves to
///   the next resolved candidate, then to the next stream. When rotation
///   comes back to where it started a round ends. A station that never
///   played is given up after [EngineTimings.maxDeadOnArrivalRounds] rounds;
///   one that played goes to Reconnecting.
/// - Connecting + ready and playing: Playing, with time-to-audio recorded.
/// - Playing + buffering: Buffering with the stall watchdog
///   ([EngineTimings.stallTimeout]); ready again cancels it. When it fires
///   the stream is reloaded through Reconnecting(attempt 0).
/// - Playing/Buffering + a failure or `completed`: Reconnecting (a live
///   stream never ends; the server or the network dropped us).
/// - Reconnecting + its backoff timer: a retry, Connecting from the stream
///   that last worked. A retry round that fails goes back to Reconnecting
///   with the next, longer backoff ([ReconnectPolicy.delayFor]).
/// - The retry budget ([RetryBudgetClock], D-10) runs while an outage is
///   failing; when it is used up the station ends in PlaybackError with
///   everything released. [EngineTimings.stablePlayingReset] of stable
///   Playing ends the outage and resets the backoff.
/// - UserPause/UserStop from an active state: Paused/Idle, everything
///   stopped, every timer cancelled and focus released.
/// - Guards (PLAY-10): an event stamped with an older generation changes
///   nothing, and only UserPlay and UserResume start playback from Paused,
///   Idle or Error. Reconnecting + its timer is the only path that starts
///   playback without a user command (01-12 adds connectivity, 01-13 focus).
class PlaybackStateMachine {
  const PlaybackStateMachine({
    required this.policy,
    this.timings = const EngineTimings(),
  });

  final ReconnectPolicy policy;
  final EngineTimings timings;

  Transition transition(
    EngineState state,
    EngineEvent event,
    DateTime now,
  ) => switch (event) {
    UserPlay(:final station, :final context, :final startStreamIndex) => _start(
      state,
      station,
      context: context,
      startStreamIndex: startStreamIndex,
      now: now,
    ),
    UserResume() => _resume(state, now),
    UserPause() => _pause(state),
    UserStop() => _stop(state),
    Resolved() => _resolved(state, event, now),
    ResolveFailed(:final generation, :final reason) =>
      generation == state.generation && state.status is Connecting
          ? _nextStream(state, now, formatFailure: _isFormatFailure(reason))
          : _unchanged(state),
    PlayerStateChanged() => _playerStateChanged(state, event, now),
    PlayerFailed(:final generation) => _playerFailed(state, generation, now),
    TimerFired(:final kind, :final generation) => _timerFired(
      state,
      kind,
      generation,
      now,
    ),
    SetRetryBudget(:final preset) => _setRetryBudget(state, preset, now),
    ConnectivityChanged() => _unchanged(state),
    BufferedPositionChanged() => _unchanged(state),
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

  /// Whether playback came back from an outage that has not yet been stable
  /// for [EngineTimings.stablePlayingReset].
  static bool _recovering(EngineState state) =>
      state.attempt > 0 || state.budget.active;

  /// Where a reconnect retry starts, and where its round ends: the stream
  /// that last worked, else the stream the session started at.
  static int _reconnectStart(EngineState state) {
    final last = state.lastWorkingStreamIndex;
    final count = state.station?.streams.length ?? 0;
    return last != null && last >= 0 && last < count
        ? last
        : state.startStreamIndex;
  }

  /// A new session on [station]: cancel the old session's timers, stop
  /// whatever plays, clear now-playing and resolve the start stream under a
  /// new generation. The handler publishes Connecting (playing: true,
  /// loading) before running these commands, so the foreground service
  /// starts from the user action (Pitfall G). The retry budget preset is
  /// kept; its clock starts afresh.
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
        budget: state.budget.reset(),
      ),
      [
        const CancelAllTimers(),
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

  /// Pause wins over everything in flight, including a reconnect: the
  /// backoff, stall, stable and budget timers are cancelled and the outage
  /// is forgotten (PLAY-10).
  Transition _pause(EngineState state) {
    final station = state.station;
    if (station == null || !_isActive(state.status)) return _unchanged(state);
    return Transition(
      state.copyWith(
        status: PlaybackStatus.paused(station: station),
        generation: state.generation + 1,
        connectStartedAt: null,
        budget: state.budget.reset(),
        attempt: 0,
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
      budget: state.budget.reset(),
      attempt: 0,
    ),
    _stopEverything,
  );

  Transition _resolved(EngineState state, Resolved event, DateTime now) {
    if (event.generation != state.generation || state.status is! Connecting) {
      return _unchanged(state);
    }
    // The resolver never returns an empty list; if one ever did, nothing in
    // this stream is playable.
    if (event.candidates.isEmpty) {
      return _nextStream(state, now, formatFailure: true);
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
    final recovering = _recovering(state);
    final stableTimer = StartTimer(
      TimerKind.stablePlaying,
      timings.stablePlayingReset,
      state.generation,
    );
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
            // Back from an outage: playing time does not count against the
            // budget, but the outage stays open until playback is stable.
            budget: state.budget.recovered(now),
          ),
          [
            const CancelTimer(TimerKind.connect),
            if (startedAt != null) RecordTimeToAudio(now.difference(startedAt)),
            if (recovering) ...[
              const CancelTimer(TimerKind.budget),
              stableTimer,
            ],
          ],
        );
      case Connecting() when completed:
        // A load that ends before any audio is as dead as a failed one.
        return _nextCandidate(state, now, formatFailure: false);
      case Playing(:final station, :final streamIndex)
          when event.state == PlayerProcessingState.buffering:
        return Transition(
          state.copyWith(
            status: PlaybackStatus.buffering(
              station: station,
              streamIndex: streamIndex,
            ),
          ),
          [
            if (recovering) const CancelTimer(TimerKind.stablePlaying),
            StartTimer(TimerKind.stall, timings.stallTimeout, state.generation),
          ],
        );
      case Buffering(:final station, :final streamIndex) when readyAndPlaying:
        return Transition(
          state.copyWith(
            status: PlaybackStatus.playing(
              station: station,
              streamIndex: streamIndex,
            ),
          ),
          [const CancelTimer(TimerKind.stall), if (recovering) stableTimer],
        );
      case Playing() || Buffering() when completed:
        // A live stream never ends: the server dropped us (Pitfall 2,
        // Anti-Pattern 4).
        return _reconnect(state, now, failed: state.currentStream);
      case _:
        return _unchanged(state);
    }
  }

  Transition _playerFailed(EngineState state, int generation, DateTime now) {
    if (generation != state.generation) return _unchanged(state);
    return switch (state.status) {
      Connecting() => _nextCandidate(state, now, formatFailure: false),
      Playing() ||
      Buffering() => _reconnect(state, now, failed: state.currentStream),
      _ => _unchanged(state),
    };
  }

  Transition _timerFired(
    EngineState state,
    TimerKind kind,
    int generation,
    DateTime now,
  ) {
    // The budget timer spans every retry of an outage (each retry is a new
    // generation), so its guard is the clock itself: it acts only while an
    // outage is failing. Pause, stop, a new session and an error all reset
    // the clock.
    if (kind == TimerKind.budget) return _budgetTimer(state, now);
    if (generation != state.generation) return _unchanged(state);
    return switch ((kind, state.status)) {
      (TimerKind.connect, Connecting()) => _nextCandidate(
        state,
        now,
        formatFailure: false,
      ),
      // The stall watchdog: ExoPlayer's own timeouts are far slower than
      // the ~10 s recovery target (ARCHITECTURE Pattern 4).
      (TimerKind.stall, Buffering()) => _reconnect(state, now),
      (TimerKind.backoff, Reconnecting()) => _retry(state, now),
      (TimerKind.stablePlaying, Playing()) => Transition(
        state.copyWith(budget: state.budget.reset(), attempt: 0),
        const [],
      ),
      _ => _unchanged(state),
    };
  }

  /// The current candidate failed: try the stream's next resolved candidate,
  /// or else the next stream.
  Transition _nextCandidate(
    EngineState state,
    DateTime now, {
    required bool formatFailure,
  }) {
    final next = state.candidateIndex + 1;
    if (next >= state.candidates.length) {
      return _nextStream(state, now, formatFailure: formatFailure);
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
  /// next one. When rotation reaches its first stream again a round ends: a
  /// station that played before reconnects with backoff (PLAY-07); one that
  /// never played is given up after the last allowed round (PLAY-08,
  /// T-09-02).
  Transition _nextStream(
    EngineState state,
    DateTime now, {
    required bool formatFailure,
  }) {
    final station = state.station!;
    final failed = station.streams[state.streamIndex];
    final onlyFormatFailures = state.onlyFormatFailures && formatFailure;
    final nextIndex = (state.streamIndex + 1) % station.streams.length;
    final roundStart = state.everPlayed
        ? _reconnectStart(state)
        : state.startStreamIndex;
    final roundEnds = nextIndex == roundStart;
    if (roundEnds && state.everPlayed) {
      return _reconnect(state, now, failed: failed);
    }
    final nextRound = roundEnds ? state.round + 1 : state.round;
    if (roundEnds && nextRound >= timings.maxDeadOnArrivalRounds) {
      return _toError(
        state.copyWith(onlyFormatFailures: onlyFormatFailures),
        onlyFormatFailures
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

  /// Playback dropped or a retry round failed: wait the backoff for this
  /// attempt, then retry at the live edge (PLAY-07, PLAY-11).
  ///
  /// The status keeps `playing: true` so the foreground service stays up
  /// while recovering (Pitfall 1). The budget clock runs from the first
  /// failure of the outage; the budget timer is armed for what is left, and
  /// a budget already used up gives up at once. [failed] is the stream whose
  /// resolution is dropped (a stall keeps it: the URL was fine).
  Transition _reconnect(
    EngineState state,
    DateTime now, {
    StationStream? failed,
  }) {
    final budget = state.budget.start(now, online: state.budget.online);
    final failing = state.copyWith(budget: budget);
    final exhaustion = budget.exhausted(now);
    if (exhaustion != null) return _giveUp(failing, exhaustion);
    final delay = policy.delayFor(state.attempt);
    final generation = state.generation + 1;
    return Transition(
      failing.copyWith(
        status: PlaybackStatus.reconnecting(
          station: state.station!,
          attempt: state.attempt,
          nextAttemptAt: now.add(delay),
        ),
        generation: generation,
        candidates: const [],
        candidateIndex: 0,
        connectStartedAt: null,
      ),
      [
        const CancelAllTimers(),
        const ClearNowPlaying(),
        const StopTransport(),
        if (failed != null) InvalidateResolution(failed),
        StartTimer(TimerKind.backoff, delay, generation),
        StartTimer(TimerKind.budget, budget.remaining(now), generation),
      ],
    );
  }

  /// The backoff ran out: a retry round, from the stream that last worked,
  /// as a fresh load at the live edge under a new generation.
  Transition _retry(EngineState state, DateTime now) {
    final exhaustion = state.budget.exhausted(now);
    if (exhaustion != null) return _giveUp(state, exhaustion);
    final station = state.station!;
    final start = _reconnectStart(state);
    final generation = state.generation + 1;
    return Transition(
      state.copyWith(
        status: PlaybackStatus.connecting(
          station: station,
          streamIndex: start,
          round: 0,
        ),
        generation: generation,
        streamIndex: start,
        candidateIndex: 0,
        round: 0,
        candidates: const [],
        attempt: state.attempt + 1,
      ),
      [
        StartTimer(TimerKind.connect, timings.connectTimeout, generation),
        Resolve(station.streams[start], generation),
      ],
    );
  }

  /// The budget timer: gives up when the budget is used up, or re-arms for
  /// the rest if it fired early. Outside a failing outage it does nothing.
  Transition _budgetTimer(EngineState state, DateTime now) {
    final inOutage =
        state.budget.running &&
        (state.status is Reconnecting || state.status is Connecting);
    if (!inOutage) return _unchanged(state);
    final exhaustion = state.budget.exhausted(now);
    if (exhaustion != null) return _giveUp(state, exhaustion);
    return Transition(state, [
      StartTimer(
        TimerKind.budget,
        state.budget.remaining(now),
        state.generation,
      ),
    ]);
  }

  /// The one engine-level reconnect setting (D-10). It applies to the
  /// outage in progress too: the budget timer is re-armed for what is left
  /// under the new limits (at once when that is nothing).
  Transition _setRetryBudget(
    EngineState state,
    RetryBudgetPreset preset,
    DateTime now,
  ) {
    final next = state.copyWith(budget: state.budget.withPreset(preset));
    final inOutage =
        next.budget.running &&
        (state.status is Reconnecting || state.status is Connecting);
    return Transition(next, [
      if (inOutage)
        StartTimer(
          TimerKind.budget,
          next.budget.remaining(now),
          state.generation,
        ),
    ]);
  }

  /// The retry budget is used up: the station ends in an error with
  /// everything released, so the foreground service goes (T-10-01).
  Transition _giveUp(EngineState state, BudgetExhaustion exhaustion) =>
      _toError(state, switch (exhaustion) {
        BudgetExhaustion.online => PlaybackErrorKind.streamUnreachable,
        BudgetExhaustion.offline => PlaybackErrorKind.offline,
      });

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
        budget: state.budget.reset(),
        attempt: 0,
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
