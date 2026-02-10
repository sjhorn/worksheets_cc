# Worksheets.cc flutter web app in gh-pages on github.com

## Project Overview

Refer to flutter-ghpages-setup.md for intent of this flutter and gh-pages project. 

In addtion we aim to use the worksheet package with worksheet_formula to create a working spreadsheet. 

## Development Principles

### TDD Workflow
1. **Write test first** - Define expected behavior before implementation
2. **Red → Green → Refactor** - Failing test → Pass → Optimize
3. **Test file mirrors source** - `lib/src/core/span_list.dart` → `test/core/span_list_test.dart`
4. **Minimum 80% coverage** - Critical paths require 100%

### SOLID Principles
- **S**: Each class has one responsibility 
- **O**: Extend via interfaces, not modification 
- **L**: Subtypes must be substitutable 
- **I**: Small, focused interfaces 
- **D**: Depend on abstractions 

### Dart Idioms
- Prefer `final` and immutable models
- Use factory constructors for complex initialization
- Extension methods for utility functions
- `typedef` for function signatures
- Named parameters with required keyword

## Package Structure

Refer flutter-ghpages-setup.md 

## Testing Strategy

### Unit Tests
- All pure functions and models
- Mock dependencies via interfaces
- Property-based tests for math operations

### Widget Tests
- `RenderObject` behavior via `TestRenderingFlutterBinding`
- Gesture simulation
- Layout verification

### Integration Tests
- Scroll + zoom combinations
- Large dataset performance
- Memory leak detection

### Performance Benchmarks
```dart
// Target metrics
const scrollFps = 60;        // Maintain 60fps while scrolling
const zoomFps = 30;          // Acceptable during zoom animation
const tileRenderMs = 8;      // Max time to render single tile
const hitTestUs = 100;       // Max hit test latency
```

## Commands
```bash
# Run tests with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html

# Run specific test file
flutter test test/core/span_list_test.dart

# Performance profiling
flutter run --profile --trace-skia
```

## UI Guidelines

### Dropdown / Popup Positioning
All toolbar dropdowns and custom overlays must be **viewport-aware**. On narrow screens (e.g. mobile portrait), a popup anchored to the button's left edge can overflow off-screen to the right. Always clamp the popup position so it stays within the visible area:
- Prefer right-aligning the popup when it would overflow the right edge
- Keep a minimum margin (8px) from screen edges
- This applies to custom `OverlayEntry` popups and any manually positioned menus
- Flutter's built-in `PopupMenuButton` handles this automatically; custom overlays must do it manually

## Code Review Checklist
- [ ] Tests written before implementation
- [ ] All public APIs documented
- [ ] No magic numbers (use constants)
- [ ] Interfaces for external dependencies
- [ ] Immutable models where possible
- [ ] Memory disposal in `dispose()` methods
- [ ] Performance-critical code benchmarked

## Version Bumping

**On every commit that is pushed**, increment the version in both places:
- `pubspec.yaml` — `version` field (bump build number too, e.g. `1.0.1+2` → `1.0.2+3`)
- `lib/src/constants.dart` — `appVersion` constant

Use semver: patch for fixes, minor for features, major for breaking changes.
Also update `dependencyVersions` in `constants.dart` whenever dependencies are upgraded.

## Release Process

Follow these steps in order. Fix any issues before proceeding to the next step.

### 1. Static Analysis
```bash
# Run the analyzer — must have zero issues
flutter analyze

# Apply automated fixes for any issues
dart fix --apply

# Re-run analyzer to confirm clean
flutter analyze
```

### 2. Tests
```bash
# Run all tests — must all pass
flutter test
```

### 3. Coverage
```bash
# Generate coverage data
flutter test --coverage

# Generate HTML report and review
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Verify minimum 80% coverage (critical paths 100%)
```

### 4. Benchmarks
```bash
# Run performance profiling
flutter run --profile --trace-skia
```
Confirm targets: scroll 60fps, zoom 30fps, tile render <8ms, hit test <100us.

### 5. Version & Changelog
- Bump version in `pubspec.yaml` following [semver](https://semver.org/)
  - **patch** (1.0.x): bug fixes
  - **minor** (1.x.0): new features, backwards compatible
  - **major** (x.0.0): breaking API changes
- Add entry to `CHANGELOG.md` under new version heading with date
- Update any version references in `README.md` if needed

### 6. Commit & Tag
```bash
git add -A
git commit -m "chore: release vX.Y.Z"
git tag vX.Y.Z
git push && git push --tags
```
