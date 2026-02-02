import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';
import 'package:worksheets_cc/src/services/formula_service.dart';

void main() {
  late FormulaService service;
  late SparseWorksheetData data;

  setUp(() {
    service = FormulaService();
    data = SparseWorksheetData(rowCount: 100, columnCount: 26);
  });

  tearDown(() {
    data.dispose();
  });

  group('evaluateCell', () {
    test('returns empty for non-formula cell', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.number(42));
      final result = service.evaluateCell(const CellCoordinate(0, 0), data);
      expect(result, isA<EmptyValue>());
    });

    test('returns empty for empty cell', () {
      final result = service.evaluateCell(const CellCoordinate(0, 0), data);
      expect(result, isA<EmptyValue>());
    });

    test('evaluates simple arithmetic formula', () {
      data.setCell(
          const CellCoordinate(0, 0), const CellValue.formula('=1+2'));
      final result = service.evaluateCell(const CellCoordinate(0, 0), data);
      expect(result, isA<NumberValue>());
      expect(result.toNumber(), 3);
    });

    test('evaluates formula with cell reference', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.number(10));
      data.setCell(const CellCoordinate(1, 0), CellValue.number(20));
      data.setCell(const CellCoordinate(2, 0),
          const CellValue.formula('=A1+A2'));

      final result = service.evaluateCell(const CellCoordinate(2, 0), data);
      expect(result, isA<NumberValue>());
      expect(result.toNumber(), 30);
    });

    test('evaluates SUM function', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      data.setCell(const CellCoordinate(1, 0), CellValue.number(2));
      data.setCell(const CellCoordinate(2, 0), CellValue.number(3));
      data.setCell(const CellCoordinate(3, 0),
          const CellValue.formula('=SUM(A1:A3)'));

      final result = service.evaluateCell(const CellCoordinate(3, 0), data);
      expect(result, isA<NumberValue>());
      expect(result.toNumber(), 6);
    });

    test('returns error for invalid formula', () {
      data.setCell(const CellCoordinate(0, 0),
          const CellValue.formula('=INVALID('));
      final result = service.evaluateCell(const CellCoordinate(0, 0), data);
      expect(result.isError, true);
    });
  });

  group('onCellChanged', () {
    test('updates dependency graph for formula cells', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.number(5));
      data.setCell(const CellCoordinate(1, 0),
          const CellValue.formula('=A1*2'));

      service.onCellChanged(const CellCoordinate(1, 0), data);

      // Now change A1 and verify B1 would need recalculation
      data.setCell(const CellCoordinate(0, 0), CellValue.number(10));
      service.onCellChanged(const CellCoordinate(0, 0), data);

      // Re-evaluate B1 (A2 in notation)
      final result = service.evaluateCell(const CellCoordinate(1, 0), data);
      expect(result, isA<NumberValue>());
      expect(result.toNumber(), 20);
    });
  });

  group('hasCircularReference', () {
    test('detects circular reference', () {
      data.setCell(
          const CellCoordinate(0, 0), const CellValue.formula('=A2'));
      service.onCellChanged(const CellCoordinate(0, 0), data);

      data.setCell(
          const CellCoordinate(1, 0), const CellValue.formula('=A1'));
      service.onCellChanged(const CellCoordinate(1, 0), data);

      expect(service.hasCircularReference(const CellCoordinate(0, 0)), true);
    });

    test('returns false when no circular reference', () {
      data.setCell(const CellCoordinate(0, 0), CellValue.number(5));
      data.setCell(const CellCoordinate(1, 0),
          const CellValue.formula('=A1*2'));
      service.onCellChanged(const CellCoordinate(1, 0), data);

      expect(service.hasCircularReference(const CellCoordinate(1, 0)), false);
    });
  });
}
