import 'package:audio_session/audio_session.dart';

import 'ports.dart';

/// Releases audio focus through audio_session. just_audio requests focus on
/// play but never abandons it, so the engine must (Pitfall F).
class AudioSessionPortImpl implements AudioSessionPort {
  @override
  Future<void> release() async {
    final session = await AudioSession.instance;
    await session.setActive(false);
  }
}
