import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';

class FormulaBar extends StatefulWidget {
  const FormulaBar({
    super.key,
    required this.selectedCell,
    required this.cellValue,
    required this.onSubmit,
  });

  final CellCoordinate? selectedCell;
  final CellValue? cellValue;
  final void Function(CellCoordinate cell, String text) onSubmit;

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEditing = false;
  CellCoordinate? _editingCell;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(FormulaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCell != oldWidget.selectedCell) {
      _isEditing = false;
    }
    if (!_isEditing) {
      _updateControllerText();
    }
  }

  void _updateControllerText() {
    final value = widget.cellValue;
    if (value == null) {
      _controller.text = '';
    } else if (value.isFormula) {
      _controller.text = value.rawValue as String;
    } else {
      _controller.text = value.displayValue;
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commit();
    }
  }

  void _commit() {
    final cell = _editingCell;
    _isEditing = false;
    _editingCell = null;
    if (cell != null) {
      widget.onSubmit(cell, _controller.text);
    }
  }

  void _cancel() {
    _isEditing = false;
    _updateControllerText();
    _focusNode.unfocus();
  }

  void _onSubmit(String text) {
    _commit();
    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cellRef = widget.selectedCell?.toNotation() ?? '';

    return Container(
      height: 28,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: toolbarBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: toolbarBorder)),
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
                onTap: () {
                  _isEditing = true;
                  _editingCell = widget.selectedCell;
                },
                onSubmitted: _onSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
