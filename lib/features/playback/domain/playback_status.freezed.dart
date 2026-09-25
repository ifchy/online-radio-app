// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'playback_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PlaybackStatus {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlaybackStatus()';
}


}

/// @nodoc
class $PlaybackStatusCopyWith<$Res>  {
$PlaybackStatusCopyWith(PlaybackStatus _, $Res Function(PlaybackStatus) __);
}


/// Adds pattern-matching-related methods to [PlaybackStatus].
extension PlaybackStatusPatterns on PlaybackStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Idle value)?  idle,TResult Function( Connecting value)?  connecting,TResult Function( Playing value)?  playing,TResult Function( Buffering value)?  buffering,TResult Function( Reconnecting value)?  reconnecting,TResult Function( Interrupted value)?  interrupted,TResult Function( Paused value)?  paused,TResult Function( PlaybackError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Idle() when idle != null:
return idle(_that);case Connecting() when connecting != null:
return connecting(_that);case Playing() when playing != null:
return playing(_that);case Buffering() when buffering != null:
return buffering(_that);case Reconnecting() when reconnecting != null:
return reconnecting(_that);case Interrupted() when interrupted != null:
return interrupted(_that);case Paused() when paused != null:
return paused(_that);case PlaybackError() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Idle value)  idle,required TResult Function( Connecting value)  connecting,required TResult Function( Playing value)  playing,required TResult Function( Buffering value)  buffering,required TResult Function( Reconnecting value)  reconnecting,required TResult Function( Interrupted value)  interrupted,required TResult Function( Paused value)  paused,required TResult Function( PlaybackError value)  error,}){
final _that = this;
switch (_that) {
case Idle():
return idle(_that);case Connecting():
return connecting(_that);case Playing():
return playing(_that);case Buffering():
return buffering(_that);case Reconnecting():
return reconnecting(_that);case Interrupted():
return interrupted(_that);case Paused():
return paused(_that);case PlaybackError():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Idle value)?  idle,TResult? Function( Connecting value)?  connecting,TResult? Function( Playing value)?  playing,TResult? Function( Buffering value)?  buffering,TResult? Function( Reconnecting value)?  reconnecting,TResult? Function( Interrupted value)?  interrupted,TResult? Function( Paused value)?  paused,TResult? Function( PlaybackError value)?  error,}){
final _that = this;
switch (_that) {
case Idle() when idle != null:
return idle(_that);case Connecting() when connecting != null:
return connecting(_that);case Playing() when playing != null:
return playing(_that);case Buffering() when buffering != null:
return buffering(_that);case Reconnecting() when reconnecting != null:
return reconnecting(_that);case Interrupted() when interrupted != null:
return interrupted(_that);case Paused() when paused != null:
return paused(_that);case PlaybackError() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( Station station,  int streamIndex,  int round)?  connecting,TResult Function( Station station,  int streamIndex)?  playing,TResult Function( Station station,  int streamIndex)?  buffering,TResult Function( Station station,  int attempt,  DateTime? nextAttemptAt,  bool waitingForNetwork)?  reconnecting,TResult Function( Station station)?  interrupted,TResult Function( Station station)?  paused,TResult Function( Station station,  PlaybackErrorKind kind)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Idle() when idle != null:
return idle();case Connecting() when connecting != null:
return connecting(_that.station,_that.streamIndex,_that.round);case Playing() when playing != null:
return playing(_that.station,_that.streamIndex);case Buffering() when buffering != null:
return buffering(_that.station,_that.streamIndex);case Reconnecting() when reconnecting != null:
return reconnecting(_that.station,_that.attempt,_that.nextAttemptAt,_that.waitingForNetwork);case Interrupted() when interrupted != null:
return interrupted(_that.station);case Paused() when paused != null:
return paused(_that.station);case PlaybackError() when error != null:
return error(_that.station,_that.kind);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( Station station,  int streamIndex,  int round)  connecting,required TResult Function( Station station,  int streamIndex)  playing,required TResult Function( Station station,  int streamIndex)  buffering,required TResult Function( Station station,  int attempt,  DateTime? nextAttemptAt,  bool waitingForNetwork)  reconnecting,required TResult Function( Station station)  interrupted,required TResult Function( Station station)  paused,required TResult Function( Station station,  PlaybackErrorKind kind)  error,}) {final _that = this;
switch (_that) {
case Idle():
return idle();case Connecting():
return connecting(_that.station,_that.streamIndex,_that.round);case Playing():
return playing(_that.station,_that.streamIndex);case Buffering():
return buffering(_that.station,_that.streamIndex);case Reconnecting():
return reconnecting(_that.station,_that.attempt,_that.nextAttemptAt,_that.waitingForNetwork);case Interrupted():
return interrupted(_that.station);case Paused():
return paused(_that.station);case PlaybackError():
return error(_that.station,_that.kind);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( Station station,  int streamIndex,  int round)?  connecting,TResult? Function( Station station,  int streamIndex)?  playing,TResult? Function( Station station,  int streamIndex)?  buffering,TResult? Function( Station station,  int attempt,  DateTime? nextAttemptAt,  bool waitingForNetwork)?  reconnecting,TResult? Function( Station station)?  interrupted,TResult? Function( Station station)?  paused,TResult? Function( Station station,  PlaybackErrorKind kind)?  error,}) {final _that = this;
switch (_that) {
case Idle() when idle != null:
return idle();case Connecting() when connecting != null:
return connecting(_that.station,_that.streamIndex,_that.round);case Playing() when playing != null:
return playing(_that.station,_that.streamIndex);case Buffering() when buffering != null:
return buffering(_that.station,_that.streamIndex);case Reconnecting() when reconnecting != null:
return reconnecting(_that.station,_that.attempt,_that.nextAttemptAt,_that.waitingForNetwork);case Interrupted() when interrupted != null:
return interrupted(_that.station);case Paused() when paused != null:
return paused(_that.station);case PlaybackError() when error != null:
return error(_that.station,_that.kind);case _:
  return null;

}
}

}

/// @nodoc


class Idle extends PlaybackStatus {
  const Idle(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Idle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'PlaybackStatus.idle()';
}


}




/// @nodoc


class Connecting extends PlaybackStatus {
  const Connecting({required this.station, required this.streamIndex, required this.round}): super._();
  

 final  Station station;
 final  int streamIndex;
 final  int round;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectingCopyWith<Connecting> get copyWith => _$ConnectingCopyWithImpl<Connecting>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Connecting&&(identical(other.station, station) || other.station == station)&&(identical(other.streamIndex, streamIndex) || other.streamIndex == streamIndex)&&(identical(other.round, round) || other.round == round));
}


@override
int get hashCode {
    return Object.hash(runtimeType,station,streamIndex,round);
}

@override
String toString() {
    return 'PlaybackStatus.connecting(station: $station, streamIndex: $streamIndex, round: $round)';
}


}

/// @nodoc
abstract mixin class $ConnectingCopyWith<$Res> implements $PlaybackStatusCopyWith<$Res> {
  factory $ConnectingCopyWith(Connecting value, $Res Function(Connecting) _then) = _$ConnectingCopyWithImpl;
@useResult
$Res call({
 Station station, int streamIndex, int round
});


$StationCopyWith<$Res> get station;

}
/// @nodoc
class _$ConnectingCopyWithImpl<$Res>
    implements $ConnectingCopyWith<$Res> {
  _$ConnectingCopyWithImpl(this._self, this._then);

  final Connecting _self;
  final $Res Function(Connecting) _then;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? station = null,Object? streamIndex = null,Object? round = null,}) {
  return _then(Connecting(
station: null == station ? _self.station : station // ignore: cast_nullable_to_non_nullable
as Station,streamIndex: null == streamIndex ? _self.streamIndex : streamIndex // ignore: cast_nullable_to_non_nullable
as int,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationCopyWith<$Res> get station {
  
  return $StationCopyWith<$Res>(_self.station, (value) {
    return _then(_self.copyWith(station: value));
  });
}
}

/// @nodoc


class Playing extends PlaybackStatus {
  const Playing({required this.station, required this.streamIndex}): super._();
  

 final  Station station;
 final  int streamIndex;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayingCopyWith<Playing> get copyWith => _$PlayingCopyWithImpl<Playing>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Playing&&(identical(other.station, station) || other.station == station)&&(identical(other.streamIndex, streamIndex) || other.streamIndex == streamIndex));
}


@override
int get hashCode {
    return Object.hash(runtimeType,station,streamIndex);
}

@override
String toString() {
    return 'PlaybackStatus.playing(station: $station, streamIndex: $streamIndex)';
}


}

/// @nodoc
abstract mixin class $PlayingCopyWith<$Res> implements $PlaybackStatusCopyWith<$Res> {
  factory $PlayingCopyWith(Playing value, $Res Function(Playing) _then) = _$PlayingCopyWithImpl;
@useResult
$Res call({
 Station station, int streamIndex
});


$StationCopyWith<$Res> get station;

}
/// @nodoc
class _$PlayingCopyWithImpl<$Res>
    implements $PlayingCopyWith<$Res> {
  _$PlayingCopyWithImpl(this._self, this._then);

  final Playing _self;
  final $Res Function(Playing) _then;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? station = null,Object? streamIndex = null,}) {
  return _then(Playing(
station: null == station ? _self.station : station // ignore: cast_nullable_to_non_nullable
as Station,streamIndex: null == streamIndex ? _self.streamIndex : streamIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationCopyWith<$Res> get station {
  
  return $StationCopyWith<$Res>(_self.station, (value) {
    return _then(_self.copyWith(station: value));
  });
}
}

/// @nodoc


class Buffering extends PlaybackStatus {
  const Buffering({required this.station, required this.streamIndex}): super._();
  

 final  Station station;
 final  int streamIndex;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BufferingCopyWith<Buffering> get copyWith => _$BufferingCopyWithImpl<Buffering>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Buffering&&(identical(other.station, station) || other.station == station)&&(identical(other.streamIndex, streamIndex) || other.streamIndex == streamIndex));
}


@override
int get hashCode {
    return Object.hash(runtimeType,station,streamIndex);
}

@override
String toString() {
    return 'PlaybackStatus.buffering(station: $station, streamIndex: $streamIndex)';
}


}

/// @nodoc
abstract mixin class $BufferingCopyWith<$Res> implements $PlaybackStatusCopyWith<$Res> {
  factory $BufferingCopyWith(Buffering value, $Res Function(Buffering) _then) = _$BufferingCopyWithImpl;
@useResult
$Res call({
 Station station, int streamIndex
});


$StationCopyWith<$Res> get station;

}
/// @nodoc
class _$BufferingCopyWithImpl<$Res>
    implements $BufferingCopyWith<$Res> {
  _$BufferingCopyWithImpl(this._self, this._then);

  final Buffering _self;
  final $Res Function(Buffering) _then;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? station = null,Object? streamIndex = null,}) {
  return _then(Buffering(
station: null == station ? _self.station : station // ignore: cast_nullable_to_non_nullable
as Station,streamIndex: null == streamIndex ? _self.streamIndex : streamIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationCopyWith<$Res> get station {
  
  return $StationCopyWith<$Res>(_self.station, (value) {
    return _then(_self.copyWith(station: value));
  });
}
}

/// @nodoc


class Reconnecting extends PlaybackStatus {
  const Reconnecting({required this.station, required this.attempt, this.nextAttemptAt, this.waitingForNetwork = false}): super._();
  

 final  Station station;
 final  int attempt;
 final  DateTime? nextAttemptAt;
@JsonKey() final  bool waitingForNetwork;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReconnectingCopyWith<Reconnecting> get copyWith => _$ReconnectingCopyWithImpl<Reconnecting>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Reconnecting&&(identical(other.station, station) || other.station == station)&&(identical(other.attempt, attempt) || other.attempt == attempt)&&(identical(other.nextAttemptAt, nextAttemptAt) || other.nextAttemptAt == nextAttemptAt)&&(identical(other.waitingForNetwork, waitingForNetwork) || other.waitingForNetwork == waitingForNetwork));
}


@override
int get hashCode {
    return Object.hash(runtimeType,station,attempt,nextAttemptAt,waitingForNetwork);
}

@override
String toString() {
    return 'PlaybackStatus.reconnecting(station: $station, attempt: $attempt, nextAttemptAt: $nextAttemptAt, waitingForNetwork: $waitingForNetwork)';
}


}

/// @nodoc
abstract mixin class $ReconnectingCopyWith<$Res> implements $PlaybackStatusCopyWith<$Res> {
  factory $ReconnectingCopyWith(Reconnecting value, $Res Function(Reconnecting) _then) = _$ReconnectingCopyWithImpl;
@useResult
$Res call({
 Station station, int attempt, DateTime? nextAttemptAt, bool waitingForNetwork
});


$StationCopyWith<$Res> get station;

}
/// @nodoc
class _$ReconnectingCopyWithImpl<$Res>
    implements $ReconnectingCopyWith<$Res> {
  _$ReconnectingCopyWithImpl(this._self, this._then);

  final Reconnecting _self;
  final $Res Function(Reconnecting) _then;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? station = null,Object? attempt = null,Object? nextAttemptAt = freezed,Object? waitingForNetwork = null,}) {
  return _then(Reconnecting(
station: null == station ? _self.station : station // ignore: cast_nullable_to_non_nullable
as Station,attempt: null == attempt ? _self.attempt : attempt // ignore: cast_nullable_to_non_nullable
as int,nextAttemptAt: freezed == nextAttemptAt ? _self.nextAttemptAt : nextAttemptAt // ignore: cast_nullable_to_non_nullable
as DateTime?,waitingForNetwork: null == waitingForNetwork ? _self.waitingForNetwork : waitingForNetwork // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationCopyWith<$Res> get station {
  
  return $StationCopyWith<$Res>(_self.station, (value) {
    return _then(_self.copyWith(station: value));
  });
}
}

/// @nodoc


class Interrupted extends PlaybackStatus {
  const Interrupted({required this.station}): super._();
  

 final  Station station;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InterruptedCopyWith<Interrupted> get copyWith => _$InterruptedCopyWithImpl<Interrupted>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Interrupted&&(identical(other.station, station) || other.station == station));
}


@override
int get hashCode {
    return Object.hash(runtimeType,station);
}

@override
String toString() {
    return 'PlaybackStatus.interrupted(station: $station)';
}


}

/// @nodoc
abstract mixin class $InterruptedCopyWith<$Res> implements $PlaybackStatusCopyWith<$Res> {
  factory $InterruptedCopyWith(Interrupted value, $Res Function(Interrupted) _then) = _$InterruptedCopyWithImpl;
@useResult
$Res call({
 Station station
});


$StationCopyWith<$Res> get station;

}
/// @nodoc
class _$InterruptedCopyWithImpl<$Res>
    implements $InterruptedCopyWith<$Res> {
  _$InterruptedCopyWithImpl(this._self, this._then);

  final Interrupted _self;
  final $Res Function(Interrupted) _then;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? station = null,}) {
  return _then(Interrupted(
station: null == station ? _self.station : station // ignore: cast_nullable_to_non_nullable
as Station,
  ));
}

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationCopyWith<$Res> get station {
  
  return $StationCopyWith<$Res>(_self.station, (value) {
    return _then(_self.copyWith(station: value));
  });
}
}

/// @nodoc


class Paused extends PlaybackStatus {
  const Paused({required this.station}): super._();
  

 final  Station station;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PausedCopyWith<Paused> get copyWith => _$PausedCopyWithImpl<Paused>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is Paused&&(identical(other.station, station) || other.station == station));
}


@override
int get hashCode {
    return Object.hash(runtimeType,station);
}

@override
String toString() {
    return 'PlaybackStatus.paused(station: $station)';
}


}

/// @nodoc
abstract mixin class $PausedCopyWith<$Res> implements $PlaybackStatusCopyWith<$Res> {
  factory $PausedCopyWith(Paused value, $Res Function(Paused) _then) = _$PausedCopyWithImpl;
@useResult
$Res call({
 Station station
});


$StationCopyWith<$Res> get station;

}
/// @nodoc
class _$PausedCopyWithImpl<$Res>
    implements $PausedCopyWith<$Res> {
  _$PausedCopyWithImpl(this._self, this._then);

  final Paused _self;
  final $Res Function(Paused) _then;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? station = null,}) {
  return _then(Paused(
station: null == station ? _self.station : station // ignore: cast_nullable_to_non_nullable
as Station,
  ));
}

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationCopyWith<$Res> get station {
  
  return $StationCopyWith<$Res>(_self.station, (value) {
    return _then(_self.copyWith(station: value));
  });
}
}

/// @nodoc


class PlaybackError extends PlaybackStatus {
  const PlaybackError({required this.station, required this.kind}): super._();
  

 final  Station station;
 final  PlaybackErrorKind kind;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaybackErrorCopyWith<PlaybackError> get copyWith => _$PlaybackErrorCopyWithImpl<PlaybackError>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is PlaybackError&&(identical(other.station, station) || other.station == station)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode {
    return Object.hash(runtimeType,station,kind);
}

@override
String toString() {
    return 'PlaybackStatus.error(station: $station, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $PlaybackErrorCopyWith<$Res> implements $PlaybackStatusCopyWith<$Res> {
  factory $PlaybackErrorCopyWith(PlaybackError value, $Res Function(PlaybackError) _then) = _$PlaybackErrorCopyWithImpl;
@useResult
$Res call({
 Station station, PlaybackErrorKind kind
});


$StationCopyWith<$Res> get station;

}
/// @nodoc
class _$PlaybackErrorCopyWithImpl<$Res>
    implements $PlaybackErrorCopyWith<$Res> {
  _$PlaybackErrorCopyWithImpl(this._self, this._then);

  final PlaybackError _self;
  final $Res Function(PlaybackError) _then;

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? station = null,Object? kind = null,}) {
  return _then(PlaybackError(
station: null == station ? _self.station : station // ignore: cast_nullable_to_non_nullable
as Station,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as PlaybackErrorKind,
  ));
}

/// Create a copy of PlaybackStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationCopyWith<$Res> get station {
  
  return $StationCopyWith<$Res>(_self.station, (value) {
    return _then(_self.copyWith(station: value));
  });
}
}

// dart format on
