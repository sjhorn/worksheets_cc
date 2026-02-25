import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

import '../constants.dart';
import '../services/formula_worksheet_data.dart';

class SheetModel {
  SheetModel({
    required this.name,
    SparseWorksheetData? sparseData,
    FormulaWorksheetData? formulaData,
    WorksheetController? controller,
    UndoManager? undoManager,
    Map<int, double>? customColumnWidths,
    Map<int, double>? customRowHeights,
    FormulaEngine? formulaEngine,
  })  : sparseData = sparseData ??
            SparseWorksheetData(
              rowCount: defaultRowCount,
              columnCount: defaultColumnCount,
            ),
        undoManager = undoManager ?? UndoManager(),
        customColumnWidths = customColumnWidths ?? {},
        customRowHeights = customRowHeights ?? {} {
    this.controller =
        controller ?? WorksheetController(undoManager: this.undoManager);
    this.formulaData = formulaData ??
        FormulaWorksheetData(this.sparseData, engine: formulaEngine);
  }

  final String name;
  final SparseWorksheetData sparseData;
  final UndoManager undoManager;
  late final FormulaWorksheetData formulaData;
  late final WorksheetController controller;
  final Map<int, double> customColumnWidths;
  final Map<int, double> customRowHeights;

  SheetModel copyWithName(String newName) {
    return SheetModel(
      name: newName,
      sparseData: sparseData,
      undoManager: undoManager,
      formulaData: formulaData,
      controller: controller,
      customColumnWidths: customColumnWidths,
      customRowHeights: customRowHeights,
    );
  }

  void dispose() {
    controller.dispose();
    formulaData.dispose();
    sparseData.dispose();
  }
}
