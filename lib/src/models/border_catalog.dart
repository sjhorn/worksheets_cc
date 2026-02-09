import 'package:flutter/material.dart' hide BorderStyle;
import 'package:worksheet/worksheet.dart';

/// Border preset options matching Google Sheets border menu.
enum BorderPreset {
  allBorders('All borders', Icons.border_all),
  innerBorders('Inner borders', Icons.border_inner),
  horizontalBorders('Horizontal borders', Icons.border_horizontal),
  verticalBorders('Vertical borders', Icons.border_vertical),
  outerBorders('Outer borders', Icons.border_outer),
  leftBorder('Left border', Icons.border_left),
  rightBorder('Right border', Icons.border_right),
  topBorder('Top border', Icons.border_top),
  bottomBorder('Bottom border', Icons.border_bottom),
  clearBorders('Clear borders', Icons.border_clear);

  const BorderPreset(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A selectable line style option for the border pen.
class BorderLineOption {
  final String label;
  final double width;
  final BorderLineStyle lineStyle;

  const BorderLineOption(this.label, this.width, this.lineStyle);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorderLineOption &&
          width == other.width &&
          lineStyle == other.lineStyle;

  @override
  int get hashCode => Object.hash(width, lineStyle);
}

/// Computes [CellBorders] for a cell based on a [BorderPreset] and its
/// position within a [CellRange].
class BorderCatalog {
  BorderCatalog._();

  /// Available line style options for the border pen.
  static const lineOptions = [
    BorderLineOption('Thin', 1.0, BorderLineStyle.solid),
    BorderLineOption('Medium', 2.0, BorderLineStyle.solid),
    BorderLineOption('Thick', 3.0, BorderLineStyle.solid),
    BorderLineOption('Dotted', 1.0, BorderLineStyle.dotted),
    BorderLineOption('Dashed', 1.0, BorderLineStyle.dashed),
    BorderLineOption('Double', 1.0, BorderLineStyle.double),
  ];

  /// Returns the [CellBorders] for a cell at [coord] within [range]
  /// according to the given [preset].
  ///
  /// Use [borderColor], [borderWidth], and [borderLineStyle] to customise
  /// the pen applied to each side.
  static CellBorders bordersForCell(
    BorderPreset preset,
    CellCoordinate coord,
    CellRange range, {
    Color borderColor = const Color(0xFF000000),
    double borderWidth = 1.0,
    BorderLineStyle borderLineStyle = BorderLineStyle.solid,
  }) {
    final style = BorderStyle(
      color: borderColor,
      width: borderWidth,
      lineStyle: borderLineStyle,
    );

    final isTop = coord.row == range.startRow;
    final isBottom = coord.row == range.endRow;
    final isLeft = coord.column == range.startColumn;
    final isRight = coord.column == range.endColumn;

    return switch (preset) {
      BorderPreset.allBorders => CellBorders.all(style),
      BorderPreset.clearBorders => CellBorders.none,
      BorderPreset.horizontalBorders => CellBorders(
          top: style,
          bottom: style,
        ),
      BorderPreset.verticalBorders => CellBorders(
          left: style,
          right: style,
        ),
      BorderPreset.leftBorder => CellBorders(left: style),
      BorderPreset.rightBorder => CellBorders(right: style),
      BorderPreset.topBorder => CellBorders(top: style),
      BorderPreset.bottomBorder => CellBorders(bottom: style),
      BorderPreset.outerBorders => CellBorders(
          top: isTop ? style : BorderStyle.none,
          bottom: isBottom ? style : BorderStyle.none,
          left: isLeft ? style : BorderStyle.none,
          right: isRight ? style : BorderStyle.none,
        ),
      BorderPreset.innerBorders => CellBorders(
          top: isTop ? BorderStyle.none : style,
          bottom: isBottom ? BorderStyle.none : style,
          left: isLeft ? BorderStyle.none : style,
          right: isRight ? BorderStyle.none : style,
        ),
    };
  }
}
