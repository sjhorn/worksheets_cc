import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheets_cc/src/services/undo_manager.dart';

void main() {
  group('UndoManager', () {
    late UndoManager manager;

    setUp(() {
      manager = UndoManager();
    });

    test('starts with empty stacks', () {
      expect(manager.canUndo, false);
      expect(manager.canRedo, false);
    });

    test('push enables undo', () {
      manager.push(_MockAction());
      expect(manager.canUndo, true);
      expect(manager.canRedo, false);
    });

    test('undo calls action.undo and enables redo', () {
      final action = _MockAction();
      manager.push(action);
      manager.undo();

      expect(action.undoCalled, true);
      expect(manager.canUndo, false);
      expect(manager.canRedo, true);
    });

    test('redo calls action.redo', () {
      final action = _MockAction();
      manager.push(action);
      manager.undo();
      manager.redo();

      expect(action.redoCalled, true);
      expect(manager.canUndo, true);
      expect(manager.canRedo, false);
    });

    test('push clears redo stack', () {
      manager.push(_MockAction());
      manager.undo();
      expect(manager.canRedo, true);

      manager.push(_MockAction());
      expect(manager.canRedo, false);
    });

    test('undo on empty stack is a no-op', () {
      manager.undo(); // Should not throw
      expect(manager.canUndo, false);
    });

    test('redo on empty stack is a no-op', () {
      manager.redo(); // Should not throw
      expect(manager.canRedo, false);
    });

    test('clear empties both stacks', () {
      manager.push(_MockAction());
      manager.push(_MockAction());
      manager.undo();
      expect(manager.canUndo, true);
      expect(manager.canRedo, true);

      manager.clear();
      expect(manager.canUndo, false);
      expect(manager.canRedo, false);
    });

    test('respects maxHistory limit', () {
      final manager = UndoManager(maxHistory: 3);
      manager.push(_MockAction());
      manager.push(_MockAction());
      manager.push(_MockAction());
      manager.push(_MockAction()); // This should evict the oldest

      // Should only be able to undo 3 times
      manager.undo();
      manager.undo();
      manager.undo();
      expect(manager.canUndo, false);
    });

    test('multiple undo/redo cycle works correctly', () {
      final a1 = _MockAction();
      final a2 = _MockAction();
      final a3 = _MockAction();

      manager.push(a1);
      manager.push(a2);
      manager.push(a3);

      manager.undo(); // undoes a3
      expect(a3.undoCalled, true);

      manager.undo(); // undoes a2
      expect(a2.undoCalled, true);

      manager.redo(); // redoes a2
      expect(a2.redoCalled, true);

      manager.redo(); // redoes a3
      expect(a3.redoCalled, true);
    });

    test('undoDescriptions returns most recent first', () {
      manager.push(_MockAction('first'));
      manager.push(_MockAction('second'));
      manager.push(_MockAction('third'));

      expect(manager.undoDescriptions, ['third', 'second', 'first']);
    });

    test('redoDescriptions returns most recent first', () {
      manager.push(_MockAction('first'));
      manager.push(_MockAction('second'));
      manager.push(_MockAction('third'));

      manager.undo(); // third → redo
      manager.undo(); // second → redo

      expect(manager.redoDescriptions, ['second', 'third']);
    });

    test('undoN undoes multiple steps', () {
      final a1 = _MockAction('a1');
      final a2 = _MockAction('a2');
      final a3 = _MockAction('a3');

      manager.push(a1);
      manager.push(a2);
      manager.push(a3);

      manager.undoN(2);

      expect(a3.undoCalled, true);
      expect(a2.undoCalled, true);
      expect(a1.undoCalled, false);
      expect(manager.undoDescriptions, ['a1']);
      expect(manager.redoDescriptions, ['a2', 'a3']);
    });

    test('redoN redoes multiple steps', () {
      manager.push(_MockAction('a1'));
      manager.push(_MockAction('a2'));
      manager.push(_MockAction('a3'));

      manager.undoN(3);
      expect(manager.canUndo, false);

      manager.redoN(2);

      expect(manager.undoDescriptions, ['a2', 'a1']);
      expect(manager.redoDescriptions, ['a3']);
    });

    test('undoN stops at stack boundary', () {
      manager.push(_MockAction('a1'));

      manager.undoN(5); // Only 1 to undo
      expect(manager.canUndo, false);
      expect(manager.redoDescriptions, ['a1']);
    });

    test('redoN stops at stack boundary', () {
      manager.push(_MockAction('a1'));
      manager.undo();

      manager.redoN(5); // Only 1 to redo
      expect(manager.canRedo, false);
      expect(manager.undoDescriptions, ['a1']);
    });
  });

  group('CellSnapshot', () {
    late SparseWorksheetData data;

    setUp(() {
      data = SparseWorksheetData(rowCount: 10, columnCount: 10);
    });

    tearDown(() {
      data.dispose();
    });

    test('captures empty cell', () {
      final snapshot =
          CellSnapshot.capture(data, const CellCoordinate(0, 0));
      expect(snapshot.value, isNull);
      expect(snapshot.style, isNull);
      expect(snapshot.format, isNull);
    });

    test('captures cell with value, style, and format', () {
      const coord = CellCoordinate(0, 0);
      data.setCell(coord, CellValue.number(42));
      data.setStyle(coord, const CellStyle(fontSize: 16));
      data.setFormat(coord, CellFormat.currency);

      final snapshot = CellSnapshot.capture(data, coord);
      expect(snapshot.value!.asDouble, 42);
      expect(snapshot.style!.fontSize, 16);
      expect(snapshot.format!.type, CellFormatType.currency);
    });

    test('applyTo restores cell state', () {
      const coord = CellCoordinate(0, 0);
      data.setCell(coord, CellValue.number(42));
      data.setStyle(coord, const CellStyle(fontSize: 16));

      final snapshot = CellSnapshot.capture(data, coord);

      // Change the cell
      data.setCell(coord, const CellValue.text('changed'));
      data.setStyle(coord, null);

      // Restore
      snapshot.applyTo(data, coord);

      expect(data.getCell(coord)!.asDouble, 42);
      expect(data.getStyle(coord)!.fontSize, 16);
    });
  });

  group('SnapshotUndoAction', () {
    late SparseWorksheetData data;

    setUp(() {
      data = SparseWorksheetData(rowCount: 10, columnCount: 10);
    });

    tearDown(() {
      data.dispose();
    });

    test('undo restores before state', () {
      const coord = CellCoordinate(0, 0);

      final before = {
        coord: const CellSnapshot(value: null),
      };
      final after = {
        coord: CellSnapshot(value: CellValue.number(42)),
      };

      // Set to "after" state
      data.setCell(coord, CellValue.number(42));

      final action = SnapshotUndoAction(
        sparseData: data,
        before: before,
        after: after,
        description: 'Edit A1',
      );

      action.undo();
      expect(data.getCell(coord), isNull);
    });

    test('redo restores after state', () {
      const coord = CellCoordinate(0, 0);

      final before = {
        coord: const CellSnapshot(value: null),
      };
      final after = {
        coord: CellSnapshot(value: CellValue.number(42)),
      };

      final action = SnapshotUndoAction(
        sparseData: data,
        before: before,
        after: after,
        description: 'Edit A1',
      );

      action.redo();
      expect(data.getCell(coord)!.asDouble, 42);
    });
  });

  group('ResizeColumnAction', () {
    test('undo restores old width', () {
      final widths = <int, double>{0: 200.0};
      final action = ResizeColumnAction(
        columnWidths: widths,
        column: 0,
        oldWidth: 100.0,
        newWidth: 200.0,
        description: 'Resize Column A',
      );

      action.undo();
      expect(widths[0], 100.0);
    });

    test('undo removes entry when old width was null', () {
      final widths = <int, double>{0: 200.0};
      final action = ResizeColumnAction(
        columnWidths: widths,
        column: 0,
        oldWidth: null,
        newWidth: 200.0,
        description: 'Resize Column A',
      );

      action.undo();
      expect(widths.containsKey(0), false);
    });

    test('redo restores new width', () {
      final widths = <int, double>{};
      final action = ResizeColumnAction(
        columnWidths: widths,
        column: 0,
        oldWidth: null,
        newWidth: 200.0,
        description: 'Resize Column A',
      );

      action.redo();
      expect(widths[0], 200.0);
    });
  });

  group('ResizeRowAction', () {
    test('undo restores old height', () {
      final heights = <int, double>{0: 50.0};
      final action = ResizeRowAction(
        rowHeights: heights,
        row: 0,
        oldHeight: 30.0,
        newHeight: 50.0,
        description: 'Resize Row 1',
      );

      action.undo();
      expect(heights[0], 30.0);
    });

    test('redo restores new height', () {
      final heights = <int, double>{};
      final action = ResizeRowAction(
        rowHeights: heights,
        row: 0,
        oldHeight: null,
        newHeight: 50.0,
        description: 'Resize Row 1',
      );

      action.redo();
      expect(heights[0], 50.0);
    });
  });
}

class _MockAction implements UndoAction {
  _MockAction([this.description = 'mock']);

  bool undoCalled = false;
  bool redoCalled = false;

  @override
  final String description;

  @override
  void undo() => undoCalled = true;

  @override
  void redo() => redoCalled = true;
}
