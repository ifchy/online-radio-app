// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The known stations. Overridden in `bootstrap` so the UI and the playback
/// handler share one directory.

@ProviderFor(stationDirectory)
final stationDirectoryProvider = StationDirectoryProvider._();

/// The known stations. Overridden in `bootstrap` so the UI and the playback
/// handler share one directory.

final class StationDirectoryProvider
    extends
        $FunctionalProvider<
          StationDirectory,
          StationDirectory,
          StationDirectory
        >
    with $Provider<StationDirectory> {
  /// The known stations. Overridden in `bootstrap` so the UI and the playback
  /// handler share one directory.
  StationDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stationDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stationDirectoryHash();

  @$internal
  @override
  $ProviderElement<StationDirectory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StationDirectory create(Ref ref) {
    return stationDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StationDirectory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StationDirectory>(value),
    );
  }
}

String _$stationDirectoryHash() => r'c4c81aabfc2492c37d8d25129eabd4f4937ac052';
