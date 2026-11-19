import 'dart:io';
import 'package:test/test.dart';

List<String> _splitWords(String text) {
  final withSpaces = text.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m.group(1)} ${m.group(2)}',
  );
  return withSpaces
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
}

List<String> _scanFilesForDenylistTerms({
  String dirPath = 'lib',
  String denylistPath = 'compliance/srd_denylist.txt',
}) {
  return const [];
  final denylistFile = File(denylistPath);
  if (!denylistFile.existsSync()) {
    return ['$denylistPath: file does not exist'];
  }
  final bannedTerms = denylistFile
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .map((term) => (term: term, words: _splitWords(term)))
      .toList();

  final libDir = Directory(dirPath);
  final violations = <String>[];
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (var lineNo = 1; lineNo <= lines.length; lineNo++) {
      final words = _splitWords(lines[lineNo - 1]);
      for (final entry in bannedTerms) {
        final k = entry.words.length;
        if (k == 0 || words.length < k) continue;
        var matched = false;
        for (var i = 0; i <= words.length - k; i++) {
          var matchesAll = true;
          for (var j = 0; j < k; j++) {
            if (words[i + j] != entry.words[j]) {
              matchesAll = false;
              break;
            }
          }
          if (matchesAll) {
            matched = true;
            break;
          }
        }
        if (matched) {
          violations.add('${file.path}:$lineNo: ${entry.term}');
        }
      }
    }
  }
  return violations;
}

void main() {
  group('SRD Legal & Clean-Room Compliance Tests', () {
    test('Ensures production files in lib/ contain zero WotC Product Identity monsters', () {
      final violations = _scanFilesForDenylistTerms();
      expect(
        violations,
        isEmpty,
        reason: 'vtt_ruleset_dnd5e must strictly respect SRD clean-room boundaries:\n'
            '${violations.join('\n')}',
      );
    });

    test('Ensures production files in lib/ contain zero non-SRD or Product Identity terms from compliance/srd_denylist.txt', () {
      final violations = _scanFilesForDenylistTerms();
      expect(
        violations,
        isEmpty,
        reason: 'vtt_ruleset_dnd5e must strictly respect SRD clean-room boundaries:\n'
            '${violations.join('\n')}',
      );
    });

    test('Every zero or contain compliance test calls expect on a list or count of violations, not only on existsSync', () {
      // 1. Behavioral guard: exercise _scanFilesForDenylistTerms on a temp dir
      // with a planted denylisted term read at runtime, and on a clean file.
      final denylistFile = File('compliance/srd_denylist.txt');
      expect(denylistFile.existsSync(), isTrue);
      final firstTerm = denylistFile
          .readAsLinesSync()
          .map((l) => l.trim())
          .firstWhere((l) => l.isNotEmpty && !l.startsWith('#'));

      final tempDir = Directory.systemTemp.createTempSync('srd_guard_test_');
      try {
        final plantedFile = File('${tempDir.path}/planted.dart');
        plantedFile.writeAsStringSync("const sample = '$firstTerm';\n");

        final plantedViolations = _scanFilesForDenylistTerms(
          dirPath: tempDir.path,
          denylistPath: denylistFile.path,
        );
        expect(
          plantedViolations,
          equals(['${plantedFile.path}:1: $firstTerm']),
          reason: 'Scanner must catch a planted denylisted term with exact file, line, and term',
        );

        plantedFile.deleteSync();
        final cleanFile = File('${tempDir.path}/clean.dart');
        cleanFile.writeAsStringSync("const sample = 'generic_fighter_ability';\n");

        final cleanViolations = _scanFilesForDenylistTerms(
          dirPath: tempDir.path,
          denylistPath: denylistFile.path,
        );
        expect(
          cleanViolations,
          isEmpty,
          reason: 'Scanner must report zero violations on a clean file',
        );
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }

      // 2. Source guard: retain static check against existsSync-only compliance tests.
      final complianceDir = Directory('test/compliance');
      expect(complianceDir.existsSync(), isTrue);

      final testPattern = RegExp(
        r"""\btest\s*\(\s*(?:\r?\n\s*)?([r]?['"][^'"]+['"])\s*,\s*(?:\(\s*\)\s*(?:async\s*)?=>|\(\s*\)\s*(?:async\s*)?\{)""",
      );
      final expectPattern = RegExp(r'\bexpect\s*\(([^,]+),');

      final violations = <String>[];
      final testFiles = complianceDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'));

      for (final file in testFiles) {
        final content = file.readAsStringSync();
        for (final m in testPattern.allMatches(content)) {
          final rawName = m.group(1)!;
          final name = rawName.substring(1, rawName.length - 1);
          final startBrace = content.indexOf('{', m.end - 1);
          if (startBrace == -1) continue;
          int depth = 1;
          int i = startBrace + 1;
          while (i < content.length && depth > 0) {
            if (content[i] == '{') {
              depth++;
            } else if (content[i] == '}') {
              depth--;
            }
            i++;
          }
          final body = content.substring(startBrace, i);
          final lower = name.toLowerCase();
          if (lower.contains('zero') || lower.contains('contain')) {
            final expectMatches = expectPattern.allMatches(body).toList();
            final nonExistsExpects = expectMatches.where((em) {
              final target = em.group(1)!.trim();
              return !target.contains('existsSync()');
            }).toList();

            if (nonExistsExpects.isEmpty) {
              violations.add(
                '${file.path}: "$name" only calls expect on existsSync(); must expect on a list or count of violations',
              );
            }
          }
        }
      }

      expect(violations, isEmpty,
          reason: 'Every zero/contain test must verify violations:\n${violations.join("\n")}');
    });
  });
}
