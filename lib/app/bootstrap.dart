import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/network/user_agent.dart';
import '../features/catalog/application/catalog_providers.dart';
import '../features/catalog/data/station_directory.dart';
import '../features/playback/application/playback_providers.dart';
import '../features/playback/engine/audio_service_engine.dart';
import '../features/playback/engine/audio_session_port_impl.dart';
import '../features/playback/engine/just_audio_stream_player.dart';
import '../features/playback/engine/radio_audio_handler.dart';
import 'app.dart';

/// Composition root. The playback handler is built here, outside the widget
/// tree, because it must keep working with the screen off and the activity
/// gone. The UI and the handler share one [StationDirectory].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final directory = StationDirectory.phase1();

  final handler = await AudioService.init(
    builder: () => RadioAudioHandler(
      JustAudioStreamPlayer(userAgent: buildUserAgent(packageInfo.version)),
      AudioSessionPortImpl(),
      directory,
    ),
    config: const AudioServiceConfig(
      // Permanent once shipped: Android keeps the user's channel settings.
      androidNotificationChannelId: 'bg.izk.radio.playback',
      androidNotificationChannelName: 'Playback',
      // Swipeable while paused (D-13).
      androidNotificationOngoing: false,
      // No foreground service while paused (D-13, battery).
      androidStopForegroundOnPause: true,
      // A headset/Bluetooth PLAY after a pause resumes playback.
      androidResumeOnClick: true,
    ),
  );

  // audio_service swallows platform errors from setState/setMediaItem into
  // this stream. Surface them in logcat, or a native failure (for example a
  // stripped notification icon) silently leaves the app without a foreground
  // service or notification.
  AudioService.asyncError.listen(
    (Object error) => debugPrint('audio_service platform error: $error'),
  );

  final container = ProviderContainer(
    overrides: [
      audioEngineProvider.overrideWithValue(AudioServiceEngine(handler)),
      stationDirectoryProvider.overrideWithValue(directory),
    ],
    // Reconnect logic lives in the engine; Riverpod must never auto-retry.
    retry: (_, _) => null,
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const RadioApp()),
  );
}
