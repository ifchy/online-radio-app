// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'eRadioto';

  @override
  String get stationListTitle => 'Stations';

  @override
  String get actionPlay => 'Play';

  @override
  String get actionPause => 'Pause';

  @override
  String get actionStop => 'Stop';

  @override
  String playStationHint(String station) {
    return 'Play $station';
  }

  @override
  String get stateConnecting => 'Connecting…';

  @override
  String get stateBuffering => 'Buffering…';

  @override
  String get stateReconnecting => 'Reconnecting…';

  @override
  String get stateInterrupted => 'Interrupted';

  @override
  String get statePaused => 'Paused';

  @override
  String get stateError => 'Error';

  @override
  String get notificationChannelName => 'Playback';

  @override
  String miniPlayerRegionLabel(String station) {
    return 'Now playing: $station';
  }
}
