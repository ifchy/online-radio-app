import 'playlist_text.dart';

/// True when [body] is an HLS playlist: its first non-empty line is `#EXTM3U`
/// and it has at least one `#EXT-X-` tag. The Content-Type alone is not
/// decisive, because `audio/x-mpegurl` is also used for plain M3U lists.
bool isHlsPlaylist(String body) {
  final lines = playlistLines(body).where((line) => line.isNotEmpty);
  if (lines.isEmpty || !lines.first.startsWith('#EXTM3U')) return false;
  return lines.any((line) => line.startsWith('#EXT-X-'));
}

/// Parses a plain or extended M3U list into its entries: the non-empty lines
/// that do not start with `#`, in order, resolved against [base] and kept once
/// at their first position. Entries are returned whatever their scheme; the
/// resolver filters.
List<Uri> parseM3u(String body, Uri base) => resolveEntries(
  playlistLines(body).where((line) => line.isNotEmpty && !line.startsWith('#')),
  base,
);
