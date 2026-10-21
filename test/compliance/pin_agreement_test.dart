import 'dart:io';
import 'package:test/test.dart';

List<String> checkRulesetCorePin(String pubspecYamlContent) {
  final lines = pubspecYamlContent.split('\n');
  final problems = <String>[];

  bool inDependencyOverrides = false;
  bool inDependencies = false;
  bool inVttEngineCore = false;
  bool isGit = false;
  String? ref;

  for (final rawLine in lines) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    // Check top-level sections (0 indentation)
    if (!rawLine.startsWith(' ') && !rawLine.startsWith('\t')) {
      if (trimmed.startsWith('dependency_overrides:')) {
        inDependencyOverrides = true;
        inDependencies = false;
      } else if (trimmed.startsWith('dependencies:')) {
        inDependencies = true;
        inDependencyOverrides = false;
      } else {
        inDependencyOverrides = false;
        inDependencies = false;
      }
      inVttEngineCore = false;
      continue;
    }

    if (inDependencyOverrides) {
      if (trimmed.startsWith('vtt_engine_core:')) {
        problems.add('dependency_overrides must not contain vtt_engine_core');
      }
    } else if (inDependencies) {
      // Indented under dependencies
      if (rawLine.startsWith('  ') && !rawLine.startsWith('    ')) {
        if (trimmed.startsWith('vtt_engine_core:')) {
          inVttEngineCore = true;
        } else {
          inVttEngineCore = false;
        }
      } else if (inVttEngineCore) {
        if (trimmed.startsWith('git:')) {
          isGit = true;
        }
        if (trimmed.startsWith('ref:')) {
          ref = trimmed.substring('ref:'.length).trim().replaceAll('"', '').replaceAll("'", '');
        }
      }
    }
  }

  if (!isGit) {
    problems.add('vtt_engine_core must be specified as a git dependency');
  }

  if (ref == null) {
    problems.add('vtt_engine_core git dependency must specify a ref');
  } else {
    final hexRegex = RegExp(r'^[0-9a-f]{40}$');
    if (!hexRegex.hasMatch(ref)) {
      problems.add('vtt_engine_core ref must be a 40-character lowercase SHA, got: $ref');
    }
  }

  return problems;
}

void main() {
  group('Ruleset Core Pin Compliance Tests', () {
    test('live pubspec.yaml pins vtt_engine_core to 40-character lowercase SHA with no overrides', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml must exist');
      final content = pubspecFile.readAsStringSync();
      final problems = checkRulesetCorePin(content);
      expect(problems, isEmpty, reason: 'Expected zero problems, but found: ${problems.join('; ')}');
    });

    test('negative case: ref with a branch name is rejected', () {
      const invalidYaml = '''
name: vtt_ruleset_dnd5e
dependencies:
  vtt_engine_core:
    git:
      url: https://github.com/kevinburkeland/vtt-engine-core.git
      ref: main
''';
      final problems = checkRulesetCorePin(invalidYaml);
      expect(problems, isNotEmpty);
      expect(
        problems.any((p) => p.contains('40-character lowercase SHA') && p.contains('main')),
        isTrue,
      );
    });

    test('negative case: dependency_overrides naming vtt_engine_core is rejected', () {
      const invalidYaml = '''
name: vtt_ruleset_dnd5e
dependencies:
  vtt_engine_core:
    git:
      url: https://github.com/kevinburkeland/vtt-engine-core.git
      ref: 0be55e80d1f4a862d386777fbd0df85f1aafd8e3
dependency_overrides:
  vtt_engine_core:
    path: ../vtt-engine-core
''';
      final problems = checkRulesetCorePin(invalidYaml);
      expect(problems, isNotEmpty);
      expect(
        problems.any((p) => p.contains('dependency_overrides must not contain vtt_engine_core')),
        isTrue,
      );
    });
  });
}
