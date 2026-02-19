import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';
import '../models/sheet_model.dart';
import '../models/border_catalog.dart';
import '../models/font_catalog.dart';
import '../models/merge_catalog.dart';
import '../models/workbook_model.dart';
import '../services/persistence_service.dart';
import '../services/print_service.dart';
import '../services/undo_manager.dart';
import 'formula_bar.dart';
import 'formatting_toolbar.dart';
import 'sheet_tabs.dart';
import 'zoom_controls.dart';

class SpreadsheetPage extends StatefulWidget {
  const SpreadsheetPage({
    super.key,
    required this.workbook,
    required this.persistenceService,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final WorkbookModel workbook;
  final WebPersistenceService persistenceService;
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  @override
  State<SpreadsheetPage> createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  CellCoordinate? _selectedCell;
  CellValue? _selectedCellValue;
  CellValue? _evaluatedCellValue;
  CellStyle? _selectedCellStyle;
  CellFormat? _selectedCellFormat;

  /// Captured formatting for paint format mode.
  /// Holds (CellStyle, CellFormat, TextStyle) from the source cell.
  ({CellStyle? style, CellFormat? format, TextStyle? textStyle})?
      _paintFormatSource;

  bool get _isPaintFormatActive => _paintFormatSource != null;

  Color _borderPenColor = const Color(0xFF000000);
  BorderLineOption _borderPenLineOption = BorderCatalog.lineOptions.first;
  List<String> _recentFonts = [];

  late EditController _editController;
  StreamSubscription<DataChangeEvent>? _dataChangeSub;
  FocusNode? _worksheetFocusNode;

  WorkbookModel get _workbook => widget.workbook;

  @override
  void initState() {
    super.initState();
    _editController = EditController();
    _editController.addListener(_onEditControllerChanged);
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
    _editController.removeListener(_onEditControllerChanged);
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

  void _onPointerUpDuringPaintFormat(PointerUpEvent _) {
    if (!_isPaintFormatActive || _selectedCell == null) return;
    // Apply after the frame so the controller's selection is finalized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isPaintFormatActive) return;
      _applyPaintFormat(_selectedCell!);
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
    // Use evaluated value so formulas that produce numbers/dates
    // get the correct alignment (e.g. =C4+1 → date → right).
    final value = sheet.formulaData.getCell(cell);
    final alignment = _defaultAlignmentFor(value);

    // Re-apply alignment on every edit so it tracks the value type
    // (e.g. number → right, text → left).
    if (currentStyle?.textAlignment == alignment) return;

    final style = (currentStyle ?? const CellStyle()).copyWith(
      textAlignment: alignment,
    );
    sheet.sparseData.setStyle(cell, style);
  }

  void _onEditControllerChanged() {
    if (!_editController.isEditing) {
      // Editing ended — refresh cell info.
      setState(_updateSelectedCellInfo);
    }
  }

  /// Called by [FormulaBar] when it commits via [EditController.commitEdit].
  void _onFormulaBarCommit(CellCoordinate cell, CellValue? value,
      {CellFormat? detectedFormat}) {
    final sheet = _workbook.activeSheet;
    sheet.formulaData.setCell(cell, value);
    if (detectedFormat != null && sheet.rawData.getFormat(cell) == null) {
      sheet.sparseData.setFormat(cell, detectedFormat);
    }
    setState(_updateSelectedCellInfo);
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

  /// Gets the effective [TextStyle] from a cell's rich text spans.
  /// Returns the style of the first span, or null if no rich text.
  TextStyle? _getEffectiveTextStyle(CellCoordinate coord) {
    final sheet = _workbook.activeSheet;
    final richText = sheet.rawData.getRichText(coord);
    if (richText != null && richText.isNotEmpty) {
      return richText.first.style;
    }
    return null;
  }

  /// Applies a [TextStyle] toggle/change to a cell's rich text spans.
  /// If the cell has no rich text, creates a single span from the cell value.
  void _applyTextStyleToCell(
    CellCoordinate coord,
    TextStyle Function(TextStyle existing) transform,
  ) {
    final sheet = _workbook.activeSheet;
    var richText = sheet.rawData.getRichText(coord);
    if (richText == null || richText.isEmpty) {
      // Create a single span from the cell value text
      final value = sheet.rawData.getCell(coord);
      final text = value?.rawValue.toString() ?? '';
      richText = [TextSpan(text: text)];
    }
    final updated = richText.map((span) {
      final existing = span.style ?? const TextStyle();
      return TextSpan(text: span.text, style: transform(existing));
    }).toList();
    sheet.rawData.setRichText(coord, updated);
  }

  /// Applies a text style change to the selected cell(s) or range.
  void _applyTextStyleChange(
      TextStyle Function(TextStyle existing) transform) {
    if (_selectedCell == null) return;
    final sheet = _workbook.activeSheet;
    final range = sheet.controller.selectedRange;

    if (range != null) {
      sheet.rawData.batchUpdate((batch) {
        for (final coord in range.cells) {
          _applyTextStyleToCell(coord, transform);
        }
      });
    } else {
      _applyTextStyleToCell(_selectedCell!, transform);
    }
    setState(_updateSelectedCellInfo);
  }

  /// Resolves a Google Fonts family name to the registered variant name.
  /// System fonts pass through unchanged.
  String _resolveGoogleFont(String family,
      {FontWeight? weight, FontStyle? fontStyle}) {
    if (!FontCatalog.isGoogleFont(family)) return family;
    final resolved = GoogleFonts.getFont(
      family,
      fontWeight: weight ?? FontWeight.normal,
      fontStyle: fontStyle ?? FontStyle.normal,
    );
    return resolved.fontFamily!;
  }

  void _onFontFamilyChanged(String family) {
    if (_selectedCell == null) return;
    if (_editController.isEditing) {
      final resolved = _resolveGoogleFont(family);
      _editController.richTextController?.setFontFamily(resolved);
      _editController.requestEditorFocus();
      setState(() {});
      return;
    }
    _applyTextStyleChange((ts) {
      if (!FontCatalog.isGoogleFont(family)) {
        return ts.copyWith(fontFamily: family);
      }
      final resolvedStyle = GoogleFonts.getFont(
        family,
        fontWeight: ts.fontWeight ?? FontWeight.normal,
        fontStyle: ts.fontStyle ?? FontStyle.normal,
      );
      return ts.copyWith(
        fontFamily: resolvedStyle.fontFamily,
        fontFamilyFallback: resolvedStyle.fontFamilyFallback,
      );
    });
  }

  void _onFontSizeChanged(double size) {
    if (_selectedCell == null) return;
    if (_editController.isEditing) {
      _editController.richTextController?.setFontSize(size);
      _editController.requestEditorFocus();
      setState(() {});
      return;
    }
    _applyTextStyleChange(
        (ts) => ts.copyWith(fontSize: size));
  }

  void _onTextColorChanged(Color color) {
    if (_selectedCell == null) return;
    if (_editController.isEditing) {
      _editController.richTextController?.setColor(color);
      _editController.requestEditorFocus();
      setState(() {});
      return;
    }
    _applyTextStyleChange(
        (ts) => ts.copyWith(color: color));
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

  void _onClearFormatting() {
    if (_selectedCell == null) return;

    final sheet = _workbook.activeSheet;
    final range = sheet.controller.selectedRange;

    if (range != null) {
      sheet.rawData.batchUpdate((batch) {
        batch.clearFormats(range);
        batch.clearStyles(range);
        for (final coord in range.cells) {
          batch.setRichText(coord, null);
        }
      });
    } else {
      sheet.rawData.setFormat(_selectedCell!, null);
      sheet.rawData.setStyle(_selectedCell!, null);
      sheet.rawData.setRichText(_selectedCell!, null);
    }

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _onPaintFormat() {
    if (_selectedCell == null) return;
    final sheet = _workbook.activeSheet;
    final coord = _selectedCell!;
    setState(() {
      _paintFormatSource = (
        style: sheet.rawData.getStyle(coord),
        format: sheet.rawData.getFormat(coord),
        textStyle: _getEffectiveTextStyle(coord),
      );
    });
  }

  void _onPrint() {
    PrintService.printSheet(_workbook.activeSheet);
  }

  void _applyPaintFormat(CellCoordinate target) {
    final source = _paintFormatSource;
    if (source == null) return;

    final sheet = _workbook.activeSheet;
    final range = sheet.controller.selectedRange;
    final targets =
        range != null ? range.cells.toList() : [target];

    sheet.rawData.batchUpdate((batch) {
      for (final coord in targets) {
        if (source.style != null) {
          batch.setStyle(coord, source.style!);
        }
        if (source.format != null) {
          batch.setFormat(coord, source.format!);
        }
        if (source.textStyle != null) {
          // Apply source text style to target, preserving text content
          var richText = sheet.rawData.getRichText(coord);
          if (richText == null || richText.isEmpty) {
            final value = sheet.rawData.getCell(coord);
            final text = value?.rawValue.toString() ?? '';
            if (text.isNotEmpty) {
              richText = [TextSpan(text: text)];
            }
          }
          if (richText != null && richText.isNotEmpty) {
            final updated = richText
                .map((span) => TextSpan(
                      text: span.text,
                      style: source.textStyle,
                    ))
                .toList();
            batch.setRichText(coord, updated);
          }
        }
      }
    });

    setState(() {
      _paintFormatSource = null;
      _updateSelectedCellInfo();
    });
  }

  void _onFontUsed(String name) {
    setState(() {
      _recentFonts = [
        name,
        ..._recentFonts.where((f) => f != name),
      ].take(5).toList();
    });
  }

  void _onBordersChanged(BorderPreset preset) {
    if (_selectedCell == null) return;

    final sheet = _workbook.activeSheet;
    final range = sheet.controller.selectedRange ??
        CellRange(
          _selectedCell!.row,
          _selectedCell!.column,
          _selectedCell!.row,
          _selectedCell!.column,
        );

    sheet.rawData.batchUpdate((batch) {
      for (final coord in range.cells) {
        final borders = BorderCatalog.bordersForCell(
          preset, coord, range,
          borderColor: _borderPenColor,
          borderWidth: _borderPenLineOption.width,
          borderLineStyle: _borderPenLineOption.lineStyle,
        );
        final existing = sheet.rawData.getStyle(coord) ?? const CellStyle();
        batch.setStyle(coord, existing.copyWith(borders: borders));
      }
    });

    setState(() {
      _updateSelectedCellInfo();
    });
  }

  void _toggleBold() {
    if (_selectedCell == null) return;
    if (_editController.isEditing) {
      _editController.toggleBold();
      _editController.requestEditorFocus();
      setState(() {});
      return;
    }
    final ts = _getEffectiveTextStyle(_selectedCell!);
    final isBold = ts?.fontWeight == FontWeight.bold;
    _applyTextStyleChange((existing) => existing.copyWith(
          fontWeight: isBold ? FontWeight.normal : FontWeight.bold,
        ));
  }

  void _toggleItalic() {
    if (_selectedCell == null) return;
    if (_editController.isEditing) {
      _editController.toggleItalic();
      _editController.requestEditorFocus();
      setState(() {});
      return;
    }
    final ts = _getEffectiveTextStyle(_selectedCell!);
    final isItalic = ts?.fontStyle == FontStyle.italic;
    _applyTextStyleChange((existing) => existing.copyWith(
          fontStyle: isItalic ? FontStyle.normal : FontStyle.italic,
        ));
  }

  void _toggleUnderline() {
    if (_selectedCell == null) return;
    if (_editController.isEditing) {
      _editController.toggleUnderline();
      _editController.requestEditorFocus();
      setState(() {});
      return;
    }
    final ts = _getEffectiveTextStyle(_selectedCell!);
    final hasUnderline =
        ts?.decoration?.contains(TextDecoration.underline) == true;
    _applyTextStyleChange((existing) {
      final current = existing.decoration;
      final newDecoration = hasUnderline
          ? _removeDecoration(current, TextDecoration.underline)
          : _addDecoration(current, TextDecoration.underline);
      return existing.copyWith(decoration: newDecoration);
    });
  }

  void _toggleStrikethrough() {
    if (_selectedCell == null) return;
    if (_editController.isEditing) {
      _editController.toggleStrikethrough();
      _editController.requestEditorFocus();
      setState(() {});
      return;
    }
    final ts = _getEffectiveTextStyle(_selectedCell!);
    final hasStrikethrough =
        ts?.decoration?.contains(TextDecoration.lineThrough) == true;
    _applyTextStyleChange((existing) {
      final current = existing.decoration;
      final newDecoration = hasStrikethrough
          ? _removeDecoration(current, TextDecoration.lineThrough)
          : _addDecoration(current, TextDecoration.lineThrough);
      return existing.copyWith(decoration: newDecoration);
    });
  }

  static TextDecoration _addDecoration(
      TextDecoration? current, TextDecoration add) {
    if (current == null || current == TextDecoration.none) return add;
    return TextDecoration.combine([current, add]);
  }

  static TextDecoration _removeDecoration(
      TextDecoration? current, TextDecoration remove) {
    if (current == null) return TextDecoration.none;
    final decorations = <TextDecoration>[];
    for (final d in [
      TextDecoration.underline,
      TextDecoration.lineThrough,
      TextDecoration.overline,
    ]) {
      if (d != remove && current.contains(d)) decorations.add(d);
    }
    return decorations.isEmpty
        ? TextDecoration.none
        : TextDecoration.combine(decorations);
  }

  bool get _isCellMerged {
    if (_selectedCell == null) return false;
    return _workbook.activeSheet.rawData.mergedCells.isMerged(_selectedCell!);
  }

  bool get _hasRangeSelected {
    final range = _workbook.activeSheet.controller.selectedRange;
    return range != null;
  }

  void _onMergeCells(MergeType type) {
    final sheet = _workbook.activeSheet;

    switch (type) {
      case MergeType.mergeAll:
        final range = sheet.controller.selectedRange;
        if (range != null) {
          sheet.rawData.mergeCells(range);
        }
      case MergeType.mergeVertically:
        final range = sheet.controller.selectedRange;
        if (range != null) {
          for (var col = range.startColumn; col <= range.endColumn; col++) {
            sheet.rawData.mergeCells(
              CellRange(range.startRow, col, range.endRow, col),
            );
          }
        }
      case MergeType.mergeHorizontally:
        final range = sheet.controller.selectedRange;
        if (range != null) {
          for (var row = range.startRow; row <= range.endRow; row++) {
            sheet.rawData.mergeCells(
              CellRange(row, range.startColumn, row, range.endColumn),
            );
          }
        }
      case MergeType.unmerge:
        if (_selectedCell != null) {
          sheet.rawData.unmergeCells(_selectedCell!);
        }
    }

    widget.persistenceService.scheduleSave(_workbook);
    setState(_updateSelectedCellInfo);
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
          const SingleActivator(LogicalKeyboardKey.keyU, control: true):
              _toggleUnderline,
          const SingleActivator(LogicalKeyboardKey.keyU, meta: true):
              _toggleUnderline,
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
              editController: _editController,
              onCommit: _onFormulaBarCommit,
            ),
            FormattingToolbar(
              currentStyle: _selectedCellStyle,
              currentFormat: _selectedCellFormat,
              currentTextStyle: _selectedCell != null
                  ? _getEffectiveTextStyle(_selectedCell!)
                  : null,
              onStyleChanged: _onStyleChanged,
              onFormatChanged: _onFormatChanged,
              onClearFormatting: _onClearFormatting,
              onBordersChanged: _onBordersChanged,
              borderColor: _borderPenColor,
              currentLineOption: _borderPenLineOption,
              onBorderColorChanged: (color) =>
                  setState(() => _borderPenColor = color),
              onBorderLineOptionChanged: (option) =>
                  setState(() => _borderPenLineOption = option),
              undoDescriptions: sheet.undoManager.undoDescriptions,
              redoDescriptions: sheet.undoManager.redoDescriptions,
              currentValue: _evaluatedCellValue,
              onUndoN: _undoN,
              onRedoN: _redoN,
              recentFonts: _recentFonts,
              onFontUsed: _onFontUsed,
              onToggleBold: _toggleBold,
              onToggleItalic: _toggleItalic,
              onToggleUnderline: _toggleUnderline,
              onToggleStrikethrough: _toggleStrikethrough,
              onFontFamilyChanged: _onFontFamilyChanged,
              onFontSizeChanged: _onFontSizeChanged,
              onTextColorChanged: _onTextColorChanged,
              editController: _editController,
              onMergeCells: _onMergeCells,
              hasRangeSelected: _hasRangeSelected,
              isCellMerged: _isCellMerged,
              isPaintFormatActive: _isPaintFormatActive,
              onPaintFormat: _onPaintFormat,
              onPrint: _onPrint,
            ),
            Expanded(
              child: Listener(
                onPointerUp: _isPaintFormatActive
                    ? _onPointerUpDuringPaintFormat
                    : null,
                child: MouseRegion(
                  cursor: _isPaintFormatActive
                      ? SystemMouseCursors.copy
                      : MouseCursor.defer,
                  child: WorksheetTheme(
                    data: widget.isDarkMode
                        ? const WorksheetThemeData(
                            defaultColumnWidth: 100.0,
                            defaultRowHeight: 21.0,
                            headerStyle: HeaderStyle.darkStyle,
                          )
                        : const WorksheetThemeData(
                            defaultColumnWidth: 100.0,
                            defaultRowHeight: 21.0,
                          ),
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
              ),
            ),
            _buildStatusBar(sheet),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuBar() {
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: AppColors.menuBarBg(brightness)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showAboutDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Image.asset(
                'assets/worksheet.png',
                height: 24,
                width: 24,
                filterQuality: FilterQuality.medium,
              ),
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
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                size: 16,
                color: Colors.white70,
              ),
              padding: EdgeInsets.zero,
              onPressed: widget.onToggleDarkMode,
              tooltip: widget.isDarkMode ? 'Light mode' : 'Dark mode',
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(appTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $appVersion'),
            const SizedBox(height: 12),
            const Text('Dependencies',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final entry in dependencyVersions.entries)
              Text('${entry.key}: ${entry.value}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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
        CellValueType.duration => 'Duration',
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
      CellValueType.duration => 'Duration',
      CellValueType.error => 'Error',
      CellValueType.formula => 'Formula',
    };
  }

  Widget _buildStatusBar(SheetModel sheet) {
    final typeName = _cellTypeName();
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.headerBg(brightness),
        border: Border(top: BorderSide(color: AppColors.border(brightness))),
      ),
      child: Row(
        children: [
          Expanded(child: SheetTabs(workbook: _workbook)),
          _SelectionStats(
            formulaData: sheet.formulaData,
            selectedRange: sheet.controller.selectedRange,
            selectedCell: _selectedCell,
          ),
          if (typeName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                typeName,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.statusBarText(brightness),
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

class _SelectionStats extends StatelessWidget {
  const _SelectionStats({
    required this.formulaData,
    required this.selectedRange,
    required this.selectedCell,
  });

  final WorksheetData formulaData;
  final CellRange? selectedRange;
  final CellCoordinate? selectedCell;

  static final _epoch = DateTime.utc(1899, 12, 30);

  @override
  Widget build(BuildContext context) {
    final values = _collectNumericValues();
    if (values.isEmpty) return const SizedBox.shrink();

    final count = values.length;
    final sum = values.reduce((a, b) => a + b);
    final avg = sum / count;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    final brightness = Theme.of(context).brightness;
    final textStyle = TextStyle(
      fontSize: 12,
      color: AppColors.statusBarText(brightness),
    );

    final stats = [
      ('Average', avg),
      ('Count', count.toDouble()),
      ('Sum', sum),
      ('Min', min),
      ('Max', max),
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border(brightness),
            ),
            for (final (label, value) in stats) ...[
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => _copyValue(context, label, value),
                  borderRadius: BorderRadius.circular(4),
                  hoverColor: brightness == Brightness.dark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.08),
                  splashColor: brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black.withValues(alpha: 0.12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      '$label: ${_formatValue(value)}',
                      style: textStyle,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<double> _collectNumericValues() {
    // Only compute stats when a multi-cell range is selected
    if (selectedRange == null) return [];
    final cells = selectedRange!.cells.toList();
    if (cells.length <= 1) return [];

    final values = <double>[];
    for (final coord in cells) {
      final cv = formulaData.getCell(coord);
      if (cv == null) continue;
      if (cv.isNumber) {
        values.add(cv.asDouble);
      } else if (cv.isDate) {
        final date = cv.asDateTime;
        final utcDate = DateTime.utc(date.year, date.month, date.day);
        values.add(utcDate.difference(_epoch).inDays.toDouble());
      }
    }
    return values;
  }

  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    // Up to 2 decimal places, trim trailing zeros
    final s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      final trimmed = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return trimmed;
    }
    return s;
  }

  void _copyValue(BuildContext context, String label, double value) {
    Clipboard.setData(ClipboardData(text: _formatValue(value)));
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
