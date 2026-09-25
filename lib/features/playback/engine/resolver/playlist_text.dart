/// Shared text handling for the playlist parsers.
library;

/// The trimmed lines of a playlist body: a leading BOM is removed and both
/// `\n` and `\r\n` line endings are accepted.
Iterable<String> playlistLines(String body) {
  final text = body.startsWith('﻿') ? body.substring(1) : body;
  return text.split(RegExp(r'\r?\n|\r')).map((line) => line.trim());
}

/// Resolves [values] against [base], in order, dropping values that are not
/// valid URIs and keeping each URL once at its first position.
List<Uri> resolveEntries(Iterable<String> values, Uri base) {
  final seen = <Uri>{};
  final result = <Uri>[];
  for (final value in values) {
    final Uri uri;
    try {
      uri = base.resolve(value);
    } on FormatException {
      continue;
    }
    if (seen.add(uri)) result.add(uri);
  }
  return result;
}
