/// Reconnect timing (ARCHITECTURE Pattern 4, RESEARCH "RetryBudget
/// presets"): the backoff between attempts and the budget clock that decides
/// when an outage is given up.
///
/// Pure: no Flutter, plugin, timer or I/O imports. The state machine stores
/// a [RetryBudgetClock] in its state and asks the [ReconnectPolicy] for each
/// delay.
library;

import 'dart:math';

import '../domain/retry_budget.dart';

/// Exponential backoff with jitter: 0, 1, 2, 4, 8, 15, 30 s, then 30 s for
/// every later attempt, each varied by up to ±[jitter] of its base so many
/// phones do not hammer a recovering server in step.
class ReconnectPolicy {
  /// [random] is the only non-determinism of the state machine; tests pass
  /// a seeded one (or [jitter] 0).
  ReconnectPolicy(this._random, {this.jitter = 0.2})
    : assert(jitter >= 0 && jitter < 1, 'jitter must be in [0, 1)');

  final Random _random;

  /// The largest relative deviation from the base delay (0.2 = ±20 %).
  final double jitter;

  /// The base delays in seconds; the last one is the cap.
  static const steps = [0, 1, 2, 4, 8, 15, 30];

  /// The delay before retry number [attempt] (0-based). Attempt 0 is always
  /// immediate.
  Duration delayFor(int attempt) {
    final base = steps[attempt.clamp(0, steps.length - 1)];
    if (base == 0) return Duration.zero;
    final factor = 1 + jitter * (_random.nextDouble() * 2 - 1);
    return Duration(milliseconds: (base * 1000 * factor).round());
  }
}

/// Which budget an outage ran out of.
enum BudgetExhaustion {
  /// Failing while the network was up: the station is unreachable.
  online,

  /// The network stayed down.
  offline,
}

/// The retry budget of one outage, as an immutable value the state machine
/// keeps in its state (so the reducer stays pure).
///
/// - The clock starts at the first failure of an outage ([start]).
/// - Time failing while online counts only against the online budget, and
///   time offline only against the offline budget ([onConnectivity]).
/// - While playback is back but not yet stable the clock is stopped
///   ([recovered]); a new drop resumes it with the time already spent.
/// - 30 s of stable playback ends the outage ([reset]).
///
/// The state machine feeds every connectivity change in through
/// [onConnectivity]; until the first one the network counts as online.
final class RetryBudgetClock {
  const RetryBudgetClock({
    this.preset = RetryBudgetPreset.standard,
    this.outageStartedAt,
    this.onlineFailing = Duration.zero,
    this.offline = Duration.zero,
    this.online = true,
    this.lastMark,
  });

  /// The limits in force.
  final RetryBudgetPreset preset;

  /// When the current outage began; null when there is none.
  final DateTime? outageStartedAt;

  /// Online failing time counted up to [lastMark].
  final Duration onlineFailing;

  /// Offline time counted up to [lastMark].
  final Duration offline;

  /// Whether the network is up (as last reported).
  final bool online;

  /// Since when the running bucket is counting; null while the clock is
  /// stopped (no outage, or playback is back).
  final DateTime? lastMark;

  /// Whether an outage is open (it may be stopped by [recovered]).
  bool get active => outageStartedAt != null;

  /// Whether the clock is counting failing time now.
  bool get running => lastMark != null;

  Duration _sinceMark(DateTime now) {
    final mark = lastMark;
    if (mark == null || now.isBefore(mark)) return Duration.zero;
    return now.difference(mark);
  }

  /// Online failing time at [now].
  Duration onlineFailingAt(DateTime now) =>
      online ? onlineFailing + _sinceMark(now) : onlineFailing;

  /// Offline time at [now].
  Duration offlineAt(DateTime now) =>
      online ? offline : offline + _sinceMark(now);

  /// Counts the running bucket up to [now] and moves the mark there.
  RetryBudgetClock _accrue(DateTime now, {required bool running}) =>
      RetryBudgetClock(
        preset: preset,
        outageStartedAt: outageStartedAt,
        onlineFailing: onlineFailingAt(now),
        offline: offlineAt(now),
        online: online,
        lastMark: running ? now : null,
      );

  /// Playback failed at [now]: opens an outage, or resumes a stopped one
  /// with the time already spent. A running clock is left as it is.
  RetryBudgetClock start(DateTime now, {bool online = true}) {
    if (running) return this;
    return RetryBudgetClock(
      preset: preset,
      outageStartedAt: outageStartedAt ?? now,
      onlineFailing: onlineFailing,
      offline: offline,
      online: online,
      lastMark: now,
    );
  }

  /// Playback is back at [now]: stops counting, keeps the outage open until
  /// playback has been stable long enough to [reset].
  RetryBudgetClock recovered(DateTime now) =>
      running ? _accrue(now, running: false) : this;

  /// The network went up or down at [now]. Outside an outage only the flag
  /// changes.
  RetryBudgetClock onConnectivity(DateTime now, {required bool online}) {
    final counted = running ? _accrue(now, running: true) : this;
    return RetryBudgetClock(
      preset: counted.preset,
      outageStartedAt: counted.outageStartedAt,
      onlineFailing: counted.onlineFailing,
      offline: counted.offline,
      online: online,
      lastMark: counted.lastMark,
    );
  }

  /// Which budget is used up at [now], or null while both last.
  BudgetExhaustion? exhausted(DateTime now) {
    if (!active) return null;
    if (offlineAt(now) >= preset.offlineBudget) return BudgetExhaustion.offline;
    if (onlineFailingAt(now) >= preset.onlineBudget) {
      return BudgetExhaustion.online;
    }
    return null;
  }

  /// The time left at [now] in the budget being spent (online or offline),
  /// never negative.
  Duration remaining(DateTime now) {
    final left = online
        ? preset.onlineBudget - onlineFailingAt(now)
        : preset.offlineBudget - offlineAt(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Ends the outage: both counters cleared, the clock stopped. The preset
  /// and the network flag are kept.
  RetryBudgetClock reset() => RetryBudgetClock(preset: preset, online: online);

  /// The same clock under [preset]'s limits; the elapsed time is kept.
  RetryBudgetClock withPreset(RetryBudgetPreset preset) => RetryBudgetClock(
    preset: preset,
    outageStartedAt: outageStartedAt,
    onlineFailing: onlineFailing,
    offline: offline,
    online: online,
    lastMark: lastMark,
  );

  @override
  bool operator ==(Object other) =>
      other is RetryBudgetClock &&
      other.preset == preset &&
      other.outageStartedAt == outageStartedAt &&
      other.onlineFailing == onlineFailing &&
      other.offline == offline &&
      other.online == online &&
      other.lastMark == lastMark;

  @override
  int get hashCode => Object.hash(
    preset,
    outageStartedAt,
    onlineFailing,
    offline,
    online,
    lastMark,
  );

  @override
  String toString() =>
      'RetryBudgetClock(${preset.name}, '
      '${active ? 'outage since $outageStartedAt' : 'no outage'}, '
      'online failing $onlineFailing, offline $offline'
      '${running ? ', running' : ''})';
}
