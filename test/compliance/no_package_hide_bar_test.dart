import 'dart:io';

import 'package:test/test.dart';

/// Scans Dart source for `import` / `export` directives targeting
/// `package:vtt_engine_core/...` or `package:vtt_ruleset_dnd5e/...` that carry
/// a `hide` combinator (including multi-line directives and `as prefix hide`).
List<String> findForbiddenPackageHideViolations(
  String relativePath,
  String source,
) {
  final violations = <String>[];
  final lines = source.split('\n');

  // Strip comments while preserving newlines so line numbers remain exact.
  final buf = StringBuffer();
  var i = 0;
  final len = source.length;
  while (i < len) {
    final c = source[i];
    final next = i + 1 < len ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < len && source[i] != '\n') {
        i++;
      }
      continue;
    }
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
          if (source[i] == '\n') buf.write('\n');
          i++;
        }
      }
      continue;
    }
    buf.write(c);
    i++;
  }
  final cleaned = buf.toString();

  // Only inspect the directive preamble at the top of the file (Dart grammar
  // forbids import/export directives after any top-level declaration), so
  // string literals inside functions/tests are never mistaken for directives.
  final preambleBuf = StringBuffer();
  var inDirective = false;
  var pastPreamble = false;
  for (final line in cleaned.split('\n')) {
    if (pastPreamble) break;
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      preambleBuf.writeln();
      continue;
    }
    if (inDirective) {
      preambleBuf.writeln(line);
      if (trimmed.contains(';')) inDirective = false;
      continue;
    }
    if (trimmed.startsWith('library ') ||
        trimmed.startsWith('library;') ||
        trimmed.startsWith('import ') ||
        trimmed.startsWith('export ') ||
        trimmed.startsWith('part ') ||
        trimmed.startsWith('@')) {
      preambleBuf.writeln(line);
      if (!trimmed.startsWith('@') && !trimmed.contains(';')) {
        inDirective = true;
      }
    } else {
      pastPreamble = true;
    }
  }
  final preamble = preambleBuf.toString();

  final directiveRe = RegExp(
    r'''(?:^|\n)[ \t]*(import|export)\s+(['"])(package:(?:vtt_engine_core|vtt_ruleset_dnd5e)/[^'"]+)\2([^;]*);''',
    multiLine: true,
    dotAll: true,
  );
  final hideRe = RegExp(
    r'\bhide\s+([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)',
    dotAll: true,
  );

  for (final m in directiveRe.allMatches(preamble)) {
    final uri = m.group(3)!;
    final tail = m.group(4) ?? '';
    final hideMatch = hideRe.firstMatch(tail);
    if (hideMatch != null) {
      final matchStart = m.start + (preamble[m.start] == '\n' ? 1 : 0);
      final lineNum = '\n'.allMatches(preamble.substring(0, matchStart)).length + 1;
      final hiddenNames = hideMatch
          .group(1)!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      violations.add('$relativePath:$lineNum: hides $hiddenNames from $uri');
    }
  }

  // Sanity guard so unused variable warning never triggers
  if (lines.isEmpty) return violations;
  return violations;
}

void main() {
  group('Fix 7.2: No hide of a core or ruleset package name', () {
    const allowedFiles = <String>{};

    test('Controls: flags single-line, multi-line, and aliased hide; allows show', () {
      const singleLine =
          "import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character;\n";
      expect(
        findForbiddenPackageHideViolations('lib/a.dart', singleLine),
        ['lib/a.dart:1: hides Character from package:vtt_engine_core/vtt_engine_core.dart'],
      );

      const multiLine = '''
import 'package:vtt_engine_core/vtt_engine_core.dart'
  hide
    Character,
    EntityType;
''';
      expect(
        findForbiddenPackageHideViolations('lib/b.dart', multiLine),
        ['lib/b.dart:1: hides Character, EntityType from package:vtt_engine_core/vtt_engine_core.dart'],
      );

      const aliasedHide =
          "import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart' as rules hide Foo;\n";
      expect(
        findForbiddenPackageHideViolations('lib/c.dart', aliasedHide),
        ['lib/c.dart:1: hides Foo from package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart'],
      );

      const allowedShow =
          "import 'package:vtt_engine_core/vtt_engine_core.dart' show EntityId;\n";
      expect(
        findForbiddenPackageHideViolations('lib/d.dart', allowedShow),
        isEmpty,
      );
    });

    test('No import or export of vtt_engine_core or vtt_ruleset_dnd5e in lib/ or test/ uses hide', () {
      expect(allowedFiles, isEmpty);
      final violations = <String>[];
      for (final root in ['lib', 'test']) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        final files = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final f in files) {
          final rel = f.path.replaceAll('\\', '/');
          violations.addAll(
            findForbiddenPackageHideViolations(rel, f.readAsStringSync()),
          );
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden hide combinators found:\n${violations.join('\n')}',
      );
    });
  });
}
