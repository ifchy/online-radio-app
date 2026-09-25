// RED stub; the fields are used once the behaviour lands.
// ignore_for_file: unused_field

import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small app settings in shared preferences (DataStore on Android), through
/// the async API, never the legacy singleton.
class SettingsRepository {
  SettingsRepository(this._prefs, this._clock);

  final SharedPreferencesAsync _prefs;
  final Clock _clock;

  /// Records the first-launch date on the very first run and returns it.
  Future<DateTime> ensureFirstLaunchAt() async => DateTime.utc(0);

  /// The recorded first-launch date, or null before the first run.
  Future<DateTime?> firstLaunchAt() async => null;
}
