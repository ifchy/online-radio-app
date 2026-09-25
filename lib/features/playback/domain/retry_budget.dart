/// How long the engine keeps trying to reconnect after a drop before it
/// gives up (D-10): one engine-level setting with named presets, so a future
/// "trip mode" / "battery saver" toggle needs no engine change.
///
/// Two separate budgets run during an outage (RESEARCH "RetryBudget
/// presets"): time spent failing while the phone is online counts only
/// against [onlineBudget], and time spent offline only against
/// [offlineBudget]. Both reset after 30 s of stable playback.
///
/// Phase 1 wires only [standard]; the user-facing toggle is deferred
/// (CONTEXT Deferred Ideas).
enum RetryBudgetPreset {
  /// The default (locked by D-10): 3 min failing online, 10 min offline.
  standard(onlineBudget: Duration(minutes: 3), offlineBudget: _tenMinutes),

  /// Longer drives with dead zones: 5 min failing online, 10 min offline.
  ///
  /// The offline value follows Android 17 guidance: keep the foreground
  /// service through transient failures of under 10 minutes (RESEARCH A6).
  /// It is the one constant the owner can raise towards ~30 min.
  trip(onlineBudget: Duration(minutes: 5), offlineBudget: _tenMinutes),

  /// Gives up sooner: 1 min failing online, 5 min offline.
  batterySaver(
    onlineBudget: Duration(minutes: 1),
    offlineBudget: Duration(minutes: 5),
  );

  const RetryBudgetPreset({
    required this.onlineBudget,
    required this.offlineBudget,
  });

  /// How long reconnecting may fail while the network is up.
  final Duration onlineBudget;

  /// How long the engine waits for the network to come back.
  final Duration offlineBudget;
}

const _tenMinutes = Duration(minutes: 10);
