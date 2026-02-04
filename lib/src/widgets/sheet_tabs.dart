import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/workbook_model.dart';

class SheetTabs extends StatelessWidget {
  const SheetTabs({
    super.key,
    required this.workbook,
  });

  final WorkbookModel workbook;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: headerBackground,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.add, size: 16),
              padding: EdgeInsets.zero,
              onPressed: () => workbook.addSheet(),
              tooltip: 'Add sheet',
            ),
          ),
          const VerticalDivider(width: 1, indent: 4, endIndent: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: workbook.sheetCount,
              itemBuilder: (context, index) {
                final sheet = workbook.sheets[index];
                final isActive = index == workbook.activeSheetIndex;

                return GestureDetector(
                  onTap: () => workbook.switchSheet(index),
                  onSecondaryTapUp: (details) =>
                      _showContextMenu(context, details.globalPosition, index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : null,
                      border: isActive
                          ? const Border(
                              top: BorderSide(color: primaryColor, width: 2),
                              left: BorderSide(color: toolbarBorder),
                              right: BorderSide(color: toolbarBorder),
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sheet.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(
      BuildContext context, Offset position, int index) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        if (workbook.sheetCount > 1)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );

    if (!context.mounted) return;

    switch (result) {
      case 'rename':
        _showRenameDialog(context, index);
      case 'delete':
        workbook.removeSheet(index);
      default:
        break;
    }
  }

  void _showRenameDialog(BuildContext context, int index) {
    final controller =
        TextEditingController(text: workbook.sheets[index].name);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Sheet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              workbook.renameSheet(index, value);
            }
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
              if (controller.text.isNotEmpty) {
                workbook.renameSheet(index, controller.text);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
