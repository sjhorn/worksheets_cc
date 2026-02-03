import 'package:worksheet/worksheet.dart';

import 'undo_manager.dart';

/// Computes a compact range notation from a set of coordinates.
/// Single cell: "A1". Multiple cells: bounding box "A1:C3".
String _coordsDescription(Iterable<CellCoordinate> coords) {
  if (coords.isEmpty) return '';
  final first = coords.first;
  if (coords.length == 1) return first.toNotation();

  var minRow = first.row;
  var maxRow = first.row;
  var minCol = first.column;
  var maxCol = first.column;
  for (final c in coords) {
    if (c.row < minRow) minRow = c.row;
    if (c.row > maxRow) maxRow = c.row;
    if (c.column < minCol) minCol = c.column;
    if (c.column > maxCol) maxCol = c.column;
  }
  final topLeft = CellCoordinate(minRow, minCol);
  final bottomRight = CellCoordinate(maxRow, maxCol);
  if (topLeft == bottomRight) return topLeft.toNotation();
  return '${topLeft.toNotation()}:${bottomRight.toNotation()}';
}

/// A [WorksheetData] wrapper that intercepts all mutations to record
/// undo/redo actions via [UndoManager].
///
/// Read methods and the [changes] stream delegate directly to the inner data.
/// Undo actions apply directly to [sparseData], bypassing this wrapper to
/// avoid re-recording.
class UndoableWorksheetData implements WorksheetData {
  UndoableWorksheetData(this.sparseData, this.undoManager);

  final SparseWorksheetData sparseData;
  final UndoManager undoManager;

  // --- Read methods: delegate to sparseData ---

  @override
  CellValue? getCell(CellCoordinate coord) => sparseData.getCell(coord);

  @override
  CellStyle? getStyle(CellCoordinate coord) => sparseData.getStyle(coord);

  @override
  CellFormat? getFormat(CellCoordinate coord) => sparseData.getFormat(coord);

  @override
  bool hasValue(CellCoordinate coord) => sparseData.hasValue(coord);

  @override
  int get rowCount => sparseData.rowCount;

  @override
  int get columnCount => sparseData.columnCount;

  @override
  Stream<DataChangeEvent> get changes => sparseData.changes;

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
          CellRange range) =>
      sparseData.getCellsInRange(range);

  // --- Mutation methods: snapshot before, delegate, snapshot after, push ---

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    final before = CellSnapshot.capture(sparseData, coord);
    sparseData.setCell(coord, value);
    final after = CellSnapshot.capture(sparseData, coord);
    undoManager.push(SnapshotUndoAction(
      sparseData: sparseData,
      before: {coord: before},
      after: {coord: after},
      description: 'Edit ${coord.toNotation()}',
    ));
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    final before = CellSnapshot.capture(sparseData, coord);
    sparseData.setStyle(coord, style);
    final after = CellSnapshot.capture(sparseData, coord);
    undoManager.push(SnapshotUndoAction(
      sparseData: sparseData,
      before: {coord: before},
      after: {coord: after},
      description: 'Style ${coord.toNotation()}',
    ));
  }

  @override
  void setFormat(CellCoordinate coord, CellFormat? format) {
    final before = CellSnapshot.capture(sparseData, coord);
    sparseData.setFormat(coord, format);
    final after = CellSnapshot.capture(sparseData, coord);
    undoManager.push(SnapshotUndoAction(
      sparseData: sparseData,
      before: {coord: before},
      after: {coord: after},
      description: 'Format ${coord.toNotation()}',
    ));
  }

  @override
  void clearRange(CellRange range) {
    final before = <CellCoordinate, CellSnapshot>{};
    for (final coord in range.cells) {
      if (sparseData.hasValue(coord) ||
          sparseData.getStyle(coord) != null ||
          sparseData.getFormat(coord) != null) {
        before[coord] = CellSnapshot.capture(sparseData, coord);
      }
    }

    sparseData.clearRange(range);

    final after = <CellCoordinate, CellSnapshot>{};
    for (final coord in before.keys) {
      after[coord] = CellSnapshot.capture(sparseData, coord);
    }

    if (before.isNotEmpty) {
      final topLeft = CellCoordinate(range.startRow, range.startColumn);
      final bottomRight = CellCoordinate(range.endRow, range.endColumn);
      final desc = topLeft == bottomRight
          ? 'Clear ${topLeft.toNotation()}'
          : 'Clear ${topLeft.toNotation()}:${bottomRight.toNotation()}';
      undoManager.push(SnapshotUndoAction(
        sparseData: sparseData,
        before: before,
        after: after,
        description: desc,
      ));
    }
  }

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) {
    final tracker = _TrackingBatch(sparseData);

    sparseData.batchUpdate((realBatch) {
      updates(_TrackingBatchProxy(realBatch, tracker));
    });

    final touchedCoords = tracker.beforeSnapshots.keys;
    if (touchedCoords.isEmpty) return;

    final after = <CellCoordinate, CellSnapshot>{};
    for (final coord in touchedCoords) {
      after[coord] = CellSnapshot.capture(sparseData, coord);
    }

    undoManager.push(SnapshotUndoAction(
      sparseData: sparseData,
      before: tracker.beforeSnapshots,
      after: after,
      description: 'Edit ${_coordsDescription(touchedCoords)}',
    ));
  }

  @override
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) async {
    final tracker = _TrackingBatch(sparseData);

    await sparseData.batchUpdateAsync((realBatch) async {
      await updates(_TrackingBatchProxy(realBatch, tracker));
    });

    final touchedCoords = tracker.beforeSnapshots.keys;
    if (touchedCoords.isEmpty) return;

    final after = <CellCoordinate, CellSnapshot>{};
    for (final coord in touchedCoords) {
      after[coord] = CellSnapshot.capture(sparseData, coord);
    }

    undoManager.push(SnapshotUndoAction(
      sparseData: sparseData,
      before: tracker.beforeSnapshots,
      after: after,
      description: 'Edit ${_coordsDescription(touchedCoords)}',
    ));
  }

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    final before = <CellCoordinate, CellSnapshot>{};
    for (final coord in range.cells) {
      before[coord] = CellSnapshot.capture(sparseData, coord);
    }

    sparseData.fillRange(source, range, valueGenerator);

    final after = <CellCoordinate, CellSnapshot>{};
    for (final coord in range.cells) {
      after[coord] = CellSnapshot.capture(sparseData, coord);
    }

    final topLeft = CellCoordinate(range.startRow, range.startColumn);
    final bottomRight = CellCoordinate(range.endRow, range.endColumn);
    final desc = topLeft == bottomRight
        ? 'Fill ${topLeft.toNotation()}'
        : 'Fill ${topLeft.toNotation()}:${bottomRight.toNotation()}';
    undoManager.push(SnapshotUndoAction(
      sparseData: sparseData,
      before: before,
      after: after,
      description: desc,
    ));
  }

  @override
  void smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) {
    // Snapshot all cells in the source range and a generous target area
    final expandedRange = range.expand(destination);
    final before = <CellCoordinate, CellSnapshot>{};
    for (final coord in expandedRange.cells) {
      before[coord] = CellSnapshot.capture(sparseData, coord);
    }

    sparseData.smartFill(range, destination, valueGenerator);

    final after = <CellCoordinate, CellSnapshot>{};
    for (final coord in expandedRange.cells) {
      after[coord] = CellSnapshot.capture(sparseData, coord);
    }

    final topLeft = CellCoordinate(expandedRange.startRow, expandedRange.startColumn);
    final bottomRight = CellCoordinate(expandedRange.endRow, expandedRange.endColumn);
    final desc = topLeft == bottomRight
        ? 'Fill ${topLeft.toNotation()}'
        : 'Fill ${topLeft.toNotation()}:${bottomRight.toNotation()}';
    undoManager.push(SnapshotUndoAction(
      sparseData: sparseData,
      before: before,
      after: after,
      description: desc,
    ));
  }

  @override
  void dispose() {
    // Don't dispose sparseData — SheetModel owns it
  }
}

/// Tracks which cells are touched during a batch, recording their
/// before-state on first access.
class _TrackingBatch {
  _TrackingBatch(this._data);

  final SparseWorksheetData _data;
  final Map<CellCoordinate, CellSnapshot> beforeSnapshots = {};

  void recordBefore(CellCoordinate coord) {
    beforeSnapshots.putIfAbsent(
        coord, () => CellSnapshot.capture(_data, coord));
  }

  void recordRangeBefore(CellRange range) {
    for (final coord in range.cells) {
      recordBefore(coord);
    }
  }
}

/// Proxies a real [WorksheetDataBatch] while recording before-state
/// for each touched cell via [_TrackingBatch].
class _TrackingBatchProxy implements WorksheetDataBatch {
  _TrackingBatchProxy(this._real, this._tracker);

  final WorksheetDataBatch _real;
  final _TrackingBatch _tracker;

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    _tracker.recordBefore(coord);
    _real.setCell(coord, value);
  }

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) {
    _tracker.recordBefore(coord);
    _real.setStyle(coord, style);
  }

  @override
  void setFormat(CellCoordinate coord, CellFormat? format) {
    _tracker.recordBefore(coord);
    _real.setFormat(coord, format);
  }

  @override
  void clearRange(CellRange range) {
    _tracker.recordRangeBefore(range);
    _real.clearRange(range);
  }

  @override
  void fillRangeWithCell(CellRange range, Cell? value) {
    _tracker.recordRangeBefore(range);
    _real.fillRangeWithCell(range, value);
  }

  @override
  void clearValues(CellRange range) {
    _tracker.recordRangeBefore(range);
    _real.clearValues(range);
  }

  @override
  void clearStyles(CellRange range) {
    _tracker.recordRangeBefore(range);
    _real.clearStyles(range);
  }

  @override
  void clearFormats(CellRange range) {
    _tracker.recordRangeBefore(range);
    _real.clearFormats(range);
  }

  @override
  void copyRange(CellRange source, CellCoordinate destination) {
    // Record the destination cells that will be overwritten
    final destRange = CellRange(
      destination.row,
      destination.column,
      destination.row + source.endRow - source.startRow,
      destination.column + source.endColumn - source.startColumn,
    );
    _tracker.recordRangeBefore(destRange);
    _real.copyRange(source, destination);
  }
}
