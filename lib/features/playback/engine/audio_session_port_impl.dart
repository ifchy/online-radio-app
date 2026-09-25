import 'package:audio_session/audio_session.dart';

import 'ports.dart';

/// The engine's audio session through audio_session.
///
/// - [release] abandons focus: just_audio requests focus on play but never
///   abandons it, so the engine must (Pitfall F).
/// - [focusChanges] and [becomingNoisy] come from
///   `AudioSession.instance.interruptionEventStream` and
///   `becomingNoisyEventStream`. just_audio is built with
///   `handleInterruptions: false`, so the engine is their single owner
///   (ARCHITECTURE Anti-Pattern 3).
///
/// On API 26+ the system ducks music by itself without telling the app, so
/// duck events mostly arrive on API 24/25; handling them with a volume
/// change therefore never ducks twice.
class AudioSessionPortImpl implements AudioSessionPort {
  AudioSessionPortImpl();

  static Future<AudioSession> get _session => AudioSession.instance;

  @override
  Future<void> release() async {
    final session = await _session;
    await session.setActive(false);
  }

  @override
  Stream<FocusChange> get focusChanges async* {
    final session = await _session;
    await for (final event in session.interruptionEventStream) {
      final change = focusChangeFor(event);
      if (change != null) yield change;
    }
  }

  @override
  Stream<void> get becomingNoisy async* {
    final session = await _session;
    yield* session.becomingNoisyEventStream;
  }
}

/// Maps an audio_session interruption event to the engine's [FocusChange]
/// (RESEARCH Pattern 1 mapping table, audio_session 0.2.4 core.dart:254-281).
///
/// | Android focus change          | event                | FocusChange    |
/// |-------------------------------|----------------------|----------------|
/// | LOSS_TRANSIENT (a phone call) | begin, pause         | transientLoss  |
/// | LOSS (another media app)      | begin, unknown       | permanentLoss  |
/// | LOSS_TRANSIENT_CAN_DUCK       | begin, duck          | duckBegin      |
/// | GAIN after a pause-type loss  | end, pause           | gainAfterPause |
/// | GAIN after a duck             | end, duck            | duckEnd        |
///
/// An end of an `unknown` interruption is ignored: after AUDIOFOCUS_LOSS
/// Android says the app "won't ever receive an AUDIOFOCUS_GAIN", and the
/// engine never resumes after a permanent loss.
FocusChange? focusChangeFor(AudioInterruptionEvent event) =>
    switch ((event.begin, event.type)) {
      (true, AudioInterruptionType.pause) => FocusChange.transientLoss,
      (true, AudioInterruptionType.unknown) => FocusChange.permanentLoss,
      (true, AudioInterruptionType.duck) => FocusChange.duckBegin,
      (false, AudioInterruptionType.pause) => FocusChange.gainAfterPause,
      (false, AudioInterruptionType.duck) => FocusChange.duckEnd,
      (false, AudioInterruptionType.unknown) => null,
    };
