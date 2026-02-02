import 'package:a1/a1.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

class FormulaService {
  FormulaService() : _engine = FormulaEngine();

  final FormulaEngine _engine;
  final DependencyGraph _dependencyGraph = DependencyGraph();

  FormulaValue evaluateCell(
    CellCoordinate coord,
    SparseWorksheetData data,
  ) {
    final cellValue = data.getCell(coord);
    if (cellValue == null || !cellValue.isFormula) {
      return const FormulaValue.empty();
    }

    final formula = cellValue.rawValue as String;
    final currentCell = A1.fromVector(coord.column, coord.row);

    try {
      final context = _WorksheetEvaluationContext(
        data: data,
        engine: _engine,
        currentCell: currentCell,
      );
      return _engine.evaluateString(formula, context);
    } on FormulaParseException {
      return const FormulaValue.error(FormulaError.value);
    }
  }

  void onCellChanged(
    CellCoordinate coord,
    SparseWorksheetData data,
  ) {
    final cellValue = data.getCell(coord);
    final cellA1 = A1.fromVector(coord.column, coord.row);

    if (cellValue != null && cellValue.isFormula) {
      final formula = cellValue.rawValue as String;
      final refs = _engine.getCellReferences(formula);
      _dependencyGraph.updateDependencies(cellA1, refs);
    } else {
      _dependencyGraph.removeCell(cellA1);
    }

    final toRecalc = _dependencyGraph.getCellsToRecalculate(cellA1);
    for (final a1 in toRecalc) {
      if (a1 == cellA1) continue;
      final depCoord = CellCoordinate(a1.row, a1.column);
      final depValue = data.getCell(depCoord);
      if (depValue != null && depValue.isFormula) {
        evaluateCell(depCoord, data);
      }
    }
  }

  bool hasCircularReference(CellCoordinate coord) {
    final a1 = A1.fromVector(coord.column, coord.row);
    return _dependencyGraph.hasCircularReference(a1);
  }

  void clear() {
    _engine.clearCache();
    _dependencyGraph.clear();
  }
}

class _WorksheetEvaluationContext implements EvaluationContext {
  _WorksheetEvaluationContext({
    required this.data,
    required this.engine,
    required this.currentCell,
    Set<A1>? evaluating,
  }) : _evaluating = evaluating ?? {};

  final SparseWorksheetData data;
  final FormulaEngine engine;
  @override
  final A1 currentCell;
  final Set<A1> _evaluating;

  @override
  String? get currentSheet => null;

  @override
  bool get isCancelled => false;

  @override
  FormulaValue getCellValue(A1 cell) {
    if (_evaluating.contains(cell)) {
      return const FormulaValue.error(FormulaError.circular);
    }

    final coord = CellCoordinate(cell.row, cell.column);
    final cellValue = data.getCell(coord);

    if (cellValue == null) return const FormulaValue.empty();

    if (cellValue.isFormula) {
      final formula = cellValue.rawValue as String;
      try {
        final nestedContext = _WorksheetEvaluationContext(
          data: data,
          engine: engine,
          currentCell: cell,
          evaluating: {..._evaluating, currentCell},
        );
        return engine.evaluateString(formula, nestedContext);
      } on FormulaParseException {
        return const FormulaValue.error(FormulaError.value);
      }
    }

    return _cellValueToFormulaValue(cellValue);
  }

  @override
  FormulaValue getRangeValues(A1Range range) {
    final from = range.from.a1;
    final to = range.to.a1;
    if (from == null || to == null) {
      return const FormulaValue.error(FormulaError.ref);
    }

    final rows = <List<FormulaValue>>[];
    for (var r = from.row; r <= to.row; r++) {
      final row = <FormulaValue>[];
      for (var c = from.column; c <= to.column; c++) {
        row.add(getCellValue(A1.fromVector(c, r)));
      }
      rows.add(row);
    }
    return FormulaValue.range(rows);
  }

  @override
  FormulaFunction? getFunction(String name) => engine.functions.get(name);

  FormulaValue _cellValueToFormulaValue(CellValue value) {
    switch (value.type) {
      case CellValueType.number:
        return FormulaValue.number(value.asDouble);
      case CellValueType.text:
        return FormulaValue.text(value.rawValue as String);
      case CellValueType.boolean:
        return FormulaValue.boolean(value.rawValue as bool);
      case CellValueType.date:
        final dt = value.rawValue as DateTime;
        final epoch = DateTime(1899, 12, 30);
        final serial = dt.difference(epoch).inDays;
        return FormulaValue.number(serial);
      case CellValueType.error:
        return const FormulaValue.error(FormulaError.value);
      case CellValueType.formula:
        return const FormulaValue.empty();
    }
  }
}
