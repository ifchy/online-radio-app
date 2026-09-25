/// RED scaffolding for 01-10 Task 1.
enum RetryBudgetPreset {
  standard,
  trip,
  batterySaver;

  Duration get onlineBudget => Duration.zero;
  Duration get offlineBudget => Duration.zero;
}
