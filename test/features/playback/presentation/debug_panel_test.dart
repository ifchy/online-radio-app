import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/app/home_screen.dart';
import 'package:radio/core/settings/settings_repository.dart';
import 'package:radio/features/catalog/application/catalog_providers.dart';
import 'package:radio/features/catalog/data/station_directory.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/application/playback_providers.dart';
import 'package:radio/features/playback/domain/engine_diagnostics.dart';
import 'package:radio/features/playback/domain/play_context.dart';
import 'package:radio/features/playback/engine/ports.dart';
import 'package:radio/features/playback/presentation/debug_panel.dart';
import 'package:radio/l10n/app_localizations.dart';

import '../../../support/fakes.dart';

/// A three-stream station, so "stream i/n" and the switcher have something
/// to show. Never played: FakeEngine only records calls.
final Station _station = Station(
  id: StationId.curated('test-fm'),
  name: 'Тест FM',
  nameLatin: 'Test FM',
  streams: [
    StationStream(
      url: Uri.parse('https://a.example/live.mp3'),
      kind: StreamKind.progressive,
      codec: 'mp3',
      bitrateKbps: 128,
    ),
    StationStream(
      url: Uri.parse('https://b.example/live/index.m3u8'),
      kind: StreamKind.hls,
      codec: 'aac',
      bitrateKbps: 64,
    ),
    StationStream(
      url: Uri.parse('http://c.example/live.pls'),
      kind: StreamKind.pls,
    ),
  ],
);

/// The stored first-launch date (UTC).
final DateTime _firstLaunch = DateTime.utc(2026, 9, 20, 8, 15, 30);

/// A mid-outage snapshot: stream 1 of 3, retry 2 waiting 2 s, three events.
final EngineDiagnostics _diagnostics = EngineDiagnostics(
  state: 'Reconnecting(attempt 2)',
  stationId: _station.id,
  streamIndex: 1,
  candidateIndex: 0,
  url: Uri.parse('https://b.example/live/index.m3u8'),
  kind: PlayableKind.hls,
  round: 1,
  reconnectAttempt: 2,
  nextRetryDelay: const Duration(seconds: 2),
  lastTimeToAudio: const Duration(milliseconds: 2480),
  recentEvents: [
    DiagnosticEvent(
      DateTime(2026, 9, 25, 10, 0, 1, 5),
      'UserPlay(curated:test-fm, from stream 0) -> Connecting(stream 0, round 0)',
    ),
    DiagnosticEvent(
      DateTime(2026, 9, 25, 10, 0, 3, 480),
      'PlayerReady -> Playing(stream 1)',
    ),
    DiagnosticEvent(
      DateTime(2026, 9, 25, 10, 5, 12, 42),
      'PlayerFailed -> Reconnecting(attempt 2)',
    ),
  ],
);

FakeEngine _engine({bool withStation = true}) {
  final engine = FakeEngine()..setDiagnostics(_diagnostics);
  if (withStation) engine.setStation(_station);
  return engine;
}

/// Pumps [home] under a ProviderScope with the engine, the one-station list
/// and the first-launch date overridden.
Future<void> _pump(WidgetTester tester, FakeEngine engine, Widget home) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        stationDirectoryProvider.overrideWithValue(
          StationDirectory([_station]),
        ),
        firstLaunchAtProvider.overrideWithValue(_firstLaunch),
      ],
      child: MaterialApp(
        locale: const Locale('bg'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  // The provider streams deliver their first value asynchronously.
  await tester.pump();
  await tester.pump();
}

const _panelHost = Scaffold(body: DebugPanel());

/// The event-log lines, top to bottom.
List<String> _eventLines(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(DebugPanel.eventLogKey),
      matching: find.byType(Text),
    ),
  ))
    text.data!,
];

void main() {
  group('diagnostics (D-07)', () {
    testWidgets('renders every engine field and the first-launch date', (
      tester,
    ) async {
      await _pump(tester, _engine(), _panelHost);

      expect(find.text('State: Reconnecting(attempt 2)'), findsOneWidget);
      expect(find.text('Station: curated:test-fm'), findsOneWidget);
      expect(find.text('Stream: 1/3 (candidate 0)'), findsOneWidget);
      expect(
        find.text('URL: https://b.example/live/index.m3u8'),
        findsOneWidget,
      );
      expect(find.text('Kind: hls'), findsOneWidget);
      expect(find.text('Round: 1'), findsOneWidget);
      expect(find.text('Reconnect attempt: 2'), findsOneWidget);
      expect(find.text('Next retry in: 2000 ms'), findsOneWidget);
      expect(find.text('Time-to-audio: 2480 ms'), findsOneWidget);
      expect(
        find.text('First launch: 2026-09-20T08:15:30.000Z'),
        findsOneWidget,
      );
    });

    testWidgets('lists the recent events newest first with HH:mm:ss.SSS', (
      tester,
    ) async {
      await _pump(tester, _engine(), _panelHost);

      expect(_eventLines(tester), [
        '10:05:12.042 PlayerFailed -> Reconnecting(attempt 2)',
        '10:00:03.480 PlayerReady -> Playing(stream 1)',
        '10:00:01.005 UserPlay(curated:test-fm, from stream 0) -> '
            'Connecting(stream 0, round 0)',
      ]);
    });

    testWidgets('shows all 50 ring-buffer events', (tester) async {
      final engine = FakeEngine()
        ..setDiagnostics(
          EngineDiagnostics(
            state: 'Playing(stream 0)',
            recentEvents: [
              for (var i = 0; i < EngineDiagnostics.maxRecentEvents; i++)
                DiagnosticEvent(DateTime(2026, 9, 25, 11, 0, i), 'event $i'),
            ],
          ),
        );
      await _pump(tester, engine, _panelHost);

      final lines = _eventLines(tester);
      expect(lines, hasLength(50));
      expect(lines.first, '11:00:49.000 event 49');
      expect(lines.last, '11:00:00.000 event 0');
    });

    testWidgets('fields with nothing to show read as a dash', (tester) async {
      await _pump(tester, FakeEngine(), _panelHost);

      expect(find.text('State: Idle'), findsOneWidget);
      expect(find.text('Station: —'), findsOneWidget);
      expect(find.text('Stream: —/— (candidate —)'), findsOneWidget);
      expect(find.text('URL: —'), findsOneWidget);
      expect(find.text('Kind: —'), findsOneWidget);
      expect(find.text('Reconnect attempt: 0'), findsOneWidget);
      expect(find.text('Next retry in: —'), findsOneWidget);
      expect(find.text('Time-to-audio: —'), findsOneWidget);
      expect(_eventLines(tester), isEmpty);
    });

    testWidgets('follows the engine as it publishes new diagnostics', (
      tester,
    ) async {
      final engine = _engine();
      await _pump(tester, engine, _panelHost);

      engine.setDiagnostics(
        const EngineDiagnostics(
          state: 'Playing(stream 1)',
          lastTimeToAudio: Duration(milliseconds: 900),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('State: Playing(stream 1)'), findsOneWidget);
      expect(find.text('Time-to-audio: 900 ms'), findsOneWidget);
    });
  });

  group('the debug action on the home screen (T-11-01)', () {
    testWidgets('showDebugTools false: no debug action and no panel', (
      tester,
    ) async {
      await _pump(tester, _engine(), const HomeScreen(showDebugTools: false));

      expect(find.byTooltip('Debug'), findsNothing);
      expect(find.byIcon(Icons.bug_report), findsNothing);
      expect(find.byType(DebugPanel), findsNothing);
    });

    testWidgets('showDebugTools true: the action opens the panel in a sheet', (
      tester,
    ) async {
      await _pump(tester, _engine(), const HomeScreen(showDebugTools: true));

      expect(find.byType(DebugPanel), findsNothing);
      expect(find.byTooltip('Debug'), findsOneWidget);
      await tester.tap(find.byTooltip('Debug'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(DebugPanel), findsOneWidget);
      expect(find.text('State: Reconnecting(attempt 2)'), findsOneWidget);
    });

    testWidgets('the default follows the build mode (on in tests)', (
      tester,
    ) async {
      expect(const HomeScreen().showDebugTools, isTrue);
    });
  });

  group('the stream switcher (SC1)', () {
    testWidgets(
      'lists every stream of the current station with a Play button',
      (tester) async {
        await _pump(tester, _engine(), _panelHost);

        expect(find.text('#0 progressive · mp3 · 128 kbps'), findsOneWidget);
        expect(find.text('#1 hls · aac · 64 kbps'), findsOneWidget);
        expect(find.text('#2 pls · — · —'), findsOneWidget);
        for (final stream in _station.streams) {
          expect(find.text(stream.url.toString()), findsOneWidget);
        }
        for (var i = 0; i < _station.streams.length; i++) {
          expect(find.widgetWithText(TextButton, 'Play #$i'), findsOneWidget);
          expect(find.byTooltip('Play stream $i'), findsOneWidget);
        }
        expect(find.text('No station'), findsNothing);
      },
    );

    testWidgets('"Play #2" starts streams[2] exactly once', (tester) async {
      final engine = _engine();
      await _pump(tester, engine, _panelHost);

      final button = find.widgetWithText(TextButton, 'Play #2');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(engine.playCalls, hasLength(1));
      final call = engine.playCalls.single;
      expect(call.station, _station);
      expect(call.startStreamIndex, 2);
      expect(call.context, isA<SinglePlayContext>());
    });

    testWidgets('with no current station it shows "No station"', (
      tester,
    ) async {
      final engine = _engine(withStation: false);
      await _pump(tester, engine, _panelHost);

      expect(find.text('No station'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(engine.playCalls, isEmpty);
    });

    testWidgets('meets the tap-target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _engine(), _panelHost);

      expect(find.byType(TextButton), findsNWidgets(3));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
