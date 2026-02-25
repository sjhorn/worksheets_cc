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

  /// True when the user started editing from the formula bar (not from
  /// the cell overlay). In this mode we keep text locally and only
  /// touch the [EditController] at commit time to leverage its value
  /// parsing / format detection.
  bool _isLocalEdit = false;

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

    // If the selected cell changed while in local edit, commit first.
    if (_isLocalEdit && widget.selectedCell != oldWidget.selectedCell) {
      _commitLocal();
    }

    // When the selected cell changes and we're not editing, show cell value.
    if (!_ec.isEditing && !_isLocalEdit) {
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
    if (_syncing || _isLocalEdit) return;

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
    if (!_focusNode.hasFocus) {
      if (_isLocalEdit) {
        _commitLocal();
      } else if (_ec.isEditing) {
        _commit();
      }
    }
  }

  void _onTap() {
    if (_ec.isEditing) return; // Already editing via cell overlay.
    if (_isLocalEdit) return; // Already in local edit mode.
    if (widget.selectedCell == null) return;

    // Enter local edit mode — don't call startEdit so the
    // CellEditorOverlay is never created and can't steal focus.
    _isLocalEdit = true;
  }

  // ---------------------------------------------------------------------------
  // Text changes  (formula bar → cell overlay)
  // ---------------------------------------------------------------------------

  void _onTextChanged(String text) {
    if (_syncing) return;

    // Local edit — text stays in our controller, no EditController sync.
    if (_isLocalEdit) return;

    // If user types before tapping (shouldn't normally happen), start
    // local edit mode.
    if (!_ec.isEditing) {
      if (widget.selectedCell == null) return;
      _isLocalEdit = true;
      return;
    }

    _syncing = true;
    _ec.updateText(text);
    _syncing = false;
  }

  // ---------------------------------------------------------------------------
  // Commit / cancel
  // ---------------------------------------------------------------------------

  /// Commits a local formula-bar edit by parsing the text directly
  /// and calling [onCommit]. Does NOT touch the [EditController] to
  /// avoid confusing the Worksheet widget's internal editing state.
  void _commitLocal() {
    final cell = widget.selectedCell;
    if (cell == null) {
      _isLocalEdit = false;
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      widget.onCommit(cell, null);
    } else {
      final value = CellValue.parse(text, dateParser: AnyDate()) ??
          CellValue.text(text);
      widget.onCommit(cell, value);
    }
    _isLocalEdit = false;
  }

  void _commit() {
    if (!_ec.isEditing) return;
    _ec.commitEdit(onCommit: widget.onCommit);
  }

  void _cancel() {
    if (_isLocalEdit) {
      _isLocalEdit = false;
      _showCellValue();
      _focusNode.unfocus();
    } else if (_ec.isEditing) {
      _ec.cancelEdit();
      _showCellValue();
      _focusNode.unfocus();
    }
  }

  void _onSubmitted(String text) {
    if (_isLocalEdit) {
      _commitLocal();
    } else {
      _commit();
    }
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
