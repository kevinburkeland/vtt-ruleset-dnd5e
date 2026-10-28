import 'dart:io';
import 'package:test/test.dart';

List<String> findDiceRegexProblemsInSource(String path, String source) {
  final problems = <String>[];
  // Match RegExp(r'...') or RegExp('...') or multiline patterns
  final regExpCalls = RegExp(
    r"""RegExp\(\s*r?(?:'''|"{3}|'|")(.*?)(?:'''|"{3}|'|")""",
    dotAll: true,
  );
  final dicePatternMatcher = RegExp(
    r'(\\d+|\d+)\)?d\(?(\\d+|\d+)|d\(\\d|d\\d|d\(\d|d\d',
  );

  for (final match in regExpCalls.allMatches(source)) {
    final patternContent = match.group(1) ?? '';
    if (dicePatternMatcher.hasMatch(patternContent)) {
      problems.add(
        '$path: found dice pattern token in RegExp pattern literal: "${match.group(0)}"',
      );
    }
  }

  return problems;
}

List<String> scanDirectoryForDiceRegex(Directory dir, {Set<String>? excludePaths}) {
  final problems = <String>[];
  if (!dir.existsSync()) return problems;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (excludePaths != null &&
          excludePaths.any((ex) => normalizedPath.contains(ex))) {
        continue;
      }
      final source = entity.readAsStringSync();
      problems.addAll(findDiceRegexProblemsInSource(normalizedPath, source));
    }
  }
  return problems;
}

void main() {
  group('Dice Regex Source Bar (DR1 & DR1c)', () {
    test('DR1c (control): detects dice regex patterns in synthetic inputs', () {
      final cases = <String, bool>{
        "final r = RegExp(r'(\\d+)d(\\d+)');": true,
        "final r = RegExp(r'^(\\d+)d(\\d+)(.*)\$');": true,
        "final r = RegExp(r'\\d+d\\d+');": true,
        "final r = RegExp(r'd(\\d+)');": true,
        "final r = RegExp(r'\\+(\\d+)');": false,
      };

      cases.forEach((code, shouldFail) {
        final problems = findDiceRegexProblemsInSource('synthetic_test.dart', code);
        if (shouldFail) {
          expect(problems, hasLength(1),
              reason: 'Expected exactly 1 problem for: $code');
        } else {
          expect(problems, isEmpty,
              reason: 'Expected 0 problems for: $code');
        }
      });
    });

    test('DR1: no dice token RegExp exists in lib/ outside lib/src/dice/', () {
      final libDir = Directory('lib');
      final problems = scanDirectoryForDiceRegex(
        libDir,
        excludePaths: {'lib/src/dice/'},
      );
      expect(problems, isEmpty,
          reason: 'Dice token regular expressions are banned under lib/ outside lib/src/dice/:\n'
              '${problems.join('\n')}');
    });
  });
}
