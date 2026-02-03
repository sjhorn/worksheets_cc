import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

import '../constants.dart';
import '../services/formula_worksheet_data.dart';
import '../services/undo_manager.dart';
import '../services/undoable_worksheet_data.dart';

class SheetModel {
  SheetModel({
    required this.name,
    SparseWorksheetData? sparseData,
    UndoManager? undoManager,
    UndoableWorksheetData? rawData,
    FormulaWorksheetData? formulaData,
    WorksheetController? controller,
    Map<int, double>? customColumnWidths,
    Map<int, double>? customRowHeights,
    FormulaEngine? formulaEngine,
  })  : sparseData = sparseData ??
            SparseWorksheetData(
              rowCount: defaultRowCount,
              columnCount: defaultColumnCount,
            ),
        undoManager = undoManager ?? UndoManager(),
        controller = controller ?? WorksheetController(),
        customColumnWidths = customColumnWidths ?? {},
        customRowHeights = customRowHeights ?? {} {
    this.rawData =
        rawData ?? UndoableWorksheetData(this.sparseData, this.undoManager);
    this.formulaData =
        formulaData ?? FormulaWorksheetData(this.rawData, engine: formulaEngine);
  }

  final String name;
  final SparseWorksheetData sparseData;
  final UndoManager undoManager;
  late final UndoableWorksheetData rawData;
  late final FormulaWorksheetData formulaData;
  final WorksheetController controller;
  final Map<int, double> customColumnWidths;
  final Map<int, double> customRowHeights;

  SheetModel copyWithName(String newName) {
    return SheetModel(
      name: newName,
      sparseData: sparseData,
      undoManager: undoManager,
      rawData: rawData,
      formulaData: formulaData,
      controller: controller,
      customColumnWidths: customColumnWidths,
      customRowHeights: customRowHeights,
    );
  }

  void dispose() {
    controller.dispose();
    formulaData.dispose();
    rawData.dispose();
    sparseData.dispose();
  }
}
