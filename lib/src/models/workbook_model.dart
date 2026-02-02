import 'package:flutter/foundation.dart';
import 'package:worksheet_formula/worksheet_formula.dart';

import '../constants.dart';
import 'sheet_model.dart';

class WorkbookModel extends ChangeNotifier {
  WorkbookModel({FormulaEngine? formulaEngine})
      : _formulaEngine = formulaEngine ?? FormulaEngine() {
    _sheets.add(SheetModel(
      name: defaultSheetName,
      formulaEngine: _formulaEngine,
    ));
  }

  final FormulaEngine _formulaEngine;
  final List<SheetModel> _sheets = [];
  int _activeSheetIndex = 0;

  List<SheetModel> get sheets => List.unmodifiable(_sheets);
  int get activeSheetIndex => _activeSheetIndex;
  SheetModel get activeSheet => _sheets[_activeSheetIndex];
  int get sheetCount => _sheets.length;

  void switchSheet(int index) {
    if (index < 0 || index >= _sheets.length) return;
    if (index == _activeSheetIndex) return;
    _activeSheetIndex = index;
    notifyListeners();
  }

  void addSheet({String? name}) {
    final sheetName = name ?? 'Sheet${_sheets.length + 1}';
    _sheets.add(SheetModel(
      name: sheetName,
      formulaEngine: _formulaEngine,
    ));
    _activeSheetIndex = _sheets.length - 1;
    notifyListeners();
  }

  void removeSheet(int index) {
    if (_sheets.length <= 1) return;
    if (index < 0 || index >= _sheets.length) return;
    _sheets[index].dispose();
    _sheets.removeAt(index);
    if (_activeSheetIndex >= _sheets.length) {
      _activeSheetIndex = _sheets.length - 1;
    }
    notifyListeners();
  }

  void renameSheet(int index, String newName) {
    if (index < 0 || index >= _sheets.length) return;
    if (newName.isEmpty) return;
    _sheets[index] = _sheets[index].copyWithName(newName);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sheet in _sheets) {
      sheet.dispose();
    }
    super.dispose();
  }
}
