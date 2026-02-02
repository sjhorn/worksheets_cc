import 'package:worksheet/worksheet.dart';

import '../constants.dart';

class SheetModel {
  SheetModel({
    required this.name,
    SparseWorksheetData? data,
    WorksheetController? controller,
    Map<int, double>? customColumnWidths,
    Map<int, double>? customRowHeights,
  })  : data = data ??
            SparseWorksheetData(
              rowCount: defaultRowCount,
              columnCount: defaultColumnCount,
            ),
        controller = controller ?? WorksheetController(),
        customColumnWidths = customColumnWidths ?? {},
        customRowHeights = customRowHeights ?? {};

  final String name;
  final SparseWorksheetData data;
  final WorksheetController controller;
  final Map<int, double> customColumnWidths;
  final Map<int, double> customRowHeights;

  SheetModel copyWithName(String newName) {
    return SheetModel(
      name: newName,
      data: data,
      controller: controller,
      customColumnWidths: customColumnWidths,
      customRowHeights: customRowHeights,
    );
  }

  void dispose() {
    controller.dispose();
    data.dispose();
  }
}
