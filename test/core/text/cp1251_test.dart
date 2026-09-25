import 'package:flutter_test/flutter_test.dart';
import 'package:radio/core/text/cp1251.dart';
import 'package:radio/core/text/icy_charset.dart';

void main() {
  group('repairCp1251 (auto)', () {
    test('windows-1251 mojibake becomes Cyrillic', () {
      expect(repairCp1251('Àðòèñò - Ïåñåí'), 'Артист - Песен');
    });

    test('every cp1251 letter byte 0xC0..0xFF maps to А..я', () {
      final mojibake = String.fromCharCodes([for (var b = 0xC0; b <= 0xFF; b++) b]);
      final cyrillic =
          String.fromCharCodes([for (var c = 0x0410; c <= 0x044F; c++) c]);
      expect(repairCp1251(mojibake), cyrillic);
    });

    test('Ё and ё (bytes 0xA8, 0xB8) are repaired', () {
      expect(repairCp1251('¨ëêà è ¸ëõà'), 'Ёлка и ёлха');
    });

    test('cp1251 punctuation „ “ ” – arriving as C1 controls is kept', () {
      expect(
        repairCp1251(
          'Àðòèñò \u0096 \u0084Ïúðâà\u0093 è \u0084Âòîðà\u0094',
        ),
        'Артист – „Първа“ и „Втора”',
      );
    });

    test('punctuation double-encoded through cp1252 is kept', () {
      expect(
        repairCp1251('„Ïåñåí“ – Àðòèñò'),
        '„Песен“ – Артист',
      );
    });

    for (final western in [
      'Mötley Crüe',
      'Beyoncé',
      'Björk',
      'Sigur Rós',
      'Mötley Crüe - Kickstart My Heart',
      'Sigur Rós - Hoppípolla',
    ]) {
      test('Western accented title "$western" is unchanged', () {
        expect(repairCp1251(western), western);
      });
    }

    test('pure ASCII is unchanged', () {
      expect(
        repairCp1251('Queen - Bohemian Rhapsody'),
        'Queen - Bohemian Rhapsody',
      );
    });

    test('already-Cyrillic input is unchanged', () {
      expect(repairCp1251('Артист - Песен'), 'Артист - Песен');
    });

    test('genuine Unicode outside Latin-1 is unchanged', () {
      expect(repairCp1251('Αλφα ✓ Ïåñåí'), 'Αλφα ✓ Ïåñåí');
    });

    test('empty input is unchanged', () {
      expect(repairCp1251(''), '');
    });

    test('auto skips a two-letter mojibake inside a Latin title', () {
      expect(repairCp1251('Rock Àç'), 'Rock Àç');
    });
  });

  group('repairCp1251 hints', () {
    test('hint utf8 returns the input unchanged', () {
      expect(
        repairCp1251('Àðòèñò - Ïåñåí', hint: IcyCharset.utf8),
        'Àðòèñò - Ïåñåí',
      );
    });

    test('hint cp1251 forces repair of a two-letter mojibake', () {
      expect(repairCp1251('Rock Àç', hint: IcyCharset.cp1251), 'Rock Аз');
    });

    test('hint cp1251 still leaves real Cyrillic alone', () {
      expect(
        repairCp1251('Артист - Песен', hint: IcyCharset.cp1251),
        'Артист - Песен',
      );
    });
  });
}
