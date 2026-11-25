import 'dart:io';
import 'package:test/test.dart';

/// Strips `//` line comments, `/* ... */` block comments, and string literals
/// from Dart source so keyword scans inspect only executable/declaration tokens.
String stripDartCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      i += 2;
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < n && !(source[i] == '*' && source[i + 1] == '/')) {
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple = i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      i += isTriple ? 3 : 1;
      while (i < n) {
        if (source[i] == r'\' && i + 1 < n) {
          i += 2;
          continue;
        }
        if (isTriple) {
          if (i + 2 < n &&
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

final _dynamicTokenPattern = RegExp(r'\bdynamic\b');

List<String> findDynamicViolations(String source) {
  final stripped = stripDartCommentsAndStrings(source);
  final lines = stripped.split('\n');
  final violations = <String>[];
  for (var idx = 0; idx < lines.length; idx++) {
    if (_dynamicTokenPattern.hasMatch(lines[idx])) {
      violations.add('line ${idx + 1}: ${lines[idx].trim()}');
    }
  }
  return violations;
}

void main() {
  group('Fix 5.1 compliance bar: Dnd5eCatalog declares no dynamic', () {
    test('controls: dynamic in declaration fails; dynamic in comment passes', () {
      const bad = '''
abstract interface class Dnd5eCatalog {
  dynamic findFeat(String slug);
}
''';
      const goodComment = '''
// No dynamic is allowed in Dnd5eCatalog.
abstract interface class Dnd5eCatalog {
  Object? findFeat(String slug);
}
''';
      expect(findDynamicViolations(bad), isNotEmpty);
      expect(findDynamicViolations(goodComment), isEmpty);
    });

    test('real bar: lib/src/catalog/dnd5e_catalog.dart declares zero dynamic tokens',
        () {
      final file = File('lib/src/catalog/dnd5e_catalog.dart');
      expect(file.existsSync(), isTrue);
      final violations = findDynamicViolations(file.readAsStringSync());
      expect(
        violations,
        isEmpty,
        reason:
            'lib/src/catalog/dnd5e_catalog.dart must not declare dynamic:\n${violations.join('\n')}',
      );
    });
  });
}
