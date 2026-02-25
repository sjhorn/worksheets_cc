import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet_formula/worksheet_formula.dart';
import 'package:worksheets_cc/src/models/formula_catalog.dart';

void main() {
  late FunctionRegistry registry;
  late List<dynamic> functions;

  setUp(() {
    registry = FunctionRegistry();
    functions = buildAutocompleteFunctions(registry);
  });

  test('produces entries for every registered function', () {
    final registeredNames = registry.names.toSet();
    final catalogNames = functions.map((f) => f.name as String).toSet();
    expect(catalogNames, registeredNames);
  });

  test('entries are sorted alphabetically', () {
    final names = functions.map((f) => f.name as String).toList();
    final sorted = [...names]..sort();
    expect(names, sorted);
  });

  test('every entry has a non-empty signature', () {
    for (final fn in functions) {
      expect((fn.signature as String).isNotEmpty, isTrue,
          reason: '${fn.name} has empty signature');
      expect((fn.signature as String).contains(fn.name as String), isTrue,
          reason: '${fn.name} signature should contain function name');
    }
  });

  test('curated functions have descriptions', () {
    // Common functions that should have hand-written descriptions
    const expectedCurated = ['SUM', 'AVERAGE', 'IF', 'VLOOKUP', 'DATE'];
    for (final name in expectedCurated) {
      final fn = functions.firstWhere((f) => f.name == name);
      expect(fn.description, isNotNull,
          reason: '$name should have a description');
      expect((fn.description as String).isNotEmpty, isTrue,
          reason: '$name description should not be empty');
    }
  });

  test('no duplicate entries', () {
    final names = functions.map((f) => f.name as String).toList();
    expect(names.length, names.toSet().length);
  });
}
