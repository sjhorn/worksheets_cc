import 'dart:async';

import 'package:a1/a1.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

import 'worksheet_evaluation_context.dart';

/// A [WorksheetData] wrapper that evaluates formula cells on the fly.
///
/// Wraps an inner [WorksheetData] and intercepts [getCell] to return
/// computed values for formula cells. Uses [DependencyGraph] for
/// efficient cache invalidation when cells change.
class FormulaWorksheetData implements WorksheetData {
  final WorksheetData _inner;
  final FormulaEngine engine;
  final DependencyGraph _dependencies = DependencyGraph();
  final Map<CellCoordinate, CellValue> _cache = {};
  final StreamController<DataChangeEvent> _changeController =
      StreamController<DataChangeEvent>.broadcast();
  late final StreamSubscription<DataChangeEvent> _innerSub;

  FormulaWorksheetData(this._inner, {FormulaEngine? engine})
      : engine = engine ?? FormulaEngine() {
    _innerSub = _inner.changes.listen(_onInnerChange);
  }

  /// Get the dependency graph (for inspection/debugging).
  DependencyGraph get dependencies => _dependencies;

  @override
  CellValue? getCell(CellCoordinate coord) {
    final raw = _inner.getCell(coord);
    if (raw == null || !raw.isFormula) return raw;

    // Check cache
    final cached = _cache[coord];
    if (cached != null) return cached;

    // Evaluate the formula
    final formulaString = raw.rawValue as String;

    // Update dependency graph
    try {
      final refs = engine.getCellReferences(formulaString);
      final depCells =
          refs.map((a1) => A1.fromVector(a1.column, a1.row)).toSet();
      _dependencies.updateDependencies(
        A1.fromVector(coord.column, coord.row),
        depCells,
      );
    } catch (_) {
      // Parse failure — dependencies can't be tracked
    }

    // Evaluate
    final context = WorksheetEvaluationContext(
      data: _inner,
      functions: engine.functions,
      engine: engine,
      currentCell: A1.fromVector(coord.column, coord.row),
    );

    try {
      final result = engine.evaluateString(formulaString, context);
      final cellValue = _formulaValueToCellValue(result);
      if (cellValue != null) {
        _cache[coord] = cellValue;
      }
      return cellValue;
    } catch (_) {
      final errorValue = const CellValue.error('#VALUE!');
      _cache[coord] = errorValue;
      return errorValue;
    }
  }

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    _inner.setCell(coord, value);
    _invalidateCell(coord);
  }

  void _invalidateCell(CellCoordinate coord) {
    _cache.remove(coord);

    final cellA1 = A1.fromVector(coord.column, coord.row);
    final toRecalc = _dependencies.getCellsToRecalculate(cellA1);
    for (final dep in toRecalc) {
      final depCoord = CellCoordinate(dep.row, dep.column);
      _cache.remove(depCoord);
      _changeController.add(DataChangeEvent.cellValue(depCoord));
    }
  }

  void _onInnerChange(DataChangeEvent event) {
    if (event.cell != null) {
      _invalidateCell(event.cell!);
    } else if (event.range != null) {
      for (final coord in event.range!.cells) {
        _cache.remove(coord);
      }
    } else {
      _cache.clear();
    }
    _changeController.add(event);
  }

  /// Clear all cached formula results.
  void clearCache() => _cache.clear();

  CellValue? _formulaValueToCellValue(FormulaValue fv) {
    return switch (fv) {
      NumberValue(value: final n) => CellValue.number(n),
      TextValue(value: final s) => CellValue.text(s),
      BooleanValue(value: final b) => CellValue.boolean(b),
      ErrorValue(error: final e) => CellValue.error(e.code),
      EmptyValue() => null,
      RangeValue() => CellValue.text(fv.toText()),
    };
  }

  // --- Delegate everything else to _inner ---

  @override
  CellStyle? getStyle(CellCoordinate coord) => _inner.getStyle(coord);

  @override
  void setStyle(CellCoordinate coord, CellStyle? style) =>
      _inner.setStyle(coord, style);

  @override
  CellFormat? getFormat(CellCoordinate coord) => _inner.getFormat(coord);

  @override
  void setFormat(CellCoordinate coord, CellFormat? format) =>
      _inner.setFormat(coord, format);

  @override
  void batchUpdate(void Function(WorksheetDataBatch batch) updates) =>
      _inner.batchUpdate(updates);

  @override
  Future<void> batchUpdateAsync(
    Future<void> Function(WorksheetDataBatch batch) updates,
  ) =>
      _inner.batchUpdateAsync(updates);

  @override
  Stream<DataChangeEvent> get changes => _changeController.stream;

  @override
  int get rowCount => _inner.rowCount;

  @override
  int get columnCount => _inner.columnCount;

  @override
  bool hasValue(CellCoordinate coord) => _inner.hasValue(coord);

  @override
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
          CellRange range) =>
      _inner.getCellsInRange(range);

  @override
  void clearRange(CellRange range) => _inner.clearRange(range);

  @override
  void smartFill(
    CellRange range,
    CellCoordinate destination, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) =>
      _inner.smartFill(range, destination, valueGenerator);

  @override
  void fillRange(
    CellCoordinate source,
    CellRange range, [
    Cell? Function(CellCoordinate coord, Cell? sourceCell)? valueGenerator,
  ]) =>
      _inner.fillRange(source, range, valueGenerator);

  @override
  void dispose() {
    _innerSub.cancel();
    _changeController.close();
    _cache.clear();
    _dependencies.clear();
  }
}
