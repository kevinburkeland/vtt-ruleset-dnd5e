import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Domain Purity & Flutter Decoupling Tests', () {
    test('Ensures all Dart files in lib/ have zero Flutter engine imports', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final violations = <String>[];
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('import ') && line.contains('package:flutter/')) {
            violations.add('${file.path}:${i + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'vtt_ruleset_dnd5e must remain 100% pure Dart. Found Flutter imports:\n'
            '${violations.join('\n')}',
      );
    });

    test('Ensures zero dependencies on downstream application', () {
      final libDir = Directory('lib');
      final violations = <String>[];
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        if (content.contains('package:dangerously_nerdy_5e_toolkit')) {
          violations.add(file.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'vtt_ruleset_dnd5e must not import downstream application packages:\n'
            '${violations.join('\n')}',
      );
    });
  });
}
