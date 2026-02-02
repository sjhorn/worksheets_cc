import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';
import '../models/sheet_model.dart';
import '../models/workbook_model.dart';
import '../services/formula_service.dart';
import '../services/persistence_service.dart';
import 'formula_bar.dart';
import 'formatting_toolbar.dart';
import 'sheet_tabs.dart';
import 'zoom_controls.dart';

class SpreadsheetPage extends StatefulWidget {
  const SpreadsheetPage({
    super.key,
    required this.workbook,
    required this.formulaService,
    required this.persistenceService,
  });

  final WorkbookModel workbook;
  final FormulaService formulaService;
  final WebPersistenceService persistenceService;

  @override
  State<SpreadsheetPage> createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  CellCoordinate? _selectedCell;
  CellValue? _selectedCellValue;
  CellStyle? _selectedCellStyle;
  CellFormat? _selectedCellFormat;

  WorkbookModel get _workbook => widget.workbook;
  FormulaService get _formulaService => widget.formulaService;

  @override
  void initState() {
    super.initState();
    _workbook.addListener(_onWorkbookChanged);
  }

  @override
  void dispose() {
    _workbook.removeListener(_onWorkbookChanged);
    super.dispose();
  }

  void _onWorkbookChanged() {
    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _updateSelectedCellInfo() {
    if (_selectedCell == null) {
      _selectedCellValue = null;
      _selectedCellStyle = null;
      _selectedCellFormat = null;
      return;
    }

    final data = _workbook.activeSheet.data;
    _selectedCellValue = data.getCell(_selectedCell!);
    _selectedCellStyle = data.getStyle(_selectedCell!);
    _selectedCellFormat = data.getFormat(_selectedCell!);
  }

  void _onCellTap(CellCoordinate cell) {
    setState(() {
      _selectedCell = cell;
      _updateSelectedCellInfo();
    });
  }

  void _onEditCell(CellCoordinate cell) {
    _showCellEditor(cell);
  }

  void _showCellEditor(CellCoordinate cell) {
    final data = _workbook.activeSheet.data;
    final currentValue = data.getCell(cell);

    String initialText;
    if (currentValue != null && currentValue.isFormula) {
      initialText = currentValue.rawValue as String;
    } else if (currentValue != null) {
      initialText = currentValue.displayValue;
    } else {
      initialText = '';
    }

    final controller = TextEditingController(text: initialText);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${cell.toNotation()}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) {
            _setCellValue(cell, value);
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _setCellValue(cell, controller.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _setCellValue(CellCoordinate cell, String text) {
    final data = _workbook.activeSheet.data;

    if (text.isEmpty) {
      data.setCell(cell, null);
    } else if (text.startsWith('=')) {
      data.setCell(cell, CellValue.formula(text));
    } else {
      final number = num.tryParse(text);
      if (number != null) {
        data.setCell(cell, CellValue.number(number));
      } else {
        data.setCell(cell, CellValue.text(text));
      }
    }

    _formulaService.onCellChanged(cell, data);
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

    final data = _workbook.activeSheet.data;
    final existing = data.getStyle(_selectedCell!) ?? const CellStyle();
    data.setStyle(_selectedCell!, existing.merge(style));
    widget.persistenceService.scheduleSave(_workbook);

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onFormatChanged(CellFormat format) {
    if (_selectedCell == null) return;

    final data = _workbook.activeSheet.data;
    data.setFormat(_selectedCell!, format);
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
        child: Focus(
          autofocus: true,
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
                child: WorksheetTheme(
                  data: const WorksheetThemeData(),
                  child: Worksheet(
                    key: ValueKey(sheet.name),
                    data: sheet.data,
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
              ),
              _buildStatusBar(sheet),
            ],
          ),
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
