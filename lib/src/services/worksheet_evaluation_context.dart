import 'package:a1/a1.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

/// Concrete [EvaluationContext] that reads cell data from a [WorksheetData].
///
/// Supports recursive formula evaluation with circular reference detection.
class WorksheetEvaluationContext implements EvaluationContext {
  final WorksheetData data;
  final FunctionRegistry functions;
  final FormulaEngine engine;

  @override
  final A1 currentCell;

  @override
  final String? currentSheet;

  @override
  bool get isCancelled => false;

  /// Cells currently being evaluated — used to detect circular references.
  final Set<A1> _evaluating;

  WorksheetEvaluationContext({
    required this.data,
    required this.functions,
    required this.engine,
    required this.currentCell,
    this.currentSheet,
    Set<A1>? evaluating,
  }) : _evaluating = evaluating ?? {};

  @override
  FormulaValue getCellValue(A1 cell) {
    if (_evaluating.contains(cell)) {
      return const FormulaValue.error(FormulaError.circular);
    }

    final coord = CellCoordinate(cell.row, cell.column);
    final cellValue = data.getCell(coord);

    if (cellValue == null) {
      return const EmptyValue();
    }

    if (cellValue.isFormula) {
      final formulaString = cellValue.rawValue as String;
      final nestedContext = WorksheetEvaluationContext(
        data: data,
        functions: functions,
        engine: engine,
        currentCell: cell,
        currentSheet: currentSheet,
        evaluating: {..._evaluating, currentCell},
      );

      try {
        return engine.evaluateString(formulaString, nestedContext);
      } catch (_) {
        return const FormulaValue.error(FormulaError.value);
      }
    }

    return _cellValueToFormulaValue(cellValue);
  }

  @override
  FormulaValue getRangeValues(A1Range range) {
    final fromA1 = range.from.a1;
    final toA1 = range.to.a1;
    if (fromA1 == null || toA1 == null) {
      return const FormulaValue.error(FormulaError.ref);
    }

    final rows = <List<FormulaValue>>[];
    for (var row = fromA1.row; row <= toA1.row; row++) {
      final rowValues = <FormulaValue>[];
      for (var col = fromA1.column; col <= toA1.column; col++) {
        final cell = A1.fromVector(col, row);
        rowValues.add(getCellValue(cell));
      }
      rows.add(rowValues);
    }
    return FormulaValue.range(rows);
  }

  @override
  FormulaFunction? getFunction(String name) => functions.get(name);

  FormulaValue _cellValueToFormulaValue(CellValue cv) {
    if (cv.isNumber) return FormulaValue.number(cv.asDouble);
    if (cv.isText) return FormulaValue.text(cv.rawValue as String);
    if (cv.isBoolean) return FormulaValue.boolean(cv.rawValue as bool);
    if (cv.isError) return const FormulaValue.error(FormulaError.value);
    if (cv.isDate) {
      final epoch = DateTime.utc(1899, 12, 30);
      final date = cv.asDateTime;
      final utcDate = DateTime.utc(date.year, date.month, date.day);
      return FormulaValue.number(utcDate.difference(epoch).inDays);
    }
    return const EmptyValue();
  }
}
