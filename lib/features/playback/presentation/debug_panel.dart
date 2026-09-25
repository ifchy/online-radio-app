import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug-only diagnostics view (D-07). Scaffolding.
class DebugPanel extends ConsumerWidget {
  const DebugPanel({super.key});

  /// The event log, for tests.
  static const eventLogKey = Key('debug-panel-event-log');

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
