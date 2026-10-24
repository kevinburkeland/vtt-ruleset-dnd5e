import 'package:test/test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('RulesetEdition RulesetRef Contract (Cold Iron Pass 12)', () {
    test('D1: every RulesetEdition value implements RulesetRef with rulesetId == name', () {
      const values = RulesetEdition.values;
      expect(values.map((e) => e.name).toList(), unorderedEquals(['v2014', 'v2024']));
      expect(values.length, equals(2));

      for (final edition in values) {
        expect(edition.rulesetId, equals(edition.name));
        expect(edition, isA<RulesetRef>());
        final RulesetRef ref = edition;
        expect(ref.rulesetId, equals(edition.name));
      }
    });
  });
}
