// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The playback engine. Overridden in `bootstrap` (and in tests).

@ProviderFor(audioEngine)
final audioEngineProvider = AudioEngineProvider._();

/// The playback engine. Overridden in `bootstrap` (and in tests).

final class AudioEngineProvider
    extends $FunctionalProvider<AudioEngine, AudioEngine, AudioEngine>
    with $Provider<AudioEngine> {
  /// The playback engine. Overridden in `bootstrap` (and in tests).
  AudioEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioEngineHash();

  @$internal
  @override
  $ProviderElement<AudioEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AudioEngine create(Ref ref) {
    return audioEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioEngine>(value),
    );
  }
}

String _$audioEngineHash() => r'64de476ceedd707836b2512f9bf9fb8403ec0117';

/// Read-only mirror of the engine status.

@ProviderFor(playbackStatus)
final playbackStatusProvider = PlaybackStatusProvider._();

/// Read-only mirror of the engine status.

final class PlaybackStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlaybackStatus>,
          PlaybackStatus,
          Stream<PlaybackStatus>
        >
    with $FutureModifier<PlaybackStatus>, $StreamProvider<PlaybackStatus> {
  /// Read-only mirror of the engine status.
  PlaybackStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackStatusHash();

  @$internal
  @override
  $StreamProviderElement<PlaybackStatus> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<PlaybackStatus> create(Ref ref) {
    return playbackStatus(ref);
  }
}

String _$playbackStatusHash() => r'e8a5154634c950e127103e8b8608981d137f7a23';

/// Read-only mirror of the engine's current station.

@ProviderFor(currentStation)
final currentStationProvider = CurrentStationProvider._();

/// Read-only mirror of the engine's current station.

final class CurrentStationProvider
    extends
        $FunctionalProvider<AsyncValue<Station?>, Station?, Stream<Station?>>
    with $FutureModifier<Station?>, $StreamProvider<Station?> {
  /// Read-only mirror of the engine's current station.
  CurrentStationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentStationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentStationHash();

  @$internal
  @override
  $StreamProviderElement<Station?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Station?> create(Ref ref) {
    return currentStation(ref);
  }
}

String _$currentStationHash() => r'0d91073337cbce0a9609dc61ea627f8ab2b1ef0b';

/// Read-only mirror of the engine's now-playing value (ICY), or null.

@ProviderFor(nowPlaying)
final nowPlayingProvider = NowPlayingProvider._();

/// Read-only mirror of the engine's now-playing value (ICY), or null.

final class NowPlayingProvider
    extends
        $FunctionalProvider<
          AsyncValue<NowPlaying?>,
          NowPlaying?,
          Stream<NowPlaying?>
        >
    with $FutureModifier<NowPlaying?>, $StreamProvider<NowPlaying?> {
  /// Read-only mirror of the engine's now-playing value (ICY), or null.
  NowPlayingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nowPlayingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nowPlayingHash();

  @$internal
  @override
  $StreamProviderElement<NowPlaying?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<NowPlaying?> create(Ref ref) {
    return nowPlaying(ref);
  }
}

String _$nowPlayingHash() => r'1ab13cedff5671a9a15ce8923c62feabfe029751';

/// Read-only mirror of the engine's diagnostics, for the debug panel (D-07).
/// In memory only: nothing reads this provider to store or send it.

@ProviderFor(diagnostics)
final diagnosticsProvider = DiagnosticsProvider._();

/// Read-only mirror of the engine's diagnostics, for the debug panel (D-07).
/// In memory only: nothing reads this provider to store or send it.

final class DiagnosticsProvider
    extends
        $FunctionalProvider<
          AsyncValue<EngineDiagnostics>,
          EngineDiagnostics,
          Stream<EngineDiagnostics>
        >
    with
        $FutureModifier<EngineDiagnostics>,
        $StreamProvider<EngineDiagnostics> {
  /// Read-only mirror of the engine's diagnostics, for the debug panel (D-07).
  /// In memory only: nothing reads this provider to store or send it.
  DiagnosticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diagnosticsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diagnosticsHash();

  @$internal
  @override
  $StreamProviderElement<EngineDiagnostics> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<EngineDiagnostics> create(Ref ref) {
    return diagnostics(ref);
  }
}

String _$diagnosticsHash() => r'b42783c866970f0bb82dae75992dc9bf74187587';
