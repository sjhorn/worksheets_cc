import 'package:flutter_test/flutter_test.dart';
import 'package:worksheets_cc/src/constants.dart';

void main() {
  group('Version constants', () {
    test('appVersion is a valid semver string', () {
      expect(appVersion, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('dependencyVersions contains expected keys', () {
      expect(dependencyVersions, contains('worksheet'));
      expect(dependencyVersions, contains('worksheet_formula'));
      expect(dependencyVersions, contains('a1'));
      expect(dependencyVersions, contains('flutter SDK'));
    });

    test('dependencyVersions values are valid version strings', () {
      for (final entry in dependencyVersions.entries) {
        expect(
          entry.value,
          matches(RegExp(r'^\d+\.\d+\.\d+$')),
          reason: '${entry.key} should have a valid version',
        );
      }
    });
  });
}
