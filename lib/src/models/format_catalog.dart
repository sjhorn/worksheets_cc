import 'package:worksheet/worksheet.dart';

/// A single entry in the format popup menu.
class FormatEntry {
  final String label;
  final String example;
  final CellFormat format;

  /// If true, selecting this entry opens a custom-format dialog
  /// instead of directly applying [format].
  final bool isCustom;

  const FormatEntry(this.label, this.example, this.format,
      {this.isCustom = false});
}

/// Sentinel format used for custom entries that open dialogs.
const _sentinel = CellFormat(type: CellFormatType.custom, formatCode: '');

/// Format catalog and menu sections matching Google Sheets style.
class FormatCatalog {
  FormatCatalog._();

  /// Menu sections separated by dividers.
  static const List<List<FormatEntry>> menuSections = [
    // Section 1: Automatic / Plain text
    [
      FormatEntry('Automatic', '', CellFormat.general),
      FormatEntry('Plain text', '', CellFormat.text),
    ],
    // Section 2: Number, Percent, Scientific
    [
      FormatEntry('Number', '1,000.12', CellFormat.number),
      FormatEntry('Percent', '10.12%', CellFormat.percentageDecimal),
      FormatEntry('Scientific', '1.01E+03', CellFormat.scientific),
    ],
    // Section 3: Accounting, Financial, Currency, Currency rounded
    [
      FormatEntry(
        'Accounting',
        r'$ (1,000.12)',
        CellFormat(
          type: CellFormatType.accounting,
          formatCode: r'_($* #,##0.00_)',
        ),
      ),
      FormatEntry(
        'Financial',
        '(1,000.12)',
        CellFormat(
          type: CellFormatType.accounting,
          formatCode: '#,##0.00_);(#,##0.00)',
        ),
      ),
      FormatEntry('Currency', r'$1,000.12', CellFormat.currency),
      FormatEntry(
        'Currency rounded',
        r'$1,000',
        CellFormat(type: CellFormatType.currency, formatCode: r'$#,##0'),
      ),
    ],
    // Section 4: Date, Time, Date time, Duration
    [
      FormatEntry('Date', '9/26/2008', CellFormat.dateUs),
      FormatEntry('Time', '3:59:00 PM', CellFormat.time12),
      FormatEntry(
        'Date time',
        '9/26/2008 15:59:00',
        CellFormat(
          type: CellFormatType.date,
          formatCode: 'm/d/yyyy H:mm:ss',
        ),
      ),
      FormatEntry(
        'Duration',
        '24:01:00',
        CellFormat(type: CellFormatType.time, formatCode: '[h]:mm:ss'),
      ),
    ],
    // Section 5: Locale-specific examples
    [
      FormatEntry(
        'Australian Dollar',
        r'$1,000.12',
        CellFormat(type: CellFormatType.currency, formatCode: r'$#,##0.00'),
      ),
      FormatEntry(
        'Danish Krone',
        '1.000,12 kr.',
        CellFormat(
          type: CellFormatType.currency,
          formatCode: '#,##0.00" kr."',
        ),
      ),
      FormatEntry(
        '9/2008',
        '9/2008',
        CellFormat(type: CellFormatType.date, formatCode: 'm/yyyy'),
      ),
    ],
    // Section 6: Custom entries that open dialogs
    [
      FormatEntry('Custom currency', '', _sentinel, isCustom: true),
      FormatEntry('Custom date and time', '', _sentinel, isCustom: true),
      FormatEntry('Custom number format', '', _sentinel, isCustom: true),
    ],
  ];

  static const currencyPresets = [
    r'$#,##0.00',
    '€#,##0.00',
    '£#,##0.00',
    '#,##0.00" kr."',
  ];

  static const dateTimePresets = [
    'm/d/yyyy',
    'yyyy-MM-dd',
    'H:mm:ss',
    'm/d/yyyy H:mm:ss',
  ];

  static const numberPresets = [
    '#,##0',
    '#,##0.00',
    '0.00%',
    '0.00E+00',
  ];
}

/// Utilities for adjusting decimal places in format codes.
class FormatUtils {
  FormatUtils._();

  static final _decimalPattern = RegExp(r'\.([0#]+)');

  /// Adjusts the number of decimal places in a format code by [delta].
  ///
  /// Returns a new [CellFormat] with the modified format code, or `null`
  /// if the format cannot be adjusted (e.g. null input or already at 0
  /// decimals when decreasing).
  /// Counts the decimal places displayed by a numeric value's string
  /// representation. Returns 0 for non-numeric or integer values.
  static int _detectDecimals(CellValue? value) {
    if (value == null || value.type != CellValueType.number) return 0;
    final s = value.displayValue;
    final dot = s.indexOf('.');
    if (dot < 0) return 0;
    return s.length - dot - 1;
  }

  static CellFormat? adjustDecimals(
    CellFormat? current,
    int delta, {
    CellValue? cellValue,
  }) {
    // Unformatted cells: detect decimal places from the actual value
    // so the first click adjusts relative to what the user sees.
    if (current == null) {
      final detected = _detectDecimals(cellValue);
      final newCount = (detected + delta).clamp(0, 10);
      final decimals = newCount > 0 ? '.${'0' * newCount}' : '';
      return CellFormat(
        type: CellFormatType.number,
        formatCode: '0$decimals',
      );
    }

    final code = current.formatCode;
    final match = _decimalPattern.firstMatch(code);

    if (match == null) {
      // No decimal portion exists
      if (delta <= 0) return null;
      // Add decimal point with one zero
      final newCode = '$code.0';
      return CellFormat(type: current.type, formatCode: newCode);
    }

    final decimalDigits = match.group(1)!;
    final count = decimalDigits.length;
    final newCount = (count + delta).clamp(0, 10);

    if (newCount == count) return null; // No change

    if (newCount == 0) {
      // Remove the decimal point and digits
      final newCode = code.replaceFirst('.${match.group(1)}', '');
      return CellFormat(type: current.type, formatCode: newCode);
    }

    final newDecimals = '0' * newCount;
    final newCode = code.replaceFirst('.${match.group(1)}', '.$newDecimals');
    return CellFormat(type: current.type, formatCode: newCode);
  }

  /// Infers a [CellFormatType] from a custom format code string.
  static CellFormatType inferType(String formatCode) {
    if (formatCode.contains(r'$') ||
        formatCode.contains('€') ||
        formatCode.contains('£') ||
        formatCode.contains('kr.')) {
      return CellFormatType.currency;
    }
    if (formatCode.contains('%')) return CellFormatType.percentage;
    if (formatCode.contains('E+') || formatCode.contains('E-')) {
      return CellFormatType.scientific;
    }
    if (formatCode.contains('y') ||
        formatCode.contains('m') ||
        formatCode.contains('d')) {
      return CellFormatType.date;
    }
    if (formatCode.contains('H') ||
        formatCode.contains('h') ||
        formatCode.contains('s')) {
      return CellFormatType.time;
    }
    return CellFormatType.number;
  }
}
