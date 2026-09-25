// The pure PlaybackStateMachine: one test per behaviour row, asserting the
// next state and the exact command sequence (RESEARCH Pattern 2,
// ARCHITECTURE Pattern 3). No fakes, no timers: the reducer is a function.
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/play_context.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/domain/retry_budget.dart';
import 'package:radio/features/playback/engine/media_session_mapping.dart';
import 'package:radio/features/playback/engine/ports.dart';
import 'package:radio/features/playback/engine/reconnect_policy.dart';
import 'package:radio/features/playback/engine/state_machine.dart';

StationStream _stream(String url, [StreamKind kind = StreamKind.progressive]) =>
    StationStream(url: Uri.parse(url), kind: kind);

ResolvedStream _candidate(String url) =>
    ResolvedStream(Uri.parse(url), PlayableKind.progressive);

final _s0 = _stream('http://one.example/primary.mp3');
final _s1 = _stream('http://two.example/fallback.aac');
final _s2 = _stream('http://three.example/list.m3u', StreamKind.m3u);
final _only = _stream('https://only.example/njoy.mp3');

final _three = Station(
  id: StationId.debug('three'),
  name: 'Три потока',
  nameLatin: 'Tri potoka',
  streams: [_s0, _s1, _s2],
);
final _single = Station(
  id: StationId.debug('single'),
  name: 'Един поток',
  nameLatin: 'Edin potok',
  streams: [_only],
);

/// No jitter, so every backoff is its exact base delay.
final _machine = PlaybackStateMachine(
  policy: ReconnectPolicy(Random(0), jitter: 0),
);
const _timeout = Duration(seconds: 10);
final _t0 = DateTime.utc(2026, 9, 25, 12);

Transition _run(EngineState state, EngineEvent event, [DateTime? now]) =>
    _machine.transition(state, event, now ?? _t0);

/// [station] just started from Idle (generation 1, Connecting stream
/// [start]).
EngineState _started(Station station, {int start = 0}) => _run(
  const EngineState.initial(),
  UserPlay(station, startStreamIndex: start),
).next;

/// [state] after its current attempt fails (a player failure of the current
/// generation, after the stream resolved to one candidate).
EngineState _failCurrent(EngineState state) {
  var s = state;
  if (s.candidates.isEmpty) {
    s = _run(
      s,
      Resolved(s.generation, [_candidate('${s.currentStream!.url}#c0')]),
    ).next;
  }
  return _run(s, PlayerFailed(s.generation, 0)).next;
}

/// [state] with its current attempt reaching Playing.
EngineState _playing(EngineState state, [DateTime? at]) {
  var s = state;
  if (s.candidates.isEmpty) {
    s = _run(
      s,
      Resolved(s.generation, [_candidate('${s.currentStream!.url}#c0')]),
    ).next;
  }
  return _run(
    s,
    PlayerStateChanged(
      s.generation,
      PlayerProcessingState.ready,
      playing: true,
    ),
    at,
  ).next;
}

void main() {
  group('UserPlay starts a station', () {
    test('from Idle: Connecting(stream 0, round 0), then CancelAllTimers, '
        'StopTransport, ClearNowPlaying, StartTimer(connect, 10 s) and '
        'Resolve', () {
      final t = _run(const EngineState.initial(), UserPlay(_three));
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 0),
      );
      expect(t.next.station, _three);
      expect(t.next.generation, 1);
      expect(t.next.connectStartedAt, _t0);
      expect(t.commands, [
        const CancelAllTimers(),
        const StopTransport(),
        const ClearNowPlaying(),
        const StartTimer(TimerKind.connect, _timeout, 1),
        Resolve(_s0, 1),
      ]);
    });

    test('while another station plays: a fresh start with a new generation '
        'and a new session', () {
      final playing = _playing(_started(_single));
      expect(playing.everPlayed, isTrue);
      final t = _run(playing, UserPlay(_three));
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 0),
      );
      expect(t.next.generation, greaterThan(playing.generation));
      expect(t.next.everPlayed, isFalse);
      expect(t.next.lastWorkingStreamIndex, isNull);
      expect(t.next.candidates, isEmpty);
      expect(t.commands, [
        const CancelAllTimers(),
        const StopTransport(),
        const ClearNowPlaying(),
        StartTimer(TimerKind.connect, _timeout, t.next.generation),
        Resolve(_s0, t.next.generation),
      ]);
    });

    test('startStreamIndex starts at that stream', () {
      final t = _run(
        const EngineState.initial(),
        UserPlay(_three, startStreamIndex: 2),
      );
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 2, round: 0),
      );
      expect(t.commands.last, Resolve(_s2, 1));
    });

    for (final index in [-1, 3, 99]) {
      test('an out-of-range startStreamIndex ($index) starts at stream 0', () {
        final t = _run(
          const EngineState.initial(),
          UserPlay(_three, startStreamIndex: index),
        );
        expect(t.next.streamIndex, 0);
        expect(t.commands.last, Resolve(_s0, 1));
      });
    }

    test('keeps the list the station was started from', () {
      final context = PlayContext.list([_single.id, _three.id]);
      final t = _run(
        const EngineState.initial(),
        UserPlay(_three, context: context),
      );
      expect(t.next.context, same(context));
    });
  });

  group('Connecting rotates through candidates and streams (PLAY-08)', () {
    test('Resolved loads the first candidate in the same generation', () {
      final s = _started(_three);
      final c0 = _candidate('http://cdn.example/a');
      final t = _run(s, Resolved(1, [c0, _candidate('http://cdn.example/b')]));
      expect(t.next.generation, 1);
      expect(t.next.candidateIndex, 0);
      expect(t.next.status, s.status);
      expect(t.commands, [Load(c0, 1)]);
    });

    test('a failing candidate moves to the next candidate of the same '
        'stream, with a new generation and a fresh connect timer', () {
      final c1 = _candidate('http://cdn.example/b');
      final s = _run(
        _started(_three),
        Resolved(1, [_candidate('http://cdn.example/a'), c1]),
      ).next;
      final t = _run(s, const PlayerFailed(1, 0));
      expect(t.next.generation, 2);
      expect(t.next.candidateIndex, 1);
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 0),
      );
      expect(t.commands, [
        const StartTimer(TimerKind.connect, _timeout, 2),
        Load(c1, 2),
      ]);
    });

    test('dead primary: after its last candidate fails, the next stream is '
        'resolved in the same round', () {
      final s = _run(
        _started(_three),
        Resolved(1, [_candidate('http://cdn.example/a')]),
      ).next;
      final t = _run(s, const PlayerFailed(1, 0));
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 1, round: 0),
      );
      expect(t.next.generation, 2);
      expect(t.next.candidates, isEmpty);
      expect(t.commands, [
        const StopTransport(),
        InvalidateResolution(_s0),
        const StartTimer(TimerKind.connect, _timeout, 2),
        Resolve(_s1, 2),
      ]);
    });

    test('a resolve failure moves to the next stream', () {
      final t = _run(
        _started(_three),
        const ResolveFailed(1, StreamResolutionFailure.httpStatus),
      );
      expect(t.next.streamIndex, 1);
      expect(t.next.round, 0);
      expect(t.commands, [
        const StopTransport(),
        InvalidateResolution(_s0),
        const StartTimer(TimerKind.connect, _timeout, 2),
        Resolve(_s1, 2),
      ]);
    });

    test('slow primary: the connect timer moves to the next stream', () {
      final s = _run(
        _started(_three),
        Resolved(1, [_candidate('http://cdn.example/a')]),
      ).next;
      final t = _run(s, const TimerFired(TimerKind.connect, 1));
      expect(t.next.streamIndex, 1);
      expect(t.commands.last, Resolve(_s1, 2));
    });

    test('a load that completes at once counts as a failure', () {
      final s = _run(
        _started(_three),
        Resolved(1, [_candidate('http://cdn.example/a')]),
      ).next;
      final t = _run(
        s,
        const PlayerStateChanged(
          1,
          PlayerProcessingState.completed,
          playing: false,
        ),
      );
      expect(t.next.streamIndex, 1);
      expect(t.commands.last, Resolve(_s1, 2));
    });

    test('after the last stream of round 0 comes round 1 from stream 0', () {
      var s = _started(_three);
      s = _failCurrent(s);
      s = _failCurrent(s);
      final before = s;
      s = _run(
        s,
        Resolved(s.generation, [_candidate('http://x.example/')]),
      ).next;
      final t = _run(s, PlayerFailed(s.generation, 0));
      expect(before.streamIndex, 2);
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 1),
      );
      expect(t.commands.last, Resolve(_s0, t.next.generation));
    });

    test('a station that never played is given up after exactly two rounds: '
        'PlaybackError(allStreamsFailed), transport stopped, focus released, '
        'all timers cancelled', () {
      var s = _started(_three);
      final visited = <(int, int)>[(s.streamIndex, s.round)];
      late Transition last;
      for (var i = 0; i < 6; i++) {
        if (s.candidates.isEmpty) {
          s = _run(
            s,
            Resolved(s.generation, [_candidate('http://x.example/$i')]),
          ).next;
        }
        last = _run(s, PlayerFailed(s.generation, 0));
        s = last.next;
        if (s.status is Connecting) visited.add((s.streamIndex, s.round));
      }
      expect(visited, [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)]);
      expect(
        s.status,
        PlaybackStatus.error(
          station: _three,
          kind: PlaybackErrorKind.allStreamsFailed,
        ),
      );
      expect(last.commands, [
        const CancelAllTimers(),
        InvalidateResolution(_s2),
        const ClearNowPlaying(),
        const StopTransport(),
        const ReleaseFocus(),
      ]);
    });

    test('a one-stream station (N-JOY) is tried twice, then given up', () {
      var s = _started(_single);
      s = _failCurrent(s);
      expect(
        s.status,
        PlaybackStatus.connecting(station: _single, streamIndex: 0, round: 1),
      );
      s = _failCurrent(s);
      expect(
        s.status,
        PlaybackStatus.error(
          station: _single,
          kind: PlaybackErrorKind.allStreamsFailed,
        ),
      );
    });

    test('rotation from startStreamIndex 1 wraps: 1, 2, 0 in each round', () {
      var s = _started(_three, start: 1);
      final visited = <(int, int)>[(s.streamIndex, s.round)];
      while (s.status is Connecting) {
        s = _failCurrent(s);
        if (s.status is Connecting) visited.add((s.streamIndex, s.round));
      }
      expect(visited, [(1, 0), (2, 0), (0, 0), (1, 1), (2, 1), (0, 1)]);
      expect(s.status, isA<PlaybackError>());
    });

    test('when every failure was a format failure, the station ends in '
        'unsupportedFormat', () {
      var s = _started(_three);
      while (s.status is Connecting) {
        s = _run(
          s,
          ResolveFailed(s.generation, StreamResolutionFailure.notAPlaylist),
        ).next;
      }
      expect(
        s.status,
        PlaybackStatus.error(
          station: _three,
          kind: PlaybackErrorKind.unsupportedFormat,
        ),
      );
    });

    test('mixed failures end in allStreamsFailed', () {
      var s = _started(_three);
      s = _run(
        s,
        ResolveFailed(s.generation, StreamResolutionFailure.httpStatus),
      ).next;
      while (s.status is Connecting) {
        s = _run(
          s,
          ResolveFailed(s.generation, StreamResolutionFailure.empty),
        ).next;
      }
      expect(
        s.status,
        isA<PlaybackError>().having(
          (e) => e.kind,
          'kind',
          PlaybackErrorKind.allStreamsFailed,
        ),
      );
    });

    test('a station that already played this session is not given up when '
        'a round ends: it goes to Reconnecting (01-10)', () {
      var s = _started(_three).copyWith(everPlayed: true);
      s = _failCurrent(s);
      s = _failCurrent(s);
      expect(s.status, isA<Connecting>());
      s = _failCurrent(s);
      expect(
        s.status,
        isA<Reconnecting>().having((r) => r.attempt, 'attempt', 0),
      );
      expect(s.budget.running, isTrue);
    });
  });

  group('Connecting reaches Playing', () {
    test('ready and playing: Playing, the connect timer cancelled and '
        'time-to-audio recorded', () {
      final s = _run(
        _started(_three),
        Resolved(1, [_candidate('http://cdn.example/a')]),
      ).next;
      final t = _run(
        s,
        const PlayerStateChanged(1, PlayerProcessingState.ready, playing: true),
        _t0.add(const Duration(milliseconds: 2500)),
      );
      expect(
        t.next.status,
        PlaybackStatus.playing(station: _three, streamIndex: 0),
      );
      expect(t.commands, [
        const CancelTimer(TimerKind.connect),
        const RecordTimeToAudio(Duration(milliseconds: 2500)),
      ]);
      expect(t.next.everPlayed, isTrue);
      expect(t.next.lastWorkingStreamIndex, 0);
      expect(t.next.connectStartedAt, isNull);
      expect(t.next.generation, 1);
    });

    test('time-to-audio counts from the user play, across fallbacks', () {
      var s = _started(_three);
      s = _failCurrent(s);
      s = _run(
        s,
        Resolved(s.generation, [_candidate('http://cdn.example/b')]),
      ).next;
      final t = _run(
        s,
        PlayerStateChanged(
          s.generation,
          PlayerProcessingState.ready,
          playing: true,
        ),
        _t0.add(const Duration(seconds: 4)),
      );
      expect(
        t.next.status,
        PlaybackStatus.playing(station: _three, streamIndex: 1),
      );
      expect(t.commands.last, const RecordTimeToAudio(Duration(seconds: 4)));
      expect(t.next.lastWorkingStreamIndex, 1);
    });

    for (final (state, playing) in [
      (PlayerProcessingState.ready, false),
      (PlayerProcessingState.loading, true),
      (PlayerProcessingState.buffering, true),
      (PlayerProcessingState.idle, false),
    ]) {
      test(
        '${state.name}${playing ? ' and playing' : ''} keeps Connecting',
        () {
          final s = _run(
            _started(_three),
            Resolved(1, [_candidate('http://cdn.example/a')]),
          ).next;
          final t = _run(s, PlayerStateChanged(1, state, playing: playing));
          expect(t.next, same(s));
          expect(t.commands, isEmpty);
        },
      );
    }
  });

  group('Playing and Buffering', () {
    test('buffering -> Buffering with the 8 s stall timer; ready again -> '
        'Playing with the stall timer cancelled', () {
      final playing = _playing(_started(_three));
      final g = playing.generation;
      final buffering = _run(
        playing,
        PlayerStateChanged(g, PlayerProcessingState.buffering, playing: true),
      );
      expect(
        buffering.next.status,
        PlaybackStatus.buffering(station: _three, streamIndex: 0),
      );
      expect(buffering.commands, [
        StartTimer(TimerKind.stall, const Duration(seconds: 8), g),
      ]);
      final again = _run(
        buffering.next,
        PlayerStateChanged(g, PlayerProcessingState.ready, playing: true),
      );
      expect(
        again.next.status,
        PlaybackStatus.playing(station: _three, streamIndex: 0),
      );
      expect(again.commands, [const CancelTimer(TimerKind.stall)]);
    });

    for (final (label, event) in [
      ('a player failure', (int g) => PlayerFailed(g, 0)),
      (
        'completed (the server dropped us)',
        (int g) => PlayerStateChanged(
          g,
          PlayerProcessingState.completed,
          playing: false,
        ),
      ),
    ]) {
      for (final buffering in [false, true]) {
        test('$label while ${buffering ? 'Buffering' : 'Playing'} -> '
            'Reconnecting(attempt 0), invalidating the stream, with an '
            'immediate retry and the budget timer (PLAY-07)', () {
          var s = _playing(_started(_three));
          if (buffering) {
            s = _run(
              s,
              PlayerStateChanged(
                s.generation,
                PlayerProcessingState.buffering,
                playing: true,
              ),
            ).next;
          }
          final t = _run(s, event(s.generation));
          expect(
            t.next.status,
            PlaybackStatus.reconnecting(
              station: _three,
              attempt: 0,
              nextAttemptAt: _t0,
            ),
          );
          final g = s.generation + 1;
          expect(t.next.generation, g);
          expect(t.commands, [
            const CancelAllTimers(),
            const ClearNowPlaying(),
            const StopTransport(),
            InvalidateResolution(_s0),
            StartTimer(TimerKind.backoff, Duration.zero, g),
            StartTimer(TimerKind.budget, const Duration(minutes: 3), g),
          ]);
          expect(t.commands.whereType<ReleaseFocus>(), isEmpty);
          expect(t.next.budget.outageStartedAt, _t0);
        });
      }
    }
  });

  group('stale generations change nothing (PLAY-10)', () {
    final stale = <String, EngineEvent>{
      'Resolved': Resolved(1, [_candidate('http://stale.example/')]),
      'ResolveFailed': const ResolveFailed(1, StreamResolutionFailure.network),
      'PlayerStateChanged ready': const PlayerStateChanged(
        1,
        PlayerProcessingState.ready,
        playing: true,
      ),
      'PlayerStateChanged completed': const PlayerStateChanged(
        1,
        PlayerProcessingState.completed,
        playing: false,
      ),
      'PlayerFailed': const PlayerFailed(1, 0),
      'TimerFired': const TimerFired(TimerKind.connect, 1),
      'TimerFired stall': const TimerFired(TimerKind.stall, 1),
      'TimerFired backoff': const TimerFired(TimerKind.backoff, 1),
      'TimerFired stablePlaying': const TimerFired(TimerKind.stablePlaying, 1),
      'TimerFired budget': const TimerFired(TimerKind.budget, 1),
    };
    for (final MapEntry(key: label, value: event) in stale.entries) {
      test('$label from generation 1 while Connecting generation 2', () {
        final s = _failCurrent(_started(_three));
        expect(s.generation, 2);
        final t = _run(s, event);
        expect(t.next, same(s));
        expect(t.commands, isEmpty);
      });
      test('$label from generation 1 while Playing generation 2', () {
        final s = _playing(_failCurrent(_started(_three)));
        final t = _run(s, event);
        expect(t.next, same(s));
        expect(t.commands, isEmpty);
      });
    }
  });

  group('user commands (PLAY-10, PLAY-11)', () {
    const stopAll = [
      CancelAllTimers(),
      ClearNowPlaying(),
      StopTransport(),
      ReleaseFocus(),
    ];

    test('pause while Connecting -> Paused with the connect timer cancelled; '
        'a resolve result landing afterwards is dropped', () {
      final s = _started(_three);
      final t = _run(s, const UserPause());
      expect(t.next.status, PlaybackStatus.paused(station: _three));
      expect(t.next.generation, 2);
      expect(t.commands, stopAll);
      final late = _run(
        t.next,
        Resolved(1, [_candidate('http://late.example/')]),
      );
      expect(late.next, same(t.next));
      expect(late.commands, isEmpty);
    });

    test('stop while Connecting -> Idle; a resolve result landing afterwards '
        'is dropped', () {
      final s = _started(_three);
      final t = _run(s, const UserStop());
      expect(t.next.status, const PlaybackStatus.idle());
      expect(t.next.station, isNull);
      expect(t.next.generation, 2);
      expect(t.commands, stopAll);
      final late = _run(
        t.next,
        Resolved(1, [_candidate('http://late.example/')]),
      );
      expect(late.next, same(t.next));
      expect(late.commands, isEmpty);
    });

    test('pause while Playing -> Paused', () {
      final s = _playing(_started(_three));
      final t = _run(s, const UserPause());
      expect(t.next.status, PlaybackStatus.paused(station: _three));
      expect(t.commands, stopAll);
    });

    test('resume from Paused -> Connecting on the stream that last worked, '
        'a fresh load at the live edge', () {
      var s = _playing(_failCurrent(_started(_three)));
      expect(s.status, PlaybackStatus.playing(station: _three, streamIndex: 1));
      s = _run(s, const UserPause()).next;
      final t1 = _t0.add(const Duration(minutes: 5));
      final t = _run(s, const UserResume(), t1);
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 1, round: 0),
      );
      expect(t.next.connectStartedAt, t1);
      expect(t.next.generation, s.generation + 1);
      expect(t.commands, [
        const CancelAllTimers(),
        const StopTransport(),
        const ClearNowPlaying(),
        StartTimer(TimerKind.connect, _timeout, t.next.generation),
        Resolve(_s1, t.next.generation),
      ]);
    });

    test('resume from Error -> Connecting from the stream the user started '
        'at', () {
      var s = _started(_three, start: 2);
      while (s.status is Connecting) {
        s = _failCurrent(s);
      }
      expect(s.status, isA<PlaybackError>());
      final t = _run(s, const UserResume());
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 2, round: 0),
      );
      expect(t.commands.last, Resolve(_s2, t.next.generation));
    });

    test('play from Error or Paused starts the station given, fresh', () {
      final paused = _run(_playing(_started(_three)), const UserPause()).next;
      final t = _run(paused, UserPlay(_single));
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _single, streamIndex: 0, round: 0),
      );
      expect(t.commands.last, Resolve(_only, t.next.generation));
    });

    final restingStates = <String, EngineState Function()>{
      'Paused': () => _run(_playing(_started(_three)), const UserPause()).next,
      'Idle': () => _run(_started(_three), const UserStop()).next,
      'Error': () {
        var s = _started(_single);
        while (s.status is Connecting) {
          s = _failCurrent(s);
        }
        return s;
      },
    };
    for (final MapEntry(key: label, value: build) in restingStates.entries) {
      test('only UserPlay and UserResume leave $label: player, resolver and '
          'timer events of the current generation start nothing', () {
        final s = build();
        final g = s.generation;
        for (final event in <EngineEvent>[
          Resolved(g, [_candidate('http://x.example/')]),
          ResolveFailed(g, StreamResolutionFailure.network),
          PlayerStateChanged(g, PlayerProcessingState.ready, playing: true),
          PlayerStateChanged(
            g,
            PlayerProcessingState.completed,
            playing: false,
          ),
          PlayerFailed(g, 0),
          for (final kind in TimerKind.values) TimerFired(kind, g),
          const UserPause(),
        ]) {
          final t = _run(s, event);
          expect(t.next, same(s), reason: '$event');
          expect(t.commands, isEmpty, reason: '$event');
        }
      });
    }

    test('resume while active or Idle does nothing', () {
      for (final s in [
        _started(_three),
        _playing(_started(_three)),
        const EngineState.initial(),
      ]) {
        final t = _run(s, const UserResume());
        expect(t.next, same(s));
        expect(t.commands, isEmpty);
      }
    });

    test('no command ever seeks: the command set has no seek', () {
      // Collect every command of a long session; each is one of the known,
      // non-seeking kinds (PLAY-11).
      final commands = <EngineCommand>[];
      var s = const EngineState.initial();
      void apply(EngineEvent e) {
        final t = _run(s, e);
        commands.addAll(t.commands);
        s = t.next;
      }

      apply(UserPlay(_three));
      apply(Resolved(s.generation, [_candidate('http://a.example/')]));
      apply(
        PlayerStateChanged(
          s.generation,
          PlayerProcessingState.ready,
          playing: true,
        ),
      );
      // A drop, the reconnect and its retry (PLAY-07) never seek either.
      apply(PlayerFailed(s.generation, 0));
      apply(TimerFired(TimerKind.backoff, s.generation));
      apply(Resolved(s.generation, [_candidate('http://a.example/')]));
      apply(
        PlayerStateChanged(
          s.generation,
          PlayerProcessingState.ready,
          playing: true,
        ),
      );
      apply(
        PlayerStateChanged(
          s.generation,
          PlayerProcessingState.buffering,
          playing: true,
        ),
      );
      apply(TimerFired(TimerKind.stall, s.generation));
      apply(const UserPause());
      apply(const UserResume());
      apply(const UserStop());
      expect(commands, hasLength(greaterThan(20)));
      expect(
        commands.every(
          (c) => switch (c) {
            StopTransport() ||
            Resolve() ||
            Load() ||
            ReleaseFocus() ||
            StartTimer() ||
            CancelTimer() ||
            CancelAllTimers() ||
            InvalidateResolution() ||
            ClearNowPlaying() ||
            SetVolume() ||
            RecordTimeToAudio() => true,
          },
        ),
        isTrue,
      );
    });
  });

  group('reconnect after a drop or a stall (PLAY-07, PLAY-11)', () {
    const sec = Duration(seconds: 1);
    const min = Duration(minutes: 1);

    PlayerStateChanged snapshot(
      EngineState s,
      PlayerProcessingState state, {
      bool playing = true,
    }) => PlayerStateChanged(s.generation, state, playing: playing);

    /// [s] (Playing or Buffering) after the server drops it at [at].
    EngineState drop(EngineState s, [DateTime? at]) =>
        _run(s, PlayerFailed(s.generation, 0), at).next;

    /// Reconnecting [s] after its backoff timer fires at [at].
    EngineState fireBackoff(EngineState s, [DateTime? at]) =>
        _run(s, TimerFired(TimerKind.backoff, s.generation), at).next;

    test('the stall timer firing in Buffering: StopTransport and '
        'Reconnecting(attempt 0) with an immediate retry, then a fresh load '
        'at the live edge with a new generation', () {
      var s = _playing(_started(_three));
      s = _run(s, snapshot(s, PlayerProcessingState.buffering)).next;
      final t8 = _t0.add(sec * 8);
      final t = _run(s, TimerFired(TimerKind.stall, s.generation), t8);
      final g = s.generation + 1;
      expect(
        t.next.status,
        PlaybackStatus.reconnecting(
          station: _three,
          attempt: 0,
          nextAttemptAt: t8,
        ),
      );
      expect(t.next.generation, g);
      // A stall is not a bad URL: the resolution is kept.
      expect(t.commands, [
        const CancelAllTimers(),
        const ClearNowPlaying(),
        const StopTransport(),
        StartTimer(TimerKind.backoff, Duration.zero, g),
        StartTimer(TimerKind.budget, const Duration(minutes: 3), g),
      ]);

      final r = _run(t.next, TimerFired(TimerKind.backoff, g), t8);
      expect(
        r.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 0),
      );
      expect(r.next.generation, g + 1);
      expect(r.next.attempt, 1);
      expect(r.commands, [
        StartTimer(TimerKind.connect, _timeout, g + 1),
        Resolve(_s0, g + 1),
      ]);
    });

    test('a ready snapshot within 8 s wins: a stall timer firing afterwards '
        'changes nothing', () {
      var s = _playing(_started(_three));
      s = _run(s, snapshot(s, PlayerProcessingState.buffering)).next;
      s = _run(s, snapshot(s, PlayerProcessingState.ready)).next;
      expect(s.status, isA<Playing>());
      final t = _run(s, TimerFired(TimerKind.stall, s.generation));
      expect(t.next, same(s));
      expect(t.commands, isEmpty);
    });

    test('a second trigger in the same outage finds a new generation and '
        'emits no Load', () {
      var s = _playing(_started(_three));
      s = _run(s, snapshot(s, PlayerProcessingState.buffering)).next;
      final buffering = s.generation;
      s = _run(s, TimerFired(TimerKind.stall, buffering)).next;
      for (final late in <EngineEvent>[
        PlayerFailed(buffering, 0),
        PlayerStateChanged(
          buffering,
          PlayerProcessingState.completed,
          playing: false,
        ),
        TimerFired(TimerKind.stall, buffering),
      ]) {
        final t = _run(s, late);
        expect(t.next, same(s), reason: '$late');
        expect(t.commands, isEmpty, reason: '$late');
      }
    });

    test('the retry starts at the stream that last worked, then rotates; '
        'a failed round backs off as the next attempt', () {
      var s = _playing(_failCurrent(_started(_three)));
      expect(s.lastWorkingStreamIndex, 1);
      s = fireBackoff(drop(s));
      expect(
        s.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 1, round: 0),
      );
      s = _failCurrent(s);
      expect(
        s.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 2, round: 0),
      );
      s = _failCurrent(s);
      expect(
        s.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 0),
      );
      expect(s.attempt, 1);
      s = _failCurrent(s);
      expect(
        s.status,
        PlaybackStatus.reconnecting(
          station: _three,
          attempt: 1,
          nextAttemptAt: _t0.add(sec),
        ),
      );
      s = fireBackoff(s);
      expect(
        s.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 1, round: 0),
      );
      expect(s.attempt, 2);
    });

    test('backoff per attempt: 0, 1, 2, 4, 8, 15, 30, 30 s', () {
      var now = _t0;
      var s = drop(_playing(_started(_single)), now);
      final delays = <Duration>[];
      for (var i = 0; i < 8; i++) {
        final r = s.status as Reconnecting;
        delays.add(r.nextAttemptAt!.difference(now));
        now = r.nextAttemptAt!;
        s = _run(s, TimerFired(TimerKind.backoff, s.generation), now).next;
        expect(s.status, isA<Connecting>());
        s = _run(
          s,
          Resolved(s.generation, [_candidate('http://x/')]),
          now,
        ).next;
        s = _run(s, PlayerFailed(s.generation, 0), now).next;
      }
      expect(delays, [
        for (final n in [0, 1, 2, 4, 8, 15, 30, 30]) sec * n,
      ]);
      expect(s.status, isA<Reconnecting>());
    });

    test('Reconnecting and a retry Connecting publish playing true, so the '
        'foreground service stays (Pitfall 1)', () {
      final reconnecting = drop(_playing(_started(_single)));
      final state = playbackStateFor(reconnecting.status);
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.buffering);
      final retry = fireBackoff(reconnecting);
      expect(retry.status, isA<Connecting>());
      expect(playbackStateFor(retry.status).playing, isTrue);
    });

    test('standard budget: 3 min of failing online -> '
        'PlaybackError(streamUnreachable) with everything released', () {
      final s = drop(_playing(_started(_single)));
      final g = s.generation;
      // A budget timer that fires a little early re-arms for the rest.
      final early = _run(
        s,
        TimerFired(TimerKind.budget, g),
        _t0.add(min * 3 - sec),
      );
      expect(early.next, same(s));
      expect(early.commands, [StartTimer(TimerKind.budget, sec, g)]);

      final t = _run(s, TimerFired(TimerKind.budget, g), _t0.add(min * 3));
      expect(
        t.next.status,
        PlaybackStatus.error(
          station: _single,
          kind: PlaybackErrorKind.streamUnreachable,
        ),
      );
      expect(t.commands, [
        const CancelAllTimers(),
        InvalidateResolution(_only),
        const ClearNowPlaying(),
        const StopTransport(),
        const ReleaseFocus(),
      ]);
      expect(playbackStateFor(t.next.status).playing, isFalse);
      expect(t.next.budget.active, isFalse);
      expect(t.next.attempt, 0);
    });

    test('the budget timer spans the retries of one outage (their '
        'generations do not make it stale)', () {
      var s = drop(_playing(_started(_single)));
      final first = s.generation;
      s = fireBackoff(s);
      s = _run(s, Resolved(s.generation, [_candidate('http://x/')])).next;
      expect(s.generation, greaterThan(first));
      final t = _run(s, TimerFired(TimerKind.budget, first), _t0.add(min * 3));
      expect(t.next.status, isA<PlaybackError>());
    });

    test('a backoff firing after the budget ran out gives up instead of '
        'retrying', () {
      final s = drop(_playing(_started(_single)));
      final t = _run(
        s,
        TimerFired(TimerKind.backoff, s.generation),
        _t0.add(min * 3),
      );
      expect(t.next.status, isA<PlaybackError>());
      expect(t.commands.whereType<Load>(), isEmpty);
      expect(t.commands.whereType<Resolve>(), isEmpty);
      expect(t.commands, contains(const ReleaseFocus()));
    });

    test('a retry that fails after the budget ran out gives up at once', () {
      var s = fireBackoff(drop(_playing(_started(_single))));
      s = _run(s, Resolved(s.generation, [_candidate('http://x/')])).next;
      final t = _run(
        s,
        PlayerFailed(s.generation, 0),
        _t0.add(min * 3 + sec * 5),
      );
      expect(
        t.next.status,
        PlaybackStatus.error(
          station: _single,
          kind: PlaybackErrorKind.streamUnreachable,
        ),
      );
    });

    test('30 s of stable Playing resets the budget and the attempt counter; '
        'a drop before that continues the backoff', () {
      var s = fireBackoff(drop(_playing(_started(_single))));
      s = _run(s, Resolved(s.generation, [_candidate('http://x/')])).next;
      final g = s.generation;
      final back = _run(
        s,
        PlayerStateChanged(g, PlayerProcessingState.ready, playing: true),
        _t0.add(sec * 2),
      );
      expect(back.next.status, isA<Playing>());
      expect(back.commands, [
        const CancelTimer(TimerKind.connect),
        const CancelTimer(TimerKind.budget),
        StartTimer(TimerKind.stablePlaying, const Duration(seconds: 30), g),
      ]);
      expect(back.next.attempt, 1);
      expect(back.next.budget.active, isTrue);
      expect(back.next.budget.running, isFalse);

      // Dropped again after 20 s: attempt 1 (1 s), and the 2 s already
      // spent still count against the budget.
      final early = _run(back.next, PlayerFailed(g, 0), _t0.add(sec * 22));
      expect(
        early.next.status,
        PlaybackStatus.reconnecting(
          station: _single,
          attempt: 1,
          nextAttemptAt: _t0.add(sec * 23),
        ),
      );
      expect(
        early.commands.last,
        StartTimer(
          TimerKind.budget,
          const Duration(minutes: 3) - sec * 2,
          g + 1,
        ),
      );

      // Stable for 30 s: everything resets.
      final stable = _run(
        back.next,
        TimerFired(TimerKind.stablePlaying, g),
        _t0.add(sec * 32),
      );
      expect(stable.commands, isEmpty);
      expect(stable.next.status, back.next.status);
      expect(stable.next.attempt, 0);
      expect(stable.next.budget.active, isFalse);
      final later = _run(stable.next, PlayerFailed(g, 0), _t0.add(min));
      expect(
        later.next.status,
        PlaybackStatus.reconnecting(
          station: _single,
          attempt: 0,
          nextAttemptAt: _t0.add(min),
        ),
      );
      expect(
        later.commands.last,
        StartTimer(TimerKind.budget, const Duration(minutes: 3), g + 1),
      );
    });

    test('buffering during the stable period restarts it', () {
      var s = fireBackoff(drop(_playing(_started(_single))));
      s = _playing(s);
      final g = s.generation;
      final buffering = _run(s, snapshot(s, PlayerProcessingState.buffering));
      expect(buffering.commands, [
        const CancelTimer(TimerKind.stablePlaying),
        StartTimer(TimerKind.stall, const Duration(seconds: 8), g),
      ]);
      final ready = _run(
        buffering.next,
        snapshot(buffering.next, PlayerProcessingState.ready),
      );
      expect(ready.commands, [
        const CancelTimer(TimerKind.stall),
        StartTimer(TimerKind.stablePlaying, const Duration(seconds: 30), g),
      ]);
    });

    test('a stable timer from before a drop changes nothing', () {
      var s = fireBackoff(drop(_playing(_started(_single))));
      s = _playing(s);
      final g = s.generation;
      final dropped = drop(s);
      final t = _run(dropped, TimerFired(TimerKind.stablePlaying, g));
      expect(t.next, same(dropped));
    });
  });

  group('the retry budget setting (D-10)', () {
    const min = Duration(minutes: 1);

    test('setRetryBudget(batterySaver) during Playing: the next outage gives '
        'up after 1 min online', () {
      var s = _playing(_started(_single));
      final set = _run(s, const SetRetryBudget(RetryBudgetPreset.batterySaver));
      expect(set.commands, isEmpty);
      expect(set.next.budget.preset, RetryBudgetPreset.batterySaver);
      expect(set.next.status, s.status);
      s = set.next;
      final dropped = _run(s, PlayerFailed(s.generation, 0));
      expect(
        dropped.commands.last,
        StartTimer(TimerKind.budget, min, dropped.next.generation),
      );
      final before = _run(
        dropped.next,
        TimerFired(TimerKind.budget, dropped.next.generation),
        _t0.add(min - const Duration(seconds: 1)),
      );
      expect(before.next.status, isA<Reconnecting>());
      final t = _run(
        dropped.next,
        TimerFired(TimerKind.budget, dropped.next.generation),
        _t0.add(min),
      );
      expect(
        t.next.status,
        PlaybackStatus.error(
          station: _single,
          kind: PlaybackErrorKind.streamUnreachable,
        ),
      );
    });

    test('a change during Reconnecting re-arms the budget timer for what is '
        'left under the new preset', () {
      final s = _run(_playing(_started(_single)), PlayerFailed(1, 0)).next;
      final t = _run(
        s,
        const SetRetryBudget(RetryBudgetPreset.batterySaver),
        _t0.add(const Duration(seconds: 20)),
      );
      expect(t.commands, [
        StartTimer(TimerKind.budget, const Duration(seconds: 40), s.generation),
      ]);
      final trip = _run(
        s,
        const SetRetryBudget(RetryBudgetPreset.trip),
        _t0.add(const Duration(seconds: 20)),
      );
      expect(trip.commands, [
        StartTimer(
          TimerKind.budget,
          const Duration(minutes: 5) - const Duration(seconds: 20),
          s.generation,
        ),
      ]);
    });

    test('the preset survives new sessions, pause and stop', () {
      var s = _run(
        const EngineState.initial(),
        const SetRetryBudget(RetryBudgetPreset.trip),
      ).next;
      s = _playing(_run(s, UserPlay(_three)).next);
      s = _run(s, const UserPause()).next;
      s = _run(s, const UserResume()).next;
      s = _run(s, const UserStop()).next;
      s = _run(s, UserPlay(_single)).next;
      expect(s.budget.preset, RetryBudgetPreset.trip);
    });
  });

  group('user commands win over a reconnect (PLAY-10)', () {
    const stopAll = [
      CancelAllTimers(),
      ClearNowPlaying(),
      StopTransport(),
      ReleaseFocus(),
    ];

    EngineState reconnecting() =>
        _run(_playing(_started(_three)), PlayerFailed(1, 0)).next;

    for (final (label, command, expected)
        in <(String, EngineEvent, PlaybackStatus)>[
          (
            'UserPause',
            const UserPause(),
            PlaybackStatus.paused(station: _three),
          ),
          ('UserStop', const UserStop(), const PlaybackStatus.idle()),
        ]) {
      test('$label during Reconnecting cancels the backoff, stall and budget '
          'timers; no later timer or result starts anything', () {
        final s = reconnecting();
        final t = _run(s, command);
        expect(t.next.status, expected);
        expect(t.commands, stopAll);
        expect(t.next.budget.active, isFalse);
        expect(t.next.attempt, 0);
        for (final late in <EngineEvent>[
          for (final kind in TimerKind.values) ...[
            TimerFired(kind, s.generation),
            TimerFired(kind, t.next.generation),
          ],
          Resolved(s.generation, [_candidate('http://late.example/')]),
          PlayerStateChanged(
            s.generation,
            PlayerProcessingState.ready,
            playing: true,
          ),
        ]) {
          final after = _run(
            t.next,
            late,
            _t0.add(const Duration(minutes: 10)),
          );
          expect(after.next, same(t.next), reason: '$late');
          expect(after.commands, isEmpty, reason: '$late');
        }
      });

      test('$label while a retry is resolving: the result is dropped and '
          'never loads', () {
        var s = reconnecting();
        s = _run(s, TimerFired(TimerKind.backoff, s.generation)).next;
        expect(s.status, isA<Connecting>());
        final retry = s.generation;
        final t = _run(s, command);
        final late = _run(
          t.next,
          Resolved(retry, [_candidate('http://late.example/')]),
        );
        expect(late.next, same(t.next));
        expect(late.commands, isEmpty);
      });
    }

    test('UserPlay of another station during Reconnecting wins: timers '
        'cancelled, a fresh session, the old timers stale', () {
      final s = reconnecting();
      final t = _run(s, UserPlay(_single));
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _single, streamIndex: 0, round: 0),
      );
      expect(t.commands.first, const CancelAllTimers());
      expect(t.next.budget.active, isFalse);
      expect(t.next.attempt, 0);
      for (final kind in TimerKind.values) {
        final late = _run(
          t.next,
          TimerFired(kind, s.generation),
          _t0.add(const Duration(minutes: 10)),
        );
        expect(late.next, same(t.next), reason: kind.name);
        expect(late.commands, isEmpty, reason: kind.name);
      }
    });

    test('resume during Reconnecting does nothing (it is already trying)', () {
      final s = reconnecting();
      final t = _run(s, const UserResume());
      expect(t.next, same(s));
      expect(t.commands, isEmpty);
    });
  });
  group('connectivity, the flow check and the offline budget (PLAY-07, '
      'PLAY-10, D-10)', () {
    const sec = Duration(seconds: 1);
    const min = Duration(minutes: 1);
    const stopAll = [
      CancelAllTimers(),
      ClearNowPlaying(),
      StopTransport(),
      ReleaseFocus(),
    ];

    EngineState net(
      EngineState s, {
      required bool online,
      bool changed = false,
      DateTime? at,
    }) => _run(
      s,
      ConnectivityChanged(online: online, networkChanged: changed),
      at,
    ).next;

    EngineState playing() => _playing(_started(_three));

    /// Playing, then the server drops it at [at].
    EngineState dropped(EngineState s, [DateTime? at]) =>
        _run(s, PlayerFailed(s.generation, 0), at).next;

    int loadsAndResolves(List<EngineCommand> commands) =>
        commands.where((c) => c is Load || c is Resolve).length;

    /// A retry round in which every stream fails.
    EngineState failRound(EngineState s) {
      var next = s;
      while (next.status is Connecting) {
        next = _failCurrent(next);
      }
      return next;
    }

    test('the network state starts online', () {
      expect(const EngineState.initial().online, isTrue);
    });

    test('offline while Playing: only the flag changes (the buffer may still '
        'play); the stall watchdog or a failure takes it from there', () {
      final s = playing();
      final t = _run(s, const ConnectivityChanged(online: false));
      expect(t.next.status, s.status);
      expect(t.next.online, isFalse);
      expect(t.commands, isEmpty);
    });

    test('a drop while offline: Reconnecting(waitingForNetwork) with no '
        'backoff timer, and the budget timer armed for the offline budget '
        '(10 min standard)', () {
      final s = net(playing(), online: false);
      final t = _run(s, PlayerFailed(s.generation, 0));
      final g = s.generation + 1;
      expect(
        t.next.status,
        PlaybackStatus.reconnecting(
          station: _three,
          attempt: 0,
          waitingForNetwork: true,
        ),
      );
      expect(t.commands, [
        const CancelAllTimers(),
        const ClearNowPlaying(),
        const StopTransport(),
        InvalidateResolution(_s0),
        StartTimer(TimerKind.budget, const Duration(minutes: 10), g),
      ]);
      expect(t.commands.whereType<StartTimer>().map((c) => c.kind), [
        TimerKind.budget,
      ]);
      expect(t.next.budget.running, isTrue);
      expect(playbackStateFor(t.next.status).playing, isTrue);
    });

    test('offline while Reconnecting between retries: the backoff stops, '
        'waitingForNetwork, the budget re-armed for the offline budget', () {
      var s = dropped(playing());
      s = _run(s, TimerFired(TimerKind.backoff, s.generation)).next;
      s = failRound(s); // the retry round fails: Reconnecting(attempt 1)
      expect(s.status, isA<Reconnecting>());
      final at = _t0.add(sec * 20);
      final t = _run(s, const ConnectivityChanged(online: false), at);
      final g = s.generation + 1;
      expect(
        t.next.status,
        PlaybackStatus.reconnecting(
          station: _three,
          attempt: s.attempt,
          waitingForNetwork: true,
        ),
      );
      expect(t.next.generation, g);
      expect(t.commands, [
        const CancelAllTimers(),
        const ClearNowPlaying(),
        const StopTransport(),
        StartTimer(TimerKind.budget, const Duration(minutes: 10), g),
      ]);
      // The old backoff timer is stale now.
      final late = _run(t.next, TimerFired(TimerKind.backoff, s.generation));
      expect(late.next, same(t.next));
      expect(late.commands, isEmpty);
    });

    test('offline while a retry is connecting: the retry is abandoned and '
        'its late result never loads', () {
      var s = dropped(playing());
      s = _run(s, TimerFired(TimerKind.backoff, s.generation)).next;
      expect(s.status, isA<Connecting>());
      final retry = s.generation;
      final t = _run(s, const ConnectivityChanged(online: false));
      expect(
        t.next.status,
        isA<Reconnecting>().having(
          (r) => r.waitingForNetwork,
          'waitingForNetwork',
          isTrue,
        ),
      );
      expect(t.commands, contains(const StopTransport()));
      final late = _run(
        t.next,
        Resolved(retry, [_candidate('http://late.example/')]),
      );
      expect(late.next, same(t.next));
      expect(late.commands, isEmpty);
    });

    test('back online while waiting: Connecting at once from the stream that '
        'last worked, the backoff reset, a fresh load at the live edge', () {
      var s = _started(_three);
      s = _failCurrent(s); // stream 0 dead
      s = _playing(s); // stream 1 plays
      s = net(s, online: false);
      s = dropped(s);
      expect(s.status, isA<Reconnecting>());
      final at = _t0.add(min * 2);
      final t = _run(s, const ConnectivityChanged(online: true), at);
      final g = s.generation + 1;
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 1, round: 0),
      );
      expect(t.next.generation, g);
      expect(t.next.attempt, 1);
      expect(t.next.online, isTrue);
      expect(t.commands, [
        const CancelAllTimers(),
        StartTimer(TimerKind.budget, const Duration(minutes: 3), g),
        StartTimer(TimerKind.connect, _timeout, g),
        Resolve(_s1, g),
      ]);
      final r = _run(
        t.next,
        Resolved(g, [_candidate('http://two.example/fallback.aac#c0')]),
        at,
      );
      expect(r.commands, [
        Load(_candidate('http://two.example/fallback.aac#c0'), g),
      ]);
    });

    test('a network change while Reconnecting (online, deep in the backoff): '
        'retry now and reset the backoff', () {
      var s = dropped(playing());
      for (var i = 0; i < 4; i++) {
        s = _run(s, TimerFired(TimerKind.backoff, s.generation)).next;
        s = failRound(s);
      }
      expect(s.status, isA<Reconnecting>());
      expect(s.attempt, 4);
      final t = _run(
        s,
        const ConnectivityChanged(online: true, networkChanged: true),
      );
      expect(t.next.status, isA<Connecting>());
      expect(t.next.attempt, 1);
      expect(loadsAndResolves(t.commands), 1);
      // If it fails, the next wait is the second step (1 s), not 15 s.
      final failed = failRound(t.next);
      expect(failed.status, isA<Reconnecting>());
      final wait = (failed.status as Reconnecting).nextAttemptAt;
      expect(wait, _t0.add(sec));
    });

    test('online while Reconnecting and already online (no change): '
        'nothing', () {
      final s = dropped(playing());
      final t = _run(s, const ConnectivityChanged(online: true));
      expect(t.next.status, s.status);
      expect(t.next.generation, s.generation);
      expect(t.commands, isEmpty);
    });

    test('a network change while Buffering: reload at once at the live edge '
        '(no waiting for the stall watchdog)', () {
      var s = playing();
      s = _run(
        s,
        PlayerStateChanged(
          s.generation,
          PlayerProcessingState.buffering,
          playing: true,
        ),
      ).next;
      final t = _run(
        s,
        const ConnectivityChanged(online: true, networkChanged: true),
      );
      final g = s.generation + 1;
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 0),
      );
      expect(t.commands, [
        const CancelAllTimers(),
        const ClearNowPlaying(),
        const StopTransport(),
        StartTimer(TimerKind.budget, const Duration(minutes: 3), g),
        StartTimer(TimerKind.connect, _timeout, g),
        Resolve(_s0, g),
      ]);
      expect(t.next.budget.running, isTrue);
      // The URL was fine: nothing is invalidated.
      expect(t.commands.whereType<InvalidateResolution>(), isEmpty);
    });

    group('the flow check after a network change while Playing', () {
      EngineState buffered(EngineState s, int ms) => _run(
        s,
        BufferedPositionChanged(s.generation, Duration(milliseconds: ms)),
      ).next;

      test('a network change arms a 5 s flow check and changes nothing '
          'else', () {
        final s = buffered(playing(), 4000);
        final t = _run(
          s,
          const ConnectivityChanged(online: true, networkChanged: true),
        );
        expect(t.next.status, s.status);
        expect(t.next.flowCheckBaseline, const Duration(milliseconds: 4000));
        expect(t.commands, [
          StartTimer(
            TimerKind.flowCheck,
            const Duration(seconds: 5),
            s.generation,
          ),
        ]);
      });

      test('no progress when it fires: reload at once', () {
        var s = buffered(playing(), 4000);
        s = net(s, online: true, changed: true);
        final t = _run(
          s,
          TimerFired(TimerKind.flowCheck, s.generation),
          _t0.add(sec * 5),
        );
        expect(t.next.status, isA<Connecting>());
        expect(t.commands, contains(const StopTransport()));
        expect(loadsAndResolves(t.commands), 1);
      });

      test('progress when it fires: nothing happens', () {
        var s = buffered(playing(), 4000);
        s = net(s, online: true, changed: true);
        s = buffered(s, 4500);
        final t = _run(s, TimerFired(TimerKind.flowCheck, s.generation));
        expect(t.next.status, s.status);
        expect(t.next.flowCheckBaseline, isNull);
        expect(t.commands, isEmpty);
      });

      test('nothing buffered before the change but positions since: '
          'progress', () {
        var s = net(playing(), online: true, changed: true);
        s = buffered(s, 800);
        final t = _run(s, TimerFired(TimerKind.flowCheck, s.generation));
        expect(t.next.status, isA<Playing>());
        expect(t.commands, isEmpty);
      });

      test('positions from an older load are not progress', () {
        var s = buffered(playing(), 4000);
        s = net(s, online: true, changed: true);
        s = _run(
          s,
          BufferedPositionChanged(s.generation - 1, const Duration(minutes: 1)),
        ).next;
        final t = _run(s, TimerFired(TimerKind.flowCheck, s.generation));
        expect(t.next.status, isA<Connecting>());
      });

      test('a stale flow check changes nothing', () {
        var s = buffered(playing(), 4000);
        s = net(s, online: true, changed: true);
        final t = _run(s, TimerFired(TimerKind.flowCheck, s.generation - 1));
        expect(t.next, same(s));
        expect(t.commands, isEmpty);
      });

      test('offline when the check finds no progress: waiting for the '
          'network, not a retry', () {
        var s = buffered(playing(), 4000);
        s = net(s, online: true, changed: true);
        s = net(s, online: false);
        final t = _run(s, TimerFired(TimerKind.flowCheck, s.generation));
        expect(
          t.next.status,
          isA<Reconnecting>().having(
            (r) => r.waitingForNetwork,
            'waitingForNetwork',
            isTrue,
          ),
        );
        expect(loadsAndResolves(t.commands), 0);
      });
    });

    group('the offline budget', () {
      test('standard: 10 min offline -> PlaybackError(offline) with '
          'everything released and playing false', () {
        var s = net(playing(), online: false);
        s = dropped(s, _t0);
        final early = _run(
          s,
          TimerFired(TimerKind.budget, s.generation),
          _t0.add(min * 10 - sec),
        );
        expect(early.next.status, isA<Reconnecting>());
        expect(early.commands, [
          StartTimer(TimerKind.budget, sec, s.generation),
        ]);

        final t = _run(
          s,
          TimerFired(TimerKind.budget, s.generation),
          _t0.add(min * 10),
        );
        expect(
          t.next.status,
          PlaybackStatus.error(
            station: _three,
            kind: PlaybackErrorKind.offline,
          ),
        );
        expect(
          t.commands,
          containsAllInOrder(<EngineCommand>[
            const CancelAllTimers(),
            const StopTransport(),
            const ReleaseFocus(),
          ]),
        );
        expect(playbackStateFor(t.next.status).playing, isFalse);
        expect(t.next.budget.active, isFalse);
      });

      test('offline time counts only against the offline budget: 2 min '
          'failing online, 8 min offline, then back online leaves 1 min of '
          'the online budget', () {
        var s = dropped(playing(), _t0);
        s = net(s, online: false, at: _t0.add(min * 2));
        final t = _run(
          s,
          const ConnectivityChanged(online: true),
          _t0.add(min * 10),
        );
        expect(t.next.status, isA<Connecting>());
        expect(
          t.commands,
          contains(StartTimer(TimerKind.budget, min, t.next.generation)),
        );
      });

      test('the budget timer is re-armed for the other budget whenever the '
          'network flag changes during an outage', () {
        var s = dropped(playing(), _t0);
        s = _run(s, TimerFired(TimerKind.backoff, s.generation)).next;
        expect(s.status, isA<Connecting>());
        // Going offline abandons the retry: waiting, 10 min offline budget.
        final t = _run(
          s,
          const ConnectivityChanged(online: false),
          _t0.add(sec * 30),
        );
        expect(
          t.commands.whereType<StartTimer>().single,
          StartTimer(
            TimerKind.budget,
            const Duration(minutes: 10),
            t.next.generation,
          ),
        );
      });
    });

    group('idempotency: one outage, one fresh connection', () {
      test('the stall timer, then a network change at the same moment: one '
          'Resolve, and the pending immediate retry is stale', () {
        var s = playing();
        s = _run(
          s,
          PlayerStateChanged(
            s.generation,
            PlayerProcessingState.buffering,
            playing: true,
          ),
        ).next;
        final commands = <EngineCommand>[];
        var t = _run(s, TimerFired(TimerKind.stall, s.generation));
        commands.addAll(t.commands);
        final backoffGeneration = t.next.generation;
        t = _run(
          t.next,
          const ConnectivityChanged(online: true, networkChanged: true),
        );
        commands.addAll(t.commands);
        expect(t.next.status, isA<Connecting>());
        t = _run(t.next, TimerFired(TimerKind.backoff, backoffGeneration));
        commands.addAll(t.commands);
        expect(loadsAndResolves(commands), 1);
      });

      test('a network change, then the stall timer at the same moment: one '
          'Resolve', () {
        var s = playing();
        s = _run(
          s,
          PlayerStateChanged(
            s.generation,
            PlayerProcessingState.buffering,
            playing: true,
          ),
        ).next;
        final commands = <EngineCommand>[];
        var t = _run(
          s,
          const ConnectivityChanged(online: true, networkChanged: true),
        );
        commands.addAll(t.commands);
        t = _run(t.next, TimerFired(TimerKind.stall, s.generation));
        commands.addAll(t.commands);
        expect(t.next.status, isA<Connecting>());
        expect(loadsAndResolves(commands), 1);
      });

      test('online or a network change while Connecting: no new load', () {
        for (final s in [
          _started(_three),
          _run(
            dropped(playing()),
            TimerFired(TimerKind.backoff, dropped(playing()).generation),
          ).next,
        ]) {
          expect(s.status, isA<Connecting>());
          for (final event in const [
            ConnectivityChanged(online: true),
            ConnectivityChanged(online: true, networkChanged: true),
          ]) {
            final t = _run(s, event);
            expect(t.next.status, s.status, reason: '$event');
            expect(t.next.generation, s.generation, reason: '$event');
            expect(loadsAndResolves(t.commands), 0, reason: '$event');
            expect(
              t.commands.whereType<StopTransport>(),
              isEmpty,
              reason: '$event',
            );
          }
        }
      });
    });

    group('after a user pause or stop, and in an error, connectivity starts '
        'nothing (PLAY-10)', () {
      final states = <String, EngineState>{
        'Paused': _run(playing(), const UserPause()).next,
        'Idle': _run(playing(), const UserStop()).next,
        'Idle (never played)': const EngineState.initial(),
      };
      states['PlaybackError'] = () {
        var s = net(playing(), online: false);
        s = dropped(s, _t0);
        return _run(
          s,
          TimerFired(TimerKind.budget, s.generation),
          _t0.add(min * 10),
        ).next;
      }();

      for (final MapEntry(key: label, value: s) in states.entries) {
        for (final event in const [
          ConnectivityChanged(online: true),
          ConnectivityChanged(online: true, networkChanged: true),
          ConnectivityChanged(online: false),
        ]) {
          test('$label + $event: no commands', () {
            final base = event.online ? net(s, online: false) : s;
            final t = _run(base, event);
            expect(t.next.status, base.status);
            expect(t.commands, isEmpty);
            expect(t.next.online, event.online);
          });
        }
      }

      test('UserPause while waiting for the network cancels the budget timer '
          'and ends the outage', () {
        var s = net(playing(), online: false);
        s = dropped(s, _t0);
        final t = _run(s, const UserPause());
        expect(t.next.status, PlaybackStatus.paused(station: _three));
        expect(t.commands, stopAll);
        expect(t.next.budget.active, isFalse);
        final late = _run(
          t.next,
          TimerFired(TimerKind.budget, s.generation),
          _t0.add(min * 11),
        );
        expect(late.next, same(t.next));
        expect(late.commands, isEmpty);
        // Coming back online later does not resume it.
        final back = _run(t.next, const ConnectivityChanged(online: true));
        expect(back.next.status, t.next.status);
        expect(back.commands, isEmpty);
      });
    });

    test('a station that never played, given up while offline, reports '
        'offline', () {
      var s = net(const EngineState.initial(), online: false);
      s = _run(s, UserPlay(_three)).next;
      for (var i = 0; i < 6; i++) {
        s = _failCurrent(s);
      }
      expect(
        s.status,
        PlaybackStatus.error(station: _three, kind: PlaybackErrorKind.offline),
      );
    });

    test('a backoff that fires while offline waits for the network instead '
        'of retrying', () {
      final s = dropped(playing());
      final offline = s.copyWith(
        budget: s.budget.onConnectivity(_t0, online: false),
      );
      final t = _run(offline, TimerFired(TimerKind.backoff, s.generation));
      expect(
        t.next.status,
        isA<Reconnecting>().having(
          (r) => r.waitingForNetwork,
          'waitingForNetwork',
          isTrue,
        ),
      );
      expect(loadsAndResolves(t.commands), 0);
    });

    test('describeStatus marks a wait for the network', () {
      expect(
        describeStatus(
          PlaybackStatus.reconnecting(
            station: _three,
            attempt: 2,
            waitingForNetwork: true,
          ),
        ),
        'Reconnecting(attempt 2, waiting for network)',
      );
    });
  });

  group('audio focus and becoming noisy (PLAY-05, PLAY-06, PLAY-10, D-11)', () {
    const min = Duration(minutes: 1);
    const stopAll = [
      CancelAllTimers(),
      ClearNowPlaying(),
      StopTransport(),
      ReleaseFocus(),
    ];
    const interruptCommands = [
      CancelAllTimers(),
      ClearNowPlaying(),
      StopTransport(),
    ];

    /// _three playing on stream 1 (so lastWorkingStreamIndex is 1).
    EngineState playing() => _playing(_started(_three, start: 1));

    EngineState buffering() {
      final s = playing();
      return _run(
        s,
        PlayerStateChanged(
          s.generation,
          PlayerProcessingState.buffering,
          playing: true,
        ),
      ).next;
    }

    EngineState reconnecting() {
      final s = playing();
      return _run(s, PlayerFailed(s.generation, 0)).next;
    }

    EngineState interrupted([EngineState? from]) => _run(
      from ?? playing(),
      const FocusChanged(FocusChange.transientLoss),
    ).next;

    EngineState paused() => _run(playing(), const UserPause()).next;

    EngineState failed() => _failCurrent(_failCurrent(_started(_single)));

    int loadsAndResolves(List<EngineCommand> commands) =>
        commands.where((c) => c is Load || c is Resolve).length;

    final active = <String, EngineState Function()>{
      'Connecting': () => _started(_three, start: 1),
      'Playing': playing,
      'Buffering': buffering,
      'Reconnecting': reconnecting,
    };

    test('the fixtures are in the states they claim', () {
      expect(active['Connecting']!().status, isA<Connecting>());
      expect(playing().status, isA<Playing>());
      expect(buffering().status, isA<Buffering>());
      expect(reconnecting().status, isA<Reconnecting>());
      expect(interrupted().status, isA<Interrupted>());
      expect(paused().status, isA<Paused>());
      expect(failed().status, isA<PlaybackError>());
    });

    group('a phone call (transient loss) interrupts and resumes (D-11)', () {
      for (final MapEntry(key: label, value: make) in active.entries) {
        test('$label + transientLoss -> Interrupted: transport stopped, '
            'timers cancelled, focus kept, playing true (FGS kept)', () {
          final s = make();
          final t = _run(s, const FocusChanged(FocusChange.transientLoss));
          expect(
            t.next.status,
            PlaybackStatus.interrupted(station: s.station!),
          );
          expect(t.commands, interruptCommands);
          expect(t.commands, isNot(contains(const ReleaseFocus())));
          expect(t.next.generation, greaterThan(s.generation));
          final state = playbackStateFor(t.next.status);
          expect(state.playing, isTrue);
          expect(state.processingState, AudioProcessingState.buffering);
        });
      }

      test('gainAfterPause in Interrupted -> Connecting at the last working '
          'stream, a fresh resolve and load at the live edge', () {
        final s = interrupted();
        final t = _run(s, const FocusChanged(FocusChange.gainAfterPause));
        expect(
          t.next.status,
          PlaybackStatus.connecting(station: _three, streamIndex: 1, round: 0),
        );
        expect(t.next.generation, greaterThan(s.generation));
        expect(t.commands, [
          const CancelAllTimers(),
          const StopTransport(),
          const ClearNowPlaying(),
          StartTimer(TimerKind.connect, _timeout, t.next.generation),
          Resolve(_s1, t.next.generation),
        ]);
        expect(t.next.everPlayed, isTrue);
        expect(t.next.lastWorkingStreamIndex, 1);
      });

      test('a 15-minute call still resumes (no budget runs while '
          'Interrupted)', () {
        final s = interrupted(reconnecting());
        expect(s.budget.active, isFalse);
        expect(s.attempt, 0);
        // Everything that can fire during the call changes nothing.
        for (final event in [
          TimerFired(TimerKind.budget, s.generation),
          TimerFired(TimerKind.backoff, s.generation),
          TimerFired(TimerKind.connect, s.generation),
          TimerFired(TimerKind.stall, s.generation),
          TimerFired(TimerKind.flowCheck, s.generation),
        ]) {
          final t = _run(s, event, _t0.add(min * 15));
          expect(t.next.status, s.status, reason: '$event');
          expect(t.commands, isEmpty, reason: '$event');
        }
        final t = _run(
          s,
          const FocusChanged(FocusChange.gainAfterPause),
          _t0.add(min * 15),
        );
        expect(t.next.status, isA<Connecting>());
        expect(loadsAndResolves(t.commands), 1);
      });

      test('Interrupted ignores connectivity: no reload during the call', () {
        final s = interrupted();
        for (final event in const [
          ConnectivityChanged(online: false),
          ConnectivityChanged(online: true, networkChanged: true),
        ]) {
          final t = _run(s, event);
          expect(t.next.status, s.status);
          expect(t.commands, isEmpty);
        }
      });

      test('player events of the load stopped by the call change nothing', () {
        final p = playing();
        final s = interrupted(p);
        for (final event in [
          PlayerFailed(p.generation, 0),
          PlayerStateChanged(
            p.generation,
            PlayerProcessingState.completed,
            playing: false,
          ),
          PlayerStateChanged(
            p.generation,
            PlayerProcessingState.ready,
            playing: true,
          ),
        ]) {
          final t = _run(s, event);
          expect(t.next.status, s.status);
          expect(t.commands, isEmpty);
        }
      });

      test('transientLoss again while Interrupted changes nothing', () {
        final s = interrupted();
        final t = _run(s, const FocusChanged(FocusChange.transientLoss));
        expect(t.next, same(s));
        expect(t.commands, isEmpty);
      });

      test('UserPause during Interrupted -> Paused with focus released; a '
          'later gain does not resume', () {
        final t = _run(interrupted(), const UserPause());
        expect(t.next.status, PlaybackStatus.paused(station: _three));
        expect(t.commands, stopAll);
        final gain = _run(
          t.next,
          const FocusChanged(FocusChange.gainAfterPause),
        );
        expect(gain.next.status, t.next.status);
        expect(gain.commands, isEmpty);
      });

      test('UserStop during Interrupted -> Idle with focus released', () {
        final t = _run(interrupted(), const UserStop());
        expect(t.next.status, const PlaybackStatus.idle());
        expect(t.commands, stopAll);
      });
    });

    group('another media app (permanent loss) pauses for good', () {
      final states = {...active, 'Interrupted': interrupted};
      for (final MapEntry(key: label, value: make) in states.entries) {
        test('$label + permanentLoss -> Paused with transport, focus and '
            'timers released; a later gain is ignored', () {
          final s = make();
          final t = _run(s, const FocusChanged(FocusChange.permanentLoss));
          expect(t.next.status, PlaybackStatus.paused(station: s.station!));
          expect(t.commands, stopAll);
          expect(playbackStateFor(t.next.status).playing, isFalse);
          final gain = _run(
            t.next,
            const FocusChanged(FocusChange.gainAfterPause),
          );
          expect(gain.next.status, t.next.status);
          expect(gain.commands, isEmpty);
        });
      }
    });

    group('unplugging headphones or Bluetooth (becoming noisy) pauses', () {
      final states = {...active, 'Interrupted': interrupted};
      for (final MapEntry(key: label, value: make) in states.entries) {
        test('$label + BecomingNoisy -> Paused with focus released; nothing '
            'resumes it', () {
          final s = make();
          final t = _run(s, const BecomingNoisy());
          expect(t.next.status, PlaybackStatus.paused(station: s.station!));
          expect(t.commands, stopAll);
          for (final event in const [
            FocusChanged(FocusChange.gainAfterPause),
            ConnectivityChanged(online: true, networkChanged: true),
          ]) {
            final after = _run(t.next, event);
            expect(after.next.status, t.next.status);
            expect(loadsAndResolves(after.commands), 0);
          }
        });
      }
    });

    group('navigation prompts duck the volume', () {
      test('duckBegin while Playing -> SetVolume(0.3), status unchanged; '
          'duckEnd -> SetVolume(1.0)', () {
        final s = playing();
        final duck = _run(s, const FocusChanged(FocusChange.duckBegin));
        expect(duck.next.status, s.status);
        expect(duck.next.generation, s.generation);
        expect(duck.commands, [const SetVolume(0.3)]);
        expect(duck.next.ducked, isTrue);
        final end = _run(duck.next, const FocusChanged(FocusChange.duckEnd));
        expect(end.next.status, s.status);
        expect(end.commands, [const SetVolume(1.0)]);
        expect(end.next.ducked, isFalse);
      });

      for (final MapEntry(key: label, value: make) in active.entries) {
        test('$label + duckBegin ducks without a status change', () {
          final s = make();
          final t = _run(s, const FocusChanged(FocusChange.duckBegin));
          expect(t.next.status, s.status);
          expect(t.commands, [const SetVolume(0.3)]);
        });
      }

      test('a second duckBegin or a duckEnd without a duck sets nothing', () {
        final ducked = _run(
          playing(),
          const FocusChanged(FocusChange.duckBegin),
        ).next;
        expect(
          _run(ducked, const FocusChanged(FocusChange.duckBegin)).commands,
          isEmpty,
        );
        expect(
          _run(playing(), const FocusChanged(FocusChange.duckEnd)).commands,
          isEmpty,
        );
      });

      test('pausing while ducked restores the volume after releasing focus '
          '(no duckEnd arrives once focus is abandoned)', () {
        final ducked = _run(
          playing(),
          const FocusChanged(FocusChange.duckBegin),
        ).next;
        final t = _run(ducked, const UserPause());
        expect(t.commands, [...stopAll, const SetVolume(1.0)]);
        expect(t.next.ducked, isFalse);
      });

      test('a call during a duck: the resume after the call restores the '
          'volume', () {
        final ducked = _run(
          playing(),
          const FocusChanged(FocusChange.duckBegin),
        ).next;
        final s = interrupted(ducked);
        final t = _run(s, const FocusChanged(FocusChange.gainAfterPause));
        expect(t.next.status, isA<Connecting>());
        expect(t.commands, contains(const SetVolume(1.0)));
        expect(t.next.ducked, isFalse);
      });
    });

    group('after a user pause or stop, and in an error, focus, noisy and '
        'network events start nothing (PLAY-10)', () {
      final states = <String, EngineState Function()>{
        'Paused': paused,
        'Idle': () => _run(playing(), const UserStop()).next,
        'Idle (never played)': () => const EngineState.initial(),
        'PlaybackError': failed,
      };
      for (final MapEntry(key: label, value: make) in states.entries) {
        for (final event in const <EngineEvent>[
          FocusChanged(FocusChange.gainAfterPause),
          FocusChanged(FocusChange.transientLoss),
          FocusChanged(FocusChange.permanentLoss),
          FocusChanged(FocusChange.duckBegin),
          BecomingNoisy(),
          ConnectivityChanged(online: true, networkChanged: true),
        ]) {
          test('$label + $event: no commands', () {
            final s = make();
            final t = _run(s, event);
            expect(t.next.status, s.status);
            expect(t.commands, isEmpty);
          });
        }
      }
    });
  });
}
