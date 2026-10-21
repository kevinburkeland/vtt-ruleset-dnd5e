import 'dart:io';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

List<String> checkRulesetCorePin(String pubspecYamlContent) {
  final yaml = loadYaml(pubspecYamlContent);
  if (yaml is! YamlMap) {
    return ['pubspec.yaml is not a valid YAML mapping'];
  }

  final problems = <String>[];

  // 1. Invariant: no dependency_overrides naming vtt_engine_core
  if (yaml.containsKey('dependency_overrides')) {
    final overrides = yaml['dependency_overrides'];
    if (overrides is YamlMap && overrides.containsKey('vtt_engine_core')) {
      problems.add('dependency_overrides must not contain vtt_engine_core');
    }
  }

  // 2. Invariant: vtt_engine_core is under dependencies
  final deps = yaml['dependencies'];
  if (deps is! YamlMap || !deps.containsKey('vtt_engine_core')) {
    problems.add('dependencies must contain vtt_engine_core');
    return problems;
  }

  final coreDep = deps['vtt_engine_core'];
  if (coreDep is! YamlMap || !coreDep.containsKey('git')) {
    problems.add('vtt_engine_core must be specified as a git dependency');
    return problems;
  }

  final git = coreDep['git'];
  if (git is! YamlMap || !git.containsKey('ref')) {
    problems.add('vtt_engine_core git dependency must specify a ref');
    return problems;
  }

  final ref = git['ref']?.toString();
  if (ref == null) {
    problems.add('vtt_engine_core ref cannot be null');
    return problems;
  }

  final hexRegex = RegExp(r'^[0-9a-f]{40}$');
  if (!hexRegex.hasMatch(ref)) {
    problems.add('vtt_engine_core ref must be a 40-character lowercase SHA, got: $ref');
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
