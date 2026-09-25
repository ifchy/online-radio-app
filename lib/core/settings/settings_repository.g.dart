// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The first-launch date, recorded in bootstrap before the app starts.
/// Overridden there (and in tests); the debug panel shows it (plan 01-11).

@ProviderFor(firstLaunchAt)
final firstLaunchAtProvider = FirstLaunchAtProvider._();

/// The first-launch date, recorded in bootstrap before the app starts.
/// Overridden there (and in tests); the debug panel shows it (plan 01-11).

final class FirstLaunchAtProvider
    extends $FunctionalProvider<DateTime, DateTime, DateTime>
    with $Provider<DateTime> {
  /// The first-launch date, recorded in bootstrap before the app starts.
  /// Overridden there (and in tests); the debug panel shows it (plan 01-11).
  FirstLaunchAtProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstLaunchAtProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstLaunchAtHash();

  @$internal
  @override
  $ProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime create(Ref ref) {
    return firstLaunchAt(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$firstLaunchAtHash() => r'7ca549e12199cdae3cdf018290e342d3aaee2da0';
