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
    this.ducked = false,
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

  /// Whether the player's volume is lowered for another app's short sound
  /// (a navigation prompt). Kept until the duck ends, focus is released or
  /// focus is regained after a call.
  final bool ducked;

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
    bool? ducked,
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
    ducked: ducked ?? this.ducked,
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
  Reconnecting(:final attempt, :final waitingForNetwork) =>
    waitingForNetwork
        ? 'Reconnecting(attempt $attempt, waiting for network)'
        : 'Reconnecting(attempt $attempt)',
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

/// Android changed our audio focus (from the AudioSessionPort).
final class FocusChanged extends EngineEvent {
  const FocusChanged(this.change);

  final FocusChange change;

  @override
  String toString() => 'FocusChanged(${change.name})';
}

/// Headphones were unplugged or Bluetooth audio disconnected.
final class BecomingNoisy extends EngineEvent {
  const BecomingNoisy();

  @override
  String toString() => 'BecomingNoisy';
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

/// Set the player's volume (1.0 is full); used to duck under another app's
/// short sound.
final class SetVolume extends EngineCommand {
  const SetVolume(this.volume);

  final double volume;

  @override
  bool operator ==(Object other) =>
      other is SetVolume && other.volume == volume;

  @override
  int get hashCode => Object.hash(SetVolume, volume);

  @override
  String toString() => 'SetVolume($volume)';
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
/// - Connectivity (01-12): offline during an outage waits for the network
///   (Reconnecting(waitingForNetwork), no backoff, the offline budget runs);
///   online or a network change while Reconnecting or Buffering retries
///   now with the backoff reset; a network change while Playing arms the
///   [EngineTimings.flowCheckDelay] flow check, which reloads only if the
///   buffered position has not advanced.
/// - Audio focus (01-13): a phone call (transient loss) in an active state
///   goes to Interrupted (transport stopped, focus and the foreground
///   service kept) and the gain after it resumes with a fresh load (D-11);
///   another media app (permanent loss) or becoming noisy (unplugged
///   headphones, Bluetooth gone) is a pause; a navigation prompt ducks the
///   volume to [duckVolume] and back.
/// - UserPause/UserStop from an active state (Interrupted included):
///   Paused/Idle, everything stopped, every timer cancelled and focus
///   released.
/// - Guards (PLAY-10): an event stamped with an older generation changes
///   nothing, and only UserPlay and UserResume start playback from Paused,
///   Idle or Error. Exactly two paths start playback without a user
///   command: Interrupted + gainAfterPause, and Reconnecting + its timer or
///   connectivity. (The stall watchdog, connectivity and the flow check
///   while Playing or Buffering reload a stream that is already playing;
///   they go through the same retry.) Nothing ever resumes after a user
///   pause or stop, becoming noisy, a permanent focus loss or a
///   budget-exhausted error.
class PlaybackStateMachine {
  const PlaybackStateMachine({
    required this.policy,
    this.timings = const EngineTimings(),
  });

  final ReconnectPolicy policy;
  final EngineTimings timings;

  /// The player volume while another app's short sound plays over ours.
  static const duckVolume = 0.3;

  Transition transition(EngineState state, EngineEvent event, DateTime now) =>
      _restoreVolumeOnRelease(_reduce(state, event, now));

  /// Once focus is abandoned no duckEnd can arrive, so a ducked player is
  /// set back to full volume whenever a transition releases focus (pause,
  /// stop, error); otherwise the next play would start quiet.
  static Transition _restoreVolumeOnRelease(Transition t) {
    if (!t.next.ducked || !t.commands.contains(const ReleaseFocus())) return t;
    return Transition(t.next.copyWith(ducked: false), [
      ...t.commands,
      const SetVolume(1.0),
    ]);
  }

  Transition _reduce(
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
    ConnectivityChanged() => _connectivityChanged(state, event, now),
    BufferedPositionChanged(:final generation, :final position) =>
      generation == state.generation
          ? Transition(
              state.copyWith(
                lastBuffered: (generation: generation, position: position),
              ),
              const [],
            )
          : _unchanged(state),
    FocusChanged(:final change) => _focusChanged(state, change, now),
    // Unplugged headphones or a Bluetooth disconnect: a user-grade pause,
    // never resumed by itself (PLAY-06). Ignored outside an active state.
    BecomingNoisy() => _pause(state),
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
        // Focus is still held (a new station is not a new focus request),
        // so a duck in progress ends with its duckEnd.
        ducked: state.ducked,
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
      (TimerKind.flowCheck, Playing() || Buffering()) => _flowCheck(state, now),
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
        !state.online
            ? PlaybackErrorKind.offline
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

  /// Playback dropped or a retry round failed: wait the backoff for this
  /// attempt, then retry at the live edge (PLAY-07, PLAY-11). Offline there
  /// is no backoff: Reconnecting(waitingForNetwork) waits for the network
  /// and only the offline budget runs (T-12-01).
  ///
  /// The status keeps `playing: true` so the foreground service stays up
  /// while recovering (Pitfall 1). The budget clock runs from the first
  /// failure of the outage; the budget timer is armed for what is left of
  /// the budget being spent (online or offline), and a budget already used
  /// up gives up at once. [failed] is the stream whose resolution is dropped
  /// (a stall keeps it: the URL was fine).
  Transition _reconnect(
    EngineState state,
    DateTime now, {
    StationStream? failed,
  }) {
    final budget = state.budget.start(now, online: state.online);
    final failing = state.copyWith(budget: budget);
    final exhaustion = budget.exhausted(now);
    if (exhaustion != null) return _giveUp(failing, exhaustion);
    final waiting = !state.online;
    final delay = waiting ? null : policy.delayFor(state.attempt);
    final generation = state.generation + 1;
    return Transition(
      failing.copyWith(
        status: PlaybackStatus.reconnecting(
          station: state.station!,
          attempt: state.attempt,
          nextAttemptAt: delay == null ? null : now.add(delay),
          waitingForNetwork: waiting,
        ),
        generation: generation,
        candidates: const [],
        candidateIndex: 0,
        connectStartedAt: null,
        flowCheckBaseline: null,
      ),
      [
        const CancelAllTimers(),
        const ClearNowPlaying(),
        const StopTransport(),
        if (failed != null) InvalidateResolution(failed),
        if (delay != null) StartTimer(TimerKind.backoff, delay, generation),
        StartTimer(TimerKind.budget, budget.remaining(now), generation),
      ],
    );
  }

  /// The backoff ran out: a retry round, from the stream that last worked,
  /// as a fresh load at the live edge under a new generation.
  Transition _retry(EngineState state, DateTime now) {
    final exhaustion = state.budget.exhausted(now);
    if (exhaustion != null) return _giveUp(state, exhaustion);
    // A retry while offline would only burn the budget and the battery.
    if (!state.online) return _reconnect(state, now);
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

  /// Reload now at the live edge, without waiting for a backoff (the
  /// network came back or changed, or audio stopped arriving): a retry from
  /// the stream that last worked with the backoff reset, under a new
  /// generation. From Playing or Buffering this opens an outage (the URL
  /// was fine, so nothing is invalidated). Offline it waits for the network
  /// instead.
  Transition _reloadNow(EngineState state, DateTime now) {
    if (!state.online) return _reconnect(state, now);
    final wasReconnecting = state.status is Reconnecting;
    final budget = state.budget.start(now, online: true);
    final retry = _retry(
      state.copyWith(budget: budget, attempt: 0, flowCheckBaseline: null),
      now,
    );
    if (retry.next.status is! Connecting) return retry;
    return Transition(retry.next, [
      const CancelAllTimers(),
      if (!wasReconnecting) ...[const ClearNowPlaying(), const StopTransport()],
      StartTimer(
        TimerKind.budget,
        budget.remaining(now),
        retry.next.generation,
      ),
      ...retry.commands,
    ]);
  }

  /// A debounced network change (RESEARCH "Transition rules", ARCHITECTURE
  /// Pattern 4). The budget clock always learns the new flag; only
  /// Reconnecting, a retry Connecting, Buffering and Playing react. Paused,
  /// Idle and PlaybackError never start anything (PLAY-10, T-12-03).
  ///
  /// - Offline during an outage: Reconnecting(waitingForNetwork), no backoff,
  ///   the offline budget runs.
  /// - Back online, or on another network, while Reconnecting or Buffering:
  ///   retry now with the backoff reset.
  /// - The same while Playing: arm the flow check.
  /// - A user start that is still Connecting is left alone: its connect
  ///   timer and rotation already cover it, and restarting it would only
  ///   make a second connection (idempotency).
  Transition _connectivityChanged(
    EngineState state,
    ConnectivityChanged event,
    DateTime now,
  ) {
    final wasOnline = state.online;
    final updated = state.copyWith(
      budget: state.budget.onConnectivity(now, online: event.online),
    );
    final cameBack = event.online && (!wasOnline || event.networkChanged);
    final retryInFlight = updated.budget.running && state.status is Connecting;
    switch (state.status) {
      case Reconnecting() when cameBack:
        return _reloadNow(updated, now);
      case Reconnecting(:final waitingForNetwork)
          when !event.online && !waitingForNetwork:
        return _reconnect(updated, now);
      case Connecting() when retryInFlight && !event.online:
        return _reconnect(updated, now);
      case Buffering() when cameBack:
        return _reloadNow(updated, now);
      case Playing() when cameBack:
        return Transition(
          updated.copyWith(flowCheckBaseline: updated.currentBufferedPosition),
          [
            StartTimer(
              TimerKind.flowCheck,
              timings.flowCheckDelay,
              state.generation,
            ),
          ],
        );
      case _:
        final rearm =
            wasOnline != event.online &&
            updated.budget.running &&
            (state.status is Reconnecting || state.status is Connecting);
        return Transition(updated, [
          if (rearm)
            StartTimer(
              TimerKind.budget,
              updated.budget.remaining(now),
              state.generation,
            ),
        ]);
    }
  }

  /// The flow check fired: if the buffered position advanced since the
  /// network change, audio is still arriving and nothing happens; otherwise
  /// the old socket is dead and the stream is reloaded at once instead of
  /// waiting for the buffer to drain.
  Transition _flowCheck(EngineState state, DateTime now) {
    final current = state.currentBufferedPosition;
    final baseline = state.flowCheckBaseline;
    final advanced =
        current != null && (baseline == null || current > baseline);
    final cleared = state.copyWith(flowCheckBaseline: null);
    if (advanced) return Transition(cleared, const []);
    return _reloadNow(cleared, now);
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

  /// An audio-focus change (RESEARCH Pattern 1 and "Transition rules").
  ///
  /// - transientLoss (a phone call) in Connecting, Playing, Buffering or
  ///   Reconnecting: Interrupted.
  /// - gainAfterPause in Interrupted: a fresh load at the live edge (D-11).
  ///   Anywhere else it is ignored (PLAY-10).
  /// - permanentLoss (another media app): Paused with focus released, like
  ///   a user pause; no gain ever follows it.
  /// - duckBegin / duckEnd: the volume goes to [duckVolume] and back; the
  ///   status does not change.
  Transition _focusChanged(
    EngineState state,
    FocusChange change,
    DateTime now,
  ) => switch (change) {
    FocusChange.transientLoss => switch (state.status) {
      Connecting() ||
      Playing() ||
      Buffering() ||
      Reconnecting() => _interrupt(state),
      _ => _unchanged(state),
    },
    FocusChange.gainAfterPause =>
      state.status is Interrupted
          ? _resumeAfterInterruption(state, now)
          : _unchanged(state),
    FocusChange.permanentLoss => _pause(state),
    FocusChange.duckBegin =>
      _isActive(state.status) && !state.ducked
          ? Transition(state.copyWith(ducked: true), const [
              SetVolume(duckVolume),
            ])
          : _unchanged(state),
    FocusChange.duckEnd =>
      state.ducked
          ? Transition(state.copyWith(ducked: false), const [SetVolume(1.0)])
          : _unchanged(state),
  };

  /// A phone call took focus for a while: stop the transport (no audio can
  /// be heard anyway, and a live stream must not be buffered through the
  /// call), cancel every timer and forget any outage. Focus is kept:
  /// audio_session still holds the request after a transient loss, so the
  /// resume needs no new grant. Interrupted reports `playing: true`, so the
  /// foreground service stays up through the call (D-11, Pitfall 1).
  ///
  /// Nothing but the gain, a user command, a permanent loss or becoming
  /// noisy changes Interrupted: connectivity only records the flag, stale
  /// player events and timers are dropped by the new generation, and no
  /// retry budget runs, so a call of any length resumes.
  Transition _interrupt(EngineState state) => Transition(
    state.copyWith(
      status: PlaybackStatus.interrupted(station: state.station!),
      generation: state.generation + 1,
      candidates: const [],
      candidateIndex: 0,
      connectStartedAt: null,
      budget: state.budget.reset(),
      attempt: 0,
      flowCheckBaseline: null,
    ),
    const [CancelAllTimers(), ClearNowPlaying(), StopTransport()],
  );

  /// The call ended: a fresh load at the live edge (PLAY-11) from the stream
  /// that last worked, as if the user pressed play, but keeping whether the
  /// station had played (so a later drop reconnects instead of giving up).
  /// A duck cut short by the call is over: full volume again.
  Transition _resumeAfterInterruption(EngineState state, DateTime now) {
    final t = _start(
      state,
      state.station!,
      context: state.context,
      startStreamIndex: state.lastWorkingStreamIndex ?? state.startStreamIndex,
      now: now,
      lastWorkingStreamIndex: state.lastWorkingStreamIndex,
    );
    return Transition(
      t.next.copyWith(everPlayed: state.everPlayed, ducked: false),
      [if (state.ducked) const SetVolume(1.0), ...t.commands],
    );
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
