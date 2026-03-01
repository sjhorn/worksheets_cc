import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/worksheet.dart';
import 'package:worksheets_cc/src/services/formula_worksheet_data.dart';

void main() {
  late SparseWorksheetData rawData;
  late FormulaWorksheetData formulaData;

  setUp(() {
    rawData = SparseWorksheetData(rowCount: 100, columnCount: 26);
    formulaData = FormulaWorksheetData(rawData);
  });

  tearDown(() {
    formulaData.dispose();
    rawData.dispose();
  });

  const c3 = CellCoordinate(2, 2);
  const d3 = CellCoordinate(2, 3);

  group('getCellsInRange returns evaluated values for formula cells', () {
    test('formula cell returns evaluated displayValue', () {
      rawData.setCell(c3, CellValue.number(1));
      rawData.setCell(d3, const CellValue.formula('=C3*3'));

      final range = CellRange(d3.row, d3.column, d3.row, d3.column);
      final entries = formulaData.getCellsInRange(range).toList();

      expect(entries.length, 1);
      expect(entries.first.key, d3);
      expect(entries.first.value.displayValue, '3',
          reason: 'getCellsInRange should return evaluated value, '
              'not raw formula');
    });

    test('non-formula cell passes through unchanged', () {
      rawData.setCell(c3, CellValue.number(42));

      final range = CellRange(c3.row, c3.column, c3.row, c3.column);
      final entries = formulaData.getCellsInRange(range).toList();

      expect(entries.length, 1);
      expect(entries.first.value.displayValue, '42');
    });

    test('range with mixed formula and non-formula cells', () {
      rawData.setCell(c3, CellValue.number(1));
      rawData.setCell(d3, const CellValue.formula('=C3*3'));

      final range = CellRange(c3.row, c3.column, d3.row, d3.column);
      final entries = formulaData.getCellsInRange(range).toList();

      expect(entries.length, 2);

      final c3Entry = entries.firstWhere((e) => e.key == c3);
      expect(c3Entry.value.displayValue, '1');

      final d3Entry = entries.firstWhere((e) => e.key == d3);
      expect(d3Entry.value.displayValue, '3');
    });

    test('formula error cell returns error value', () {
      rawData.setCell(d3, const CellValue.formula('=INVALID('));

      final range = CellRange(d3.row, d3.column, d3.row, d3.column);
      final entries = formulaData.getCellsInRange(range).toList();

      expect(entries.length, 1);
      expect(entries.first.value.isError, true);
    });
  });

  group('ToggleBoldAction simulation (Ctrl+B path)', () {
    test('auto-span text uses evaluated value for formula cells', () {
      rawData.setCell(c3, CellValue.number(1));
      rawData.setCell(d3, const CellValue.formula('=C3*3'));

      // Simulate what ToggleBoldAction._toggleOnSelection does:
      // 1. Get rich text in range (none yet)
      final range = CellRange(d3.row, d3.column, d3.row, d3.column);
      final richTextEntries =
          formulaData.getRichTextInRange(range).toList();
      final richTextCoords =
          richTextEntries.map((e) => e.key).toSet();

      // 2. Get cells without rich text and create auto-spans
      final entries = <MapEntry<CellCoordinate, List<TextSpan>>>[];
      for (final entry in formulaData.getCellsInRange(range)) {
        if (!richTextCoords.contains(entry.key)) {
          final autoSpans = [TextSpan(text: entry.value.displayValue)];
          entries.add(MapEntry(entry.key, autoSpans));
        }
      }

      expect(entries.length, 1);
      expect(entries.first.value.first.text, '3',
          reason: 'auto-span should use evaluated "3", not formula "=C3*3"');

      // 3. Apply bold
      for (final entry in entries) {
        final toggled = entry.value
            .map((s) => TextSpan(
                  text: s.text,
                  style: (s.style ?? const TextStyle())
                      .copyWith(fontWeight: FontWeight.bold),
                ))
            .toList();
        formulaData.setRichText(entry.key, toggled);
      }

      // 4. Verify the stored rich text
      final stored = formulaData.getRichText(d3);
      expect(stored, isNotNull);
      expect(stored!.first.text, '3');
      expect(stored.first.style!.fontWeight, FontWeight.bold);
    });
  });

  group('Cell-level style for formula cells (worksheet 3.8.0)', () {
    test('cell-level style uses empty-text TextSpan', () {
      rawData.setCell(c3, CellValue.number(1));
      rawData.setCell(d3, const CellValue.formula('=C3*3'));

      // Apply cell-level bold style (what our app does for formula cells)
      formulaData.setRichText(
        d3,
        [const TextSpan(style: TextStyle(fontWeight: FontWeight.bold))],
      );

      // Verify: stored span has no text, just style
      final stored = formulaData.getRichText(d3);
      expect(stored, isNotNull);
      expect(stored!.length, 1);
      expect(stored.first.text, isNull,
          reason: 'cell-level style should have no text');
      expect(stored.first.style!.fontWeight, FontWeight.bold);

      // Verify: the cell's evaluated value is still accessible
      final evaluated = formulaData.getCell(d3);
      expect(evaluated!.displayValue, '3');
    });

    test('cell-level style survives formula re-evaluation', () {
      rawData.setCell(c3, CellValue.number(1));
      rawData.setCell(d3, const CellValue.formula('=C3*3'));

      // Apply cell-level bold
      formulaData.setRichText(
        d3,
        [const TextSpan(style: TextStyle(fontWeight: FontWeight.bold))],
      );

      // Change C3 so D3 re-evaluates
      rawData.setCell(c3, CellValue.number(10));

      // Style is preserved (it's independent of the display value)
      final stored = formulaData.getRichText(d3);
      expect(stored, isNotNull);
      expect(stored!.first.text, isNull);
      expect(stored.first.style!.fontWeight, FontWeight.bold);

      // Display value updated
      final evaluated = formulaData.getCell(d3);
      expect(evaluated!.displayValue, '30');
    });
  });
}
