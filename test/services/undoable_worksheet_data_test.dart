import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheets_cc/src/services/undo_manager.dart';
import 'package:worksheets_cc/src/services/undoable_worksheet_data.dart';

void main() {
  late SparseWorksheetData sparseData;
  late UndoManager undoManager;
  late UndoableWorksheetData undoable;

  setUp(() {
    sparseData = SparseWorksheetData(rowCount: 100, columnCount: 26);
    undoManager = UndoManager();
    undoable = UndoableWorksheetData(sparseData, undoManager);
  });

  tearDown(() {
    undoable.dispose();
    sparseData.dispose();
  });

  group('read delegation', () {
    test('getCell delegates to sparseData', () {
      sparseData.setCell(const CellCoordinate(0, 0), CellValue.number(42));
      expect(undoable.getCell(const CellCoordinate(0, 0))!.asDouble, 42);
    });

    test('getStyle delegates to sparseData', () {
      sparseData.setStyle(const CellCoordinate(0, 0),
          const CellStyle(textAlignment: CellTextAlignment.center));
      expect(undoable.getStyle(const CellCoordinate(0, 0))!.textAlignment,
          CellTextAlignment.center);
    });

    test('getFormat delegates to sparseData', () {
      sparseData.setFormat(const CellCoordinate(0, 0), CellFormat.currency);
      expect(undoable.getFormat(const CellCoordinate(0, 0))!.type,
          CellFormatType.currency);
    });

    test('rowCount and columnCount delegate', () {
      expect(undoable.rowCount, 100);
      expect(undoable.columnCount, 26);
    });

    test('hasValue delegates', () {
      expect(undoable.hasValue(const CellCoordinate(0, 0)), false);
      sparseData.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      expect(undoable.hasValue(const CellCoordinate(0, 0)), true);
    });
  });

  group('setCell undo/redo', () {
    test('setCell records undo action', () {
      undoable.setCell(const CellCoordinate(0, 0), CellValue.number(42));
      expect(undoManager.canUndo, true);
    });

    test('undo restores previous cell value', () {
      const coord = CellCoordinate(0, 0);
      undoable.setCell(coord, CellValue.number(42));

      undoManager.undo();
      expect(sparseData.getCell(coord), isNull);
    });

    test('redo re-applies cell value', () {
      const coord = CellCoordinate(0, 0);
      undoable.setCell(coord, CellValue.number(42));

      undoManager.undo();
      undoManager.redo();
      expect(sparseData.getCell(coord)!.asDouble, 42);
    });

    test('overwriting cell value undoes to previous value', () {
      const coord = CellCoordinate(0, 0);
      undoable.setCell(coord, CellValue.number(10));
      undoable.setCell(coord, CellValue.number(20));

      undoManager.undo(); // Undo second set
      expect(sparseData.getCell(coord)!.asDouble, 10);

      undoManager.undo(); // Undo first set
      expect(sparseData.getCell(coord), isNull);
    });

    test('clearing a cell (setting null) is undoable', () {
      const coord = CellCoordinate(0, 0);
      undoable.setCell(coord, CellValue.number(42));
      undoable.setCell(coord, null);

      undoManager.undo();
      expect(sparseData.getCell(coord)!.asDouble, 42);
    });
  });

  group('setStyle undo/redo', () {
    test('undo restores previous style', () {
      const coord = CellCoordinate(0, 0);
      undoable.setStyle(
          coord, const CellStyle(textAlignment: CellTextAlignment.right));

      undoManager.undo();
      expect(sparseData.getStyle(coord), isNull);
    });

    test('redo re-applies style', () {
      const coord = CellCoordinate(0, 0);
      undoable.setStyle(
          coord, const CellStyle(textAlignment: CellTextAlignment.right));

      undoManager.undo();
      undoManager.redo();
      expect(sparseData.getStyle(coord)!.textAlignment,
          CellTextAlignment.right);
    });
  });

  group('setFormat undo/redo', () {
    test('undo restores previous format', () {
      const coord = CellCoordinate(0, 0);
      undoable.setFormat(coord, CellFormat.currency);

      undoManager.undo();
      expect(sparseData.getFormat(coord), isNull);
    });

    test('redo re-applies format', () {
      const coord = CellCoordinate(0, 0);
      undoable.setFormat(coord, CellFormat.currency);

      undoManager.undo();
      undoManager.redo();
      expect(
          sparseData.getFormat(coord)!.type, CellFormatType.currency);
    });
  });

  group('clearRange undo/redo', () {
    test('undo restores cleared cells', () {
      const a1 = CellCoordinate(0, 0);
      const b1 = CellCoordinate(0, 1);
      undoable.setCell(a1, CellValue.number(10));
      undoable.setCell(b1, CellValue.number(20));

      // Clear undo history from setup
      undoManager.clear();

      undoable.clearRange(const CellRange(0, 0, 0, 1));
      expect(sparseData.getCell(a1), isNull);
      expect(sparseData.getCell(b1), isNull);

      undoManager.undo();
      expect(sparseData.getCell(a1)!.asDouble, 10);
      expect(sparseData.getCell(b1)!.asDouble, 20);
    });

    test('clearRange on empty range does not push action', () {
      undoable.clearRange(const CellRange(0, 0, 0, 1));
      expect(undoManager.canUndo, false);
    });
  });

  group('batchUpdate undo/redo', () {
    test('batch produces single undo action', () {
      undoable.batchUpdate((batch) {
        batch.setCell(const CellCoordinate(0, 0), CellValue.number(1));
        batch.setCell(const CellCoordinate(0, 1), CellValue.number(2));
        batch.setCell(const CellCoordinate(0, 2), CellValue.number(3));
      });

      // Should be a single undo action
      expect(undoManager.canUndo, true);
      undoManager.undo();
      expect(undoManager.canUndo, false);

      // All three cells should be restored
      expect(sparseData.getCell(const CellCoordinate(0, 0)), isNull);
      expect(sparseData.getCell(const CellCoordinate(0, 1)), isNull);
      expect(sparseData.getCell(const CellCoordinate(0, 2)), isNull);
    });

    test('batch redo re-applies all changes', () {
      undoable.batchUpdate((batch) {
        batch.setCell(const CellCoordinate(0, 0), CellValue.number(1));
        batch.setCell(const CellCoordinate(0, 1), CellValue.number(2));
      });

      undoManager.undo();
      undoManager.redo();

      expect(sparseData.getCell(const CellCoordinate(0, 0))!.asDouble, 1);
      expect(sparseData.getCell(const CellCoordinate(0, 1))!.asDouble, 2);
    });

    test('batch with style changes undoes correctly', () {
      undoable.batchUpdate((batch) {
        batch.setStyle(const CellCoordinate(0, 0),
            const CellStyle(textAlignment: CellTextAlignment.left));
        batch.setStyle(const CellCoordinate(0, 1),
            const CellStyle(textAlignment: CellTextAlignment.right));
      });

      undoManager.undo();
      expect(sparseData.getStyle(const CellCoordinate(0, 0)), isNull);
      expect(sparseData.getStyle(const CellCoordinate(0, 1)), isNull);
    });

    test('empty batch does not push action', () {
      undoable.batchUpdate((batch) {
        // No operations
      });

      expect(undoManager.canUndo, false);
    });

    test('batch tracks first-touch only per cell', () {
      // Set initial values
      sparseData.setCell(const CellCoordinate(0, 0), CellValue.number(10));

      undoManager.clear();

      undoable.batchUpdate((batch) {
        // Set cell twice in same batch — should only snapshot before first touch
        batch.setCell(const CellCoordinate(0, 0), CellValue.number(20));
        batch.setCell(const CellCoordinate(0, 0), CellValue.number(30));
      });

      // Value should be 30 after batch
      expect(sparseData.getCell(const CellCoordinate(0, 0))!.asDouble, 30);

      // Undo should restore to original value (10), not intermediate (20)
      undoManager.undo();
      expect(sparseData.getCell(const CellCoordinate(0, 0))!.asDouble, 10);
    });
  });

  group('fillRange undo/redo', () {
    test('fillRange is undoable', () {
      const source = CellCoordinate(0, 0);
      undoable.setCell(source, CellValue.number(42));
      undoManager.clear();

      const range = CellRange(0, 0, 2, 0);
      undoable.fillRange(source, range);

      // All cells in range should have values
      expect(sparseData.getCell(const CellCoordinate(1, 0))!.asDouble, 42);
      expect(sparseData.getCell(const CellCoordinate(2, 0))!.asDouble, 42);

      undoManager.undo();
      expect(sparseData.getCell(const CellCoordinate(1, 0)), isNull);
      expect(sparseData.getCell(const CellCoordinate(2, 0)), isNull);
    });
  });

  group('change events propagate', () {
    test('undo triggers change event on sparseData', () async {
      const coord = CellCoordinate(0, 0);
      undoable.setCell(coord, CellValue.number(42));

      var eventReceived = false;
      sparseData.changes.listen((_) {
        eventReceived = true;
      });

      undoManager.undo();

      // Allow stream to deliver
      await Future<void>.delayed(Duration.zero);
      expect(eventReceived, true);
    });
  });

  group('action descriptions', () {
    test('setCell generates "Edit" description', () {
      undoable.setCell(const CellCoordinate(0, 0), CellValue.number(42));
      expect(undoManager.undoDescriptions.first, 'Edit A1');
    });

    test('setStyle generates "Style" description', () {
      undoable.setStyle(const CellCoordinate(2, 1),
          const CellStyle(textAlignment: CellTextAlignment.center));
      expect(undoManager.undoDescriptions.first, 'Style B3');
    });

    test('setFormat generates "Format" description', () {
      undoable.setFormat(const CellCoordinate(0, 0), CellFormat.currency);
      expect(undoManager.undoDescriptions.first, 'Format A1');
    });

    test('clearRange generates "Clear" description with range', () {
      // Put data so clearRange actually pushes an action
      sparseData.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      sparseData.setCell(const CellCoordinate(2, 1), CellValue.number(2));
      undoManager.clear();

      undoable.clearRange(const CellRange(0, 0, 2, 1));
      expect(undoManager.undoDescriptions.first, 'Clear A1:B3');
    });

    test('clearRange on single cell generates "Clear" with single cell', () {
      sparseData.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      undoManager.clear();

      undoable.clearRange(const CellRange(0, 0, 0, 0));
      expect(undoManager.undoDescriptions.first, 'Clear A1');
    });

    test('batchUpdate generates "Edit" description with bounding range', () {
      undoable.batchUpdate((batch) {
        batch.setCell(const CellCoordinate(0, 0), CellValue.number(1));
        batch.setCell(const CellCoordinate(2, 2), CellValue.number(2));
      });
      expect(undoManager.undoDescriptions.first, 'Edit A1:C3');
    });

    test('batchUpdate on single cell generates single-cell description', () {
      undoable.batchUpdate((batch) {
        batch.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      });
      expect(undoManager.undoDescriptions.first, 'Edit A1');
    });

    test('fillRange generates "Fill" description with range', () {
      const source = CellCoordinate(0, 0);
      sparseData.setCell(source, CellValue.number(42));
      undoManager.clear();

      undoable.fillRange(source, const CellRange(0, 0, 4, 0));
      expect(undoManager.undoDescriptions.first, 'Fill A1:A5');
    });
  });

  group('integration: undo bypasses wrapper', () {
    test('undo does not create new undo action', () {
      const coord = CellCoordinate(0, 0);
      undoable.setCell(coord, CellValue.number(42));

      // One action on stack
      expect(undoManager.canUndo, true);

      undoManager.undo();
      // Should have moved to redo, not created a new undo action
      expect(undoManager.canUndo, false);
      expect(undoManager.canRedo, true);
    });
  });
}
