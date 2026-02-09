import 'package:flutter/material.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheets_cc/src/models/border_catalog.dart';

const _solid = BorderStyle(width: 1.0, lineStyle: BorderLineStyle.solid);

/// Helper: true when the border side has a solid style.
bool _isSolid(BorderStyle b) => b.lineStyle == BorderLineStyle.solid;
bool _isNone(BorderStyle b) => b.isNone;

void main() {
  // 3x3 range: rows 0-2, columns 0-2
  const range = CellRange(0, 0, 2, 2);

  group('allBorders', () {
    test('every cell gets all 4 sides', () {
      for (final cell in range.cells) {
        final b = BorderCatalog.bordersForCell(
          BorderPreset.allBorders, cell, range,
        );
        expect(b, const CellBorders.all(_solid));
      }
    });
  });

  group('outerBorders', () {
    test('top-left corner gets top + left', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.outerBorders, const CellCoordinate(0, 0), range,
      );
      expect(_isSolid(b.top), isTrue);
      expect(_isSolid(b.left), isTrue);
      expect(_isNone(b.bottom), isTrue);
      expect(_isNone(b.right), isTrue);
    });

    test('center cell gets no borders', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.outerBorders, const CellCoordinate(1, 1), range,
      );
      expect(b, CellBorders.none);
    });

    test('top-center edge gets top only', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.outerBorders, const CellCoordinate(0, 1), range,
      );
      expect(_isSolid(b.top), isTrue);
      expect(_isNone(b.bottom), isTrue);
      expect(_isNone(b.left), isTrue);
      expect(_isNone(b.right), isTrue);
    });

    test('bottom-right corner gets bottom + right', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.outerBorders, const CellCoordinate(2, 2), range,
      );
      expect(_isSolid(b.bottom), isTrue);
      expect(_isSolid(b.right), isTrue);
      expect(_isNone(b.top), isTrue);
      expect(_isNone(b.left), isTrue);
    });
  });

  group('innerBorders', () {
    test('top-left corner gets right + bottom', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.innerBorders, const CellCoordinate(0, 0), range,
      );
      expect(_isNone(b.top), isTrue);
      expect(_isNone(b.left), isTrue);
      expect(_isSolid(b.right), isTrue);
      expect(_isSolid(b.bottom), isTrue);
    });

    test('center cell gets all 4 sides', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.innerBorders, const CellCoordinate(1, 1), range,
      );
      expect(b, const CellBorders.all(_solid));
    });

    test('bottom-right corner gets top + left only', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.innerBorders, const CellCoordinate(2, 2), range,
      );
      expect(_isSolid(b.top), isTrue);
      expect(_isSolid(b.left), isTrue);
      expect(_isNone(b.bottom), isTrue);
      expect(_isNone(b.right), isTrue);
    });
  });

  group('horizontalBorders', () {
    test('all cells get top + bottom', () {
      for (final cell in range.cells) {
        final b = BorderCatalog.bordersForCell(
          BorderPreset.horizontalBorders, cell, range,
        );
        expect(_isSolid(b.top), isTrue);
        expect(_isSolid(b.bottom), isTrue);
        expect(_isNone(b.left), isTrue);
        expect(_isNone(b.right), isTrue);
      }
    });
  });

  group('verticalBorders', () {
    test('all cells get left + right', () {
      for (final cell in range.cells) {
        final b = BorderCatalog.bordersForCell(
          BorderPreset.verticalBorders, cell, range,
        );
        expect(_isNone(b.top), isTrue);
        expect(_isNone(b.bottom), isTrue);
        expect(_isSolid(b.left), isTrue);
        expect(_isSolid(b.right), isTrue);
      }
    });
  });

  group('leftBorder', () {
    test('all cells get left only', () {
      for (final cell in range.cells) {
        final b = BorderCatalog.bordersForCell(
          BorderPreset.leftBorder, cell, range,
        );
        expect(_isSolid(b.left), isTrue);
        expect(_isNone(b.top), isTrue);
        expect(_isNone(b.bottom), isTrue);
        expect(_isNone(b.right), isTrue);
      }
    });
  });

  group('clearBorders', () {
    test('all cells get CellBorders.none', () {
      for (final cell in range.cells) {
        final b = BorderCatalog.bordersForCell(
          BorderPreset.clearBorders, cell, range,
        );
        expect(b, CellBorders.none);
      }
    });
  });

  group('single-cell range', () {
    test('outerBorders gives all 4 sides', () {
      const singleRange = CellRange(3, 3, 3, 3);
      final b = BorderCatalog.bordersForCell(
        BorderPreset.outerBorders, const CellCoordinate(3, 3), singleRange,
      );
      expect(b, const CellBorders.all(_solid));
    });
  });

  group('custom pen style', () {
    test('allBorders applies custom color and width', () {
      const color = Color(0xFFFF0000);
      const width = 2.0;
      final b = BorderCatalog.bordersForCell(
        BorderPreset.allBorders,
        const CellCoordinate(0, 0),
        range,
        borderColor: color,
        borderWidth: width,
      );
      expect(b.top.color, color);
      expect(b.top.width, width);
      expect(b.top.lineStyle, BorderLineStyle.solid);
      expect(b.right.color, color);
      expect(b.bottom.color, color);
      expect(b.left.color, color);
    });

    test('dashed line style is applied', () {
      final b = BorderCatalog.bordersForCell(
        BorderPreset.topBorder,
        const CellCoordinate(0, 0),
        range,
        borderLineStyle: BorderLineStyle.dashed,
      );
      expect(b.top.lineStyle, BorderLineStyle.dashed);
      expect(_isNone(b.bottom), isTrue);
    });
  });

  group('BorderLineOption', () {
    test('equality by width and lineStyle', () {
      const a = BorderLineOption('Thin', 1.0, BorderLineStyle.solid);
      const b = BorderLineOption('Thin', 1.0, BorderLineStyle.solid);
      const c = BorderLineOption('Thick', 3.0, BorderLineStyle.solid);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
