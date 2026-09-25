// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'station.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StationId {


/// Create a copy of StationId
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StationIdCopyWith<StationId> get copyWith => _$StationIdCopyWithImpl<StationId>(this as StationId, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StationId;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StationId&&(identical(other.namespace, _this.namespace) || other.namespace == _this.namespace)&&(identical(other.key, _this.key) || other.key == _this.key));
}


@override
int get hashCode {
  final _this = this as StationId;
  return Object.hash(runtimeType,_this.namespace,_this.key);
}

@override
String toString() {
  final _this = this as StationId;
  return 'StationId(namespace: ${_this.namespace}, key: ${_this.key})';
}


}

/// @nodoc
abstract mixin class $StationIdCopyWith<$Res>  {
  factory $StationIdCopyWith(StationId value, $Res Function(StationId) _then) = _$StationIdCopyWithImpl;
@useResult
$Res call({
 StationNamespace namespace, String key
});




}
/// @nodoc
class _$StationIdCopyWithImpl<$Res>
    implements $StationIdCopyWith<$Res> {
  _$StationIdCopyWithImpl(this._self, this._then);

  final StationId _self;
  final $Res Function(StationId) _then;

/// Create a copy of StationId
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? namespace = null,Object? key = null,}) {
  return _then(StationId(
null == namespace ? _self.namespace : namespace // ignore: cast_nullable_to_non_nullable
as StationNamespace,null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [StationId].
extension StationIdPatterns on StationId {
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

/// @nodoc
mixin _$StationStream {


/// Create a copy of StationStream
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StationStreamCopyWith<StationStream> get copyWith => _$StationStreamCopyWithImpl<StationStream>(this as StationStream, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as StationStream;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StationStream&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.codec, _this.codec) || other.codec == _this.codec)&&(identical(other.bitrateKbps, _this.bitrateKbps) || other.bitrateKbps == _this.bitrateKbps)&&(identical(other.icyCharset, _this.icyCharset) || other.icyCharset == _this.icyCharset));
}


@override
int get hashCode {
  final _this = this as StationStream;
  return Object.hash(runtimeType,_this.url,_this.kind,_this.codec,_this.bitrateKbps,_this.icyCharset);
}

@override
String toString() {
  final _this = this as StationStream;
  return 'StationStream(url: ${_this.url}, kind: ${_this.kind}, codec: ${_this.codec}, bitrateKbps: ${_this.bitrateKbps}, icyCharset: ${_this.icyCharset})';
}


}

/// @nodoc
abstract mixin class $StationStreamCopyWith<$Res>  {
  factory $StationStreamCopyWith(StationStream value, $Res Function(StationStream) _then) = _$StationStreamCopyWithImpl;
@useResult
$Res call({
 Uri url, StreamKind kind, String? codec, int? bitrateKbps, IcyCharset icyCharset
});




}
/// @nodoc
class _$StationStreamCopyWithImpl<$Res>
    implements $StationStreamCopyWith<$Res> {
  _$StationStreamCopyWithImpl(this._self, this._then);

  final StationStream _self;
  final $Res Function(StationStream) _then;

/// Create a copy of StationStream
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? kind = null,Object? codec = freezed,Object? bitrateKbps = freezed,Object? icyCharset = null,}) {
  return _then(StationStream(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as Uri,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as StreamKind,codec: freezed == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String?,bitrateKbps: freezed == bitrateKbps ? _self.bitrateKbps : bitrateKbps // ignore: cast_nullable_to_non_nullable
as int?,icyCharset: null == icyCharset ? _self.icyCharset : icyCharset // ignore: cast_nullable_to_non_nullable
as IcyCharset,
  ));
}

}


/// Adds pattern-matching-related methods to [StationStream].
extension StationStreamPatterns on StationStream {
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

/// @nodoc
mixin _$Station {


/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StationCopyWith<Station> get copyWith => _$StationCopyWithImpl<Station>(this as Station, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Station;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Station&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.nameLatin, _this.nameLatin) || other.nameLatin == _this.nameLatin)&&const DeepCollectionEquality().equals(other.streams, _this.streams)&&(identical(other.homepage, _this.homepage) || other.homepage == _this.homepage));
}


@override
int get hashCode {
  final _this = this as Station;
  return Object.hash(runtimeType,_this.id,_this.name,_this.nameLatin,const DeepCollectionEquality().hash(_this.streams),_this.homepage);
}

@override
String toString() {
  final _this = this as Station;
  return 'Station(id: ${_this.id}, name: ${_this.name}, nameLatin: ${_this.nameLatin}, streams: ${_this.streams}, homepage: ${_this.homepage})';
}


}

/// @nodoc
abstract mixin class $StationCopyWith<$Res>  {
  factory $StationCopyWith(Station value, $Res Function(Station) _then) = _$StationCopyWithImpl;
@useResult
$Res call({
 StationId id, String name, String nameLatin, List<StationStream> streams, Uri? homepage
});


$StationIdCopyWith<$Res> get id;

}
/// @nodoc
class _$StationCopyWithImpl<$Res>
    implements $StationCopyWith<$Res> {
  _$StationCopyWithImpl(this._self, this._then);

  final Station _self;
  final $Res Function(Station) _then;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? nameLatin = null,Object? streams = null,Object? homepage = freezed,}) {
  return _then(Station(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as StationId,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nameLatin: null == nameLatin ? _self.nameLatin : nameLatin // ignore: cast_nullable_to_non_nullable
as String,streams: null == streams ? _self.streams : streams // ignore: cast_nullable_to_non_nullable
as List<StationStream>,homepage: freezed == homepage ? _self.homepage : homepage // ignore: cast_nullable_to_non_nullable
as Uri?,
  ));
}
/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StationIdCopyWith<$Res> get id {
  
  return $StationIdCopyWith<$Res>(_self.id, (value) {
    return _then(_self.copyWith(id: value));
  });
}
}


/// Adds pattern-matching-related methods to [Station].
extension StationPatterns on Station {
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
