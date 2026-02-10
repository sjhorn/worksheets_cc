import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheets_cc/src/models/format_catalog.dart';

void main() {
  group('FormatUtils.adjustDecimals', () {
    test('+1 on #,##0.00 → #,##0.000', () {
      const fmt = CellFormat(type: CellFormatType.number, formatCode: '#,##0.00');
      final result = FormatUtils.adjustDecimals(fmt, 1);
      expect(result, isNotNull);
      expect(result!.formatCode, '#,##0.000');
      expect(result.type, CellFormatType.number);
    });

    test('-1 on #,##0.00 → #,##0.0', () {
      const fmt = CellFormat(type: CellFormatType.number, formatCode: '#,##0.00');
      final result = FormatUtils.adjustDecimals(fmt, -1);
      expect(result, isNotNull);
      expect(result!.formatCode, '#,##0.0');
    });

    test('-1 on #,##0.0 → #,##0', () {
      const fmt = CellFormat(type: CellFormatType.number, formatCode: '#,##0.0');
      final result = FormatUtils.adjustDecimals(fmt, -1);
      expect(result, isNotNull);
      expect(result!.formatCode, '#,##0');
    });

    test('+1 on #,##0 (no decimal) → #,##0.0', () {
      const fmt = CellFormat(type: CellFormatType.number, formatCode: '#,##0');
      final result = FormatUtils.adjustDecimals(fmt, 1);
      expect(result, isNotNull);
      expect(result!.formatCode, '#,##0.0');
    });

    test('-1 on #,##0 (no decimal) → null', () {
      const fmt = CellFormat(type: CellFormatType.number, formatCode: '#,##0');
      final result = FormatUtils.adjustDecimals(fmt, -1);
      expect(result, isNull);
    });

    test('null format +1 with no value → 0.0', () {
      final result = FormatUtils.adjustDecimals(null, 1);
      expect(result, isNotNull);
      expect(result!.formatCode, '0.0');
      expect(result.type, CellFormatType.number);
    });

    test('null format -1 with no value → 0', () {
      final result = FormatUtils.adjustDecimals(null, -1);
      expect(result, isNotNull);
      expect(result!.formatCode, '0');
      expect(result.type, CellFormatType.number);
    });

    test('null format +1 with 3.14 → 0.000 (detects 2 decimals)', () {
      final result = FormatUtils.adjustDecimals(
        null, 1, cellValue: CellValue.number(3.14),
      );
      expect(result, isNotNull);
      expect(result!.formatCode, '0.000');
    });

    test('null format -1 with 3.14 → 0.0 (detects 2 decimals)', () {
      final result = FormatUtils.adjustDecimals(
        null, -1, cellValue: CellValue.number(3.14),
      );
      expect(result, isNotNull);
      expect(result!.formatCode, '0.0');
    });

    test('null format -1 with integer → 0', () {
      final result = FormatUtils.adjustDecimals(
        null, -1, cellValue: CellValue.number(42),
      );
      expect(result, isNotNull);
      expect(result!.formatCode, '0');
    });

    test('null format with text cell value → 0.0 (ignores non-number)', () {
      final result = FormatUtils.adjustDecimals(
        null, 1, cellValue: const CellValue.text('hello'),
      );
      expect(result, isNotNull);
      expect(result!.formatCode, '0.0');
    });

    test('null format does not introduce comma grouping', () {
      final result = FormatUtils.adjustDecimals(
        null, 1, cellValue: CellValue.number(1234.56),
      );
      expect(result, isNotNull);
      expect(result!.formatCode, isNot(contains(',')));
    });

    test('cellValue is ignored when format is already set', () {
      const fmt = CellFormat(
        type: CellFormatType.number,
        formatCode: '#,##0.00',
      );
      final result = FormatUtils.adjustDecimals(
        fmt, 1, cellValue: CellValue.number(3.14),
      );
      expect(result, isNotNull);
      expect(result!.formatCode, '#,##0.000');
    });

    test('+1 on \$#,##0.00 (currency) preserves prefix', () {
      const fmt =
          CellFormat(type: CellFormatType.currency, formatCode: r'$#,##0.00');
      final result = FormatUtils.adjustDecimals(fmt, 1);
      expect(result, isNotNull);
      expect(result!.formatCode, r'$#,##0.000');
      expect(result.type, CellFormatType.currency);
    });

    test('-1 on \$#,##0.00 preserves prefix', () {
      const fmt =
          CellFormat(type: CellFormatType.currency, formatCode: r'$#,##0.00');
      final result = FormatUtils.adjustDecimals(fmt, -1);
      expect(result, isNotNull);
      expect(result!.formatCode, r'$#,##0.0');
    });

    test('clamps at 10 decimals', () {
      final tenDecimals = '0.${'0' * 10}';
      final fmt =
          CellFormat(type: CellFormatType.number, formatCode: tenDecimals);
      final result = FormatUtils.adjustDecimals(fmt, 1);
      expect(result, isNull);
    });
  });

  group('FormatUtils.inferType', () {
    test('currency symbols → currency', () {
      expect(FormatUtils.inferType(r'$#,##0.00'), CellFormatType.currency);
      expect(FormatUtils.inferType('€#,##0.00'), CellFormatType.currency);
      expect(FormatUtils.inferType('£#,##0.00'), CellFormatType.currency);
    });

    test('percent → percentage', () {
      expect(FormatUtils.inferType('0.00%'), CellFormatType.percentage);
    });

    test('scientific notation → scientific', () {
      expect(FormatUtils.inferType('0.00E+00'), CellFormatType.scientific);
    });

    test('date patterns → date', () {
      expect(FormatUtils.inferType('m/d/yyyy'), CellFormatType.date);
    });

    test('plain number → number', () {
      expect(FormatUtils.inferType('#,##0'), CellFormatType.number);
    });
  });

  group('FormatCatalog.menuSections', () {
    test('has 6 sections', () {
      expect(FormatCatalog.menuSections.length, 6);
    });

    test('first section has Automatic and Plain text', () {
      final section = FormatCatalog.menuSections[0];
      expect(section.length, 2);
      expect(section[0].label, 'Automatic');
      expect(section[1].label, 'Plain text');
    });

    test('last section entries are all custom', () {
      final section = FormatCatalog.menuSections[5];
      expect(section.length, 3);
      for (final entry in section) {
        expect(entry.isCustom, isTrue);
      }
    });

    test('non-custom entries have valid formats', () {
      for (final section in FormatCatalog.menuSections) {
        for (final entry in section) {
          if (!entry.isCustom) {
            expect(entry.format.formatCode, isNotEmpty);
          }
        }
      }
    });
  });
}
