import 'playlist_text.dart';

final _fileKey = RegExp(r'^file(\d+)\s*=(.*)$', caseSensitive: false);

/// Parses a Shoutcast/Winamp `.pls` playlist into its stream URLs.
///
/// Tolerant of what real servers send: a leading BOM, CRLF line endings,
/// `file1=`/`File1=`/`FILE1=` keys and a missing `NumberOfEntries`. Entries
/// are ordered by their numeric index (File2 before File10), relative entries
/// are resolved against [base], and a duplicate URL is kept once, at its first
/// position. Entries are returned whatever their scheme; the resolver filters.
List<Uri> parsePls(String body, Uri base) {
  final entries = <(int, String)>[];
  for (final line in playlistLines(body)) {
    final match = _fileKey.firstMatch(line);
    if (match == null) continue;
    final index = int.tryParse(match.group(1)!);
    final value = match.group(2)!.trim();
    if (index == null || value.isEmpty) continue;
    entries.add((index, value));
  }
  // List.sort is not guaranteed stable; sort indices with the original
  // position as the tie-breaker so repeated FileN keys keep file order.
  final indexed = entries.indexed.toList()
    ..sort((a, b) {
      final byIndex = a.$2.$1.compareTo(b.$2.$1);
      return byIndex != 0 ? byIndex : a.$1.compareTo(b.$1);
    });
  return resolveEntries([for (final (_, (_, value)) in indexed) value], base);
}
