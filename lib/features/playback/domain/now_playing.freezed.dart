// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'now_playing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NowPlaying {


/// Create a copy of NowPlaying
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NowPlayingCopyWith<NowPlaying> get copyWith => _$NowPlayingCopyWithImpl<NowPlaying>(this as NowPlaying, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NowPlaying;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NowPlaying&&(identical(other.artist, _this.artist) || other.artist == _this.artist)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.text, _this.text) || other.text == _this.text));
}


@override
int get hashCode {
  final _this = this as NowPlaying;
  return Object.hash(runtimeType,_this.artist,_this.title,_this.text);
}

@override
String toString() {
  final _this = this as NowPlaying;
  return 'NowPlaying(artist: ${_this.artist}, title: ${_this.title}, text: ${_this.text})';
}


}

/// @nodoc
abstract mixin class $NowPlayingCopyWith<$Res>  {
  factory $NowPlayingCopyWith(NowPlaying value, $Res Function(NowPlaying) _then) = _$NowPlayingCopyWithImpl;
@useResult
$Res call({
 String? artist, String? title, String text
});




}
/// @nodoc
class _$NowPlayingCopyWithImpl<$Res>
    implements $NowPlayingCopyWith<$Res> {
  _$NowPlayingCopyWithImpl(this._self, this._then);

  final NowPlaying _self;
  final $Res Function(NowPlaying) _then;

/// Create a copy of NowPlaying
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? artist = freezed,Object? title = freezed,Object? text = null,}) {
  return _then(NowPlaying(
artist: freezed == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NowPlaying].
extension NowPlayingPatterns on NowPlaying {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}

// dart format on
