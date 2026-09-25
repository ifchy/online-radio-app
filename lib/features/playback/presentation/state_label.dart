import '../../../l10n/app_localizations.dart';
import '../domain/playback_status.dart';

/// The short text state label shown whenever playback is not simply playing
/// (D-09), or null when there is nothing to say.
///
/// The switch is exhaustive over the sealed [PlaybackStatus], so a new
/// variant is a compile error here instead of a silently blank label.
String? stateLabelFor(PlaybackStatus status, AppLocalizations l) =>
    switch (status) {
      Idle() || Playing() => null,
      Connecting() => l.stateConnecting,
      Buffering() => l.stateBuffering,
      Reconnecting() => l.stateReconnecting,
      Interrupted() => l.stateInterrupted,
      Paused() => l.statePaused,
      PlaybackError() => l.stateError,
    };
