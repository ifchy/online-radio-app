// APP-06: the first-launch date is written once, on the very first run, and
// later launches never overwrite it.
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _key = 'first_launch_at';

void main() {
  final firstRun = DateTime.utc(2026, 9, 25, 16, 30, 5);
  final laterRun = DateTime.utc(2026, 10, 3, 8, 0);

  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  test('the first call stores the clock time as UTC ISO-8601 under '
      'first_launch_at and returns it', () async {
    final repo = SettingsRepository(prefs, Clock.fixed(firstRun));
    final recorded = await repo.ensureFirstLaunchAt();
    expect(recorded, firstRun);
    expect(recorded.isUtc, isTrue);
    expect(await prefs.getString(_key), '2026-09-25T16:30:05.000Z');
  });

  test('a later launch returns the original date and leaves the stored '
      'string unchanged', () async {
    await SettingsRepository(
      prefs,
      Clock.fixed(firstRun),
    ).ensureFirstLaunchAt();
    final stored = await prefs.getString(_key);

    final later = SettingsRepository(prefs, Clock.fixed(laterRun));
    expect(await later.ensureFirstLaunchAt(), firstRun);
    expect(await prefs.getString(_key), stored);
  });

  test('a local-time clock is stored in UTC', () async {
    final local = DateTime(2026, 9, 25, 19, 30, 5);
    final repo = SettingsRepository(prefs, Clock.fixed(local));
    final recorded = await repo.ensureFirstLaunchAt();
    expect(recorded.isUtc, isTrue);
    expect(recorded, local.toUtc());
    expect(await prefs.getString(_key), local.toUtc().toIso8601String());
  });

  test('an unreadable stored value never breaks startup: it reads as null '
      'and the next launch records a valid date', () async {
    await prefs.setString(_key, 'not a date');
    final repo = SettingsRepository(prefs, Clock.fixed(firstRun));
    expect(await repo.firstLaunchAt(), isNull);
    expect(await repo.ensureFirstLaunchAt(), firstRun);
    expect(await prefs.getString(_key), '2026-09-25T16:30:05.000Z');
  });

  test(
    'firstLaunchAtProvider must be overridden, and returns the override',
    () {
      final unset = ProviderContainer();
      addTearDown(unset.dispose);
      expect(() => unset.read(firstLaunchAtProvider), throwsA(anything));

      final container = ProviderContainer(
        overrides: [firstLaunchAtProvider.overrideWithValue(firstRun)],
      );
      addTearDown(container.dispose);
      expect(container.read(firstLaunchAtProvider), firstRun);
    },
  );

  test('firstLaunchAt is null before the first run and the stored date '
      'after it', () async {
    final repo = SettingsRepository(prefs, Clock.fixed(firstRun));
    expect(await repo.firstLaunchAt(), isNull);
    await repo.ensureFirstLaunchAt();
    expect(await repo.firstLaunchAt(), firstRun);
    expect(
      await SettingsRepository(prefs, Clock.fixed(laterRun)).firstLaunchAt(),
      firstRun,
    );
  });
}
