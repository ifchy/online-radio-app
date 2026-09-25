import 'dart:ui' show PlatformDispatcher;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/media_http_client.dart';
import '../core/network/user_agent.dart';
import '../core/settings/settings_repository.dart';
import '../features/catalog/application/catalog_providers.dart';
import '../features/catalog/data/station_directory.dart';
import '../features/playback/application/playback_providers.dart';
import '../features/playback/domain/engine_strings.dart';
import '../features/playback/engine/audio_service_engine.dart';
import '../features/playback/engine/audio_session_port_impl.dart';
import '../features/playback/engine/connectivity_port_impl.dart';
import '../features/playback/engine/just_audio_stream_player.dart';
import '../features/playback/engine/radio_audio_handler.dart';
import '../features/playback/engine/resolver/stream_resolver.dart';
import '../features/playback/engine/state_machine.dart';
import '../features/playback/engine/wifi_lock_channel.dart';
import '../l10n/app_localizations.dart';
import 'app.dart';

/// Composition root. The playback handler is built here, outside the widget
/// tree, because it must keep working with the screen off and the activity
/// gone. The UI and the handler share one [StationDirectory].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();

  // APP-06: written once, on the very first run, before anything else can
  // fail. Order: prefs -> first launch -> session -> AudioService.init ->
  // container.
  final prefs = SharedPreferencesAsync();
  final settings = SettingsRepository(prefs, const Clock());
  final firstLaunchAt = await settings.ensureFirstLaunchAt();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final directory = StationDirectory.phase1();
  final userAgent = buildUserAgent(packageInfo.version);

  // The only Dart client allowed to fetch http:// (media playlists, STRM-04).
  // App-owned traffic goes through AppHttpClient, which is HTTPS-only.
  final mediaClient = MediaHttpClient(http.Client(), userAgent);
  final resolver = HttpStreamResolver(mediaClient, const Clock());

  // Notification text in the device language (D-08, D-09). Built without a
  // BuildContext: the handler outlives the activity.
  final strings = EngineStrings.fromLocalizations(
    lookupAppLocalizations(
      resolveAppLocale(PlatformDispatcher.instance.locale),
    ),
  );

  final handler = await AudioService.init(
    builder: () => RadioAudioHandler(
      JustAudioStreamPlayer(userAgent: userAgent),
      AudioSessionPortImpl(),
      directory,
      resolver,
      strings,
      // Network changes trigger an immediate reconnect instead of waiting
      // for ExoPlayer's I/O timeouts (PLAY-07).
      ConnectivityPortImpl(
        Connectivity(),
        debounce: const EngineTimings().connectivityDebounce,
      ),
      // Keeps Wi-Fi awake with the screen off, only while audio is live or
      // recovering (PLAT-03, PLAT-06).
      WifiLockChannel(),
    ),
    config: AudioServiceConfig(
      // Permanent once shipped: Android keeps the user's channel settings.
      androidNotificationChannelId: 'bg.izk.radio.playback',
      // "Възпроизвеждане" / "Playback". Android names the channel when it is
      // first created, from the device language at that moment.
      androidNotificationChannelName: strings.notificationChannelName,
      // Monochrome status-bar icon; kept in release by res/raw/keep.xml.
      androidNotificationIcon: 'drawable/ic_stat_radio',
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
      firstLaunchAtProvider.overrideWithValue(firstLaunchAt),
    ],
    // Reconnect logic lives in the engine; Riverpod must never auto-retry.
    retry: (_, _) => null,
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const RadioApp()),
  );
}
