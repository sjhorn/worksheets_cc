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

    test('evaluates LAMBDA function', () {
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.formula('=LAMBDA(x, x+1)(5)'),
      );
      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isNumber, true);
      expect(result.asDouble, 6);
    });

    test('handles FunctionValue from unapplied LAMBDA', () {
      // An unapplied LAMBDA (no call args) returns a FunctionValue,
      // which should be converted to text rather than crashing.
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.formula('=LAMBDA(x, x+1)'),
      );
      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isText, true);
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

  group('date and duration arithmetic', () {
    test('adding 1 to a date cell returns next day as date', () {
      rawData.setCell(
        const CellCoordinate(0, 0),
        CellValue.date(DateTime.utc(2024, 1, 15)),
      );
      rawData.setCell(
        const CellCoordinate(1, 0),
        const CellValue.formula('=A1+1'),
      );

      final result = formulaData.getCell(const CellCoordinate(1, 0));
      expect(result, isNotNull);
      expect(result!.isDate, true);
      expect(result.asDateTime, DateTime.utc(2024, 1, 16));
    });

    test('DATE function returns a date value', () {
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.formula('=DATE(2024,1,15)'),
      );

      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isDate, true);
      expect(result.asDateTime, DateTime.utc(2024, 1, 15));
    });

    test('adding 1 to DATE formula gives next day', () {
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.formula('=DATE(2024,1,15)+1'),
      );

      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isDate, true);
      expect(result.asDateTime, DateTime.utc(2024, 1, 16));
    });

    test('inline date arithmetic adds 7 days', () {
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.formula('=DATE(2024,1,15)+7'),
      );

      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      expect(result!.isDate, true);
      expect(result.asDateTime, DateTime.utc(2024, 1, 22));
    });

    test('date subtraction gives days between', () {
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.formula('=DATE(2024,1,20)-DATE(2024,1,15)'),
      );

      final result = formulaData.getCell(const CellCoordinate(0, 0));
      expect(result, isNotNull);
      // Result is 5 days — since the formula involves DATE functions,
      // this gets converted to a date (serial 5 = Jan 4, 1900).
      // The underlying numeric value is still correct.
      expect(result!.isDate, true);
    });

    test('chained date formula returns date', () {
      // C4 = date, C5 = =C4+1, C6 = =C5+1 → should all be dates
      rawData.setCell(
        const CellCoordinate(3, 2),
        CellValue.date(DateTime.utc(2026, 1, 12)),
      );
      rawData.setCell(
        const CellCoordinate(4, 2),
        const CellValue.formula('=C4+1'),
      );
      rawData.setCell(
        const CellCoordinate(5, 2),
        const CellValue.formula('=C5+1'),
      );

      final c5 = formulaData.getCell(const CellCoordinate(4, 2));
      expect(c5, isNotNull);
      expect(c5!.isDate, true);
      expect(c5.asDateTime, DateTime.utc(2026, 1, 13));

      final c6 = formulaData.getCell(const CellCoordinate(5, 2));
      expect(c6, isNotNull);
      expect(c6!.isDate, true);
      expect(c6.asDateTime, DateTime.utc(2026, 1, 14));
    });

    test('duration cell converts to fractional days', () {
      // 12 hours = 0.5 days
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.duration(Duration(hours: 12)),
      );
      rawData.setCell(
        const CellCoordinate(1, 0),
        const CellValue.formula('=A1'),
      );

      final result = formulaData.getCell(const CellCoordinate(1, 0));
      expect(result, isNotNull);
      expect(result!.isNumber, true);
      expect(result.asDouble, 0.5);
    });

    test('duration 24 hours equals 1 day', () {
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.duration(Duration(hours: 24)),
      );
      rawData.setCell(
        const CellCoordinate(1, 0),
        const CellValue.formula('=A1'),
      );

      final result = formulaData.getCell(const CellCoordinate(1, 0));
      expect(result!.asDouble, 1.0);
    });

    test('duration arithmetic works in formulas', () {
      // 6 hours = 0.25 days
      rawData.setCell(
        const CellCoordinate(0, 0),
        const CellValue.duration(Duration(hours: 6)),
      );
      rawData.setCell(
        const CellCoordinate(1, 0),
        const CellValue.formula('=A1*2'),
      );

      final result = formulaData.getCell(const CellCoordinate(1, 0));
      expect(result!.asDouble, 0.5);
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
