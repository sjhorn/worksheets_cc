import 'dart:async';

import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

import 'worksheet_evaluation_context.dart';

/// A [WorksheetData] wrapper that evaluates formula cells on the fly.
///
/// Extends [DelegatingWorksheetData] so only [getCell] and [setCell]
/// need overriding; everything else delegates to the inner data source.
/// Uses [DependencyGraph] for efficient cache invalidation when cells change.
class FormulaWorksheetData extends DelegatingWorksheetData {
  final FormulaEngine engine;
  final DependencyGraph _dependencies = DependencyGraph();
  final Map<CellCoordinate, CellValue> _cache = {};
  final StreamController<DataChangeEvent> _changeController =
      StreamController<DataChangeEvent>.broadcast();
  late final StreamSubscription<DataChangeEvent> _innerSub;

  FormulaWorksheetData(super.inner, {FormulaEngine? engine})
      : engine = engine ?? FormulaEngine() {
    _innerSub = inner.changes.listen(_onInnerChange);
  }

  /// Get the dependency graph (for inspection/debugging).
  DependencyGraph get dependencies => _dependencies;

  @override
  CellValue? getCell(CellCoordinate coord) {
    final raw = inner.getCell(coord);
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
      data: inner,
      functions: engine.functions,
      engine: engine,
      currentCell: A1.fromVector(coord.column, coord.row),
    );

    try {
      final result = engine.evaluateString(formulaString, context);
      var cellValue = _formulaValueToCellValue(result);
      // If the result is a number and the formula involves dates,
      // convert the serial number back to a date.
      if (cellValue != null &&
          cellValue.isNumber &&
          _formulaInvolvesDate(formulaString)) {
        cellValue = _serialToDate(cellValue.asDouble);
      }
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
  Iterable<MapEntry<CellCoordinate, CellValue>> getCellsInRange(
    CellRange range,
  ) sync* {
    for (final entry in inner.getCellsInRange(range)) {
      final raw = entry.value;
      if (raw.isFormula) {
        final evaluated = getCell(entry.key);
        if (evaluated != null) {
          yield MapEntry(entry.key, evaluated);
        }
      } else {
        yield entry;
      }
    }
  }

  @override
  void setCell(CellCoordinate coord, CellValue? value) {
    inner.setCell(coord, value);
    _invalidateCell(coord);
  }

  @override
  Stream<DataChangeEvent> get changes => _changeController.stream;

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
      // Invalidate each cell in the range AND propagate to dependents.
      // batchUpdate from the Worksheet widget bypasses our setCell override,
      // so we must handle dependency propagation here.
      for (final coord in event.range!.cells) {
        _invalidateCell(coord);
      }
    } else {
      _cache.clear();
    }
    _changeController.add(event);
  }

  /// Clear all cached formula results.
  void clearCache() => _cache.clear();

  /// Date function names that produce serial numbers.
  static final _dateFunctionPattern = RegExp(
    r'\b(DATE|TODAY|NOW|EDATE|EOMONTH|DATEVALUE|WORKDAY|WORKDAY\.INTL)\b',
    caseSensitive: false,
  );

  /// Returns true if the formula references date cells or uses date functions.
  bool _formulaInvolvesDate(String formula) {
    // Check for date function calls
    if (_dateFunctionPattern.hasMatch(formula)) return true;

    // Check if any referenced cell contains or evaluates to a date.
    // Uses getCell (which evaluates formulas) so chained date formulas
    // like =C5+1 where C5=C4+1 are detected.
    try {
      final refs = engine.getCellReferences(formula);
      for (final ref in refs) {
        final coord = CellCoordinate(ref.row, ref.column);
        final raw = inner.getCell(coord);
        if (raw != null && raw.isDate) return true;
        // Also check evaluated value for formula cells
        if (raw != null && raw.isFormula) {
          final evaluated = getCell(coord);
          if (evaluated != null && evaluated.isDate) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Excel epoch: 1899-12-30.
  static final _epoch = DateTime.utc(1899, 12, 30);

  /// Converts an Excel serial number back to a [CellValue.date].
  /// Returns [CellValue.number] if the serial is out of valid date range.
  CellValue _serialToDate(double serial) {
    final days = serial.truncate();
    if (days < 1 || days > 2958465) return CellValue.number(serial);
    return CellValue.date(_epoch.add(Duration(days: days)));
  }

  CellValue? _formulaValueToCellValue(FormulaValue fv) {
    return switch (fv) {
      SerialValue(value: final n) => _serialToDate(n.toDouble()),
      NumberValue(value: final n) => CellValue.number(n),
      TextValue(value: final s) => CellValue.text(s),
      BooleanValue(value: final b) => CellValue.boolean(b),
      ErrorValue(error: final e) => CellValue.error(e.code),
      EmptyValue() => null,
      RangeValue() => CellValue.text(fv.toText()),
      FunctionValue() => CellValue.text(fv.toText()),
      OmittedValue() => null,
    };
  }

  @override
  void dispose() {
    _innerSub.cancel();
    _changeController.close();
    _cache.clear();
    _dependencies.clear();
  }
}
