import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';

class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.currentStyle,
    required this.currentFormat,
    required this.onStyleChanged,
    required this.onFormatChanged,
  });

  final CellStyle? currentStyle;
  final CellFormat? currentFormat;
  final ValueChanged<CellStyle> onStyleChanged;
  final ValueChanged<CellFormat> onFormatChanged;

  @override
  Widget build(BuildContext context) {
    final style = currentStyle ?? const CellStyle();

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: toolbarBorder)),
        color: headerBackground,
      ),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            isActive: style.fontWeight == FontWeight.bold,
            onPressed: () => onStyleChanged(
              CellStyle(
                fontWeight: style.fontWeight == FontWeight.bold
                    ? FontWeight.normal
                    : FontWeight.bold,
              ),
            ),
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            isActive: style.fontStyle == FontStyle.italic,
            onPressed: () => onStyleChanged(
              CellStyle(
                fontStyle: style.fontStyle == FontStyle.italic
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.format_align_left,
            isActive: style.textAlignment == CellTextAlignment.left,
            onPressed: () => onStyleChanged(
              const CellStyle(textAlignment: CellTextAlignment.left),
            ),
          ),
          _ToolbarButton(
            icon: Icons.format_align_center,
            isActive: style.textAlignment == CellTextAlignment.center,
            onPressed: () => onStyleChanged(
              const CellStyle(textAlignment: CellTextAlignment.center),
            ),
          ),
          _ToolbarButton(
            icon: Icons.format_align_right,
            isActive: style.textAlignment == CellTextAlignment.right,
            onPressed: () => onStyleChanged(
              const CellStyle(textAlignment: CellTextAlignment.right),
            ),
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _FormatDropdown(
            currentFormat: currentFormat,
            onFormatChanged: onFormatChanged,
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _ColorButton(
            icon: Icons.format_color_text,
            color: style.textColor ?? Colors.black,
            onColorSelected: (color) =>
                onStyleChanged(CellStyle(textColor: color)),
          ),
          _ColorButton(
            icon: Icons.format_color_fill,
            color: style.backgroundColor ?? Colors.white,
            onColorSelected: (color) =>
                onStyleChanged(CellStyle(backgroundColor: color)),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              isActive ? primaryColor.withValues(alpha: 0.15) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

class _FormatDropdown extends StatelessWidget {
  const _FormatDropdown({
    required this.currentFormat,
    required this.onFormatChanged,
  });

  final CellFormat? currentFormat;
  final ValueChanged<CellFormat> onFormatChanged;

  static const _formats = <(String, CellFormat)>[
    ('General', CellFormat.general),
    ('Number', CellFormat.number),
    ('Currency', CellFormat.currency),
    ('Percentage', CellFormat.percentage),
    ('Date', CellFormat.dateIso),
    ('Scientific', CellFormat.scientific),
    ('Text', CellFormat.text),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<CellFormat>(
      value: currentFormat ?? CellFormat.general,
      underline: const SizedBox.shrink(),
      isDense: true,
      style: const TextStyle(fontSize: 12, color: Colors.black),
      items: _formats
          .map((e) => DropdownMenuItem(value: e.$2, child: Text(e.$1)))
          .toList(),
      onChanged: (format) {
        if (format != null) onFormatChanged(format);
      },
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.icon,
    required this.color,
    required this.onColorSelected,
  });

  final IconData icon;
  final Color color;
  final ValueChanged<Color> onColorSelected;

  static const _palette = [
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      onSelected: onColorSelected,
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _palette.map((c) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context, c);
                  onColorSelected(c);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
