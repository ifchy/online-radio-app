import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../catalog/data/station_directory.dart';
import '../../catalog/domain/station.dart';
import '../domain/engine_strings.dart';
import '../domain/media_id.dart';
import '../domain/now_playing.dart';
import '../domain/play_context.dart';
import '../domain/playback_status.dart';
import 'icy/now_playing_parser.dart';
import 'media_session_mapping.dart';
import 'ports.dart';

/// The audio_service handler: the single owner of playback.
///
/// The phone UI, the media notification, the lock screen and headset or
/// Bluetooth buttons all arrive here through the same methods
/// (`playFromMediaId`, `play`, `pause`, `stop`, `click`).
///
/// Live-radio rules:
/// - Pause stops the network transport; play after a pause is a fresh load
///   at the live edge (PLAY-11). There is no seek.
/// - The media session is told about a start *before* the stream loads, so
///   the foreground service starts from the user action (Pitfall G).
/// - Every load gets a new generation; events from older loads are dropped.
/// - Focus is released on pause, stop and error (Pitfall F).
/// - Now-playing (ICY) is cleared on every start, pause, stop and error, and
///   only titles from the current load after it is ready are shown
///   (Pitfall E).
///
/// Reconnect, fallback rotation and interruptions arrive in later plans.
class RadioAudioHandler extends BaseAudioHandler {
  RadioAudioHandler(
    this._player,
    this._session,
    this._directory,
    this._resolver,
    this._strings,
  ) {
    _subscriptions.addAll([
      _player.snapshots.listen(_onSnapshot),
      _player.failures.listen(_onFailure),
      _player.icyTitles.listen(_onIcyTitle),
    ]);
  }

  final StreamPlayer _player;
  final AudioSessionPort _session;
  final StationDirectory _directory;
  final StreamResolver _resolver;
  final EngineStrings _strings;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  final _statusController = StreamController<PlaybackStatus>.broadcast();
  final _stationController = StreamController<Station?>.broadcast();
  final _nowPlayingController = StreamController<NowPlaying?>.broadcast();

  PlaybackStatus _status = const PlaybackStatus.idle();
  Station? _station;

  /// The last now-playing value published, or null.
  NowPlaying? _nowPlaying;

  /// The station most recently started, kept after Stop. Android shows a
  /// resumable media card for the app after Stop (audio_service always
  /// answers the system UI's "recent" browse query), and its Play button, a
  /// Bluetooth PLAY or a car must start this station again.
  Station? _lastStation;

  /// The catalogue stream of the current start, invalidated in the resolver
  /// when playback of it fails.
  StationStream? _currentStream;
  int _generation = 0;

  /// Whether the current generation's load has reported ready. ICY titles
  /// that arrive earlier are dropped: the native player's ICY state survives
  /// a load, so an early title can be the previous source's (Pitfall E).
  bool _readySeenForGeneration = false;

  /// The list the current station was started from.
  PlayContext playContext = const PlayContext.single();

  PlaybackStatus get status => _status;
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  Station? get currentStation => _station;
  Stream<Station?> get currentStationStream => _stationController.stream;

  NowPlaying? get nowPlaying => _nowPlaying;
  Stream<NowPlaying?> get nowPlayingStream => _nowPlayingController.stream;

  bool get _isActive => switch (_status) {
    Connecting() ||
    Playing() ||
    Buffering() ||
    Reconnecting() ||
    Interrupted() => true,
    Idle() || Paused() || PlaybackError() => false,
  };

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
    await _start(station);
  }

  @override
  Future<void> play() async {
    switch (_status) {
      case Paused() || PlaybackError():
        final station = _station;
        if (station != null) await _start(station);
      case Idle():
        // After Stop: the media card's Play (or a headset/Bluetooth PLAY)
        // starts the last station again, live.
        final station = _lastStation;
        if (station != null) await _start(station);
      case _:
        // Active states are already playing.
        break;
    }
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
    final station = _station;
    if (!_isActive || station == null) return;
    _nextGeneration();
    _setStatus(PlaybackStatus.paused(station: station));
    _setNowPlaying(null);
    await _player.stop();
    await _session.release();
  }

  @override
  Future<void> stop() async {
    _nextGeneration();
    await _player.stop();
    await _session.release();
    _setStation(null);
    _publishMediaItem(null);
    // processingState idle: audio_service stops the service and removes the
    // notification.
    _setStatus(const PlaybackStatus.idle());
    _setNowPlaying(null);
  }

  Future<void> _start(Station station) async {
    final generation = _nextGeneration();
    // A new start never shows the previous title, not even for the moment
    // the old transport takes to stop (STRM-05).
    _setNowPlaying(null);
    await _player.stop();
    if (generation != _generation) return;

    // Publish before loading, so the FGS starts from the user action. The
    // media item (station name, "Connecting…") goes out with the status.
    _lastStation = station;
    _setStation(station);
    _setStatus(
      PlaybackStatus.connecting(station: station, streamIndex: 0, round: 0),
    );

    // Playlists and extension-less HLS are resolved in Dart first; the
    // catalogue kind decides the source type, never the file extension.
    // Rotation across candidates and streams[] arrives with plan 01-09.
    final stream = station.streams.first;
    _currentStream = stream;
    final List<ResolvedStream> candidates;
    try {
      candidates = await _resolver.resolve(stream);
    } on StreamResolutionException catch (e) {
      _resolver.invalidate(stream);
      if (generation == _generation) {
        await _fail(station, _errorKindFor(e.reason), invalidate: false);
      }
      return;
    } catch (_) {
      _resolver.invalidate(stream);
      if (generation == _generation) {
        await _fail(
          station,
          PlaybackErrorKind.streamUnreachable,
          invalidate: false,
        );
      }
      return;
    }
    // A newer play(), pause() or stop() arrived while resolving.
    if (generation != _generation) return;

    try {
      await _player.load(candidates.first, generation: generation);
    } catch (_) {
      if (generation == _generation) {
        await _fail(station, PlaybackErrorKind.streamUnreachable);
      }
    }
  }

  static PlaybackErrorKind _errorKindFor(StreamResolutionFailure reason) =>
      switch (reason) {
        StreamResolutionFailure.unsupportedScheme ||
        StreamResolutionFailure.notAPlaylist ||
        StreamResolutionFailure.empty => PlaybackErrorKind.unsupportedFormat,
        StreamResolutionFailure.httpStatus ||
        StreamResolutionFailure.timeout ||
        StreamResolutionFailure.tooLarge ||
        StreamResolutionFailure.tooDeep ||
        StreamResolutionFailure.tooManyRedirects ||
        StreamResolutionFailure.network => PlaybackErrorKind.streamUnreachable,
      };

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (snapshot.generation != _generation) return;
    if (snapshot.state == PlayerProcessingState.ready) {
      _readySeenForGeneration = true;
    }
    final ready =
        snapshot.state == PlayerProcessingState.ready && snapshot.playing;
    switch (_status) {
      case Connecting(:final station, :final streamIndex) when ready:
        _setStatus(
          PlaybackStatus.playing(station: station, streamIndex: streamIndex),
        );
      case Buffering(:final station, :final streamIndex) when ready:
        _setStatus(
          PlaybackStatus.playing(station: station, streamIndex: streamIndex),
        );
      case Playing(:final station, :final streamIndex)
          when snapshot.state == PlayerProcessingState.buffering:
        _setStatus(
          PlaybackStatus.buffering(station: station, streamIndex: streamIndex),
        );
      case Playing(:final station) || Buffering(:final station)
          when snapshot.state == PlayerProcessingState.completed:
        // A live stream never ends: the server dropped us. Until reconnect
        // lands (plan 01-09), end in an error instead of holding the
        // foreground service with no audio.
        unawaited(_fail(station, PlaybackErrorKind.streamUnreachable));
      case _:
        break;
    }
  }

  /// ICY "now playing" (RESEARCH Pattern 5). Only parseIcyTitle's output
  /// (repaired, sanitised, junk-filtered) ever reaches the media session;
  /// the raw title never does (T-08-01).
  ///
  /// Titles from a superseded load, or from the current load before its
  /// first ready snapshot, are dropped (T-08-03). A junk title (null, empty,
  /// '-', the station name, a URL) parses to null and clears the line.
  void _onIcyTitle(IcyTitle icy) {
    if (icy.generation != _generation || !_readySeenForGeneration) return;
    final station = _station;
    final stream = _currentStream;
    if (station == null || stream == null) return;
    _setNowPlaying(
      parseIcyTitle(icy.title, station: station, charset: stream.icyCharset),
    );
  }

  /// Publishes [value] when it differs from the last one (NowPlaying value
  /// equality). Each media-item update redraws the notification, so an
  /// unchanged title republishes nothing (Anti-Pattern 9, T-08-02).
  ///
  /// `_setNowPlaying(null)` is the clear: every start or switch, pause, stop
  /// and failure calls it.
  void _setNowPlaying(NowPlaying? value) {
    if (value == _nowPlaying) return;
    _nowPlaying = value;
    _nowPlayingController.add(value);
    final station = _status.stationOrNull;
    if (station != null) {
      _publishMediaItem(
        mediaItemFor(station, _status, _strings, nowPlaying: value),
      );
    }
  }

  void _onFailure(PlayerFailure failure) {
    if (failure.generation != _generation || !_isActive) return;
    final station = _station;
    if (station == null) return;
    unawaited(_fail(station, PlaybackErrorKind.streamUnreachable));
  }

  /// Ends the current start in [PlaybackError]. Unless [invalidate] is false
  /// (the caller already did it), the current stream's resolution is dropped:
  /// the resolved URL may be stale (a rotated CDN token, a moved playlist
  /// entry), so the next start fetches the playlist again.
  Future<void> _fail(
    Station station,
    PlaybackErrorKind kind, {
    bool invalidate = true,
  }) async {
    _nextGeneration();
    final stream = _currentStream;
    if (invalidate && stream != null) _resolver.invalidate(stream);
    _setStatus(PlaybackStatus.error(station: station, kind: kind));
    _setNowPlaying(null);
    await _player.stop();
    await _session.release();
  }

  /// Supersedes the current load: its events are dropped from now on, and
  /// the next load must report ready before its ICY titles are shown.
  int _nextGeneration() {
    _readySeenForGeneration = false;
    return ++_generation;
  }

  /// Publishes [status] to the media session and the app. The media item
  /// goes first, so the notification never shows a new state under an old
  /// subtitle.
  void _setStatus(PlaybackStatus status) {
    _status = status;
    final station = status.stationOrNull;
    if (station != null) {
      _publishMediaItem(
        mediaItemFor(station, status, _strings, nowPlaying: _nowPlaying),
      );
    }
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
}
