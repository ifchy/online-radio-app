// The audio_session -> FocusChange mapping (RESEARCH Pattern 1 table).
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/playback/engine/audio_session_port_impl.dart';
import 'package:radio/features/playback/engine/ports.dart';

void main() {
  final cases = <(bool, AudioInterruptionType, FocusChange?)>[
    (true, AudioInterruptionType.pause, FocusChange.transientLoss),
    (true, AudioInterruptionType.unknown, FocusChange.permanentLoss),
    (true, AudioInterruptionType.duck, FocusChange.duckBegin),
    (false, AudioInterruptionType.pause, FocusChange.gainAfterPause),
    (false, AudioInterruptionType.duck, FocusChange.duckEnd),
    // "won't ever receive an AUDIOFOCUS_GAIN": never a resume.
    (false, AudioInterruptionType.unknown, null),
  ];

  for (final (begin, type, expected) in cases) {
    test('${begin ? 'begin' : 'end'} + ${type.name} -> '
        '${expected?.name ?? 'ignored'}', () {
      expect(focusChangeFor(AudioInterruptionEvent(begin, type)), expected);
    });
  }

  test('every FocusChange is produced by some event', () {
    expect(
      {for (final (_, _, change) in cases) ?change},
      FocusChange.values.toSet(),
    );
  });
}
