import 'package:flutter_test/flutter_test.dart';
import 'package:worksheets_cc/src/models/font_catalog.dart';

void main() {
  group('FontCatalog', () {
    test('allFonts is not empty', () {
      expect(FontCatalog.allFonts, isNotEmpty);
    });

    test('allFonts is sorted alphabetically', () {
      final sorted = List<String>.from(FontCatalog.allFonts)..sort();
      expect(FontCatalog.allFonts, sorted);
    });

    test('allFonts contains Roboto (default)', () {
      expect(FontCatalog.allFonts, contains('Roboto'));
    });

    test('allFonts has no duplicates', () {
      expect(FontCatalog.allFonts.toSet().length, FontCatalog.allFonts.length);
    });

    test('googleFonts is a subset of allFonts', () {
      for (final font in FontCatalog.googleFonts) {
        expect(FontCatalog.allFonts, contains(font),
            reason: '$font is in googleFonts but not in allFonts');
      }
    });

    test('isGoogleFont returns true for Google Fonts', () {
      expect(FontCatalog.isGoogleFont('Lato'), isTrue);
      expect(FontCatalog.isGoogleFont('Roboto'), isTrue);
      expect(FontCatalog.isGoogleFont('Pacifico'), isTrue);
    });

    test('isGoogleFont returns false for system fonts', () {
      expect(FontCatalog.isGoogleFont('Arial'), isFalse);
      expect(FontCatalog.isGoogleFont('Times New Roman'), isFalse);
      expect(FontCatalog.isGoogleFont('Courier New'), isFalse);
    });

    test('isGoogleFont returns false for unknown fonts', () {
      expect(FontCatalog.isGoogleFont('NotAFont'), isFalse);
    });
  });
}
