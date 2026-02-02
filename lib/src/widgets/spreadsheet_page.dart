import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';
import '../models/sheet_model.dart';
import '../models/workbook_model.dart';
import '../services/persistence_service.dart';
import 'formula_bar.dart';
import 'formatting_toolbar.dart';
import 'sheet_tabs.dart';
import 'zoom_controls.dart';

class SpreadsheetPage extends StatefulWidget {
  const SpreadsheetPage({
    super.key,
    required this.workbook,
    required this.persistenceService,
  });

  final WorkbookModel workbook;
  final WebPersistenceService persistenceService;

  @override
  State<SpreadsheetPage> createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  CellCoordinate? _selectedCell;
  CellValue? _selectedCellValue;
  CellStyle? _selectedCellStyle;
  CellFormat? _selectedCellFormat;

  late EditController _editController;
  Rect? _editingCellBounds;
  FocusNode? _worksheetFocusNode;

  WorkbookModel get _workbook => widget.workbook;

  @override
  void initState() {
    super.initState();
    _editController = EditController();
    _workbook.addListener(_onWorkbookChanged);
    _workbook.activeSheet.controller.addListener(_onControllerChanged);
    _captureWorksheetFocusNode();
  }

  @override
  void dispose() {
    _workbook.activeSheet.controller.removeListener(_onControllerChanged);
    _workbook.removeListener(_onWorkbookChanged);
    _editController.dispose();
    super.dispose();
  }

  /// After a build frame, capture the Worksheet's internal FocusNode.
  /// The Worksheet uses Focus(autofocus: true), so after the first frame
  /// it becomes the primaryFocus. We save the reference so we can
  /// re-focus it after the formula bar steals focus.
  void _captureWorksheetFocusNode([int retries = 20]) {
    if (retries <= 0 || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary != null && primary is! FocusScopeNode) {
        _worksheetFocusNode = primary;
      } else {
        _captureWorksheetFocusNode(retries - 1);
      }
    });
  }

  void _onWorkbookChanged() {
    // Re-attach controller listener when active sheet changes
    for (final sheet in _workbook.sheets) {
      sheet.controller.removeListener(_onControllerChanged);
    }
    _workbook.activeSheet.controller.addListener(_onControllerChanged);

    // Re-capture the Worksheet's FocusNode after the new sheet builds
    _captureWorksheetFocusNode();

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onControllerChanged() {
    final focusCell = _workbook.activeSheet.controller.focusCell;
    if (focusCell != _selectedCell) {
      setState(() {
        _selectedCell = focusCell;
        _updateSelectedCellInfo();
      });
    }
  }

  void _updateSelectedCellInfo() {
    if (_selectedCell == null) {
      _selectedCellValue = null;
      _selectedCellStyle = null;
      _selectedCellFormat = null;
      return;
    }

    final sheet = _workbook.activeSheet;
    // Show raw value in formula bar (so formulas display as "=SUM(...)")
    _selectedCellValue = sheet.rawData.getCell(_selectedCell!);
    _selectedCellStyle = sheet.rawData.getStyle(_selectedCell!);
    _selectedCellFormat = sheet.rawData.getFormat(_selectedCell!);
  }

  void _onCellTap(CellCoordinate cell) {
    // If editing a different cell, commit the current edit first
    if (_editController.isEditing && _editController.editingCell != cell) {
      _editController.commitEdit(onCommit: _onCommitEdit);
    }

    // Return focus to the Worksheet's internal Focus node so arrow keys work.
    // Deferred to post-frame because on Flutter web, unfocusing a TextField
    // triggers browser-level text input cleanup that can override a
    // synchronous requestFocus() call.
    if (_worksheetFocusNode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _worksheetFocusNode?.requestFocus();
      });
    }

    setState(() {
      _editingCellBounds = null;
      _selectedCell = cell;
      _updateSelectedCellInfo();
    });
  }

  void _onEditCell(CellCoordinate cell) {
    final sheet = _workbook.activeSheet;
    final rawValue = sheet.rawData.getCell(cell);

    final bounds = sheet.controller.getCellScreenBounds(cell);
    if (bounds == null) return;

    _editController.startEdit(
      cell: cell,
      currentValue: rawValue,
      trigger: EditTrigger.doubleTap,
    );

    setState(() {
      _selectedCell = cell;
      _editingCellBounds = bounds;
      _updateSelectedCellInfo();
    });
  }

  void _onCommitEdit(CellCoordinate cell, CellValue? value) {
    final sheet = _workbook.activeSheet;
    sheet.formulaData.setCell(cell, value);
    widget.persistenceService.scheduleSave(_workbook);

    setState(() {
      _editingCellBounds = null;
      _updateSelectedCellInfo();
    });
  }

  void _onCancelEdit() {
    setState(() {
      _editingCellBounds = null;
    });
  }

  void _setCellValue(CellCoordinate cell, String text) {
    final sheet = _workbook.activeSheet;

    CellValue? value;
    if (text.isEmpty) {
      value = null;
    } else if (text.startsWith('=')) {
      value = CellValue.formula(text);
    } else {
      final number = num.tryParse(text);
      if (number != null) {
        value = CellValue.number(number);
      } else {
        value = CellValue.text(text);
      }
    }

    sheet.formulaData.setCell(cell, value);
    widget.persistenceService.scheduleSave(_workbook);

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onFormulaBarSubmit(String text) {
    if (_selectedCell != null) {
      _setCellValue(_selectedCell!, text);
    }
  }

  void _onStyleChanged(CellStyle style) {
    if (_selectedCell == null) return;

    final sheet = _workbook.activeSheet;
    final existing = sheet.rawData.getStyle(_selectedCell!) ?? const CellStyle();
    sheet.rawData.setStyle(_selectedCell!, existing.merge(style));
    widget.persistenceService.scheduleSave(_workbook);

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onFormatChanged(CellFormat format) {
    if (_selectedCell == null) return;

    final sheet = _workbook.activeSheet;
    sheet.rawData.setFormat(_selectedCell!, format);
    widget.persistenceService.scheduleSave(_workbook);

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onResizeColumn(int column, double newWidth) {
    _workbook.activeSheet.customColumnWidths[column] = newWidth;
    widget.persistenceService.scheduleSave(_workbook);
    setState(() {});
  }

  void _onResizeRow(int row, double newHeight) {
    _workbook.activeSheet.customRowHeights[row] = newHeight;
    widget.persistenceService.scheduleSave(_workbook);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _workbook.activeSheet;

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              () => widget.persistenceService.save(_workbook),
        },
        child: Column(
            children: [
              _buildMenuBar(),
              FormulaBar(
                selectedCell: _selectedCell,
                cellValue: _selectedCellValue,
                onSubmit: _onFormulaBarSubmit,
              ),
              FormattingToolbar(
                currentStyle: _selectedCellStyle,
                currentFormat: _selectedCellFormat,
                onStyleChanged: _onStyleChanged,
                onFormatChanged: _onFormatChanged,
              ),
              Expanded(
                child: Stack(
                  children: [
                    WorksheetTheme(
                      data: const WorksheetThemeData(),
                      child: Worksheet(
                        key: ValueKey(sheet.name),
                        data: sheet.formulaData,
                        controller: sheet.controller,
                        rowCount: defaultRowCount,
                        columnCount: defaultColumnCount,
                        customColumnWidths: sheet.customColumnWidths,
                        customRowHeights: sheet.customRowHeights,
                        onCellTap: _onCellTap,
                        onEditCell: _onEditCell,
                        onResizeColumn: _onResizeColumn,
                        onResizeRow: _onResizeRow,
                      ),
                    ),
                    if (_editController.isEditing && _editingCellBounds != null)
                      CellEditorOverlay(
                        editController: _editController,
                        cellBounds: _editingCellBounds!,
                        onCommit: _onCommitEdit,
                        onCancel: _onCancelEdit,
                      ),
                  ],
                ),
              ),
              _buildStatusBar(sheet),
            ],
          ),
        ),
      );
  }

  Widget _buildMenuBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: primaryColor,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              'assets/worksheet.png',
              height: 24,
              width: 24,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            appTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _MenuButton(
            label: 'Import',
            icon: Icons.file_upload_outlined,
            onPressed: () =>
                widget.persistenceService.importFile(_workbook),
          ),
          _MenuButton(
            label: 'Export',
            icon: Icons.file_download_outlined,
            onPressed: () =>
                widget.persistenceService.exportFile(_workbook),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(SheetModel sheet) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: headerBackground,
        border: Border(top: BorderSide(color: toolbarBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SheetTabs(workbook: _workbook),
          ),
          ZoomControls(
            controller: sheet.controller,
            onZoomChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: Colors.white70),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
      ),
    );
  }
}
