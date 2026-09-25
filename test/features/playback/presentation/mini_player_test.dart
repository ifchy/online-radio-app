import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/app/app.dart';
import 'package:radio/l10n/app_localizations.dart';

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
}
