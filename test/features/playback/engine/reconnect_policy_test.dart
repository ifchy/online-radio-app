// The reconnect backoff and the retry budget (D-10): pure values, no timers.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/playback/domain/retry_budget.dart';
import 'package:radio/features/playback/engine/reconnect_policy.dart';

final _t0 = DateTime.utc(2026, 9, 25, 12);

DateTime _at(Duration d) => _t0.add(d);

const _min = Duration(minutes: 1);

void main() {
  group('ReconnectPolicy', () {
    const baseSeconds = [0, 1, 2, 4, 8, 15, 30, 30, 30];

    test('without jitter the delays for attempts 0..8 are '
        '0, 1, 2, 4, 8, 15, 30, 30, 30 s', () {
      final policy = ReconnectPolicy(Random(1), jitter: 0);
      expect(
        [for (var a = 0; a < baseSeconds.length; a++) policy.delayFor(a)],
        [for (final s in baseSeconds) Duration(seconds: s)],
      );
    });

    test('every jittered delay stays within ±20 % of its base, and attempt 0 '
        'is 0 s', () {
      for (var seed = 0; seed < 50; seed++) {
        final policy = ReconnectPolicy(Random(seed));
        for (var a = 0; a < baseSeconds.length; a++) {
          final base = baseSeconds[a] * 1000;
          final ms = policy.delayFor(a).inMilliseconds;
          expect(
            ms,
            inInclusiveRange((base * 0.8).floor(), (base * 1.2).ceil()),
            reason: 'seed $seed, attempt $a',
          );
        }
        expect(policy.delayFor(0), Duration.zero);
      }
    });

    test('the jitter actually varies the delay (not always the base)', () {
      final policy = ReconnectPolicy(Random(7));
      final delays = {for (var i = 0; i < 20; i++) policy.delayFor(6)};
      expect(delays.length, greaterThan(1));
    });

    test('the delay is capped at 30 s (±20 %) for any later attempt', () {
      final policy = ReconnectPolicy(Random(3));
      for (final a in [7, 10, 100, 1 << 20]) {
        expect(
          policy.delayFor(a).inMilliseconds,
          inInclusiveRange(24000, 36000),
        );
      }
    });

    test('a negative attempt is treated as attempt 0', () {
      expect(ReconnectPolicy(Random(1)).delayFor(-3), Duration.zero);
    });

    test('the same seed gives the same sequence', () {
      final a = ReconnectPolicy(Random(42));
      final b = ReconnectPolicy(Random(42));
      for (var i = 0; i < 9; i++) {
        expect(a.delayFor(i), b.delayFor(i));
      }
    });
  });

  group('RetryBudgetPreset (D-10)', () {
    test('standard is 3 min online / 10 min offline', () {
      expect(
        RetryBudgetPreset.standard.onlineBudget,
        const Duration(minutes: 3),
      );
      expect(
        RetryBudgetPreset.standard.offlineBudget,
        const Duration(minutes: 10),
      );
    });

    test('trip is 5 min online / 10 min offline', () {
      expect(RetryBudgetPreset.trip.onlineBudget, const Duration(minutes: 5));
      expect(RetryBudgetPreset.trip.offlineBudget, const Duration(minutes: 10));
    });

    test('batterySaver is 1 min online / 5 min offline', () {
      expect(
        RetryBudgetPreset.batterySaver.onlineBudget,
        const Duration(minutes: 1),
      );
      expect(
        RetryBudgetPreset.batterySaver.offlineBudget,
        const Duration(minutes: 5),
      );
    });
  });

  group('RetryBudgetClock', () {
    RetryBudgetClock clock(RetryBudgetPreset preset) =>
        RetryBudgetClock(preset: preset);

    test('no outage is never exhausted', () {
      final c = clock(RetryBudgetPreset.batterySaver);
      expect(c.active, isFalse);
      expect(c.exhausted(_at(const Duration(hours: 5))), isNull);
    });

    for (final (preset, limit) in [
      (RetryBudgetPreset.standard, 3),
      (RetryBudgetPreset.batterySaver, 1),
      (RetryBudgetPreset.trip, 5),
    ]) {
      test('${preset.name}: failing online is exhausted after $limit min '
          '(online), not a moment before', () {
        final c = clock(preset).start(_t0, online: true);
        expect(c.active, isTrue);
        expect(
          c.exhausted(_at(_min * limit - const Duration(milliseconds: 1))),
          isNull,
        );
        expect(c.exhausted(_at(_min * limit)), BudgetExhaustion.online);
      });
    }

    test('standard: 10 min offline is exhausted (offline)', () {
      final c = clock(RetryBudgetPreset.standard).start(_t0, online: false);
      expect(c.exhausted(_at(_min * 9)), isNull);
      expect(c.exhausted(_at(_min * 10)), BudgetExhaustion.offline);
    });

    test('offline time counts only against the offline budget: 5 min offline '
        'plus 2 min online failing is not yet exhausted', () {
      var c = clock(RetryBudgetPreset.standard).start(_t0, online: false);
      c = c.onConnectivity(_at(_min * 5), online: true);
      expect(c.exhausted(_at(_min * 7)), isNull);
      expect(c.onlineFailingAt(_at(_min * 7)), _min * 2);
      expect(c.offlineAt(_at(_min * 7)), _min * 5);
      // The online budget runs out after 3 min of online failing.
      expect(c.exhausted(_at(_min * 8)), BudgetExhaustion.online);
    });

    test('online failing time never counts against the offline budget', () {
      var c = clock(RetryBudgetPreset.standard).start(_t0, online: true);
      c = c.onConnectivity(_at(_min * 2), online: false);
      expect(c.exhausted(_at(_min * 11)), isNull);
      expect(c.exhausted(_at(_min * 12)), BudgetExhaustion.offline);
    });

    test('remaining is the time left in the budget being spent', () {
      final c = clock(RetryBudgetPreset.standard).start(_t0, online: true);
      expect(c.remaining(_t0), _min * 3);
      expect(c.remaining(_at(_min)), _min * 2);
      expect(c.remaining(_at(_min * 5)), Duration.zero);
      final off = c.onConnectivity(_at(_min), online: false);
      expect(off.remaining(_at(_min * 2)), _min * 9);
    });

    test('start during a running outage keeps its start', () {
      final c = clock(RetryBudgetPreset.standard).start(_t0, online: true);
      final again = c.start(_at(_min * 2), online: true);
      expect(again.outageStartedAt, _t0);
      expect(again.exhausted(_at(_min * 3)), BudgetExhaustion.online);
    });

    test('recovered stops the clock; a later start resumes it without '
        'losing the time already spent', () {
      var c = clock(RetryBudgetPreset.standard).start(_t0, online: true);
      c = c.recovered(_at(_min * 2));
      expect(c.active, isTrue);
      expect(c.running, isFalse);
      // Playing time does not count.
      expect(c.exhausted(_at(_min * 30)), isNull);
      c = c.start(_at(_min * 10), online: true);
      expect(c.running, isTrue);
      expect(c.outageStartedAt, _t0);
      expect(c.exhausted(_at(_min * 10 + const Duration(seconds: 59))), isNull);
      expect(c.exhausted(_at(_min * 11)), BudgetExhaustion.online);
    });

    test('reset clears both counters and ends the outage', () {
      var c = clock(RetryBudgetPreset.standard).start(_t0, online: false);
      c = c.onConnectivity(_at(_min * 5), online: true);
      c = c.reset();
      expect(c.active, isFalse);
      expect(c.outageStartedAt, isNull);
      expect(c.onlineFailing, Duration.zero);
      expect(c.offline, Duration.zero);
      expect(c.preset, RetryBudgetPreset.standard);
      expect(c.exhausted(_at(_min * 60)), isNull);
      // A new outage gets the full budget again.
      final again = c.start(_at(_min * 60), online: true);
      expect(again.exhausted(_at(_min * 62)), isNull);
      expect(again.exhausted(_at(_min * 63)), BudgetExhaustion.online);
    });

    test(
      'withPreset changes the limits without resetting the elapsed time',
      () {
        final c = clock(RetryBudgetPreset.standard).start(_t0, online: true);
        final saver = c.withPreset(RetryBudgetPreset.batterySaver);
        expect(saver.preset, RetryBudgetPreset.batterySaver);
        expect(saver.outageStartedAt, _t0);
        expect(saver.exhausted(_at(const Duration(seconds: 59))), isNull);
        expect(saver.exhausted(_at(_min)), BudgetExhaustion.online);
        final trip = saver.withPreset(RetryBudgetPreset.trip);
        expect(trip.exhausted(_at(_min * 4)), isNull);
        expect(trip.exhausted(_at(_min * 5)), BudgetExhaustion.online);
      },
    );

    test('onConnectivity outside an outage only records the network', () {
      final c = clock(RetryBudgetPreset.standard)
          .onConnectivity(_t0, online: false);
      expect(c.active, isFalse);
      expect(c.online, isFalse);
      expect(c.exhausted(_at(_min * 60)), isNull);
    });
  });
}
