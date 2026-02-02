import 'package:worksheet/worksheet.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

import '../constants.dart';
import '../services/formula_worksheet_data.dart';

class SheetModel {
  SheetModel({
    required this.name,
    SparseWorksheetData? rawData,
    FormulaWorksheetData? formulaData,
    WorksheetController? controller,
    Map<int, double>? customColumnWidths,
    Map<int, double>? customRowHeights,
    FormulaEngine? formulaEngine,
  })  : rawData = rawData ??
            SparseWorksheetData(
              rowCount: defaultRowCount,
              columnCount: defaultColumnCount,
            ),
        controller = controller ?? WorksheetController(),
        customColumnWidths = customColumnWidths ?? {},
        customRowHeights = customRowHeights ?? {} {
    this.formulaData =
        formulaData ?? FormulaWorksheetData(this.rawData, engine: formulaEngine);
  }

  final String name;
  final SparseWorksheetData rawData;
  late final FormulaWorksheetData formulaData;
  final WorksheetController controller;
  final Map<int, double> customColumnWidths;
  final Map<int, double> customRowHeights;

  SheetModel copyWithName(String newName) {
    return SheetModel(
      name: newName,
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
  }
}
