// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'eRadioto';

  @override
  String get stationListTitle => 'Станции';

  @override
  String get actionPlay => 'Пусни';

  @override
  String get actionPause => 'Пауза';

  @override
  String get actionStop => 'Спри';

  @override
  String playStationHint(String station) {
    return 'Пусни $station';
  }

  @override
  String get stateConnecting => 'Свързване…';

  @override
  String get stateBuffering => 'Буфериране…';

  @override
  String get stateReconnecting => 'Повторно свързване…';

  @override
  String get stateInterrupted => 'Прекъснато';

  @override
  String get statePaused => 'На пауза';

  @override
  String get stateError => 'Грешка';

  @override
  String get notificationChannelName => 'Възпроизвеждане';

  @override
  String miniPlayerRegionLabel(String station) {
    return 'Сега звучи: $station';
  }
}
