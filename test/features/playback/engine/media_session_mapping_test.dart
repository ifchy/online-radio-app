// The FGS table (01-RESEARCH Pattern 2) row by row, and the notification /
// lock-screen subtitle for every state (D-09).
//
// audio_service holds the foreground service and wake lock exactly while
// `playing` is true, and stops the service when processingState is idle. So
// Paused, PlaybackError and Idle must report playing false (T-07-01).
import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/engine_strings.dart';
import 'package:radio/features/playback/domain/media_id.dart';
import 'package:radio/features/playback/domain/now_playing.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/engine/media_session_mapping.dart';
import 'package:radio/l10n/app_localizations.dart';

final _station = Station(
  id: StationId.curated('bg-radio'),
  name: 'БГ Радио',
  nameLatin: 'BG Radio',
  streams: [
    StationStream(
      url: Uri.parse('http://play.example/bgradio128'),
      kind: StreamKind.progressive,
    ),
  ],
);

List<MediaAction> _actions(PlaybackState state) => [
  for (final c in state.controls) c.action,
];

/// One FGS-table row: what audio_service must see for a status.
typedef _Row = ({
  PlaybackStatus status,
  AudioProcessingState processingState,
  bool playing,
  List<MediaAction> controls,
});

void main() {
  final rows = <String, _Row>{
    'Idle': (
      status: const PlaybackStatus.idle(),
      processingState: AudioProcessingState.idle,
      playing: false,
      controls: const [],
    ),
    'Connecting': (
      status: PlaybackStatus.connecting(
        station: _station,
        streamIndex: 0,
        round: 0,
      ),
      processingState: AudioProcessingState.loading,
      playing: true,
      controls: const [MediaAction.pause, MediaAction.stop],
    ),
    'Playing': (
      status: PlaybackStatus.playing(station: _station, streamIndex: 0),
      processingState: AudioProcessingState.ready,
      playing: true,
      controls: const [MediaAction.pause, MediaAction.stop],
    ),
    'Buffering': (
      status: PlaybackStatus.buffering(station: _station, streamIndex: 0),
      processingState: AudioProcessingState.buffering,
      playing: true,
      controls: const [MediaAction.pause, MediaAction.stop],
    ),
    'Reconnecting': (
      status: PlaybackStatus.reconnecting(station: _station, attempt: 1),
      processingState: AudioProcessingState.buffering,
      playing: true,
      controls: const [MediaAction.pause, MediaAction.stop],
    ),
    'Interrupted': (
      status: PlaybackStatus.interrupted(station: _station),
      processingState: AudioProcessingState.buffering,
      playing: true,
      controls: const [MediaAction.pause, MediaAction.stop],
    ),
    'Paused': (
      status: PlaybackStatus.paused(station: _station),
      processingState: AudioProcessingState.ready,
      playing: false,
      controls: const [MediaAction.play, MediaAction.stop],
    ),
    'PlaybackError': (
      status: PlaybackStatus.error(
        station: _station,
        kind: PlaybackErrorKind.streamUnreachable,
      ),
      processingState: AudioProcessingState.error,
      playing: false,
      controls: const [MediaAction.play, MediaAction.stop],
    ),
  };

  group('playbackStateFor (the FGS table)', () {
    test('has one row per PlaybackStatus variant', () {
      expect(
        rows.values.map((r) => r.status.runtimeType.toString()).toSet(),
        hasLength(8),
      );
    });

    for (final MapEntry(key: name, value: row) in rows.entries) {
      test('$name -> ${row.processingState.name}, playing ${row.playing}, '
          'controls ${row.controls.map((a) => a.name).join('+')}', () {
        final state = playbackStateFor(row.status);
        expect(state.processingState, row.processingState);
        expect(state.playing, row.playing);
        expect(_actions(state), row.controls);
        expect(
          state.androidCompactActionIndices,
          row.controls.isEmpty ? isNull : [0, 1],
        );
        expect(state.systemActions, isEmpty);
      });
    }

    test('Paused, PlaybackError and Idle hold no foreground service', () {
      for (final name in ['Paused', 'PlaybackError', 'Idle']) {
        expect(playbackStateFor(rows[name]!.status).playing, isFalse);
      }
    });

    test('PlaybackError carries the error kind as errorMessage', () {
      expect(
        playbackStateFor(rows['PlaybackError']!.status).errorMessage,
        PlaybackErrorKind.streamUnreachable.name,
      );
      expect(playbackStateFor(rows['Playing']!.status).errorMessage, isNull);
    });
  });

  group('mediaItemFor (notification and lock-screen text, D-09)', () {
    final bg = EngineStrings.fromLocalizations(
      lookupAppLocalizations(const Locale('bg')),
    );
    final en = EngineStrings.fromLocalizations(
      lookupAppLocalizations(const Locale('en')),
    );

    final subtitles = <String, String?>{
      'Connecting': 'Свързване…',
      'Buffering': 'Буфериране…',
      'Reconnecting': 'Повторно свързване…',
      'Interrupted': 'Прекъснато',
      'Paused': 'На пауза',
      'PlaybackError': 'Грешка',
      'Playing': null,
      'Idle': null,
    };

    for (final MapEntry(key: name, value: subtitle) in subtitles.entries) {
      test('$name: title is the station name, subtitle '
          '${subtitle == null ? 'none' : '"$subtitle"'}', () {
        final item = mediaItemFor(_station, rows[name]!.status, bg);
        expect(item.title, 'БГ Радио');
        expect(item.displaySubtitle, subtitle);
        expect(item.artist, subtitle);
        expect(item.id, StationMediaId(_station.id).format());
        expect(item.isLive, isTrue);
      });
    }

    test('uses the English strings on an English phone', () {
      final item = mediaItemFor(_station, rows['Paused']!.status, en);
      expect(item.title, 'БГ Радио');
      expect(item.displaySubtitle, 'Paused');
    });

    test('the localised notification channel name', () {
      expect(bg.notificationChannelName, 'Възпроизвеждане');
      expect(en.notificationChannelName, 'Playback');
    });
  });

  group('mediaItemFor with now playing (ICY, PLAY-02)', () {
    final bg = EngineStrings.fromLocalizations(
      lookupAppLocalizations(const Locale('bg')),
    );
    const song = NowPlaying(
      artist: 'Артист',
      title: 'Песен',
      text: 'Артист - Песен',
    );

    test('Playing: the title stays the station name, the ICY text is the '
        'subtitle and the artist is the artist', () {
      final item = mediaItemFor(
        _station,
        rows['Playing']!.status,
        bg,
        nowPlaying: song,
      );
      expect(item.title, 'БГ Радио');
      expect(item.displaySubtitle, 'Артист - Песен');
      expect(item.artist, 'Артист');
      expect(item.id, StationMediaId(_station.id).format());
      expect(item.isLive, isTrue);
    });

    test('Playing with a title-only value: the artist is the whole text', () {
      final item = mediaItemFor(
        _station,
        rows['Playing']!.status,
        bg,
        nowPlaying: const NowPlaying(title: 'Новини', text: 'Новини'),
      );
      expect(item.title, 'БГ Радио');
      expect(item.displaySubtitle, 'Новини');
      expect(item.artist, 'Новини');
    });

    test('Playing without a value: no subtitle and no artist', () {
      final item = mediaItemFor(_station, rows['Playing']!.status, bg);
      expect(item.title, 'БГ Радио');
      expect(item.displaySubtitle, isNull);
      expect(item.artist, isNull);
    });

    final stateTexts = <String, String?>{
      'Connecting': 'Свързване…',
      'Buffering': 'Буфериране…',
      'Reconnecting': 'Повторно свързване…',
      'Interrupted': 'Прекъснато',
      'Paused': 'На пауза',
      'PlaybackError': 'Грешка',
      'Idle': null,
    };
    for (final MapEntry(key: name, value: text) in stateTexts.entries) {
      test('$name keeps its state text and never shows the ICY text', () {
        final item = mediaItemFor(
          _station,
          rows[name]!.status,
          bg,
          nowPlaying: song,
        );
        expect(item.title, 'БГ Радио');
        expect(item.displaySubtitle, text);
        expect(item.artist, text);
      });
    }
  });
}
