// The pure PlaybackStateMachine: one test per behaviour row, asserting the
// next state and the exact command sequence (RESEARCH Pattern 2,
// ARCHITECTURE Pattern 3). No fakes, no timers: the reducer is a function.
import 'package:flutter_test/flutter_test.dart';
import 'package:radio/features/catalog/domain/station.dart';
import 'package:radio/features/playback/domain/play_context.dart';
import 'package:radio/features/playback/domain/playback_status.dart';
import 'package:radio/features/playback/engine/ports.dart';
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

const _machine = PlaybackStateMachine();
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
    test('from Idle: Connecting(stream 0, round 0), then StopTransport, '
        'ClearNowPlaying, StartTimer(connect, 10 s) and Resolve', () {
      final t = _run(const EngineState.initial(), UserPlay(_three));
      expect(
        t.next.status,
        PlaybackStatus.connecting(station: _three, streamIndex: 0, round: 0),
      );
      expect(t.next.station, _three);
      expect(t.next.generation, 1);
      expect(t.next.connectStartedAt, _t0);
      expect(t.commands, [
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

    test('a station that already played this session errors after one round '
        '(streamUnreachable); 01-10 turns this row into Reconnecting', () {
      var s = _started(_three).copyWith(everPlayed: true);
      s = _failCurrent(s);
      s = _failCurrent(s);
      expect(s.status, isA<Connecting>());
      s = _failCurrent(s);
      expect(
        s.status,
        PlaybackStatus.error(
          station: _three,
          kind: PlaybackErrorKind.streamUnreachable,
        ),
      );
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
    test('buffering -> Buffering, ready again -> Playing, no commands', () {
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
      expect(buffering.commands, isEmpty);
      final again = _run(
        buffering.next,
        PlayerStateChanged(g, PlayerProcessingState.ready, playing: true),
      );
      expect(
        again.next.status,
        PlaybackStatus.playing(station: _three, streamIndex: 0),
      );
      expect(again.commands, isEmpty);
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
            'Error(streamUnreachable), invalidating the stream', () {
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
            PlaybackStatus.error(
              station: _three,
              kind: PlaybackErrorKind.streamUnreachable,
            ),
          );
          expect(t.next.generation, s.generation + 1);
          expect(t.commands, [
            const CancelAllTimers(),
            InvalidateResolution(_s0),
            const ClearNowPlaying(),
            const StopTransport(),
            const ReleaseFocus(),
          ]);
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
          TimerFired(TimerKind.connect, g),
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
      apply(const UserPause());
      apply(const UserResume());
      apply(const UserStop());
      expect(commands, hasLength(greaterThan(10)));
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
            RecordTimeToAudio() => true,
          },
        ),
        isTrue,
      );
    });
  });
}
