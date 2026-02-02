import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';
import 'package:web/web.dart' as web;

import '../models/sheet_model.dart';
import '../models/workbook_model.dart';

const _storageKey = 'worksheets_cc_workbook';
const _version = 1;

abstract class PersistenceService {
  Future<void> save(WorkbookModel workbook);
  Future<bool> load(WorkbookModel workbook);
  Future<void> exportFile(WorkbookModel workbook);
  Future<void> importFile(WorkbookModel workbook);
}

class WebPersistenceService implements PersistenceService {
  Timer? _debounceTimer;

  void scheduleSave(WorkbookModel workbook) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      save(workbook);
    });
  }

  @override
  Future<void> save(WorkbookModel workbook) async {
    try {
      final json = _serializeWorkbook(workbook);
      final encoded = jsonEncode(json);
      web.window.localStorage.setItem(_storageKey, encoded);
    } catch (e) {
      debugPrint('Failed to save workbook: $e');
    }
  }

  @override
  Future<bool> load(WorkbookModel workbook) async {
    try {
      final encoded = web.window.localStorage.getItem(_storageKey);
      if (encoded == null) return false;

      final json = jsonDecode(encoded) as Map<String, dynamic>;
      _deserializeWorkbook(json, workbook);
      return true;
    } catch (e) {
      debugPrint('Failed to load workbook: $e');
      return false;
    }
  }

  @override
  Future<void> exportFile(WorkbookModel workbook) async {
    final json = _serializeWorkbook(workbook);
    final encoded = jsonEncode(json);
    final bytes = Uint8List.fromList(utf8.encode(encoded));

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = 'workbook.json';
    anchor.click();

    web.URL.revokeObjectURL(url);
  }

  @override
  Future<void> importFile(WorkbookModel workbook) async {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = '.json';

    final completer = Completer<void>();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete();
        return;
      }

      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.addEventListener(
        'load',
        ((web.Event event) {
          try {
            final encoded = (reader.result as JSString).toDart;
            final json = jsonDecode(encoded) as Map<String, dynamic>;
            _deserializeWorkbook(json, workbook);
          } catch (e) {
            debugPrint('Failed to import file: $e');
          }
          completer.complete();
        }).toJS,
      );

      reader.readAsText(file);
    });

    input.click();
    // Don't await completer — user may cancel file dialog
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

  Map<String, dynamic> _serializeWorkbook(WorkbookModel workbook) {
    return {
      'version': _version,
      'activeSheet': workbook.activeSheetIndex,
      'sheets': workbook.sheets
          .map((sheet) => _serializeSheet(sheet))
          .toList(),
    };
  }

  Map<String, dynamic> _serializeSheet(SheetModel sheet) {
    final cells = <String, dynamic>{};

    for (final entry in sheet.data.cells.entries) {
      final coord = entry.key;
      final cell = entry.value;
      final key = coord.toNotation();
      cells[key] = _serializeCell(cell);
    }

    return {
      'name': sheet.name,
      'cells': cells,
      'columnWidths': sheet.customColumnWidths
          .map((k, v) => MapEntry(k.toString(), v)),
      'rowHeights': sheet.customRowHeights
          .map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  Map<String, dynamic> _serializeCell(Cell cell) {
    final map = <String, dynamic>{};

    if (cell.value != null) {
      final v = cell.value!;
      map['type'] = v.type.name;
      map['value'] = v.rawValue.toString();
    }

    if (cell.style != null) {
      map['style'] = _serializeStyle(cell.style!);
    }

    if (cell.format != null) {
      map['format'] = {
        'type': cell.format!.type.name,
        'code': cell.format!.formatCode,
      };
    }

    return map;
  }

  Map<String, dynamic> _serializeStyle(CellStyle style) {
    final map = <String, dynamic>{};
    if (style.backgroundColor != null) {
      map['bg'] = style.backgroundColor!.toARGB32();
    }
    if (style.textColor != null) {
      map['fg'] = style.textColor!.toARGB32();
    }
    if (style.fontWeight != null) {
      map['bold'] = style.fontWeight == FontWeight.bold;
    }
    if (style.fontStyle != null) {
      map['italic'] = style.fontStyle == FontStyle.italic;
    }
    if (style.fontSize != null) {
      map['size'] = style.fontSize;
    }
    if (style.textAlignment != null) {
      map['align'] = style.textAlignment!.name;
    }
    return map;
  }

  void _deserializeWorkbook(
      Map<String, dynamic> json, WorkbookModel workbook) {
    // Clear existing sheets
    while (workbook.sheetCount > 1) {
      workbook.removeSheet(workbook.sheetCount - 1);
    }

    final sheetsJson = json['sheets'] as List<dynamic>;
    for (var i = 0; i < sheetsJson.length; i++) {
      final sheetJson = sheetsJson[i] as Map<String, dynamic>;

      if (i == 0) {
        workbook.renameSheet(0, sheetJson['name'] as String);
      } else {
        workbook.addSheet(name: sheetJson['name'] as String);
      }

      _deserializeSheet(sheetJson, workbook.sheets[i]);
    }

    final activeSheet = json['activeSheet'] as int? ?? 0;
    workbook.switchSheet(activeSheet);
  }

  void _deserializeSheet(Map<String, dynamic> json, SheetModel sheet) {
    final cells = json['cells'] as Map<String, dynamic>? ?? {};

    for (final entry in cells.entries) {
      final coord = CellCoordinate.fromNotation(entry.key);
      final cellJson = entry.value as Map<String, dynamic>;
      _deserializeCell(cellJson, coord, sheet.data);
    }

    final colWidths = json['columnWidths'] as Map<String, dynamic>? ?? {};
    for (final entry in colWidths.entries) {
      sheet.customColumnWidths[int.parse(entry.key)] =
          (entry.value as num).toDouble();
    }

    final rowHeights = json['rowHeights'] as Map<String, dynamic>? ?? {};
    for (final entry in rowHeights.entries) {
      sheet.customRowHeights[int.parse(entry.key)] =
          (entry.value as num).toDouble();
    }
  }

  void _deserializeCell(
    Map<String, dynamic> json,
    CellCoordinate coord,
    SparseWorksheetData data,
  ) {
    if (json.containsKey('type') && json.containsKey('value')) {
      final typeStr = json['type'] as String;
      final valueStr = json['value'] as String;
      final cellValue = _parseCellValue(typeStr, valueStr);
      if (cellValue != null) {
        data.setCell(coord, cellValue);
      }
    }

    if (json.containsKey('style')) {
      final styleJson = json['style'] as Map<String, dynamic>;
      data.setStyle(coord, _deserializeStyle(styleJson));
    }

    if (json.containsKey('format')) {
      final formatJson = json['format'] as Map<String, dynamic>;
      final type = CellFormatType.values.byName(formatJson['type'] as String);
      data.setFormat(coord, CellFormat(type: type, formatCode: formatJson['code'] as String));
    }
  }

  CellValue? _parseCellValue(String type, String value) {
    return switch (type) {
      'text' => CellValue.text(value),
      'number' => CellValue.number(num.parse(value)),
      'boolean' => CellValue.boolean(value == 'true'),
      'formula' => CellValue.formula(value),
      'date' => CellValue.date(DateTime.parse(value)),
      _ => null,
    };
  }

  CellStyle _deserializeStyle(Map<String, dynamic> json) {
    return CellStyle(
      backgroundColor:
          json['bg'] != null ? Color(json['bg'] as int) : null,
      textColor: json['fg'] != null ? Color(json['fg'] as int) : null,
      fontWeight:
          json['bold'] == true ? FontWeight.bold : null,
      fontStyle:
          json['italic'] == true ? FontStyle.italic : null,
      fontSize: json['size'] != null ? (json['size'] as num).toDouble() : null,
      textAlignment: json['align'] != null
          ? CellTextAlignment.values.byName(json['align'] as String)
          : null,
    );
  }
}
