import 'package:flutter_test/flutter_test.dart';
import 'package:worksheets_cc/src/models/workbook_model.dart';
import 'package:worksheets_cc/src/models/sheet_model.dart';

void main() {
  group('WorkbookModel', () {
    late WorkbookModel workbook;

    setUp(() {
      workbook = WorkbookModel();
    });

    tearDown(() {
      workbook.dispose();
    });

    test('initializes with one sheet', () {
      expect(workbook.sheetCount, 1);
      expect(workbook.activeSheetIndex, 0);
      expect(workbook.activeSheet.name, 'Sheet1');
    });

    test('addSheet creates new sheet and switches to it', () {
      workbook.addSheet();
      expect(workbook.sheetCount, 2);
      expect(workbook.activeSheetIndex, 1);
      expect(workbook.activeSheet.name, 'Sheet2');
    });

    test('addSheet with custom name', () {
      workbook.addSheet(name: 'MySheet');
      expect(workbook.sheets[1].name, 'MySheet');
    });

    test('switchSheet changes active sheet', () {
      workbook.addSheet();
      workbook.switchSheet(0);
      expect(workbook.activeSheetIndex, 0);
    });

    test('switchSheet ignores invalid index', () {
      workbook.switchSheet(-1);
      expect(workbook.activeSheetIndex, 0);
      workbook.switchSheet(99);
      expect(workbook.activeSheetIndex, 0);
    });

    test('removeSheet removes and adjusts active index', () {
      workbook.addSheet();
      workbook.addSheet();
      workbook.switchSheet(2);
      workbook.removeSheet(2);
      expect(workbook.sheetCount, 2);
      expect(workbook.activeSheetIndex, 1);
    });

    test('removeSheet prevents removing last sheet', () {
      workbook.removeSheet(0);
      expect(workbook.sheetCount, 1);
    });

    test('renameSheet changes sheet name', () {
      workbook.renameSheet(0, 'Revenue');
      expect(workbook.sheets[0].name, 'Revenue');
    });

    test('renameSheet ignores empty name', () {
      workbook.renameSheet(0, '');
      expect(workbook.sheets[0].name, 'Sheet1');
    });

    test('notifies listeners on changes', () {
      var notified = 0;
      workbook.addListener(() => notified++);

      workbook.addSheet();
      expect(notified, 1);

      workbook.switchSheet(0);
      expect(notified, 2);

      workbook.renameSheet(0, 'Test');
      expect(notified, 3);
    });
  });

  group('SheetModel', () {
    test('creates with default data and controller', () {
      final sheet = SheetModel(name: 'Test');
      expect(sheet.name, 'Test');
      expect(sheet.rawData.rowCount, 1000);
      expect(sheet.rawData.columnCount, 26);
      expect(sheet.customColumnWidths, isEmpty);
      expect(sheet.customRowHeights, isEmpty);
      sheet.dispose();
    });

    test('copyWithName preserves data reference', () {
      final sheet = SheetModel(name: 'Original');
      final copy = sheet.copyWithName('Copy');
      expect(copy.name, 'Copy');
      expect(identical(copy.rawData, sheet.rawData), true);
      expect(identical(copy.formulaData, sheet.formulaData), true);
      expect(identical(copy.controller, sheet.controller), true);
      // Don't dispose both since they share data/controller
    });
  });
}
