import '../../../../core/text/cp1251.dart';
import '../../../../core/text/icy_charset.dart';
import '../../../../core/text/sanitize.dart';
import '../../../catalog/domain/station.dart';
import '../../domain/now_playing.dart';

const _separator = ' - ';

/// Turns a raw ICY `StreamTitle` into a [NowPlaying], or null when the title
/// carries nothing worth showing.
///
/// Pipeline order:
/// 1. [repairCp1251] with [charset], the `icyCharset` of the stream that is
///    playing. Repair runs first on purpose: cp1251 punctuation („ “ –)
///    arrives as U+0080–U+009F, which the sanitiser would delete.
/// 2. [sanitizeIcyText]: strip controls and bidi overrides, collapse
///    whitespace, clamp to 200 code points.
/// 3. Junk filter: empty, '-', the station's name or Latin name (any case),
///    or anything URL-like ('://' anywhere, or a leading 'www.').
/// 4. Split on the first ' - ' into artist and title. A dangling separator
///    ('Artist - ' or ' - Title') leaves a title only.
NowPlaying? parseIcyTitle(
  String? raw, {
  required Station station,
  required IcyCharset charset,
}) {
  if (raw == null) return null;
  final text = _dropDanglingSeparator(
    sanitizeIcyText(repairCp1251(raw, hint: charset)),
  );
  if (_isJunk(text, station)) return null;

  final at = text.indexOf(_separator);
  if (at > 0) {
    final artist = text.substring(0, at).trim();
    final title = text.substring(at + _separator.length).trim();
    if (artist.isNotEmpty && title.isNotEmpty) {
      return NowPlaying(artist: artist, title: title, text: text);
    }
  }
  return NowPlaying(title: text, text: text);
}

/// Removes a separator left over from an empty artist or title:
/// 'Artist -' becomes 'Artist' and '- Title' becomes 'Title'. The input is
/// already sanitised, so the ends are trimmed and spaces are single.
String _dropDanglingSeparator(String text) {
  var result = text;
  if (result.endsWith(' -')) {
    result = result.substring(0, result.length - 2).trimRight();
  }
  if (result.startsWith('- ')) {
    result = result.substring(2).trimLeft();
  }
  return result;
}

bool _isJunk(String text, Station station) {
  if (text.isEmpty || text == '-') return true;
  final lower = text.toLowerCase();
  if (lower == station.name.toLowerCase() ||
      lower == station.nameLatin.toLowerCase()) {
    return true;
  }
  return lower.contains('://') || lower.startsWith('www.');
}
