import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Strips Dart line comments, block comments, and string literals while
/// preserving line breaks so regexes only inspect real Dart tokens.
String _stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  final len = source.length;
  var i = 0;

  while (i < len) {
    final c = source[i];
    final next = i + 1 < len ? source[i + 1] : '';

    // Line comment
    if (c == '/' && next == '/') {
      while (i < len && source[i] != '\n') {
        i++;
      }
      continue;
    }

    // Block comment (nestable in Dart)
    if (c == '/' && next == '*') {
      var depth = 1;
      i += 2;
      while (i < len && depth > 0) {
        if (source[i] == '/' && i + 1 < len && source[i + 1] == '*') {
          depth++;
          i += 2;
        } else if (source[i] == '*' && i + 1 < len && source[i + 1] == '/') {
          depth--;
          i += 2;
        } else {
          if (source[i] == '\n') out.write('\n');
          i++;
        }
      }
      continue;
    }

    // Raw string r'...' r"..." r'''...''' r"""..."""
    if (c == 'r' && (next == "'" || next == '"')) {
      final quote = next;
      final isTriple = i + 3 < len &&
          source[i + 2] == quote &&
          source[i + 3] == quote;
      i += isTriple ? 4 : 2;
      while (i < len) {
        if (isTriple) {
          if (i + 2 < len &&
              source[i] == quote &&
              source[i + 1] == quote &&
              source[i + 2] == quote) {
            i += 3;
            break;
          }
        } else if (source[i] == quote) {
          i++;
          break;
        }
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      out.write(' ');
      continue;
    }

    // Regular string '...' "..." '''...''' """..."""
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple = i + 2 < len &&
          source[i + 1] == quote &&
          source[i + 2] == quote;
      i += isTriple ? 3 : 1;
      while (i < len) {
        if (source[i] == r'\') {
          i += 2;
          continue;
        }
        if (isTriple) {
          if (i + 2 < len &&
              source[i] == quote &&
              source[i + 1] == quote &&
              source[i + 2] == quote) {
            i += 3;
            break;
          }
        } else if (source[i] == quote) {
          i++;
          break;
        }
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      out.write(' ');
      continue;
    }

    out.write(c);
    i++;
  }

  return out.toString();
}

/// Collects public top-level declared type names from a Dart source file.
/// Recognizes `class` (with any class modifiers), `mixin`, `enum`, named
/// `extension`, `extension type`, and `typedef`. Ignores private `_...` names.
Set<String> extractTopLevelDeclaredTypeNames(String source) {
  final cleaned = _stripCommentsAndStrings(source);
  final names = <String>{};

  // Walk top-level only (brace depth 0) to avoid picking up local declarations.
  final topLevel = StringBuffer();
  var depth = 0;
  for (var i = 0; i < cleaned.length; i++) {
    final ch = cleaned[i];
    if (ch == '{') {
      if (depth == 0) topLevel.write(' ');
      depth++;
    } else if (ch == '}') {
      if (depth > 0) depth--;
    } else if (depth == 0) {
      topLevel.write(ch);
    }
  }

  final text = topLevel.toString();

  final declRegex = RegExp(
    r'(?:^|[\n;])\s*'
    r'(?:(?:abstract|base|interface|final|sealed|mixin)\s+)*'
    r'(?:(class|mixin|enum|typedef)\s+([A-Za-z_][A-Za-z0-9_]*)'
    r'|extension\s+type\s+(?:const\s+)?([A-Za-z_][A-Za-z0-9_]*)'
    r'|extension\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>]*>)?\s+on\b)',
  );

  for (final m in declRegex.allMatches(text)) {
    final name = m.group(2) ?? m.group(3) ?? m.group(4);
    if (name == null || name.startsWith('_')) continue;
    names.add(name);
  }

  return names;
}

Map<String, String> _collectPackageTypes(Directory libDir) {
  final map = <String, String>{};
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final rel = file.path
        .replaceAll('\\', '/')
        .substring(libDir.path.replaceAll('\\', '/').length)
        .replaceFirst(RegExp(r'^/+'), 'lib/');
    for (final name in extractTopLevelDeclaredTypeNames(file.readAsStringSync())) {
      map.putIfAbsent(name, () => rel);
    }
  }
  return map;
}

Directory _resolvePackageLibDir(String packageName) {
  final configFile = File('.dart_tool/package_config.json');
  if (!configFile.existsSync()) {
    throw StateError(
      'Fail-closed: .dart_tool/package_config.json not found; cannot locate $packageName.',
    );
  }
  final decoded = jsonDecode(configFile.readAsStringSync());
  if (decoded is! Map<String, dynamic> || decoded['packages'] is! List) {
    throw StateError(
      'Fail-closed: malformed .dart_tool/package_config.json.',
    );
  }
  final configDir = configFile.parent.uri;
  for (final entry in decoded['packages'] as List<dynamic>) {
    if (entry is Map<String, dynamic> && entry['name'] == packageName) {
      final rootUriStr = entry['rootUri'] as String?;
      final pkgUriStr = (entry['packageUri'] as String?) ?? 'lib/';
      if (rootUriStr == null) break;
      final rootUri = configDir.resolve(rootUriStr.endsWith('/') ? rootUriStr : '$rootUriStr/');
      final libUri = rootUri.resolve(pkgUriStr);
      final dir = Directory.fromUri(libUri);
      if (!dir.existsSync()) {
        throw StateError(
          'Fail-closed: resolved $packageName lib directory does not exist: ${dir.path}',
        );
      }
      return dir;
    }
  }
  throw StateError(
    'Fail-closed: package $packageName not found in .dart_tool/package_config.json.',
  );
}

List<String> findSharedTypeNameViolations({
  required Map<String, String> coreTypes,
  required Map<String, String> rulesetTypes,
}) {
  final shared = coreTypes.keys.toSet().intersection(rulesetTypes.keys.toSet()).toList()
    ..sort();
  return [
    for (final name in shared)
      '$name: declared in core ${coreTypes[name]} and ruleset ${rulesetTypes[name]}',
  ];
}

void main() {
  group('Fix 7.1: One name, one type across core and ruleset', () {
    test('Controls: flags duplicate class/typedef/enum, ignores private and comments/strings', () {
      // 1. Duplicate class
      final c1 = extractTopLevelDeclaredTypeNames('class ZzSame {}');
      final r1 = extractTopLevelDeclaredTypeNames('final class ZzSame {}');
      expect(
        findSharedTypeNameViolations(
          coreTypes: {for (final n in c1) n: 'lib/a.dart'},
          rulesetTypes: {for (final n in r1) n: 'lib/b.dart'},
        ),
        ['ZzSame: declared in core lib/a.dart and ruleset lib/b.dart'],
      );

      // 2. typedef vs enum
      final c2 = extractTopLevelDeclaredTypeNames('typedef ZzSame = int;');
      final r2 = extractTopLevelDeclaredTypeNames('enum ZzSame { a }');
      expect(
        findSharedTypeNameViolations(
          coreTypes: {for (final n in c2) n: 'lib/a.dart'},
          rulesetTypes: {for (final n in r2) n: 'lib/b.dart'},
        ),
        ['ZzSame: declared in core lib/a.dart and ruleset lib/b.dart'],
      );

      // 3. Private name in both is ignored
      final c3 = extractTopLevelDeclaredTypeNames('class _ZzPrivate {}');
      final r3 = extractTopLevelDeclaredTypeNames('class _ZzPrivate {}');
      expect(
        findSharedTypeNameViolations(
          coreTypes: {for (final n in c3) n: 'lib/a.dart'},
          rulesetTypes: {for (final n in r3) n: 'lib/b.dart'},
        ),
        isEmpty,
      );

      // 4. Name inside comment or string is ignored
      const commentAndString = '''
// class ZzGhost {}
/* enum ZzGhost2 { a } */
const s = "class ZzGhost3 {}";
const r = r'typedef ZzGhost4 = int;';
''';
      expect(extractTopLevelDeclaredTypeNames(commentAndString), isEmpty);
    });

    test('No public top-level type name is declared in both vtt_engine_core and vtt_ruleset_dnd5e', () {
      final coreLibDir = _resolvePackageLibDir('vtt_engine_core');
      final rulesetLibDir = Directory('lib');
      expect(rulesetLibDir.existsSync(), isTrue);

      final coreTypes = _collectPackageTypes(coreLibDir);
      final rulesetTypes = _collectPackageTypes(rulesetLibDir);
      expect(coreTypes, isNotEmpty);
      expect(rulesetTypes, isNotEmpty);

      final violations = findSharedTypeNameViolations(
        coreTypes: coreTypes,
        rulesetTypes: rulesetTypes,
      );
      expect(
        violations,
        isEmpty,
        reason: 'Shared top-level type names across core and ruleset:\n${violations.join('\n')}',
      );
    });
  });
}
