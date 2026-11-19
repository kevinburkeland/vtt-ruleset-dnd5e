import 'dart:io';

import 'package:test/test.dart';

/// Replaces Dart comments and string literals with spaces while preserving
/// exact character offsets and newlines so line numbers stay exact.
String _maskCommentsAndStrings(String source) {
  final out = StringBuffer();
  final len = source.length;
  var i = 0;

  void writeMasked(int start, int end) {
    for (var k = start; k < end; k++) {
      out.write(source[k] == '\n' ? '\n' : ' ');
    }
  }

  while (i < len) {
    final c = source[i];
    final next = i + 1 < len ? source[i + 1] : '';
    if (c == 'r' && (next == "'" || next == '"')) {
      final quote = next;
      final isTriple =
          i + 3 < len && source[i + 2] == quote && source[i + 3] == quote;
      final start = i;
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
        i++;
      }
      writeMasked(start, i);
      continue;
    }
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple =
          i + 2 < len && source[i + 1] == quote && source[i + 2] == quote;
      final start = i;
      i += isTriple ? 3 : 1;
      while (i < len) {
        if (source[i] == '\\') {
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
        i++;
      }
      writeMasked(start, i);
      continue;
    }
    if (c == '/' && next == '/') {
      final start = i;
      i += 2;
      while (i < len && source[i] != '\n') {
        i++;
      }
      writeMasked(start, i);
      continue;
    }
    if (c == '/' && next == '*') {
      final start = i;
      i += 2;
      while (i + 1 < len && !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i = i + 2 <= len ? i + 2 : len;
      writeMasked(start, i);
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

int _lineNumberAt(String text, int offset) {
  var line = 1;
  for (var i = 0; i < offset && i < text.length; i++) {
    if (text.codeUnitAt(i) == 10) line++;
  }
  return line;
}

/// Finds the index of the matching `)` for an opening `(` at [openParenIndex],
/// or `text.length` if unbalanced.
int _findMatchingParen(String text, int openParenIndex) {
  var depth = 0;
  for (var i = openParenIndex; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code == 40) {
      depth++;
    } else if (code == 41) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return text.length;
}

/// Scans [source] (comments and strings masked while keeping exact line numbers)
/// for runtime super-member conversions, including inside closures passed to
/// methods called on `super.<name>`.
///
/// Every violation is formatted as `path:line: <label> -> <matched text>`.
List<String> scanSuperConversions(String path, String source) {
  final masked = _maskCommentsAndStrings(source);
  final violations = <String>[];

  void addHit(int offset, String label, String rawMatch) {
    final line = _lineNumberAt(masked, offset);
    final compact = rawMatch.replaceAll(RegExp(r'\s+'), ' ').trim();
    violations.add('$path:$line: $label -> $compact');
  }

  final patterns = <(String, RegExp)>[
    ('super.<name> is', RegExp(r'\bsuper\.[A-Za-z_][A-Za-z0-9_]*\s+is\b')),
    ('super.<name> as', RegExp(r'\bsuper\.[A-Za-z_][A-Za-z0-9_]*\s+as\b')),
    ('.fromMap(super.', RegExp(r'\.fromMap\s*\(\s*super\.')),
    (
      'fromMap(super.<name>',
      RegExp(r'\bfromMap\s*\([^;{}]*\bsuper\.[A-Za-z_][A-Za-z0-9_]*'),
    ),
  ];

  for (final (label, re) in patterns) {
    for (final m in re.allMatches(masked)) {
      addHit(m.start, label, m.group(0)!);
    }
  }

  // Scan closures passed to method calls rooted at `super.<name>`, e.g.:
  //   super.inventory.map((i) => i is T ? i : T.fromMap(i.toMap()))
  //   super.resources.where((r) => r as Object? != null)
  final superClosureRe = RegExp(
    r'\bsuper\.[A-Za-z_][A-Za-z0-9_]*(?:\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*\s*\(\s*\(([^)]*)\)\s*(?:=>|\{)',
  );

  for (final m in superClosureRe.allMatches(masked)) {
    final openCallParen = masked.indexOf('(', m.start);
    if (openCallParen < 0) continue;
    final closeCallParen = _findMatchingParen(masked, openCallParen);
    final bodyStart = m.end;
    if (bodyStart >= closeCallParen) continue;

    final rawParams = m.group(1) ?? '';
    final paramNames = <String>[];
    for (final raw in rawParams.split(',')) {
      final tokens = raw
          .replaceAll(RegExp(r'[\[\]{}=].*'), '')
          .trim()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      if (tokens.isNotEmpty) {
        final name = tokens.last;
        if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
          paramNames.add(name);
        }
      }
    }
    if (paramNames.isEmpty) continue;

    final body = masked.substring(bodyStart, closeCallParen);
    for (final p in paramNames) {
      final esc = RegExp.escape(p);
      final closurePatterns = <(String, RegExp)>[
        ('super closure $p is', RegExp('\\b$esc\\s+is\\b')),
        ('super closure $p as', RegExp('\\b$esc\\s+as\\b')),
        (
          'super closure .fromMap($p)',
          RegExp('\\.fromMap\\s*\\([^;{}]*\\b$esc\\b'),
        ),
        (
          'super closure fromMap($p)',
          RegExp('(?<!\\.)\\bfromMap\\s*\\([^;{}]*\\b$esc\\b'),
        ),
      ];
      for (final (label, re) in closurePatterns) {
        for (final hit in re.allMatches(body)) {
          addHit(bodyStart + hit.start, label, hit.group(0)!);
        }
      }
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

    test('controls (Fix 4.3): flags closures on super.<name> with exact line numbers, ignores unrelated casts and strings', () {
      const closureBoth = '''
  List<T> get items => super.inventory.map((i) => i is T ? i : T.fromMap(i.toMap())).toList();
''';
      final closureHits = scanSuperConversions('closure.dart', closureBoth);
      expect(closureHits, isNotEmpty);
      expect(
        closureHits.any((h) => h.startsWith('closure.dart:1:') && h.contains('is')),
        isTrue,
        reason: 'Expected line 1 is-check hit in: $closureHits',
      );
      expect(
        closureHits.any((h) => h.startsWith('closure.dart:1:') && h.contains('fromMap')),
        isTrue,
        reason: 'Expected line 1 fromMap hit in: $closureHits',
      );

      const whereAs = '''
  Iterable<Object?> get res => super.resources.where((r) => r as Object? != null);
''';
      final whereHits = scanSuperConversions('where_as.dart', whereAs);
      expect(whereHits, isNotEmpty);
      expect(
        whereHits.any((h) => h.startsWith('where_as.dart:1:') && h.contains('as')),
        isTrue,
        reason: 'Expected line 1 as-cast hit in: $whereHits',
      );

      const multiLineClosure =
          '  final x = super.inventory\n'
          '    .map((i) =>\n'
          '        i as InventoryItemInstance);\n';
      final mlHits = scanSuperConversions('multiline.dart', multiLineClosure);
      expect(mlHits, isNotEmpty);
      expect(
        mlHits.any((h) => h.startsWith('multiline.dart:3:') && h.contains('i as')),
        isTrue,
        reason: 'Expected line 3 hit for i as in: $mlHits',
      );

      const unrelatedCast = '''
  @override
  Map<String, dynamic> toMap() {
    final base = super.toMap();
    return {...base, 'a': other as int};
  }
''';
      expect(scanSuperConversions('unrelated.dart', unrelatedCast), isEmpty);

      const insideString = '''
  const s = 'super.inventory.map((i) => i is T ? i : T.fromMap(i.toMap()))';
  const s2 = "super.resources is CharacterResourcePool";
''';
      expect(scanSuperConversions('string_only.dart', insideString), isEmpty);
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
