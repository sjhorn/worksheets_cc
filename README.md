# Worksheets.cc

A spreadsheet in your browser, built with [Flutter](https://flutter.dev) for the web and deployed to [worksheets.cc](https://worksheets.cc) via GitHub Pages.

## Features

- **Spreadsheet grid** with smooth 60fps scrolling and 10%-400% pinch-to-zoom
- **43 built-in formulas** -- SUM, AVERAGE, VLOOKUP, IF, COUNTIF, and more (Excel/Google Sheets compatible)
- **Cell formatting** -- bold, italic, text/background colours, number formats (currency, percentage, date, scientific, etc.)
- **Multiple sheets** with tab management (add, rename, delete)
- **Formula bar** showing cell reference and formula text for the selected cell
- **Auto-save** to browser localStorage with file export/import as JSON
- **Row/column resizing** via drag handles
- **Keyboard navigation** within the grid
- **Circular reference detection** with dependency-based recalculation

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter (web) |
| Spreadsheet Widget | [worksheet](https://pub.dev/packages/worksheet) |
| Formula Engine | [worksheet_formula](https://pub.dev/packages/worksheet_formula) |
| Cell References | [a1](https://pub.dev/packages/a1) |
| State Management | ChangeNotifier + ListenableBuilder |
| Persistence | Browser localStorage + JSON file export |
| Hosting | GitHub Pages at worksheets.cc |
| CI/CD | GitHub Actions |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, Dart SDK >= 3.10.7)

### Setup

```bash
git clone git@github.com:sjhorn/worksheets_cc.git
cd worksheets_cc
flutter pub get
```

### Run locally

```bash
flutter run -d chrome
```

### Run tests

```bash
flutter test
```

### Static analysis

```bash
flutter analyze
```

### Build for production

```bash
flutter build web --release --base-href /
```

The build output is in `build/web/`.

## Project Structure

```
lib/
├── main.dart                          # App entry point
└── src/
    ├── constants.dart                 # App-wide constants
    ├── models/
    │   ├── sheet_model.dart           # Sheet data + controller wrapper
    │   └── workbook_model.dart        # Multi-sheet ChangeNotifier
    ├── services/
    │   ├── formula_service.dart       # Bridges worksheet data to FormulaEngine
    │   └── persistence_service.dart   # localStorage auto-save + JSON file I/O
    └── widgets/
        ├── formula_bar.dart           # Cell reference + formula display
        ├── formatting_toolbar.dart    # Bold, italic, colours, number formats
        ├── sheet_tabs.dart            # Sheet tab bar with add/rename/delete
        ├── spreadsheet_page.dart      # Main page scaffold
        └── zoom_controls.dart         # Zoom slider + percentage display

test/
├── widget_test.dart                   # WorkbookModel + SheetModel tests
└── services/
    └── formula_service_test.dart      # Formula evaluation + dependency tests
```

## Deployment

Every push to `main` triggers the GitHub Actions workflow (`.github/workflows/deploy.yml`):

1. **Test** -- `flutter analyze` and `flutter test` must pass
2. **Build** -- `flutter build web --release`
3. **Deploy** -- publishes `build/web/` to the `gh-pages` branch via [peaceiris/actions-gh-pages](https://github.com/peaceiris/actions-gh-pages)

GitHub Pages serves the `gh-pages` branch at [worksheets.cc](https://worksheets.cc). DNS and CNAME configuration details are in [flutter-ghpages-setup.md](flutter-ghpages-setup.md).

## Contributing

Contributions are welcome. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
