import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';
import '../models/sheet_model.dart';
import '../models/workbook_model.dart';
import '../services/persistence_service.dart';
import '../services/undo_manager.dart';
import 'formula_bar.dart';
import 'formatting_toolbar.dart';
import 'sheet_tabs.dart';
import 'zoom_controls.dart';

// JS interop for system date format detection.
@JS('Date')
extension type _JSDate._(JSObject _) implements JSObject {
  external factory _JSDate(int year, int month, int day);
}

@JS('Intl.DateTimeFormat')
extension type _JSIntlDateTimeFormat._(JSObject _) implements JSObject {
  external factory _JSIntlDateTimeFormat([JSAny? locales, JSAny? options]);
  external JSString format(_JSDate date);
}

/// Detects the system date format by formatting a known test date
/// (Jan 15 2024) via the browser's Intl.DateTimeFormat and inspecting
/// the component order.
CellFormat _detectSystemDateFormat() {
  try {
    final date = _JSDate(2024, 0, 15); // JS months are 0-based
    final options = <String, String>{
      'year': 'numeric',
      'month': 'numeric',
      'day': 'numeric',
    }.jsify();
    final formatter = _JSIntlDateTimeFormat(null, options);
    final formatted = formatter.format(date).toDart;

    // Extract the separator character (first non-digit)
    final sepMatch = RegExp(r'[^\d]').firstMatch(formatted);
    final sep = sepMatch?.group(0) ?? '/';

    // Split into numeric parts
    final parts = formatted.split(RegExp(r'[^\d]+'));
    if (parts.length < 3) return CellFormat.dateIso;

    // year=2024, month=1, day=15
    if (parts[0] == '2024') {
      return CellFormat.dateIso; // YMD
    } else if (parts[0] == '15') {
      return CellFormat(
        type: CellFormatType.date,
        formatCode: 'd${sep}m${sep}yyyy',
      ); // DMY
    } else {
      return CellFormat(
        type: CellFormatType.date,
        formatCode: 'm${sep}d${sep}yyyy',
      ); // MDY
    }
  } catch (_) {
    return CellFormat.dateIso;
  }
}

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
  CellValue? _evaluatedCellValue;
  CellStyle? _selectedCellStyle;
  CellFormat? _selectedCellFormat;

  late EditController _editController;
  StreamSubscription<DataChangeEvent>? _dataChangeSub;
  FocusNode? _worksheetFocusNode;

  WorkbookModel get _workbook => widget.workbook;

  @override
  void initState() {
    super.initState();
    _editController = EditController();
    _workbook.addListener(_onWorkbookChanged);
    _workbook.activeSheet.controller.addListener(_onControllerChanged);
    _dataChangeSub = _workbook.activeSheet.formulaData.changes.listen(
      _onDataChange,
    );
    _captureWorksheetFocusNode();
  }

  @override
  void dispose() {
    _dataChangeSub?.cancel();
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

    // Re-subscribe to data changes for the new active sheet
    _dataChangeSub?.cancel();
    _dataChangeSub = _workbook.activeSheet.formulaData.changes.listen(
      _onDataChange,
    );

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
      _evaluatedCellValue = null;
      _selectedCellStyle = null;
      _selectedCellFormat = null;
      return;
    }

    final sheet = _workbook.activeSheet;
    // Show raw value in formula bar (so formulas display as "=SUM(...)")
    _selectedCellValue = sheet.rawData.getCell(_selectedCell!);
    _evaluatedCellValue = sheet.formulaData.getCell(_selectedCell!);
    _selectedCellStyle = sheet.rawData.getStyle(_selectedCell!);
    _selectedCellFormat = sheet.rawData.getFormat(_selectedCell!);
  }

  void _onDataChange(DataChangeEvent event) {
    widget.persistenceService.scheduleSave(_workbook);
    if (event.type == DataChangeType.cellValue && event.cell != null) {
      _maybeAutoAlign(event.cell!);
      _maybeAutoFormatDate(event.cell!);
    }
    setState(_updateSelectedCellInfo);
  }

  void _onCellTap(CellCoordinate cell) {
    // Return focus to the Worksheet so arrow keys work
    if (_worksheetFocusNode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _worksheetFocusNode?.requestFocus();
      });
    }

    setState(() {
      _selectedCell = cell;
      _updateSelectedCellInfo();
    });
  }

  /// Returns the default alignment for a cell value type.
  /// Numbers and dates align right; everything else aligns left.
  static CellTextAlignment _defaultAlignmentFor(CellValue? value) {
    if (value != null &&
        (value.type == CellValueType.number ||
            value.type == CellValueType.date)) {
      return CellTextAlignment.right;
    }
    return CellTextAlignment.left;
  }

  /// Auto-sets alignment on [cell] when textAlignment is null.
  ///
  /// Writes directly to sparseData so the change is captured in the
  /// same undo snapshot that UndoableWorksheetData.setCell is building
  /// (the after-snapshot hasn't been taken yet when our listener fires).
  void _maybeAutoAlign(CellCoordinate cell) {
    final sheet = _workbook.activeSheet;
    final currentStyle = sheet.rawData.getStyle(cell);
    if (currentStyle?.textAlignment != null) return;

    final value = sheet.rawData.getCell(cell);
    final alignment = _defaultAlignmentFor(value);
    final style = (currentStyle ?? const CellStyle()).copyWith(
      textAlignment: alignment,
    );
    sheet.sparseData.setStyle(cell, style);
  }

  /// Cached system date format, detected once from the browser.
  static final CellFormat _systemDateFormat = _detectSystemDateFormat();

  /// Auto-sets a locale-appropriate date format when a date is entered
  /// without an explicit format. Writes directly to sparseData so the
  /// change is captured in the same undo snapshot.
  void _maybeAutoFormatDate(CellCoordinate cell) {
    final sheet = _workbook.activeSheet;
    final value = sheet.rawData.getCell(cell);
    if (value == null || !value.isDate) return;

    final currentFormat = sheet.rawData.getFormat(cell);
    if (currentFormat != null) return;

    sheet.sparseData.setFormat(cell, _systemDateFormat);
  }

  void _setCellValue(CellCoordinate cell, String text) {
    final sheet = _workbook.activeSheet;
    final value = CellValue.parse(text);
    sheet.formulaData.setCell(cell, value);

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onFormulaBarSubmit(CellCoordinate cell, String text) {
    _setCellValue(cell, text);
  }

  void _onStyleChanged(CellStyle style) {
    if (_selectedCell == null) return;

    final sheet = _workbook.activeSheet;
    final range = sheet.controller.selectedRange;

    if (range != null) {
      sheet.rawData.batchUpdate((batch) {
        for (final coord in range.cells) {
          final existing = sheet.rawData.getStyle(coord) ?? const CellStyle();
          batch.setStyle(coord, existing.merge(style));
        }
      });
    } else {
      final existing =
          sheet.rawData.getStyle(_selectedCell!) ?? const CellStyle();
      sheet.rawData.setStyle(_selectedCell!, existing.merge(style));
    }

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onFormatChanged(CellFormat format) {
    if (_selectedCell == null) return;

    final sheet = _workbook.activeSheet;
    final range = sheet.controller.selectedRange;

    if (range != null) {
      sheet.rawData.batchUpdate((batch) {
        for (final coord in range.cells) {
          batch.setFormat(coord, format);
        }
      });
    } else {
      sheet.rawData.setFormat(_selectedCell!, format);
    }

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _toggleBold() {
    if (_selectedCell == null) return;
    final sheet = _workbook.activeSheet;
    final existing =
        sheet.rawData.getStyle(_selectedCell!) ?? const CellStyle();
    final newWeight = existing.fontWeight == FontWeight.bold
        ? FontWeight.normal
        : FontWeight.bold;
    _onStyleChanged(CellStyle(fontWeight: newWeight));
  }

  void _toggleItalic() {
    if (_selectedCell == null) return;
    final sheet = _workbook.activeSheet;
    final existing =
        sheet.rawData.getStyle(_selectedCell!) ?? const CellStyle();
    final newStyle = existing.fontStyle == FontStyle.italic
        ? FontStyle.normal
        : FontStyle.italic;
    _onStyleChanged(CellStyle(fontStyle: newStyle));
  }

  void _onResizeColumn(int column, double newWidth) {
    final sheet = _workbook.activeSheet;
    final oldWidth = sheet.customColumnWidths[column];
    sheet.customColumnWidths[column] = newWidth;
    // Extract column letter from notation (e.g. "A1" → "A")
    final colLetter = CellCoordinate(
      0,
      column,
    ).toNotation().replaceAll(RegExp(r'\d+$'), '');
    sheet.undoManager.push(
      ResizeColumnAction(
        columnWidths: sheet.customColumnWidths,
        column: column,
        oldWidth: oldWidth,
        newWidth: newWidth,
        description: 'Resize Column $colLetter',
      ),
    );
    widget.persistenceService.scheduleSave(_workbook);
    setState(() {});
  }

  void _onResizeRow(int row, double newHeight) {
    final sheet = _workbook.activeSheet;
    final oldHeight = sheet.customRowHeights[row];
    sheet.customRowHeights[row] = newHeight;
    sheet.undoManager.push(
      ResizeRowAction(
        rowHeights: sheet.customRowHeights,
        row: row,
        oldHeight: oldHeight,
        newHeight: newHeight,
        description: 'Resize Row ${row + 1}',
      ),
    );
    widget.persistenceService.scheduleSave(_workbook);
    setState(() {});
  }

  void _undoN(int n) {
    final sheet = _workbook.activeSheet;
    sheet.undoManager.undoN(n);
    widget.persistenceService.scheduleSave(_workbook);
    setState(_updateSelectedCellInfo);
  }

  void _redoN(int n) {
    final sheet = _workbook.activeSheet;
    sheet.undoManager.redoN(n);
    widget.persistenceService.scheduleSave(_workbook);
    setState(_updateSelectedCellInfo);
  }

  void _undo() => _undoN(1);

  void _redo() => _redoN(1);

  @override
  Widget build(BuildContext context) {
    final sheet = _workbook.activeSheet;

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              widget.persistenceService.save(_workbook),
          const SingleActivator(LogicalKeyboardKey.keyB, control: true):
              _toggleBold,
          const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
              _toggleBold,
          const SingleActivator(LogicalKeyboardKey.keyI, control: true):
              _toggleItalic,
          const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
              _toggleItalic,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): _redo,
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): _redo,
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
              undoDescriptions: sheet.undoManager.undoDescriptions,
              redoDescriptions: sheet.undoManager.redoDescriptions,
              onUndoN: _undoN,
              onRedoN: _redoN,
            ),
            Expanded(
              child: WorksheetTheme(
                data: const WorksheetThemeData(),
                child: Worksheet(
                  key: ValueKey(sheet.name),
                  data: sheet.formulaData,
                  controller: sheet.controller,
                  editController: _editController,
                  dateParser: AnyDate(),
                  rowCount: defaultRowCount,
                  columnCount: defaultColumnCount,
                  customColumnWidths: sheet.customColumnWidths,
                  customRowHeights: sheet.customRowHeights,
                  onCellTap: _onCellTap,
                  onResizeColumn: _onResizeColumn,
                  onResizeRow: _onResizeRow,
                ),
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
      decoration: const BoxDecoration(color: primaryColor),
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
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          _MenuButton(
            label: 'Import',
            icon: Icons.file_upload_outlined,
            onPressed: () => widget.persistenceService.importFile(_workbook),
          ),
          _MenuButton(
            label: 'Export',
            icon: Icons.file_download_outlined,
            onPressed: () => widget.persistenceService.exportFile(_workbook),
          ),
        ],
      ),
    );
  }

  /// Returns a display string for the cell value type shown in the status bar.
  String _cellTypeName() {
    final raw = _selectedCellValue;
    final evaluated = _evaluatedCellValue;

    if (raw == null && evaluated == null) return '';

    if (raw != null && raw.isFormula) {
      if (evaluated == null) return 'Formula';
      final resultType = switch (evaluated.type) {
        CellValueType.number => 'Number',
        CellValueType.text => 'Text',
        CellValueType.boolean => 'Boolean',
        CellValueType.date => 'Date',
        CellValueType.error => 'Error',
        CellValueType.formula => 'Formula',
      };
      return 'Formula \u203A $resultType';
    }

    final value = evaluated ?? raw;
    return switch (value!.type) {
      CellValueType.text => 'Text',
      CellValueType.number => 'Number',
      CellValueType.boolean => 'Boolean',
      CellValueType.date => 'Date',
      CellValueType.error => 'Error',
      CellValueType.formula => 'Formula',
    };
  }

  Widget _buildStatusBar(SheetModel sheet) {
    final typeName = _cellTypeName();
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: headerBackground,
        border: Border(top: BorderSide(color: toolbarBorder)),
      ),
      child: Row(
        children: [
          Expanded(child: SheetTabs(workbook: _workbook)),
          if (typeName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                typeName,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
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
