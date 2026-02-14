import 'package:flutter/material.dart';

import 'src/constants.dart';
import 'src/models/workbook_model.dart';
import 'src/services/persistence_service.dart';
import 'src/widgets/spreadsheet_page.dart';

void main() {
  runApp(const WorksheetsApp());
}

class WorksheetsApp extends StatefulWidget {
  const WorksheetsApp({super.key});

  @override
  State<WorksheetsApp> createState() => _WorksheetsAppState();
}

class _WorksheetsAppState extends State<WorksheetsApp> {
  late final WorkbookModel _workbook;
  late final WebPersistenceService _persistenceService;
  bool _isLoading = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _workbook = WorkbookModel();
    _persistenceService = WebPersistenceService();
    _loadWorkbook();
  }

  Future<void> _loadWorkbook() async {
    await _persistenceService.load(_workbook);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _persistenceService.dispose();
    _workbook.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : SpreadsheetPage(
              workbook: _workbook,
              persistenceService: _persistenceService,
              isDarkMode: _isDarkMode,
              onToggleDarkMode: () =>
                  setState(() => _isDarkMode = !_isDarkMode),
            ),
    );
  }
}
