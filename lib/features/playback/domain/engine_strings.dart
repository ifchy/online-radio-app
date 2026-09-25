import '../../../l10n/app_localizations.dart';

/// The user-facing text the playback engine needs below the UI: the media
/// notification and lock-screen subtitle (D-09) and the notification channel
/// name.
///
/// The handler keeps working with the activity gone, so it has no
/// `BuildContext` (ARCHITECTURE Anti-Pattern 8). Bootstrap builds this from
/// `lookupAppLocalizations(resolveAppLocale(...))`.
class EngineStrings {
  const EngineStrings({
    required this.connecting,
    required this.buffering,
    required this.reconnecting,
    required this.interrupted,
    required this.paused,
    required this.error,
    required this.notificationChannelName,
  });

  /// The strings of [l], the gen-l10n localisations for one locale.
  factory EngineStrings.fromLocalizations(AppLocalizations l) => EngineStrings(
    connecting: l.stateConnecting,
    buffering: l.stateBuffering,
    reconnecting: l.stateReconnecting,
    interrupted: l.stateInterrupted,
    paused: l.statePaused,
    error: l.stateError,
    notificationChannelName: l.notificationChannelName,
  );

  final String connecting;
  final String buffering;
  final String reconnecting;
  final String interrupted;
  final String paused;
  final String error;

  /// The Android notification channel name. Android fixes it when the
  /// channel is created at `AudioService.init`.
  final String notificationChannelName;
}
