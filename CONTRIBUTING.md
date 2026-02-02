# Contributing to Worksheets.cc

Thank you for your interest in contributing. This document explains how to get involved.

## Development Setup

1. Fork and clone the repository
2. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
3. Run `flutter pub get` to install dependencies
4. Run `flutter test` to verify everything works

## Workflow

1. Create a branch from `main` for your change
2. Write tests first (TDD) -- see [Testing](#testing) below
3. Implement the change
4. Ensure `flutter analyze` reports zero issues
5. Ensure `flutter test` passes
6. Open a pull request against `main`

## Code Style

This project follows the conventions in [CLAUDE.md](CLAUDE.md):

- **SOLID principles** -- single responsibility, depend on abstractions
- **Dart idioms** -- prefer `final`, immutable models, factory constructors, named parameters with `required`
- **No magic numbers** -- use named constants in `lib/src/constants.dart`
- **Interfaces for external dependencies** -- e.g. `PersistenceService` abstract class

The project uses [flutter_lints](https://pub.dev/packages/flutter_lints) for static analysis. Run `flutter analyze` before submitting.

## Testing

Tests live in `test/` and mirror the `lib/src/` directory structure:

```
lib/src/models/workbook_model.dart  -->  test/widget_test.dart (WorkbookModel group)
lib/src/services/formula_service.dart  -->  test/services/formula_service_test.dart
```

### Running tests

```bash
# All tests
flutter test

# Specific file
flutter test test/services/formula_service_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Writing tests

- Write the test before the implementation (red-green-refactor)
- Unit test all pure functions and models
- Mock dependencies via interfaces
- Target minimum 80% coverage; critical paths require 100%

## Architecture Overview

```
SpreadsheetPage (main scaffold)
├── FormulaBar          -- cell ref + formula text
├── FormattingToolbar   -- bold, italic, colours, number formats
├── Worksheet           -- spreadsheet grid (from worksheet package)
├── SheetTabs           -- sheet tab bar
└── ZoomControls        -- zoom slider

WorkbookModel (ChangeNotifier)
├── SheetModel[]        -- SparseWorksheetData + WorksheetController per sheet

FormulaService          -- bridges worksheet data to FormulaEngine
PersistenceService      -- localStorage auto-save + JSON file I/O
```

State flows through `WorkbookModel` via `ChangeNotifier` and `ListenableBuilder`. No additional state management packages are used.

## Pull Request Guidelines

- Keep PRs focused -- one feature or fix per PR
- Include tests for new functionality
- Update documentation if public APIs change
- Ensure the CI pipeline passes (analyze + test)

## Reporting Issues

Open an issue on GitHub with:

- Steps to reproduce
- Expected vs actual behaviour
- Browser and OS version

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
