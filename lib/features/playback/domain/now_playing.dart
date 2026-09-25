import 'package:freezed_annotation/freezed_annotation.dart';

part 'now_playing.freezed.dart';

/// What the station says is on air, parsed from its ICY `StreamTitle`.
///
/// Every field is already repaired and sanitised. Value equality matters: the
/// handler republishes the notification only when the value changes.
@freezed
class NowPlaying with _$NowPlaying {
  const NowPlaying({this.artist, this.title, required this.text});

  /// The part before the first ' - ', or null when the title has no artist.
  final String? artist;

  /// The part after the first ' - ', or the whole line when there is no
  /// artist.
  final String? title;

  /// The full sanitised line, for places that show a single line of text.
  final String text;
}
