import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('SRD Legal & Clean-Room Compliance Tests', () {
    const bannedProductIdentityTerms = [
      'beholder',
      'githyanki',
      'githzerai',
      'mind flayer',
      'illithid',
      'umber hulk',
      'yuan-ti',
      'carrion crawler',
      'displacer beast',
      'slaad',
    ];

    test('Ensures production files in lib/ contain zero WotC Product Identity monsters', () {
      final libDir = Directory('lib');
      final violations = <String>[];
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync().toLowerCase();
        for (final term in bannedProductIdentityTerms) {
          if (content.contains(term)) {
            violations.add('${file.path} contains banned term "$term"');
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
