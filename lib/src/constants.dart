import 'package:flutter/material.dart';

const String appTitle = 'worksheets.cc';
const int defaultRowCount = 1048576; // 2^20, matches Excel
const int defaultColumnCount = 16384; // 2^14 (A–XFD), matches Excel
const String defaultSheetName = 'Sheet1';

const String appVersion = '1.6.4';
const Map<String, String> dependencyVersions = {
  'worksheet': '3.0.2',
  'worksheet_formula': '1.3.0',
  'material_symbols_icons': '4.2906.0',
  'google_fonts': '8.0.0',
  'a1': '2.2.0',
  'pdf': '3.11.3',
  'printing': '5.14.2',
  'flutter SDK': '3.10.7',
};

const Color primaryColor = Color(0xFF673AB7);
const Color headerBackground = Color(0xFFF3F3F3);
const Color toolbarBorder = Color(0xFFD9D9D9);

class AppColors {
  static Color headerBg(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2D2D2D) : headerBackground;
  static Color border(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF4A4A4A) : toolbarBorder;
  static Color menuBarBg(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF1E1E1E) : primaryColor;
  static Color statusBarText(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF999999) : const Color(0xFF666666);
  static Color sheetTabActive(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2D2D2D) : Colors.white;
}
