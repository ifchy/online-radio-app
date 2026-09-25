/// RED scaffolding for 01-10 Task 1.
library;

import 'dart:math';

import '../domain/retry_budget.dart';

class ReconnectPolicy {
  ReconnectPolicy(this._random, {this.jitter = 0.2});

  // ignore: unused_field
  final Random _random;
  final double jitter;

  Duration delayFor(int attempt) => Duration.zero;
}

enum BudgetExhaustion { online, offline }

final class RetryBudgetClock {
  const RetryBudgetClock({
    this.preset = RetryBudgetPreset.standard,
    this.outageStartedAt,
    this.onlineFailing = Duration.zero,
    this.offline = Duration.zero,
    this.online = true,
    this.lastMark,
  });

  final RetryBudgetPreset preset;
  final DateTime? outageStartedAt;
  final Duration onlineFailing;
  final Duration offline;
  final bool online;
  final DateTime? lastMark;

  bool get active => false;
  bool get running => false;
  Duration onlineFailingAt(DateTime now) => Duration.zero;
  Duration offlineAt(DateTime now) => Duration.zero;
  RetryBudgetClock start(DateTime now, {bool online = true}) => this;
  RetryBudgetClock recovered(DateTime now) => this;
  RetryBudgetClock onConnectivity(DateTime now, {required bool online}) => this;
  BudgetExhaustion? exhausted(DateTime now) => null;
  Duration remaining(DateTime now) => Duration.zero;
  RetryBudgetClock reset() => this;
  RetryBudgetClock withPreset(RetryBudgetPreset preset) => this;
}
