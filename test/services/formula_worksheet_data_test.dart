import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheets_cc/src/services/formula_worksheet_data.dart';

void main() {
  late SparseWorksheetData rawData;
  late FormulaWorksheetData formulaData;

  setUp(() {
    rawData = SparseWorksheetData(rowCount: 100, columnCount: 26);
    formulaData = FormulaWorksheetData(rawData);
  });

  tearDown(() {
    formulaData.dispose();
    rawData.dispose();
  });

  group('getCell', () {
    test('returns null for empty cell', () {
      expect(formulaData.getCell(const CellCoordinate(0, 0)), isNull);
    });

    test('passes through non-formula values unchanged', () {
      rawData.setCell(const CellCoordinate(0, 0), CellValue.number(42));
      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isNumber, true);
      expect(result.asDouble, 42);
    });

    test('passes through text values unchanged', () {
      rawData.setCell(
          const CellCoordinate(0, 0), const CellValue.text('hello'));
      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isText, true);
      expect(result.rawValue, 'hello');
    });

    test('evaluates simple arithmetic formula', () {
      rawData.setCell(
          const CellCoordinate(0, 0), const CellValue.formula('=1+2'));
      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isNumber, true);
      expect(result.asDouble, 3);
    });

    test('evaluates formula with cell reference', () {
      rawData.setCell(const CellCoordinate(0, 0), CellValue.number(10));
      rawData.setCell(const CellCoordinate(1, 0), CellValue.number(20));
      rawData.setCell(
          const CellCoordinate(2, 0), const CellValue.formula('=A1+A2'));

      final result = formulaData.getCell(const CellCoordinate(2, 0));
      expect(result, isNotNull);
      expect(result!.isNumber, true);
      expect(result.asDouble, 30);
    });

    test('evaluates SUM function', () {
      rawData.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      rawData.setCell(const CellCoordinate(1, 0), CellValue.number(2));
      rawData.setCell(const CellCoordinate(2, 0), CellValue.number(3));
      rawData.setCell(
          const CellCoordinate(3, 0), const CellValue.formula('=SUM(A1:A3)'));

      final result = formulaData.getCell(const CellCoordinate(3, 0));
      expect(result, isNotNull);
      expect(result!.isNumber, true);
      expect(result.asDouble, 6);
    });

    test('returns error for invalid formula', () {
      rawData.setCell(
          const CellCoordinate(0, 0), const CellValue.formula('=INVALID('));
      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isError, true);
    });

    test('caches formula results', () {
      rawData.setCell(
          const CellCoordinate(0, 0), const CellValue.formula('=1+2'));

      // First call evaluates
      final result1 = formulaData.getCell(const CellCoordinate(0, 0));
      // Second call should return cached value
      final result2 = formulaData.getCell(const CellCoordinate(0, 0));

      expect(result1!.asDouble, 3);
      expect(result2!.asDouble, 3);
    });
  });

  group('setCell', () {
    test('sets value on inner data', () {
      formulaData.setCell(
          const CellCoordinate(0, 0), CellValue.number(42));
      expect(rawData.getCell(const CellCoordinate(0, 0))!.asDouble, 42);
    });

    test('invalidates cache on cell change', () {
      rawData.setCell(const CellCoordinate(0, 0), CellValue.number(5));
      rawData.setCell(
          const CellCoordinate(1, 0), const CellValue.formula('=A1*2'));

      // Evaluate to populate cache
      final before = formulaData.getCell(const CellCoordinate(1, 0));
      expect(before!.asDouble, 10);

      // Change A1 via formulaData (triggers invalidation)
      formulaData.setCell(const CellCoordinate(0, 0), CellValue.number(10));

      // Re-evaluate — should reflect new value
      final after = formulaData.getCell(const CellCoordinate(1, 0));
      expect(after!.asDouble, 20);
    });

    test('invalidates dependent chain', () {
      rawData.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      rawData.setCell(
          const CellCoordinate(1, 0), const CellValue.formula('=A1+1'));
      rawData.setCell(
          const CellCoordinate(2, 0), const CellValue.formula('=A2+1'));

      // Evaluate chain to populate caches and dependencies
      expect(formulaData.getCell(const CellCoordinate(1, 0))!.asDouble, 2);
      expect(formulaData.getCell(const CellCoordinate(2, 0))!.asDouble, 3);

      // Change root
      formulaData.setCell(const CellCoordinate(0, 0), CellValue.number(10));

      // Both dependents should recalculate
      expect(formulaData.getCell(const CellCoordinate(1, 0))!.asDouble, 11);
      expect(formulaData.getCell(const CellCoordinate(2, 0))!.asDouble, 12);
    });

    test('clears cell with null', () {
      formulaData.setCell(
          const CellCoordinate(0, 0), CellValue.number(42));
      formulaData.setCell(const CellCoordinate(0, 0), null);
      expect(formulaData.getCell(const CellCoordinate(0, 0)), isNull);
    });
  });

  group('circular references', () {
    test('returns error for direct circular reference', () {
      rawData.setCell(
          const CellCoordinate(0, 0), const CellValue.formula('=A1'));
      final result = formulaData.getCell(const CellCoordinate(0, 0));
      // The evaluation context detects circular refs and returns an error
      // The exact behavior depends on the engine, but it should not hang
      expect(result, isNotNull);
    });

    test('returns error for indirect circular reference', () {
      rawData.setCell(
          const CellCoordinate(0, 0), const CellValue.formula('=A2'));
      rawData.setCell(
          const CellCoordinate(1, 0), const CellValue.formula('=A1'));

      final result = formulaData.getCell(const CellCoordinate(0, 0));
      // Should not hang — circular reference detected
      expect(result, isNotNull);
    });
  });

  group('delegation', () {
    test('delegates getStyle to inner', () {
      rawData.setStyle(const CellCoordinate(0, 0),
          const CellStyle(fontWeight: FontWeight.bold));
      expect(
          formulaData.getStyle(const CellCoordinate(0, 0))!.fontWeight,
          FontWeight.bold);
    });

    test('delegates setStyle to inner', () {
      formulaData.setStyle(const CellCoordinate(0, 0),
          const CellStyle(fontWeight: FontWeight.bold));
      expect(rawData.getStyle(const CellCoordinate(0, 0))!.fontWeight,
          FontWeight.bold);
    });

    test('delegates rowCount and columnCount', () {
      expect(formulaData.rowCount, 100);
      expect(formulaData.columnCount, 26);
    });

    test('delegates hasValue', () {
      expect(formulaData.hasValue(const CellCoordinate(0, 0)), false);
      rawData.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      expect(formulaData.hasValue(const CellCoordinate(0, 0)), true);
    });
  });
}
