import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:worksheet/worksheet.dart';

import '../constants.dart';
import '../models/border_catalog.dart';
import '../models/font_catalog.dart';
import '../models/format_catalog.dart';

class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.currentStyle,
    required this.currentFormat,
    required this.onStyleChanged,
    required this.onFormatChanged,
    required this.onClearFormatting,
    required this.undoDescriptions,
    required this.redoDescriptions,
    required this.onBordersChanged,
    required this.borderColor,
    required this.currentLineOption,
    required this.onBorderColorChanged,
    required this.onBorderLineOptionChanged,
    required this.onUndoN,
    required this.onRedoN,
    required this.recentFonts,
    required this.onFontUsed,
    this.currentValue,
  });

  final CellStyle? currentStyle;
  final CellFormat? currentFormat;
  final CellValue? currentValue;
  final ValueChanged<CellStyle> onStyleChanged;
  final ValueChanged<CellFormat> onFormatChanged;
  final VoidCallback onClearFormatting;
  final ValueChanged<BorderPreset> onBordersChanged;
  final Color borderColor;
  final BorderLineOption currentLineOption;
  final ValueChanged<Color> onBorderColorChanged;
  final ValueChanged<BorderLineOption> onBorderLineOptionChanged;
  final List<String> undoDescriptions;
  final List<String> redoDescriptions;
  final ValueChanged<int> onUndoN;
  final ValueChanged<int> onRedoN;
  final List<String> recentFonts;
  final ValueChanged<String> onFontUsed;

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
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
        children: [
          _UndoRedoComboButton(
            icon: Icons.undo,
            descriptions: undoDescriptions,
            onAction: onUndoN,
          ),
          _UndoRedoComboButton(
            icon: Icons.redo,
            descriptions: redoDescriptions,
            onAction: onRedoN,
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
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
          _ToolbarButton(
            icon: Icons.attach_money,
            onPressed: () => onFormatChanged(CellFormat.currency),
          ),
          _ToolbarButton(
            icon: Icons.percent,
            onPressed: () => onFormatChanged(CellFormat.percentage),
          ),
          _ToolbarButton(
            icon: Symbols.decimal_decrease,
            onPressed: () {
              final adjusted = FormatUtils.adjustDecimals(
                currentFormat, -1, cellValue: currentValue,
              );
              if (adjusted != null) onFormatChanged(adjusted);
            },
          ),
          _ToolbarButton(
            icon: Symbols.decimal_increase,
            onPressed: () {
              final adjusted = FormatUtils.adjustDecimals(
                currentFormat, 1, cellValue: currentValue,
              );
              if (adjusted != null) onFormatChanged(adjusted);
            },
          ),
          _FormatPopupButton(
            currentFormat: currentFormat,
            onFormatChanged: onFormatChanged,
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _FontFamilyButton(
            currentFamily: style.fontFamily ?? 'Roboto',
            recentFonts: recentFonts,
            onFontSelected: (name) {
              onFontUsed(name);
              onStyleChanged(CellStyle(fontFamily: name));
            },
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _FontSizeControl(
            currentSize: style.fontSize ?? 14.0,
            onSizeChanged: (size) =>
                onStyleChanged(CellStyle(fontSize: size)),
          ),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _ToolbarButton(
            icon: Icons.format_clear,
            onPressed: onClearFormatting,
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
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _BorderPopupButton(
            onBordersChanged: onBordersChanged,
            borderColor: borderColor,
            currentLineOption: currentLineOption,
            onBorderColorChanged: onBorderColorChanged,
            onBorderLineOptionChanged: onBorderLineOptionChanged,
          ),
            ],
          ),
          ),
        ),
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

class _UndoRedoComboButton extends StatelessWidget {
  const _UndoRedoComboButton({
    required this.icon,
    required this.descriptions,
    required this.onAction,
  });

  final IconData icon;
  final List<String> descriptions;
  final ValueChanged<int> onAction;

  @override
  Widget build(BuildContext context) {
    final enabled = descriptions.isNotEmpty;
    final iconColor = enabled ? null : Colors.grey.shade400;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton(
            icon: Icon(icon, size: 16, color: iconColor),
            padding: EdgeInsets.zero,
            onPressed: enabled ? () => onAction(1) : null,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 16,
          height: 28,
          child: PopupMenuButton<int>(
            enabled: enabled,
            padding: EdgeInsets.zero,
            tooltip: '',
            onSelected: onAction,
            offset: const Offset(0, 28),
            itemBuilder: (_) => [
              for (var i = 0; i < descriptions.length; i++)
                PopupMenuItem<int>(
                  value: i + 1,
                  height: 32,
                  child: Text(
                    descriptions[i],
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
            child: Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatPopupButton extends StatelessWidget {
  const _FormatPopupButton({
    required this.currentFormat,
    required this.onFormatChanged,
  });

  final CellFormat? currentFormat;
  final ValueChanged<CellFormat> onFormatChanged;

  bool _isCurrentFormat(CellFormat format) {
    if (currentFormat == null) return format == CellFormat.general;
    return currentFormat == format ||
        currentFormat!.formatCode == format.formatCode;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<FormatEntry>(
      tooltip: 'More formats',
      offset: const Offset(0, 28),
      onSelected: (entry) {
        if (entry.isCustom) {
          final title = entry.label;
          final List<String> presets;
          if (title.contains('currency')) {
            presets = FormatCatalog.currencyPresets;
          } else if (title.contains('date')) {
            presets = FormatCatalog.dateTimePresets;
          } else {
            presets = FormatCatalog.numberPresets;
          }
          _showCustomFormatDialog(context, title, presets, onFormatChanged);
        } else {
          onFormatChanged(entry.format);
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<FormatEntry>>[];
        for (var si = 0; si < FormatCatalog.menuSections.length; si++) {
          if (si > 0) items.add(const PopupMenuDivider());
          for (final entry in FormatCatalog.menuSections[si]) {
            final isActive = !entry.isCustom && _isCurrentFormat(entry.format);
            items.add(
              PopupMenuItem<FormatEntry>(
                value: entry,
                height: 32,
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: isActive
                          ? const Icon(Icons.check, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (entry.example.isNotEmpty)
                      Text(
                        entry.example,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        }
        return items;
      },
      child: const SizedBox(
        width: 38,
        height: 28,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('123', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Icon(Icons.arrow_drop_down, size: 14),
          ],
        ),
      ),
    );
  }
}

class _FontFamilyButton extends StatelessWidget {
  const _FontFamilyButton({
    required this.currentFamily,
    required this.recentFonts,
    required this.onFontSelected,
  });

  final String currentFamily;
  final List<String> recentFonts;
  final ValueChanged<String> onFontSelected;

  static TextStyle _styleForFont(String name, {double fontSize = 14}) {
    if (FontCatalog.isGoogleFont(name)) {
      return GoogleFonts.getFont(name, fontSize: fontSize);
    }
    return TextStyle(fontFamily: name, fontSize: fontSize);
  }

  String get _displayName {
    final name = currentFamily == 'Roboto' ? 'Default' : currentFamily;
    return name.length > 8 ? '${name.substring(0, 7)}...' : name;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Font',
      offset: const Offset(0, 28),
      onSelected: onFontSelected,
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];

        if (recentFonts.isNotEmpty) {
          items.add(const PopupMenuItem<String>(
            enabled: false,
            height: 24,
            child: Text(
              'RECENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ));
          for (final name in recentFonts) {
            items.add(PopupMenuItem<String>(
              value: name,
              height: 32,
              child: Text(name, style: _styleForFont(name)),
            ));
          }
          items.add(const PopupMenuDivider());
        }

        for (final name in FontCatalog.allFonts) {
          final isActive = name == currentFamily;
          items.add(PopupMenuItem<String>(
            value: name,
            height: 32,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: isActive
                      ? const Icon(Icons.check, size: 14)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(name, style: _styleForFont(name)),
              ],
            ),
          ));
        }

        return items;
      },
      child: SizedBox(
        width: 90,
        height: 28,
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _displayName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 14),
          ],
        ),
      ),
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  const _FontSizeControl({
    required this.currentSize,
    required this.onSizeChanged,
  });

  final double currentSize;
  final ValueChanged<double> onSizeChanged;

  static const double _minSize = 6;
  static const double _maxSize = 72;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 28,
          child: IconButton(
            icon: const Icon(Icons.remove, size: 14),
            padding: EdgeInsets.zero,
            onPressed: currentSize > _minSize
                ? () => onSizeChanged((currentSize - 1).clamp(_minSize, _maxSize))
                : null,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        Container(
          width: 36,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: toolbarBorder),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            currentSize.round().toString(),
            style: const TextStyle(fontSize: 11),
          ),
        ),
        SizedBox(
          width: 24,
          height: 28,
          child: IconButton(
            icon: const Icon(Icons.add, size: 14),
            padding: EdgeInsets.zero,
            onPressed: currentSize < _maxSize
                ? () => onSizeChanged((currentSize + 1).clamp(_minSize, _maxSize))
                : null,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _showCustomFormatDialog(
  BuildContext context,
  String title,
  List<String> presets,
  ValueChanged<CellFormat> onApply,
) {
  showDialog<void>(
    context: context,
    builder: (context) => _CustomFormatDialog(
      title: title,
      presets: presets,
      onApply: onApply,
    ),
  );
}

class _CustomFormatDialog extends StatefulWidget {
  const _CustomFormatDialog({
    required this.title,
    required this.presets,
    required this.onApply,
  });

  final String title;
  final List<String> presets;
  final ValueChanged<CellFormat> onApply;

  @override
  State<_CustomFormatDialog> createState() => _CustomFormatDialogState();
}

class _CustomFormatDialogState extends State<_CustomFormatDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.presets.isNotEmpty ? widget.presets.first : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Format code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          const Text('Presets', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.presets.map((preset) {
              return ActionChip(
                label: Text(preset, style: const TextStyle(fontSize: 11)),
                onPressed: () => _controller.text = preset,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final code = _controller.text.trim();
            if (code.isNotEmpty) {
              final type = FormatUtils.inferType(code);
              widget.onApply(CellFormat(type: type, formatCode: code));
            }
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
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

class _BorderPopupButton extends StatefulWidget {
  const _BorderPopupButton({
    required this.onBordersChanged,
    required this.borderColor,
    required this.currentLineOption,
    required this.onBorderColorChanged,
    required this.onBorderLineOptionChanged,
  });

  final ValueChanged<BorderPreset> onBordersChanged;
  final Color borderColor;
  final BorderLineOption currentLineOption;
  final ValueChanged<Color> onBorderColorChanged;
  final ValueChanged<BorderLineOption> onBorderLineOptionChanged;

  @override
  State<_BorderPopupButton> createState() => _BorderPopupButtonState();
}

class _BorderPopupButtonState extends State<_BorderPopupButton> {
  OverlayEntry? _overlayEntry;

  static const _colorPalette = [
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
  void didUpdateWidget(covariant _BorderPopupButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    _hidePopup();
    super.dispose();
  }

  void _togglePopup() {
    if (_overlayEntry != null) {
      _hidePopup();
    } else {
      _showPopup();
    }
  }

  void _showPopup() {
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonOffset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 5 * 28.0 + 4 * 4.0 + 16; // grid + padding
    // Clamp so the popup's right edge stays on screen.
    final left = (buttonOffset.dx + popupWidth > screenSize.width)
        ? screenSize.width - popupWidth - 8
        : buttonOffset.dx;

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          GestureDetector(
            onTap: _hidePopup,
            behavior: HitTestBehavior.opaque,
          ),
          Positioned(
            left: left.clamp(8.0, screenSize.width - popupWidth - 8),
            top: buttonOffset.dy + buttonSize.height + 4,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preset grid — closes popup
                    SizedBox(
                      width: 5 * 28.0 + 4 * 4.0,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: BorderPreset.values.map((preset) {
                          return Tooltip(
                            message: preset.label,
                            child: InkWell(
                              onTap: () {
                                _hidePopup();
                                widget.onBordersChanged(preset);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: Icon(preset.icon, size: 18),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 16),
                    // Border color — stays open
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit,
                            size: 14, color: widget.borderColor),
                        const SizedBox(width: 6),
                        ..._colorPalette.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: GestureDetector(
                              onTap: () => widget.onBorderColorChanged(c),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: c,
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const Divider(height: 16),
                    // Line style options — stays open
                    ...BorderCatalog.lineOptions.map((option) {
                      final isSelected =
                          option == widget.currentLineOption;
                      return InkWell(
                        onTap: () =>
                            widget.onBorderLineOptionChanged(option),
                        child: SizedBox(
                          width: 5 * 28.0 + 4 * 4.0,
                          height: 24,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: isSelected
                                    ? Icon(Icons.check,
                                        size: 14,
                                        color: Colors.grey.shade700)
                                    : null,
                              ),
                              Expanded(
                                child: CustomPaint(
                                  painter: _LineStylePainter(
                                      option, widget.borderColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hidePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Borders',
      child: GestureDetector(
        onTap: _togglePopup,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.border_all, size: 16),
        ),
      ),
    );
  }
}

class _LineStylePainter extends CustomPainter {
  const _LineStylePainter(this.option, this.color);

  final BorderLineOption option;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = option.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final y = size.height / 2;
    const startX = 4.0;
    final endX = size.width - 4.0;

    switch (option.lineStyle) {
      case BorderLineStyle.solid:
        canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      case BorderLineStyle.dotted:
        paint.style = PaintingStyle.fill;
        var x = startX;
        while (x <= endX) {
          canvas.drawCircle(Offset(x, y), option.width * 0.6, paint);
          x += option.width * 3;
        }
      case BorderLineStyle.dashed:
        var x = startX;
        while (x < endX) {
          final dashEnd = (x + 6).clamp(startX, endX);
          canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
          x += 10;
        }
      case BorderLineStyle.double:
        const gap = 1.5;
        canvas.drawLine(
            Offset(startX, y - gap), Offset(endX, y - gap), paint);
        canvas.drawLine(
            Offset(startX, y + gap), Offset(endX, y + gap), paint);
      case BorderLineStyle.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_LineStylePainter old) =>
      option != old.option || color != old.color;
}
