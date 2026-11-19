import 'dart:io';

import 'package:test/test.dart';

/// Strips Dart comments while keeping newlines for readability.
String _stripComments(String source) {
  final out = StringBuffer();
  final len = source.length;
  var i = 0;
  while (i < len) {
    final c = source[i];
    final next = i + 1 < len ? source[i + 1] : '';
    if (c == 'r' && (next == "'" || next == '"')) {
      final quote = next;
      final isTriple = i + 3 < len && source[i + 2] == quote && source[i + 3] == quote;
      final start = i;
      i += isTriple ? 4 : 2;
      while (i < len) {
        if (isTriple) {
          if (i + 2 < len && source[i] == quote && source[i + 1] == quote && source[i + 2] == quote) {
            i += 3;
            break;
          }
        } else if (source[i] == quote) {
          i++;
          break;
        }
        i++;
      }
      out.write(source.substring(start, i));
      continue;
    }
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple = i + 2 < len && source[i + 1] == quote && source[i + 2] == quote;
      final start = i;
      i += isTriple ? 3 : 1;
      while (i < len) {
        if (source[i] == '\\') {
          i += 2;
          continue;
        }
        if (isTriple) {
          if (i + 2 < len && source[i] == quote && source[i + 1] == quote && source[i + 2] == quote) {
            i += 3;
            break;
          }
        } else if (source[i] == quote) {
          i++;
          break;
        }
        i++;
      }
      out.write(source.substring(start, i));
      continue;
    }
    if (c == '/' && next == '/') {
      i += 2;
      while (i < len && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < len && !(source[i] == '*' && source[i + 1] == '/')) {
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Scans [source] (comments stripped, whitespace normalised across line breaks)
/// for runtime super-member conversions:
/// - `super.<name> is ` / `super.<name> as `
/// - `fromMap(super.<name>` or `.fromMap(super.`
/// - `super.<name>` passed to `fromMap(` (e.g. `fromMap(super.foo.toMap())`)
List<String> scanSuperConversions(String path, String source) {
  final stripped = _stripComments(source);
  final normalized = stripped.replaceAll(RegExp(r'\s+'), ' ');
  final violations = <String>[];

  final patterns = <(String, RegExp)>[
    ('super.<name> is', RegExp(r'\bsuper\.[A-Za-z_][A-Za-z0-9_]*\s+is\b')),
    ('super.<name> as', RegExp(r'\bsuper\.[A-Za-z_][A-Za-z0-9_]*\s+as\b')),
    ('.fromMap(super.', RegExp(r'\.fromMap\s*\(\s*super\.')),
    ('fromMap(super.<name>', RegExp(r'\bfromMap\s*\([^;{}]*\bsuper\.[A-Za-z_][A-Za-z0-9_]*')),
  ];

  for (final (label, re) in patterns) {
    for (final m in re.allMatches(normalized)) {
      violations.add('$path: $label -> ${m.group(0)}');
    }
  }
  return violations;
}

void main() {
  group('Fix 8.3: No super.* runtime conversion bar', () {
    test('controls: flags multi-line super conversion getters and allows super.toMap()', () {
      const legacyGetter = '''
  @override
  CharacterResourcePool get resources =>
      super.resources
          is CharacterResourcePool
          ? super.resources
              as CharacterResourcePool
          : CharacterResourcePool.fromMap(
              super.resources.toMap());
''';
      final hits = scanSuperConversions('control_bad.dart', legacyGetter);
      expect(hits, isNotEmpty);
      expect(hits.any((h) => h.contains('super.<name> is')), isTrue);
      expect(hits.any((h) => h.contains('super.<name> as')), isTrue);
      expect(hits.any((h) => h.contains('.fromMap(super.')), isTrue);

      const cleanCall = '''
  @override
  Map<String, dynamic> toMap() {
    final base = super.toMap();
    return {...base, 'extra': 1};
  }
''';
      expect(scanSuperConversions('control_good.dart', cleanCall), isEmpty);

      const commentedOut = '''
  // super.resources is CharacterResourcePool ? super.resources as CharacterResourcePool : CharacterResourcePool.fromMap(super.resources.toMap())
  int ok() => 1;
''';
      expect(scanSuperConversions('control_comment.dart', commentedOut), isEmpty);
    });

    test('lib/src/models/ contains zero super.* runtime type checks, casts, or fromMap conversions', () {
      final dir = Directory('lib/src/models');
      expect(dir.existsSync(), isTrue);
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final violations = <String>[];
      for (final file in files) {
        violations.addAll(
          scanSuperConversions(file.path, file.readAsStringSync()),
        );
      }

      expect(
        violations,
        isEmpty,
        reason: 'Found super.* runtime conversions in lib/src/models/:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
