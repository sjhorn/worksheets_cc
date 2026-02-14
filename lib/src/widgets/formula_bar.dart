import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';

class FormulaBar extends StatefulWidget {
  const FormulaBar({
    super.key,
    required this.selectedCell,
    required this.cellValue,
    required this.editController,
    required this.onCommit,
  });

  final CellCoordinate? selectedCell;
  final CellValue? cellValue;
  final EditController editController;

  /// Called when a value is committed from the formula bar.
  /// The [EditController.commitEdit] handles the cell overlay side;
  /// this callback lets the page perform any additional work (e.g. auto-align).
  final void Function(CellCoordinate cell, CellValue? value,
      {CellFormat? detectedFormat}) onCommit;

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// Guards against feedback loops when syncing from EditController.
  bool _syncing = false;

  EditController get _ec => widget.editController;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _ec.addListener(_onEditControllerChanged);
  }

  @override
  void didUpdateWidget(FormulaBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.editController != widget.editController) {
      oldWidget.editController.removeListener(_onEditControllerChanged);
      widget.editController.addListener(_onEditControllerChanged);
    }

    // When the selected cell changes and we're not editing, show cell value.
    if (!_ec.isEditing) {
      _showCellValue();
    }
  }

  @override
  void dispose() {
    _ec.removeListener(_onEditControllerChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Sets the text field to the committed cell value (not the live edit text).
  void _showCellValue() {
    final value = widget.cellValue;
    if (value == null) {
      _controller.text = '';
    } else if (value.isFormula) {
      _controller.text = value.rawValue as String;
    } else {
      _controller.text = value.displayValue;
    }
  }

  // ---------------------------------------------------------------------------
  // EditController listener  (cell overlay → formula bar)
  // ---------------------------------------------------------------------------

  void _onEditControllerChanged() {
    if (_syncing) return;

    if (_ec.isEditing) {
      // Sync live text from cell overlay → formula bar.
      if (_controller.text != _ec.currentText) {
        _syncing = true;
        _controller.text = _ec.currentText;
        // Place cursor at end.
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        _syncing = false;
      }
    } else {
      // Editing ended (commit or cancel) — show committed value.
      _showCellValue();
    }
  }

  // ---------------------------------------------------------------------------
  // Focus / tap
  // ---------------------------------------------------------------------------

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _ec.isEditing) {
      // Lost focus while editing — commit.
      _commit();
    }
  }

  void _onTap() {
    if (_ec.isEditing) return; // Already editing via cell overlay.

    final cell = widget.selectedCell;
    if (cell == null) return;

    // Start an edit so the cell overlay also appears.
    _ec.startEdit(
      cell: cell,
      currentValue: widget.cellValue,
      trigger: EditTrigger.programmatic,
    );
  }

  // ---------------------------------------------------------------------------
  // Text changes  (formula bar → cell overlay)
  // ---------------------------------------------------------------------------

  void _onTextChanged(String text) {
    if (_syncing) return;

    // If user types before tapping (shouldn't normally happen), start edit.
    if (!_ec.isEditing) {
      final cell = widget.selectedCell;
      if (cell == null) return;
      _ec.startEdit(
        cell: cell,
        currentValue: widget.cellValue,
        trigger: EditTrigger.programmatic,
      );
    }

    _syncing = true;
    _ec.updateText(text);
    _syncing = false;
  }

  // ---------------------------------------------------------------------------
  // Commit / cancel
  // ---------------------------------------------------------------------------

  void _commit() {
    if (!_ec.isEditing) return;
    _ec.commitEdit(onCommit: widget.onCommit);
  }

  void _cancel() {
    if (_ec.isEditing) {
      _ec.cancelEdit();
    }
    _showCellValue();
    _focusNode.unfocus();
  }

  void _onSubmitted(String text) {
    _commit();
    _focusNode.unfocus();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cellRef = widget.selectedCell?.toNotation() ?? '';

    final borderColor = AppColors.border(Theme.of(context).brightness);
    return Container(
      height: 28,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Text(
              cellRef,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.functions, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _cancel();
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
                onTap: _onTap,
                onChanged: _onTextChanged,
                onSubmitted: _onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
