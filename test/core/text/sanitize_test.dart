import 'package:flutter_test/flutter_test.dart';
import 'package:radio/core/text/sanitize.dart';

/// True when [s] contains a high surrogate without a following low surrogate,
/// or a low surrogate without a preceding high surrogate.
bool hasLoneSurrogate(String s) {
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    final isHigh = u >= 0xD800 && u <= 0xDBFF;
    final isLow = u >= 0xDC00 && u <= 0xDFFF;
    if (isHigh) {
      final next = i + 1 < units.length ? units[i + 1] : -1;
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++;
    } else if (isLow) {
      return true;
    }
  }
  return false;
}

void main() {
  group('sanitizeIcyText strips hostile characters', () {
    test('C0 controls U+0000..U+001F are removed', () {
      expect(sanitizeIcyText('A\u0000B\u0007C\u001BD\u001F'), 'ABCD');
    });

    test('DEL and C1 controls U+007F..U+009F are removed', () {
      expect(sanitizeIcyText('A\u007FB\u0080C\u0085D\u009F'), 'ABCD');
    });

    test('bidi overrides U+202A..U+202E are removed', () {
      expect(
        sanitizeIcyText('A\u202AB\u202BC\u202CD\u202DE\u202EF'),
        'ABCDEF',
      );
    });

    test('bidi isolates U+2066..U+2069 are removed', () {
      expect(sanitizeIcyText('A\u2066B\u2067C\u2068D\u2069E'), 'ABCDE');
    });

    test('Cyrillic, accents and typographic punctuation are kept', () {
      expect(
        sanitizeIcyText('Артист – „Песен“ · Mötley Crüe'),
        'Артист – „Песен“ · Mötley Crüe',
      );
    });
  });

  group('sanitizeIcyText whitespace', () {
    test('whitespace runs collapse to one space and the ends are trimmed', () {
      expect(
        sanitizeIcyText('   Artist \t\n   -    Title  \r\n'),
        'Artist - Title',
      );
    });

    test('a tab or newline between words becomes a space, not a join', () {
      expect(sanitizeIcyText('Artist\tTitle\nMore'), 'Artist Title More');
    });

    test('removing a control does not leave a double space', () {
      expect(sanitizeIcyText('A \u0000 B'), 'A B');
    });

    test('empty and whitespace-only input become empty', () {
      expect(sanitizeIcyText(''), '');
      expect(sanitizeIcyText(' \t\n '), '');
    });
  });

  group('sanitizeIcyText clamp', () {
    test('a long title is clamped to 200 code points', () {
      final result = sanitizeIcyText('a' * 250);
      expect(result.runes.length, 200);
      expect(result, 'a' * 200);
    });

    test('a title of exactly 200 code points is unchanged', () {
      final input = 'a' * 200;
      expect(sanitizeIcyText(input), input);
    });

    test('199 chars then an emoji keep the whole emoji, no lone surrogate', () {
      final result = sanitizeIcyText('${'a' * 199}😀😀tail');
      expect(result, '${'a' * 199}😀');
      expect(result.runes.length, 200);
      expect(hasLoneSurrogate(result), isFalse);
    });

    test('an emoji straddling the UTF-16 limit is never split', () {
      // 200 code points but 201 UTF-16 code units: nothing is cut.
      final input = '${'a' * 199}😀';
      final result = sanitizeIcyText(input);
      expect(result, input);
      expect(hasLoneSurrogate(result), isFalse);
    });

    test('a space at the cut point is trimmed after clamping', () {
      expect(sanitizeIcyText('${'a' * 199} bcd'), 'a' * 199);
    });

    test('maxCodePoints can be lowered', () {
      expect(sanitizeIcyText('Артист - Песен', maxCodePoints: 6), 'Артист');
    });
  });
}
