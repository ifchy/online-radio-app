## Deferred Items

- `dart format` would reformat four files that 01-07 did not touch: lib/core/text/cp1251.dart, test/core/text/cp1251_test.dart, test/core/text/sanitize_test.dart and test/features/playback/engine/icy/now_playing_parser_test.dart (these came from 01-06). CI does not check formatting, so nothing fails. Either run `dart format lib test` once in a separate style commit, or add `dart format --set-exit-if-changed lib test` to CI.
  status: open
  **Found during:** 01-07 Task 1. It is out of scope, so it was left as is.
