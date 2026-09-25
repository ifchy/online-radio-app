import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_repository.g.dart';

/// Small app settings in shared preferences (DataStore on Android), through
/// the async API, never the legacy singleton.
class SettingsRepository {
  SettingsRepository(this._prefs, this._clock);

  static const _firstLaunchAtKey = 'first_launch_at';

  final SharedPreferencesAsync _prefs;
  final Clock _clock;

  /// Records the first-launch date on the very first run and returns it
  /// (APP-06). Later calls return the stored date and never overwrite it.
  ///
  /// Stored as UTC ISO-8601, so a time-zone change or a clock adjustment
  /// after the first run cannot move it.
  Future<DateTime> ensureFirstLaunchAt() async {
    final existing = await firstLaunchAt();
    if (existing != null) return existing;
    final now = _clock.now().toUtc();
    await _prefs.setString(_firstLaunchAtKey, now.toIso8601String());
    return now;
  }

  /// The recorded first-launch date, or null before the first run.
  ///
  /// An unreadable value also reads as null, so bootstrap (which awaits
  /// [ensureFirstLaunchAt]) can never fail on it at every launch; the next
  /// [ensureFirstLaunchAt] replaces it.
  Future<DateTime?> firstLaunchAt() async {
    final stored = await _prefs.getString(_firstLaunchAtKey);
    return stored == null ? null : DateTime.tryParse(stored)?.toUtc();
  }
}

/// The first-launch date, recorded in bootstrap before the app starts.
/// Overridden there (and in tests); the debug panel shows it (plan 01-11).
@Riverpod(keepAlive: true)
DateTime firstLaunchAt(Ref ref) => throw UnimplementedError(
  'firstLaunchAtProvider must be overridden in bootstrap',
);
