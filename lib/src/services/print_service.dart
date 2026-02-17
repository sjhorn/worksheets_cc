import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:worksheet/worksheet.dart';

import '../models/sheet_model.dart';

class PrintService {
  static Future<void> printSheet(SheetModel sheet) async {
    final usedRange = _getUsedRange(sheet);
    if (usedRange == null) {
      // Empty sheet — open print dialog with just the sheet name
      await Printing.layoutPdf(
        name: sheet.name,
        onLayout: (_) {
          final pdf = pw.Document();
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              build: (context) => pw.Center(
                child: pw.Text(sheet.name,
                    style: const pw.TextStyle(fontSize: 18)),
              ),
            ),
          );
          return pdf.save();
        },
      );
      return;
    }

    final maxRow = usedRange.endRow;
    final maxCol = usedRange.endColumn;

    await Printing.layoutPdf(
      name: sheet.name,
      onLayout: (format) {
        final pdf = pw.Document();

        // Build column widths proportional to custom widths or default
        const defaultWidth = 100.0;
        final colWidths = <int, pw.TableColumnWidth>{};
        var totalWidth = 30.0; // row-number column
        for (var c = 0; c <= maxCol; c++) {
          final w = sheet.customColumnWidths[c] ?? defaultWidth;
          totalWidth += w;
        }

        // Scale factor to fit page width
        final pageWidth =
            format.availableWidth > 0 ? format.availableWidth : 750.0;
        final scale = pageWidth / totalWidth;

        colWidths[0] = pw.FixedColumnWidth(30.0 * scale);
        for (var c = 0; c <= maxCol; c++) {
          final w = sheet.customColumnWidths[c] ?? defaultWidth;
          colWidths[c + 1] = pw.FixedColumnWidth(w * scale);
        }

        // Header row (column letters)
        final headerCells = <pw.Widget>[
          _headerCell('', scale), // empty corner cell
        ];
        for (var c = 0; c <= maxCol; c++) {
          headerCells.add(_headerCell(_columnLetter(c), scale));
        }

        // Data rows
        final rows = <pw.TableRow>[
          pw.TableRow(children: headerCells),
        ];

        for (var r = 0; r <= maxRow; r++) {
          final rowCells = <pw.Widget>[
            _headerCell('${r + 1}', scale), // row number
          ];
          for (var c = 0; c <= maxCol; c++) {
            final coord = CellCoordinate(r, c);
            final cv = sheet.formulaData.getCell(coord);
            final text = cv?.displayValue ?? '';
            rowCells.add(_dataCell(text, scale));
          }
          rows.add(pw.TableRow(children: rowCells));
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            header: (context) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(sheet.name,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
            build: (context) => [
              pw.Table(
                columnWidths: colWidths,
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: rows,
              ),
            ],
          ),
        );

        return pdf.save();
      },
    );
  }

  static ({int endRow, int endColumn})? _getUsedRange(SheetModel sheet) {
    int maxRow = -1;
    int maxCol = -1;
    for (final entry in sheet.sparseData.cells.entries) {
      final coord = entry.key;
      if (coord.row > maxRow) maxRow = coord.row;
      if (coord.column > maxCol) maxCol = coord.column;
    }
    if (maxRow < 0) return null;
    return (endRow: maxRow, endColumn: maxCol);
  }

  static String _columnLetter(int col) {
    return CellCoordinate(0, col).toNotation().replaceAll(RegExp(r'\d+$'), '');
  }

  static pw.Widget _headerCell(String text, double scale) {
    final fontSize = (9.0 * scale).clamp(6.0, 9.0);
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      color: PdfColors.grey200,
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _dataCell(String text, double scale) {
    final fontSize = (8.0 * scale).clamp(6.0, 8.0);
    return pw.Container(
      padding: const pw.EdgeInsets.all(2),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize)),
    );
  }
}
