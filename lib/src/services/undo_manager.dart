import 'package:worksheet/worksheet.dart';

/// Abstract interface for an undoable/redoable action.
abstract class UndoAction {
  String get description;
  void undo();
  void redo();
}

/// Manages undo/redo stacks with a configurable history limit.
class UndoManager {
  UndoManager({this.maxHistory = 50});

  final int maxHistory;
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Descriptions from the undo stack, most recent first.
  List<String> get undoDescriptions =>
      _undoStack.reversed.map((a) => a.description).toList();

  /// Descriptions from the redo stack, most recent first.
  List<String> get redoDescriptions =>
      _redoStack.reversed.map((a) => a.description).toList();

  void push(UndoAction action) {
    _undoStack.add(action);
    _redoStack.clear();
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  void undo() {
    if (!canUndo) return;
    final action = _undoStack.removeLast();
    action.undo();
    _redoStack.add(action);
  }

  void redo() {
    if (!canRedo) return;
    final action = _redoStack.removeLast();
    action.redo();
    _undoStack.add(action);
  }

  /// Undo [n] steps at once.
  void undoN(int n) {
    for (var i = 0; i < n; i++) {
      if (!canUndo) break;
      undo();
    }
  }

  /// Redo [n] steps at once.
  void redoN(int n) {
    for (var i = 0; i < n; i++) {
      if (!canRedo) break;
      redo();
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}

/// Captures the value, style, and format of a cell at a point in time.
class CellSnapshot {
  const CellSnapshot({this.value, this.style, this.format});

  final CellValue? value;
  final CellStyle? style;
  final CellFormat? format;

  factory CellSnapshot.capture(WorksheetData data, CellCoordinate coord) {
    return CellSnapshot(
      value: data.getCell(coord),
      style: data.getStyle(coord),
      format: data.getFormat(coord),
    );
  }

  /// Applies this snapshot to the given data at the given coordinate.
  void applyTo(SparseWorksheetData data, CellCoordinate coord) {
    data.setCell(coord, value);
    data.setStyle(coord, style);
    data.setFormat(coord, format);
  }
}

/// Undoes/redoes a set of cell changes by restoring before/after snapshots.
class SnapshotUndoAction implements UndoAction {
  SnapshotUndoAction({
    required this.sparseData,
    required this.before,
    required this.after,
    required this.description,
  });

  final SparseWorksheetData sparseData;
  final Map<CellCoordinate, CellSnapshot> before;
  final Map<CellCoordinate, CellSnapshot> after;

  @override
  final String description;

  @override
  void undo() {
    sparseData.batchUpdate((batch) {
      for (final entry in before.entries) {
        batch.setCell(entry.key, entry.value.value);
        batch.setStyle(entry.key, entry.value.style);
        batch.setFormat(entry.key, entry.value.format);
      }
    });
  }

  @override
  void redo() {
    sparseData.batchUpdate((batch) {
      for (final entry in after.entries) {
        batch.setCell(entry.key, entry.value.value);
        batch.setStyle(entry.key, entry.value.style);
        batch.setFormat(entry.key, entry.value.format);
      }
    });
  }
}

/// Undoes/redoes a column resize.
class ResizeColumnAction implements UndoAction {
  ResizeColumnAction({
    required this.columnWidths,
    required this.column,
    required this.oldWidth,
    required this.newWidth,
    required this.description,
  });

  final Map<int, double> columnWidths;
  final int column;
  final double? oldWidth;
  final double newWidth;

  @override
  final String description;

  @override
  void undo() {
    if (oldWidth != null) {
      columnWidths[column] = oldWidth!;
    } else {
      columnWidths.remove(column);
    }
  }

  @override
  void redo() {
    columnWidths[column] = newWidth;
  }
}

/// Undoes/redoes a row resize.
class ResizeRowAction implements UndoAction {
  ResizeRowAction({
    required this.rowHeights,
    required this.row,
    required this.oldHeight,
    required this.newHeight,
    required this.description,
  });

  final Map<int, double> rowHeights;
  final int row;
  final double? oldHeight;
  final double newHeight;

  @override
  final String description;

  @override
  void undo() {
    if (oldHeight != null) {
      rowHeights[row] = oldHeight!;
    } else {
      rowHeights.remove(row);
    }
  }

  @override
  void redo() {
    rowHeights[row] = newHeight;
  }
}
