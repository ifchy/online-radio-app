import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../catalog/data/station_directory.dart';
import '../../catalog/domain/station.dart';
import '../domain/media_id.dart';
import '../domain/play_context.dart';
import '../domain/playback_status.dart';
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
///
/// Reconnect, fallback rotation and interruptions arrive in later plans.
class RadioAudioHandler extends BaseAudioHandler {
  RadioAudioHandler(this._player, this._session, this._directory) {
    _subscriptions.addAll([
      _player.snapshots.listen(_onSnapshot),
      _player.failures.listen(_onFailure),
    ]);
  }

  final StreamPlayer _player;
  final AudioSessionPort _session;
  final StationDirectory _directory;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  final _statusController = StreamController<PlaybackStatus>.broadcast();
  final _stationController = StreamController<Station?>.broadcast();

  PlaybackStatus _status = const PlaybackStatus.idle();
  Station? _station;
  int _generation = 0;

  /// The list the current station was started from.
  PlayContext playContext = const PlayContext.single();

  PlaybackStatus get status => _status;
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  Station? get currentStation => _station;
  Stream<Station?> get currentStationStream => _stationController.stream;

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
    final station = _station;
    if (station == null) return;
    switch (_status) {
      case Paused() || PlaybackError():
        await _start(station);
      case _:
        // Idle has nothing to resume; active states are already playing.
        break;
    }
  }

  @override
  Future<void> pause() async {
    final station = _station;
    if (!_isActive || station == null) return;
    _generation++;
    _setStatus(PlaybackStatus.paused(station: station));
    await _player.stop();
    await _session.release();
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _player.stop();
    await _session.release();
    _setStation(null);
    mediaItem.add(null);
    // processingState idle: audio_service stops the service and removes the
    // notification.
    _setStatus(const PlaybackStatus.idle());
  }

  Future<void> _start(Station station) async {
    final generation = ++_generation;
    await _player.stop();
    if (generation != _generation) return;

    // Publish before loading, so the FGS starts from the user action.
    _setStation(station);
    mediaItem.add(mediaItemFor(station));
    _setStatus(
      PlaybackStatus.connecting(station: station, streamIndex: 0, round: 0),
    );

    final resolved = _resolvedFor(station.streams.first);
    if (resolved == null) {
      // .pls / .m3u / unknown need the resolver (plan 01-04).
      await _fail(station, PlaybackErrorKind.unsupportedFormat);
      return;
    }
    try {
      await _player.load(resolved, generation: generation);
    } catch (_) {
      if (generation == _generation) {
        await _fail(station, PlaybackErrorKind.streamUnreachable);
      }
    }
  }

  static ResolvedStream? _resolvedFor(StationStream stream) =>
      switch (stream.kind) {
        StreamKind.progressive => ResolvedStream(
          stream.url,
          PlayableKind.progressive,
        ),
        StreamKind.hls => ResolvedStream(stream.url, PlayableKind.hls),
        StreamKind.pls || StreamKind.m3u || StreamKind.unknown => null,
      };

  void _onSnapshot(PlayerSnapshot snapshot) {
    if (snapshot.generation != _generation) return;
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

  void _onFailure(PlayerFailure failure) {
    if (failure.generation != _generation || !_isActive) return;
    final station = _station;
    if (station == null) return;
    unawaited(_fail(station, PlaybackErrorKind.streamUnreachable));
  }

  Future<void> _fail(Station station, PlaybackErrorKind kind) async {
    _generation++;
    _setStatus(PlaybackStatus.error(station: station, kind: kind));
    await _player.stop();
    await _session.release();
  }

  void _setStatus(PlaybackStatus status) {
    _status = status;
    playbackState.add(playbackStateFor(status));
    _statusController.add(status);
  }

  void _setStation(Station? station) {
    if (_station == station) return;
    _station = station;
    _stationController.add(station);
  }
}
