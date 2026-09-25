/// Cleans untrusted ICY text before it can reach the notification, the lock
/// screen or a car display.
///
/// - Whitespace controls (tab, line feed, vertical tab, form feed and
///   carriage return) become a space, so words are never glued together.
/// - Every other C0 control (U+0000–U+001F), DEL and C1 control
///   (U+007F–U+009F) is removed.
/// - Bidi overrides and embeddings (U+202A–U+202E) and bidi isolates
///   (U+2066–U+2069) are removed, so a title cannot reverse or reorder the
///   text around it.
/// - Whitespace runs collapse to one space and the ends are trimmed.
/// - The result is clamped to [maxCodePoints] Unicode code points. It is cut
///   by runes, so a surrogate pair (an emoji) is never split.
///
/// Run windows-1251 repair first: repair maps U+0080–U+009F back to cp1251
/// punctuation („ “ –), which this function would otherwise delete.
String sanitizeIcyText(String input, {int maxCodePoints = 200}) {
  final cleaned = StringBuffer();
  for (final rune in input.runes) {
    if (_isWhitespaceControl(rune)) {
      cleaned.write(' ');
    } else if (!_isStripped(rune)) {
      cleaned.writeCharCode(rune);
    }
  }
  final collapsed = cleaned.toString().replaceAll(_whitespaceRun, ' ').trim();
  final runes = collapsed.runes;
  if (runes.length <= maxCodePoints) return collapsed;
  return String.fromCharCodes(runes.take(maxCodePoints)).trim();
}

final _whitespaceRun = RegExp(r'\s+');

bool _isWhitespaceControl(int rune) => rune >= 0x09 && rune <= 0x0D;

bool _isStripped(int rune) =>
    rune <= 0x1F ||
    (rune >= 0x7F && rune <= 0x9F) ||
    (rune >= 0x202A && rune <= 0x202E) ||
    (rune >= 0x2066 && rune <= 0x2069);
