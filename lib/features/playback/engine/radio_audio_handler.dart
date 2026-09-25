import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:clock/clock.dart';

import '../../catalog/data/station_directory.dart';
import '../../catalog/domain/station.dart';
import '../domain/engine_diagnostics.dart';
import '../domain/engine_strings.dart';
import '../domain/media_id.dart';
import '../domain/now_playing.dart';
import '../domain/play_context.dart';
import '../domain/playback_status.dart';
import '../domain/retry_budget.dart';
import 'icy/now_playing_parser.dart';
import 'media_session_mapping.dart';
import 'ports.dart';
import 'reconnect_policy.dart';
import 'state_machine.dart';

/// The audio_service handler: the single owner of playback.
///
/// The phone UI, the media notification, the lock screen and headset or
/// Bluetooth buttons all arrive here through the same methods
/// (`playFromMediaId`, `play`, `pause`, `stop`, `click`).
///
/// The handler decides nothing itself. Every input (user commands, player
/// snapshots and failures, resolve results, timer fires) becomes an
/// [EngineEvent] on one serial queue. Each event is reduced by the pure
/// [PlaybackStateMachine]; the new state is published to the media session
/// and the app, and only then are the returned [EngineCommand]s executed, in
/// order, before the next event is reduced.
///
/// Live-radio rules (enforced by the state machine):
/// - Pause stops the network transport; play after a pause is a fresh load
///   at the live edge (PLAY-11). There is no seek.
/// - The media session is told about a start *before* the stream resolves
///   or loads, so the foreground service starts from the user action
///   (Pitfall G).
/// - Every load gets a new generation; events from older loads are dropped
///   (PLAY-10).
/// - A dead or slow stream falls over to the next candidate and stream; a
///   station that never plays is given up after two rounds (PLAY-08).
/// - A drop, a `completed` or 8 s of Buffering reconnects at the live edge
///   with backoff, keeping `playing: true` so the foreground service stays;
///   the station is given up when the retry budget (D-10) is used up
///   (PLAY-07).
/// - Focus is released on pause, stop and error (Pitfall F).
/// - Now-playing (ICY) is cleared on every start, pause, stop and error, and
///   only titles from the current load after it is ready are shown
///   (Pitfall E).
///
/// - Network changes (the debounced [ConnectivityPort]) go through the same
///   queue: offline during an outage waits without retrying until the
///   offline budget runs out; back online or on another network it retries
///   at once; a network change while Playing checks after 5 s that audio is
///   still arriving (buffered position) and reloads only if not.
///
/// - Audio focus and becoming-noisy events (the [AudioSessionPort]) go
///   through the same queue: a phone call interrupts (transport stopped,
///   focus and the foreground service kept) and the station resumes live
///   after hang-up, however long the call (D-11); a navigation prompt ducks
///   the volume; another media app or unplugging headphones pauses, and
///   nothing resumes it (PLAY-05, PLAY-06, PLAY-10).
class RadioAudioHandler extends BaseAudioHandler {
  RadioAudioHandler(
    this._player,
    this._session,
    this._directory,
    this._resolver,
    this._strings,
    this._connectivity,
    this._wifiLock, {
    EngineTimings timings = const EngineTimings(),
    Clock? clock,
    RetryBudgetPreset initialRetryBudget = RetryBudgetPreset.standard,
    ReconnectPolicy? reconnectPolicy,
  }) : _machine = PlaybackStateMachine(
         policy: reconnectPolicy ?? ReconnectPolicy(Random()),
         timings: timings,
       ),
       _clockOverride = clock,
       _state = EngineState(
         status: const PlaybackStatus.idle(),
         budget: RetryBudgetClock(preset: initialRetryBudget),
       ) {
    _subscriptions.addAll([
      _player.snapshots.listen(_onSnapshot),
      _player.failures.listen(_onFailure),
      _player.icyTitles.listen(_onIcyTitle),
      _player.bufferedPositions.listen(_onBufferedPosition),
      // The engine is the single owner of focus and noisy events; just_audio
      // runs with handleInterruptions: false (Anti-Pattern 3).
      _session.focusChanges.listen(
        (change) => unawaited(_dispatch(FocusChanged(change))),
      ),
      _session.becomingNoisy.listen(
        (_) => unawaited(_dispatch(const BecomingNoisy())),
      ),
    ]);
    unawaited(_watchConnectivity());
  }

  final StreamPlayer _player;
  final AudioSessionPort _session;
  final StationDirectory _directory;
  final StreamResolver _resolver;
  final EngineStrings _strings;
  final ConnectivityPort _connectivity;
  // RED scaffolding (01-13 Task 2): used in the GREEN step.
  // ignore: unused_field
  final WifiLockPort _wifiLock;
  final PlaybackStateMachine _machine;

  /// Null: the zone's clock (fake under fakeAsync).
  final Clock? _clockOverride;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  final _statusController = StreamController<PlaybackStatus>.broadcast();
  final _stationController = StreamController<Station?>.broadcast();
  final _nowPlayingController = StreamController<NowPlaying?>.broadcast();
  final _diagnosticsController =
      StreamController<EngineDiagnostics>.broadcast();

  EngineState _state;
  Station? _station;

  /// Events waiting to be reduced, each with the completer its caller awaits.
  final _queue = ListQueue<(EngineEvent, Completer<void>)>();

  /// Completes when the queue runs empty; null while the queue is idle.
  Completer<void>? _draining;

  /// The latest Resolve command, so user commands can wait for it.
  _InFlightResolve? _inFlightResolve;

  final Map<TimerKind, Timer> _timers = {};
  bool _disposed = false;

  /// The last now-playing value published, or null.
  NowPlaying? _nowPlaying;

  /// The station most recently started, kept after Stop. Android shows a
  /// resumable media card for the app after Stop (audio_service always
  /// answers the system UI's "recent" browse query), and its Play button, a
  /// Bluetooth PLAY or a car must start this station again.
  Station? _lastStation;

  /// Whether the current generation's load has reported ready. ICY titles
  /// that arrive earlier are dropped: the native player's ICY state survives
  /// a load, so an early title can be the previous source's (Pitfall E).
  /// Reset whenever the state machine moves to a new generation.
  bool _readySeenForGeneration = false;

  final _recentEvents = ListQueue<DiagnosticEvent>();
  Duration? _lastTimeToAudio;

  /// The backoff of the latest reconnect wait, for diagnostics.
  Duration? _lastBackoff;
  EngineDiagnostics _diagnostics = const EngineDiagnostics.initial();

  /// The `playFromMediaId` extras key (an int) for the stream to start at,
  /// used by `AudioEngine.play(startStreamIndex:)` (01-11's stream
  /// switcher). Without it the station starts at `streams[0]`.
  static const startStreamIndexExtra = 'startStreamIndex';

  /// The list the next station started through [playFromMediaId] belongs to.
  PlayContext playContext = const PlayContext.single();

  /// The reconnect give-up policy in force (D-10).
  RetryBudgetPreset get retryBudget => _state.budget.preset;

  /// Sets the reconnect give-up policy (D-10), the engine-level setting
  /// behind `AudioEngine.setRetryBudget`. It goes through the event queue
  /// like every other input, so it also applies to an outage in progress.
  Future<void> setRetryBudget(RetryBudgetPreset preset) =>
      _dispatch(SetRetryBudget(preset));

  PlaybackStatus get status => _state.status;
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  Station? get currentStation => _station;
  Stream<Station?> get currentStationStream => _stationController.stream;

  NowPlaying? get nowPlaying => _nowPlaying;
  Stream<NowPlaying?> get nowPlayingStream => _nowPlayingController.stream;

  /// What the engine is doing, for the debug panel (D-07). In memory only:
  /// never persisted or transmitted (T-09-03).
  EngineDiagnostics get currentDiagnostics => _diagnostics;
  Stream<EngineDiagnostics> get diagnostics => _diagnosticsController.stream;

  DateTime get _now => (_clockOverride ?? clock).now();

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final MediaId parsed;
    try {
      parsed = MediaId.parse(mediaId);
    } on FormatException catch (e) {
      throw ArgumentError.value(mediaId, 'mediaId', e.message);
    }
    if (parsed is! StationMediaId) {
      throw ArgumentError.value(mediaId, 'mediaId', 'Not a station');
    }
    final station = _directory.byId(parsed.stationId);
    if (station == null) {
      throw ArgumentError.value(mediaId, 'mediaId', 'Unknown station');
    }
    // Extras can come from other apps (a car, a launcher): anything but an
    // int is ignored, and the state machine starts an out-of-range index at
    // the primary.
    final startStreamIndex = extras?[startStreamIndexExtra];
    await _dispatch(
      UserPlay(
        station,
        context: playContext,
        startStreamIndex: startStreamIndex is int ? startStreamIndex : 0,
      ),
    );
    await _settle();
  }

  /// Headset, car and Bluetooth "next" (PLAY-03): the next station of the
  /// list the current one was started from, wrapping at the end. Not shown
  /// in the notification until Phase 3 (D-12).
  @override
  Future<void> skipToNext() => _skip(1);

  /// Headset, car and Bluetooth "previous" (PLAY-03), wrapping at the start.
  @override
  Future<void> skipToPrevious() => _skip(-1);

  /// Starts the station [delta] places away in the current list, keeping
  /// the list. After Stop it moves from the last station. A single station
  /// has no neighbour, so nothing happens.
  Future<void> _skip(int delta) async {
    final current = _state.station ?? _lastStation;
    if (current == null) return;
    final context = _state.context;
    final id = context.neighbour(current.id, delta);
    final station = id == null ? null : _directory.byId(id);
    if (station == null) return;
    await _dispatch(UserPlay(station, context: context));
    await _settle();
  }

  @override
  Future<void> play() async {
    final last = _lastStation;
    if (_state.status is Idle) {
      // After Stop: the media card's Play (or a headset/Bluetooth PLAY)
      // starts the last station again, live.
      if (last == null) return;
      await _dispatch(UserPlay(last, context: _state.context));
    } else {
      // Paused or Error: a fresh load. Active states ignore it.
      await _dispatch(const UserResume());
    }
    await _settle();
  }

  /// Answers the system UI's media-resumption query ([AudioService.recentRootId])
  /// with the last station, so the card after Stop is playable. The full
  /// browse tree (Android Auto) arrives in v1.1.
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final last = _lastStation;
    if (parentMediaId == AudioService.recentRootId && last != null) {
      return [mediaItemFor(last, const PlaybackStatus.idle(), _strings)];
    }
    return const [];
  }

  @override
  Future<void> pause() async {
    await _dispatch(const UserPause());
    await _settle();
  }

  /// processingState idle: audio_service stops the service and removes the
  /// notification.
  @override
  Future<void> stop() async {
    await _dispatch(const UserStop());
    await _settle();
  }

  /// Cancels timers and subscriptions. The app never disposes the handler;
  /// tests do.
  Future<void> dispose() async {
    _disposed = true;
    _cancelTimers();
    for (final s in _subscriptions) {
      await s.cancel();
    }
  }

  // -------------------------------------------------------------------------
  // The serial event queue
  // -------------------------------------------------------------------------

  /// Queues [event]; the future completes once its commands have run. When
  /// the queue is idle the event is reduced and published synchronously.
  ///
  /// Code running inside a command must not await this (it would wait for
  /// itself); it uses `unawaited`.
  Future<void> _dispatch(EngineEvent event) {
    final done = Completer<void>();
    if (_disposed) {
      done.complete();
      return done.future;
    }
    _queue.add((event, done));
    if (_draining == null) unawaited(_drain());
    return done.future;
  }

  Future<void> _drain() async {
    final draining = _draining = Completer<void>();
    try {
      while (_queue.isNotEmpty) {
        final (event, done) = _queue.removeFirst();
        try {
          final transition = _machine.transition(_state, event, _now);
          _apply(event, transition.next);
          for (final command in transition.commands) {
            await _execute(command);
          }
        } catch (error, stack) {
          // A reducer or executor bug must never stop the queue: playback
          // would be dead until the app restarts. Report it and go on.
          _log('internal error on $event: $error');
          Zone.current.handleUncaughtError(error, stack);
        } finally {
          done.complete();
        }
      }
    } finally {
      _draining = null;
      draining.complete();
    }
  }

  /// Waits until the queue is idle and the current generation's resolution
  /// (if any) has been handled, so `await handler.play()` returns once the
  /// stream is loaded or has failed over. A resolution of a superseded
  /// generation is not waited for.
  Future<void> _settle() async {
    while (true) {
      final inFlight = _inFlightResolve;
      if (inFlight != null &&
          !inFlight.done.isCompleted &&
          inFlight.generation == _state.generation) {
        await inFlight.done.future;
        continue;
      }
      final draining = _draining;
      if (draining != null) {
        await draining.future;
        continue;
      }
      return;
    }
  }

  /// Adopts [next] and publishes it: station, then media item, then
  /// PlaybackState, before any command runs (Pitfall G).
  void _apply(EngineEvent event, EngineState next) {
    final previous = _state;
    _state = next;
    if (next.generation != previous.generation) {
      // A new generation supersedes the current load: its ICY titles are
      // dropped until the new load reports ready.
      _readySeenForGeneration = false;
    }
    final station = next.station;
    if (station != null) _lastStation = station;
    _setStation(station);
    if (next.status != previous.status) _publishStatus(next.status);
    // Buffered positions arrive about every 500 ms while playing; logging
    // them would push everything else out of the 50-entry log.
    if (event is! BufferedPositionChanged) {
      _log('$event → ${describeStatus(next.status)}');
    }
  }

  Future<void> _execute(EngineCommand command) async {
    try {
      switch (command) {
        case StopTransport():
          await _player.stop();
        case Resolve(:final stream, :final generation):
          _startResolve(stream, generation);
        case Load(:final resolved, :final generation):
          try {
            await _player.load(resolved, generation: generation);
          } catch (_) {
            unawaited(_dispatch(PlayerFailed(generation, -1)));
          }
        case ReleaseFocus():
          await _session.release();
        case StartTimer(:final kind, :final duration, :final generation):
          _timers.remove(kind)?.cancel();
          _timers[kind] = Timer(
            duration,
            () => unawaited(_dispatch(TimerFired(kind, generation))),
          );
          if (kind == TimerKind.backoff) {
            _lastBackoff = duration;
            _emitDiagnostics();
          }
        case CancelTimer(:final kind):
          _timers.remove(kind)?.cancel();
        case CancelAllTimers():
          _cancelTimers();
        case InvalidateResolution(:final stream):
          _resolver.invalidate(stream);
        case ClearNowPlaying():
          _setNowPlaying(null);
        case SetVolume(:final volume):
          await _player.setVolume(volume);
        case RecordTimeToAudio(:final duration):
          _lastTimeToAudio = duration;
          _emitDiagnostics();
      }
    } catch (error) {
      // A platform call (stop, focus release) failing must not stop the
      // commands after it.
      _log('$command failed: $error');
    }
  }

  /// Resolves in the background, so a slow playlist never blocks a pause or
  /// stop; the result comes back as an event stamped with [generation].
  void _startResolve(StationStream stream, int generation) {
    final inFlight = _inFlightResolve = _InFlightResolve(generation);
    unawaited(
      () async {
        EngineEvent result;
        try {
          result = Resolved(generation, await _resolver.resolve(stream));
        } on StreamResolutionException catch (e) {
          result = ResolveFailed(generation, e.reason);
        } catch (_) {
          result = ResolveFailed(generation, null);
        }
        await _dispatch(result);
      }().whenComplete(() => inFlight.done.complete()),
    );
  }

  void _cancelTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  // -------------------------------------------------------------------------
  // Player and network inputs
  // -------------------------------------------------------------------------

  /// Seeds the network state from [ConnectivityPort.isOnline], then feeds
  /// every change onto the queue. The state machine starts online, so only
  /// an offline answer needs an event. A port that fails counts as online:
  /// the stall watchdog and player failures still reconnect.
  Future<void> _watchConnectivity() async {
    var online = true;
    try {
      online = await _connectivity.isOnline();
    } catch (error) {
      _log('isOnline failed: $error');
    }
    if (_disposed) return;
    if (!online) unawaited(_dispatch(const ConnectivityChanged(online: false)));
    _subscriptions.add(
      _connectivity.changes.listen(
        (change) => unawaited(
          _dispatch(
            ConnectivityChanged(
              online: change.online,
              networkChanged: change.networkChanged,
            ),
          ),
        ),
      ),
    );
  }

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (snapshot.generation == _state.generation &&
        snapshot.state == PlayerProcessingState.ready) {
      _readySeenForGeneration = true;
    }
    unawaited(
      _dispatch(
        PlayerStateChanged(
          snapshot.generation,
          snapshot.state,
          playing: snapshot.playing,
        ),
      ),
    );
  }

  void _onBufferedPosition(BufferedPosition buffered) => unawaited(
    _dispatch(BufferedPositionChanged(buffered.generation, buffered.position)),
  );

  void _onFailure(PlayerFailure failure) =>
      unawaited(_dispatch(PlayerFailed(failure.generation, failure.code)));

  /// ICY "now playing" (RESEARCH Pattern 5). Only parseIcyTitle's output
  /// (repaired, sanitised, junk-filtered) ever reaches the media session;
  /// the raw title never does (T-08-01).
  ///
  /// Titles from a superseded load, or from the current load before its
  /// first ready snapshot, are dropped (T-08-03). A junk title (null, empty,
  /// '-', the station name, a URL) parses to null and clears the line.
  void _onIcyTitle(IcyTitle icy) {
    if (icy.generation != _state.generation || !_readySeenForGeneration) {
      return;
    }
    final station = _state.station;
    final stream = _state.currentStream;
    if (station == null || stream == null) return;
    _setNowPlaying(
      parseIcyTitle(icy.title, station: station, charset: stream.icyCharset),
    );
  }

  // -------------------------------------------------------------------------
  // Publishing
  // -------------------------------------------------------------------------

  /// Publishes [value] when it differs from the last one (NowPlaying value
  /// equality). Each media-item update redraws the notification, so an
  /// unchanged title republishes nothing (Anti-Pattern 9, T-08-02).
  ///
  /// `_setNowPlaying(null)` is the clear (the ClearNowPlaying command): every
  /// start or switch, pause, stop and failure runs it.
  void _setNowPlaying(NowPlaying? value) {
    if (value == _nowPlaying) return;
    _nowPlaying = value;
    _nowPlayingController.add(value);
    final station = _state.status.stationOrNull;
    if (station != null) {
      _publishMediaItem(
        mediaItemFor(station, _state.status, _strings, nowPlaying: value),
      );
    }
  }

  /// Publishes [status] to the media session and the app. The media item
  /// goes first, so the notification never shows a new state under an old
  /// subtitle; Idle clears it.
  void _publishStatus(PlaybackStatus status) {
    final station = status.stationOrNull;
    _publishMediaItem(
      station == null
          ? null
          : mediaItemFor(station, status, _strings, nowPlaying: _nowPlaying),
    );
    playbackState.add(playbackStateFor(status));
    _statusController.add(status);
  }

  /// Every media-item update redraws the notification and the lock screen,
  /// so an unchanged item is not sent again (ARCHITECTURE Anti-Pattern 9).
  void _publishMediaItem(MediaItem? item) {
    if (sameMediaItem(mediaItem.value, item)) return;
    mediaItem.add(item);
  }

  void _setStation(Station? station) {
    if (_station == station) return;
    _station = station;
    _stationController.add(station);
  }

  /// Appends to the diagnostics event log (newest last, at most
  /// [EngineDiagnostics.maxRecentEvents]) and emits the diagnostics.
  void _log(String message) {
    _recentEvents.addLast(DiagnosticEvent(_now, message));
    while (_recentEvents.length > EngineDiagnostics.maxRecentEvents) {
      _recentEvents.removeFirst();
    }
    _emitDiagnostics();
  }

  void _emitDiagnostics() {
    final s = _state;
    final candidate = s.currentCandidate;
    _diagnostics = EngineDiagnostics(
      state: describeStatus(s.status),
      stationId: s.station?.id,
      streamIndex: s.station == null ? null : s.streamIndex,
      candidateIndex: candidate == null ? null : s.candidateIndex,
      url: candidate?.uri,
      kind: candidate?.kind,
      round: s.round,
      reconnectAttempt: s.attempt,
      nextRetryDelay: switch (s.status) {
        Reconnecting(waitingForNetwork: false) => _lastBackoff,
        _ => null,
      },
      lastTimeToAudio: _lastTimeToAudio,
      recentEvents: List.unmodifiable(_recentEvents),
    );
    _diagnosticsController.add(_diagnostics);
  }
}

/// The latest Resolve command and whether its result has been handled.
final class _InFlightResolve {
  _InFlightResolve(this.generation);

  final int generation;
  final done = Completer<void>();
}
