import 'dart:io';
import 'dart:isolate';
import 'package:test/test.dart';

/// Checks that every path in every fenced tree block (```text ... ```) exists on disk.
List<String> checkTreePaths(String content, {String filename = 'AGENTS.md', String repoRoot = '.'}) {
  final problems = <String>[];
  final lines = content.split('\n');

  var inTree = false;
  final stack = <String>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed == '```text') {
      inTree = true;
      stack.clear();
      continue;
    } else if (inTree && trimmed == '```') {
      inTree = false;
      stack.clear();
      continue;
    }

    if (!inTree || trimmed.isEmpty) continue;

    // First line of tree is root directory (e.g. vtt_ruleset_dnd5e/)
    if (stack.isEmpty) {
      stack.add('');
      continue;
    }

    // Determine indentation depth
    // Tree prefixes use characters: ├──, └──, │, and spaces, in multiples of 4 columns
    final branchMatch = RegExp(r'^(.*?)(?:├──|└──)\s*').firstMatch(line);
    if (branchMatch == null) continue;

    final prefix = branchMatch.group(0)!;
    final depth = prefix.length ~/ 4;

    // Extract path component up to comment '#' or end of string
    final rest = line.substring(prefix.length);
    final commentIdx = rest.indexOf('#');
    final rawPath = (commentIdx == -1 ? rest : rest.substring(0, commentIdx)).trim();
    if (rawPath.isEmpty) continue;

    final cleanName = rawPath.endsWith('/') ? rawPath.substring(0, rawPath.length - 1) : rawPath;

    while (stack.length > depth) {
      stack.removeLast();
    }

    final parent = stack.isNotEmpty ? stack.last : '';
    final fullPath = parent.isEmpty ? cleanName : '$parent/$cleanName';
    stack.add(fullPath);

    final diskPath = repoRoot == '.' ? fullPath : '$repoRoot/$fullPath';
    if (!Directory(diskPath).existsSync() && !File(diskPath).existsSync()) {
      problems.add('$filename:${i + 1}: path does not exist: $fullPath');
    }
  }

  return problems;
}

/// Checks that every UpperCamelCase identifier inside tree comments or backtick spans
/// is declared in the ruleset's lib/ or pinned core's lib/.
Future<List<String>> checkTypeNames(
  String content, {
  String filename = 'AGENTS.md',
  Set<String>? declaredTypesOverride,
}) async {
  final declaredTypes = declaredTypesOverride ?? await getDeclaredTypes();
  final problems = <String>[];
  final lines = content.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Check tree comment
    if (line.contains('├──') || line.contains('└──') || line.contains('│')) {
      final commentIdx = line.indexOf('#');
      if (commentIdx != -1) {
        final comment = line.substring(commentIdx + 1);
        _scanForIdentifiers(comment, filename, i + 1, declaredTypes, problems);
      }
    }

    // Check backtick spans
    final backtickRegex = RegExp(r'`([^`]+)`');
    for (final match in backtickRegex.allMatches(line)) {
      final span = match.group(1)!;
      _scanForIdentifiers(span, filename, i + 1, declaredTypes, problems);
    }
  }

  return problems;
}

void _scanForIdentifiers(
  String text,
  String filename,
  int lineNum,
  Set<String> declaredTypes,
  List<String> problems,
) {
  final tokenRegex = RegExp(r'\b[A-Za-z0-9_$]+\b');
  for (final match in tokenRegex.allMatches(text)) {
    final word = match.group(0)!;
    if (_isUpperCamelCaseWithMultipleParts(word)) {
      if (!declaredTypes.contains(word)) {
        problems.add('$filename:$lineNum: undeclared type identifier: $word');
      }
    }
  }
}

bool _isUpperCamelCaseWithMultipleParts(String word) {
  if (!RegExp(r'[a-z]').hasMatch(word)) return false;
  return RegExp(r'^[A-Z][a-z0-9]*(?:[A-Z][a-z0-9]*)+$').hasMatch(word);
}

/// Checks that every backtick span starting with lib/, test/, scripts/ or .github/ exists on disk.
List<String> checkPathSpans(String content, {String filename = 'AGENTS.md', String repoRoot = '.'}) {
  final problems = <String>[];
  final lines = content.split('\n');
  final backtickRegex = RegExp(r'`([^`]+)`');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final match in backtickRegex.allMatches(line)) {
      final span = match.group(1)!;
      if (span.startsWith('lib/') ||
          span.startsWith('test/') ||
          span.startsWith('scripts/') ||
          span.startsWith('.github/')) {
        // Strip trailing slash if any
        final cleanSpan = span.endsWith('/') ? span.substring(0, span.length - 1) : span;
        final diskPath = repoRoot == '.' ? cleanSpan : '$repoRoot/$cleanSpan';
        if (!Directory(diskPath).existsSync() && !File(diskPath).existsSync()) {
          problems.add('$filename:${i + 1}: backtick path does not exist: $span');
        }
      }
    }
  }

  return problems;
}

/// Extracts all declared type names across ruleset lib/ and pinned core lib/.
Future<Set<String>> getDeclaredTypes() async {
  final types = <String>{};
  final declRegex = RegExp(
    r'\b(?:class|enum|mixin|extension\s+type|extension|typedef)\s+([A-Za-z0-9_$]+)',
  );

  // 1. Ruleset lib/
  final rulesetLib = Directory('lib');
  if (rulesetLib.existsSync()) {
    for (final entity in rulesetLib.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final text = entity.readAsStringSync();
        for (final m in declRegex.allMatches(text)) {
          types.add(m.group(1)!);
        }
      }
    }
  }

  // 2. Core lib/
  final coreUri = await Isolate.resolvePackageUri(
    Uri.parse('package:vtt_engine_core/vtt_engine_core.dart'),
  );
  if (coreUri != null) {
    final coreLib = Directory.fromUri(coreUri).parent;
    for (final entity in coreLib.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final text = entity.readAsStringSync();
        for (final m in declRegex.allMatches(text)) {
          types.add(m.group(1)!);
        }
      }
    }
  }

  return types;
}

void main() {
  test('DT1: Every path in AGENTS.md fenced tree blocks exists', () {
    final content = File('AGENTS.md').readAsStringSync();
    final problems = checkTreePaths(content);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('DT2: Every UpperCamelCase identifier in tree comments or backticks exists in lib/', () async {
    final agentsContent = File('AGENTS.md').readAsStringSync();
    final agentsProblems = await checkTypeNames(agentsContent, filename: 'AGENTS.md');

    final rulesContent = File('.antigravityrules').readAsStringSync();
    final rulesProblems = await checkTypeNames(rulesContent, filename: '.antigravityrules');

    final allProblems = [...agentsProblems, ...rulesProblems];
    expect(allProblems, isEmpty, reason: allProblems.join('\n'));
  });

  test('DT3: Every backtick span starting with lib/, test/, scripts/, or .github/ exists', () {
    final agentsContent = File('AGENTS.md').readAsStringSync();
    final agentsProblems = checkPathSpans(agentsContent, filename: 'AGENTS.md');

    final rulesContent = File('.antigravityrules').readAsStringSync();
    final rulesProblems = checkPathSpans(rulesContent, filename: '.antigravityrules');

    final allProblems = [...agentsProblems, ...rulesProblems];
    expect(allProblems, isEmpty, reason: allProblems.join('\n'));
  });

  test('DT4: Control: in-memory document with bad tree line and bad backtick path fails', () async {
    const mockDoc = '''
# Mock Documentation
```text
vtt_ruleset_dnd5e/
├── lib/
│   └── src/
│       ├── no_such/   # NoSuchEngine
```
Here is a test: `test/no_such_test.dart`
''';

    final treeProblems = checkTreePaths(mockDoc, filename: 'mock.md');
    final typeProblems = await checkTypeNames(
      mockDoc,
      filename: 'mock.md',
      declaredTypesOverride: {'RealType'},
    );
    final pathProblems = checkPathSpans(mockDoc, filename: 'mock.md');

    final allProblems = [...treeProblems, ...typeProblems, ...pathProblems];
    expect(allProblems, hasLength(3));
    expect(treeProblems.single, contains('no_such'));
    expect(typeProblems.single, contains('NoSuchEngine'));
    expect(pathProblems.single, contains('test/no_such_test.dart'));
  });
}
