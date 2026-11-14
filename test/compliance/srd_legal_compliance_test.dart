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

void main() {
  group('SRD Legal & Clean-Room Compliance Tests', () {
    test('Ensures production files in lib/ contain zero non-SRD or Product Identity terms from compliance/srd_denylist.txt', () {
      final denylistFile = File('compliance/srd_denylist.txt');
      expect(denylistFile.existsSync(), isTrue, reason: 'compliance/srd_denylist.txt must exist');
      final bannedTerms = denylistFile
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .map((term) => (term: term, words: _splitWords(term)))
          .toList();

      final libDir = Directory('lib');
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
              violations.add('${file.path}:$lineNo contains banned term "${entry.term}"');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'vtt_ruleset_dnd5e must strictly respect SRD clean-room boundaries:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
