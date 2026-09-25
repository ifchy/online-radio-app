import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/app/app.dart';
import 'package:radio/app/home_screen.dart';
import 'package:radio/features/catalog/application/catalog_providers.dart';
import 'package:radio/features/catalog/data/station_directory.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/application/playback_providers.dart';
import 'package:radio/features/playback/domain/play_context.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/presentation/mini_player.dart';
import 'package:radio/l10n/app_localizations.dart';

import '../../../support/fakes.dart';

/// Every ARB key of the phase, read from a looked-up [AppLocalizations].
Map<String, String> _allStrings(AppLocalizations l) => {
  'appTitle': l.appTitle,
  'stationListTitle': l.stationListTitle,
  'actionPlay': l.actionPlay,
  'actionPause': l.actionPause,
  'actionStop': l.actionStop,
  'playStationHint': l.playStationHint('БГ Радио'),
  'stateConnecting': l.stateConnecting,
  'stateBuffering': l.stateBuffering,
  'stateReconnecting': l.stateReconnecting,
  'stateInterrupted': l.stateInterrupted,
  'statePaused': l.statePaused,
  'stateError': l.stateError,
  'notificationChannelName': l.notificationChannelName,
  'miniPlayerRegionLabel': l.miniPlayerRegionLabel('БГ Радио'),
};

const _bg = Locale('bg');
const _en = Locale('en');

final Station _station = StationDirectory.phase1().all.first;

/// The mini-player where the home screen puts it.
const _miniPlayerHost = Scaffold(
  body: SizedBox.expand(),
  bottomNavigationBar: MiniPlayer(),
);

/// Pumps [home] with the real delegates, a fixed [locale] and text scale, and
/// the engine and station list overridden.
Future<void> _pumpMiniPlayer(
  WidgetTester tester,
  FakeEngine engine, {
  Locale locale = _bg,
  double textScale = 1.0,
  Widget home = _miniPlayerHost,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        stationDirectoryProvider.overrideWithValue(StationDirectory.phase1()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  // The provider streams deliver their first value asynchronously.
  await tester.pump();
}

/// Lets an engine change reach the widgets: the provider receives the event,
/// then the next frame rebuilds.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// The texts the mini-player shows, in order.
List<String?> _miniPlayerTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: find.byType(MiniPlayer), matching: find.byType(Text)),
  ))
    text.data,
];

/// Every status variant with its expected label in bg and en; null is no
/// label.
final List<(PlaybackStatus, String?, String?)> _variants = [
  (const PlaybackStatus.idle(), null, null),
  (
    PlaybackStatus.connecting(station: _station, streamIndex: 0, round: 0),
    'Свързване…',
    'Connecting…',
  ),
  (PlaybackStatus.playing(station: _station, streamIndex: 0), null, null),
  (
    PlaybackStatus.buffering(station: _station, streamIndex: 0),
    'Буфериране…',
    'Buffering…',
  ),
  (
    PlaybackStatus.reconnecting(station: _station, attempt: 1),
    'Повторно свързване…',
    'Reconnecting…',
  ),
  (PlaybackStatus.interrupted(station: _station), 'Прекъснато', 'Interrupted'),
  (PlaybackStatus.paused(station: _station), 'На пауза', 'Paused'),
  (
    PlaybackStatus.error(
      station: _station,
      kind: PlaybackErrorKind.streamUnreachable,
    ),
    'Грешка',
    'Error',
  ),
];

/// A status with the station set, as the engine publishes it.
FakeEngine _engineWith(PlaybackStatus status) =>
    FakeEngine(status: status)..setStation(_station);

void main() {
  group('localisation', () {
    test('a Bulgarian device resolves to Bulgarian', () {
      expect(resolveAppLocale(const Locale('bg')), const Locale('bg'));
      expect(resolveAppLocale(const Locale('bg', 'BG')), const Locale('bg'));
    });

    test('any other device language, or none, resolves to English', () {
      expect(resolveAppLocale(const Locale('en', 'US')), const Locale('en'));
      expect(resolveAppLocale(const Locale('de')), const Locale('en'));
      expect(resolveAppLocale(null), const Locale('en'));
    });

    test('every phase string exists in Bulgarian', () {
      expect(_allStrings(lookupAppLocalizations(const Locale('bg'))), {
        'appTitle': 'eRadioto',
        'stationListTitle': 'Станции',
        'actionPlay': 'Пусни',
        'actionPause': 'Пауза',
        'actionStop': 'Спри',
        'playStationHint': 'Пусни БГ Радио',
        'stateConnecting': 'Свързване…',
        'stateBuffering': 'Буфериране…',
        'stateReconnecting': 'Повторно свързване…',
        'stateInterrupted': 'Прекъснато',
        'statePaused': 'На пауза',
        'stateError': 'Грешка',
        'notificationChannelName': 'Възпроизвеждане',
        'miniPlayerRegionLabel': 'Сега звучи: БГ Радио',
      });
    });

    test('every phase string exists in English', () {
      expect(_allStrings(lookupAppLocalizations(const Locale('en'))), {
        'appTitle': 'eRadioto',
        'stationListTitle': 'Stations',
        'actionPlay': 'Play',
        'actionPause': 'Pause',
        'actionStop': 'Stop',
        'playStationHint': 'Play БГ Радио',
        'stateConnecting': 'Connecting…',
        'stateBuffering': 'Buffering…',
        'stateReconnecting': 'Reconnecting…',
        'stateInterrupted': 'Interrupted',
        'statePaused': 'Paused',
        'stateError': 'Error',
        'notificationChannelName': 'Playback',
        'miniPlayerRegionLabel': 'Now playing: БГ Радио',
      });
    });
  });

  group('home screen', () {
    for (final (locale, title, hint) in [
      (_bg, 'Станции', 'Пусни БГ Радио'),
      (_en, 'Stations', 'Play БГ Радио'),
    ]) {
      testWidgets('in $locale the title is "$title" and tiles hint "$hint"', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final engine = FakeEngine();
        await _pumpMiniPlayer(
          tester,
          engine,
          locale: locale,
          home: const HomeScreen(),
        );

        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text(title)),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(find.byType(ListTile)),
          isSemantics(hint: hint, isButton: true),
        );
        semantics.dispose();
      });
    }

    testWidgets('tapping a tile plays that station from the home list', (
      tester,
    ) async {
      final engine = FakeEngine();
      await _pumpMiniPlayer(tester, engine, home: const HomeScreen());

      await tester.tap(find.text(_station.name));
      await tester.pump();

      expect(engine.playCalls, hasLength(1));
      expect(engine.playCalls.single.station, _station);
      final context = engine.playCalls.single.context;
      expect(context, isA<ListPlayContext>());
      expect((context as ListPlayContext).ids, [_station.id]);
    });

    testWidgets('the mini-player sits at the bottom of the home screen', (
      tester,
    ) async {
      final engine = _engineWith(
        PlaybackStatus.playing(station: _station, streamIndex: 0),
      );
      await _pumpMiniPlayer(tester, engine, home: const HomeScreen());

      final screen = tester.getRect(find.byType(Scaffold));
      final player = tester.getRect(find.byType(MiniPlayer));
      expect(player.bottom, screen.bottom);
      expect(find.byTooltip('Пауза'), findsOneWidget);
    });
  });

  group('mini-player state label', () {
    for (final (status, bgLabel, enLabel) in _variants) {
      for (final (locale, label) in [(_bg, bgLabel), (_en, enLabel)]) {
        testWidgets(
          '${status.runtimeType} in $locale shows ${label ?? 'no label'}',
          (tester) async {
            await _pumpMiniPlayer(tester, _engineWith(status), locale: locale);

            expect(_miniPlayerTexts(tester), [_station.name, ?label]);
          },
        );
      }
    }

    testWidgets('the label is a live region, so TalkBack announces changes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final engine = _engineWith(
        PlaybackStatus.playing(station: _station, streamIndex: 0),
      );
      await _pumpMiniPlayer(tester, engine);

      engine.setStatus(
        PlaybackStatus.buffering(station: _station, streamIndex: 0),
      );
      await _settle(tester);

      expect(
        tester.getSemantics(find.text('Буфериране…')),
        isSemantics(label: 'Буфериране…', isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('the player region is labelled with the station', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpMiniPlayer(
        tester,
        _engineWith(PlaybackStatus.playing(station: _station, streamIndex: 0)),
      );

      expect(find.bySemanticsLabel('Сега звучи: БГ Радио'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('mini-player controls', () {
    testWidgets('with no current station it builds nothing', (tester) async {
      await _pumpMiniPlayer(tester, FakeEngine());

      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(tester.getSize(find.byType(MiniPlayer)).height, 0);
      expect(find.byType(IconButton), findsNothing);
      expect(_miniPlayerTexts(tester), isEmpty);
    });

    testWidgets('while playing, Pause calls togglePause exactly once', (
      tester,
    ) async {
      final engine = _engineWith(
        PlaybackStatus.playing(station: _station, streamIndex: 0),
      );
      await _pumpMiniPlayer(tester, engine);

      expect(find.byTooltip('Пусни'), findsNothing);
      await tester.tap(find.byTooltip('Пауза'));
      await tester.pump();

      expect(engine.togglePauseCalls, 1);
      expect(engine.stopCalls, 0);
    });

    for (final status in [
      PlaybackStatus.connecting(station: _station, streamIndex: 0, round: 0),
      PlaybackStatus.buffering(station: _station, streamIndex: 0),
      PlaybackStatus.reconnecting(station: _station, attempt: 1),
      PlaybackStatus.interrupted(station: _station),
    ]) {
      testWidgets('${status.runtimeType} offers Pause, as the engine would '
          'pause', (tester) async {
        await _pumpMiniPlayer(tester, _engineWith(status));

        expect(find.byTooltip('Пауза'), findsOneWidget);
        expect(find.byTooltip('Пусни'), findsNothing);
      });
    }

    for (final status in [
      PlaybackStatus.paused(station: _station),
      PlaybackStatus.error(
        station: _station,
        kind: PlaybackErrorKind.streamUnreachable,
      ),
    ]) {
      testWidgets(
        '${status.runtimeType}: Play calls togglePause exactly once',
        (tester) async {
          final engine = _engineWith(status);
          await _pumpMiniPlayer(tester, engine);

          expect(find.byTooltip('Пауза'), findsNothing);
          await tester.tap(find.byTooltip('Пусни'));
          await tester.pump();

          expect(engine.togglePauseCalls, 1);
          expect(engine.stopCalls, 0);
        },
      );
    }

    testWidgets('Stop calls stop exactly once; then the player disappears', (
      tester,
    ) async {
      final engine = _engineWith(
        PlaybackStatus.playing(station: _station, streamIndex: 0),
      );
      await _pumpMiniPlayer(tester, engine);

      await tester.tap(find.byTooltip('Спри'));
      await tester.pump();
      expect(engine.stopCalls, 1);
      expect(engine.togglePauseCalls, 0);

      // The engine's reaction to stop().
      engine
        ..setStatus(const PlaybackStatus.idle())
        ..setStation(null);
      await _settle(tester);

      expect(find.byType(IconButton), findsNothing);
      expect(_miniPlayerTexts(tester), isEmpty);
    });

    testWidgets('there is no seek bar and no position or duration', (
      tester,
    ) async {
      await _pumpMiniPlayer(
        tester,
        _engineWith(PlaybackStatus.playing(station: _station, streamIndex: 0)),
      );

      final inPlayer = find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byWidgetPredicate(
          (w) => w is Slider || w is RangeSlider || w is ProgressIndicator,
        ),
      );
      expect(inPlayer, findsNothing);
      for (final text in _miniPlayerTexts(tester)) {
        expect(text, isNot(matches(RegExp(r'\d+:\d{2}'))));
      }
    });
  });

  group('mini-player accessibility', () {
    for (final status in [
      PlaybackStatus.playing(station: _station, streamIndex: 0),
      PlaybackStatus.reconnecting(station: _station, attempt: 1),
      PlaybackStatus.paused(station: _station),
    ]) {
      testWidgets('${status.runtimeType} meets the tap-target, label and '
          'contrast guidelines', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpMiniPlayer(tester, _engineWith(status));

        expect(find.byType(IconButton), findsNWidgets(2));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });
    }

    testWidgets('a long name at 2x text scale on a phone does not overflow', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1080, 1920)
        ..devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final longName = _station.copyWith(
        name: 'Радио с изключително дълго име за проверка на многоточието',
      );
      final engine = FakeEngine(
        status: PlaybackStatus.reconnecting(station: longName, attempt: 3),
      )..setStation(longName);

      await _pumpMiniPlayer(
        tester,
        engine,
        textScale: 2.0,
        home: const HomeScreen(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Повторно свързване…'), findsOneWidget);
      // Both controls stay on screen and tappable.
      await tester.tap(find.byTooltip('Пауза'));
      await tester.tap(find.byTooltip('Спри'));
      await tester.pump();
      expect(engine.togglePauseCalls, 1);
      expect(engine.stopCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
