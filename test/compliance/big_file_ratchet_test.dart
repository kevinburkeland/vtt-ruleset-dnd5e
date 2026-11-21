import 'dart:io';

import 'package:test/test.dart';

const int kMaxAllowedLines = 1500;

/// Ruleset big-file allowlist: only `character_models.dart` is above 1,500 lines.
/// Grows -> fail; shrinks -> fail until lowered; <= 1,500 -> fail until removed.
const Map<String, int> kRulesetBigFileAllowlist = <String, int>{
  'lib/src/models/character_models.dart': 1742,
};

List<String> evaluateBigFileRatchet({
  required Map<String, int> actualLineCounts,
  required Map<String, int> allowlist,
  int limit = kMaxAllowedLines,
}) {
  final problems = <String>[];
  final sortedActual = actualLineCounts.keys.toList()..sort();

  for (final path in sortedActual) {
    final lines = actualLineCounts[path]!;
    final ceiling = allowlist[path];
    if (ceiling == null) {
      if (lines > limit) {
        problems.add(
          '$path has $lines lines (limit $limit, not on allowlist)',
        );
      }
    } else {
      if (lines > ceiling) {
        problems.add(
          '$path grew to $lines lines (allowlist ceiling $ceiling)',
        );
      } else if (lines <= limit) {
        problems.add(
          '$path shrank to $lines lines (<= $limit); remove it from the allowlist',
        );
      } else if (lines < ceiling) {
        problems.add(
          '$path shrank to $lines lines (allowlist ceiling $ceiling); lower its ceiling',
        );
      }
    }
  }

  final sortedAllowlist = allowlist.keys.toList()..sort();
  for (final path in sortedAllowlist) {
    if (!actualLineCounts.containsKey(path)) {
      problems.add('$path is on the allowlist but does not exist');
    }
  }

  return problems;
}

Map<String, int> _collectLibLineCounts() {
  final counts = <String, int>{};
  final libDir = Directory('lib');
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final path = entity.path.replaceAll('\\', '/');
      final content = entity.readAsStringSync();
      final lines = content.isEmpty
          ? 0
          : '\n'.allMatches(content).length + (content.endsWith('\n') ? 0 : 1);
      counts[path] = lines;
    }
  }
  return counts;
}

void main() {
  group('Fix 7.3: Ruleset Big-File Ratchet Controls (in-memory)', () {
    test('control: 1501 lines not on allowlist fails naming file and 1501', () {
      final problems = evaluateBigFileRatchet(
        actualLineCounts: {'lib/src/oversized.dart': 1501},
        allowlist: const {},
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('lib/src/oversized.dart'));
      expect(problems.single, contains('1501'));
    });

    test('control: 1500 lines not on allowlist passes', () {
      final problems = evaluateBigFileRatchet(
        actualLineCounts: {'lib/src/exact.dart': 1500},
        allowlist: const {},
      );
      expect(problems, isEmpty);
    });

    test('control: allowlisted file grows, shrinks, or drops to <= 1500 fails', () {
      final grew = evaluateBigFileRatchet(
        actualLineCounts: {'lib/src/big.dart': 1819},
        allowlist: const {'lib/src/big.dart': 1818},
      );
      expect(grew, hasLength(1));
      expect(grew.single, contains('grew'));

      final shrank = evaluateBigFileRatchet(
        actualLineCounts: {'lib/src/big.dart': 1817},
        allowlist: const {'lib/src/big.dart': 1818},
      );
      expect(shrank, hasLength(1));
      expect(shrank.single, contains('lower its ceiling'));

      final underLimit = evaluateBigFileRatchet(
        actualLineCounts: {'lib/src/big.dart': 1500},
        allowlist: const {'lib/src/big.dart': 1818},
      );
      expect(underLimit, hasLength(1));
      expect(underLimit.single, contains('remove it from the allowlist'));
    });
  });

  group('Fix 7.3: Ruleset Big-File Ratchet on live lib/ tree', () {
    test('allowlist holds exactly character_models.dart', () {
      expect(
        kRulesetBigFileAllowlist.keys,
        equals(['lib/src/models/character_models.dart']),
      );
    });

    test('no lib/ .dart file exceeds $kMaxAllowedLines lines outside exact allowlist ceilings', () {
      final counts = _collectLibLineCounts();
      final problems = evaluateBigFileRatchet(
        actualLineCounts: counts,
        allowlist: kRulesetBigFileAllowlist,
      );
      expect(
        problems,
        isEmpty,
        reason: 'Big-file ratchet violations:\n${problems.join('\n')}',
      );
    });
  });
}
