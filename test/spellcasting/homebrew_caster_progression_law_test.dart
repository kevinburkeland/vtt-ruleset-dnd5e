import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../helpers/test_dnd5e_catalog.dart';

void main() {
  setUp(() {
    Dnd5eRuleset.install(const TestDnd5eCatalog());
  });

  group('Fix 3.2 law: homebrew caster progression', () {
    test(
      'non-SRD class with casting ability and progression matches SRD counterpart highestSpellLevel for every progression x levels 1-20 x both editions',
      () {
        final counterparts = <CasterProgression, ({String slug, String? sub})>{
          CasterProgression.full: (slug: 'wizard', sub: null),
          CasterProgression.half: (slug: 'paladin', sub: null),
          CasterProgression.third: (slug: 'fighter', sub: 'eldritch_knight'),
          CasterProgression.pact: (slug: 'warlock', sub: null),
        };

        for (final edition in const [RulesetEdition.v2014, RulesetEdition.v2024]) {
          final edLabel = edition == RulesetEdition.v2014 ? '2014' : '2024';
          for (final progression in CasterProgression.values) {
            final counterpart = counterparts[progression]!;
            for (var level = 1; level <= 20; level++) {
              final expected = resolveClassSpellcasterProfile(
                classSlug: counterpart.slug,
                subclassSlug: counterpart.sub,
                classLevel: level,
                edition: edition,
              );
              final actual = resolveClassSpellcasterProfile(
                classSlug: 'homebrew_mystic_class',
                classLevel: level,
                edition: edition,
                fallbackCastingAbility: AbilityType.intelligence,
                casterProgression: progression,
              );

              expect(
                actual.isSpellcaster,
                equals(expected.isSpellcaster),
                reason:
                    '$edLabel progression=${progression.name} level=$level: expected isSpellcaster=${expected.isSpellcaster}, got ${actual.isSpellcaster}',
              );
              expect(
                actual.highestSpellLevel,
                equals(expected.highestSpellLevel),
                reason:
                    '$edLabel progression=${progression.name} level=$level: expected highestSpellLevel=${expected.highestSpellLevel}, got ${actual.highestSpellLevel}',
              );
              if (expected.isSpellcaster) {
                expect(
                  actual.castingAbility,
                  equals(AbilityType.intelligence),
                  reason:
                      '$edLabel progression=${progression.name} level=$level: expected castingAbility=intelligence, got ${actual.castingAbility}',
                );
              }
            }
          }
        }
      },
    );

    test('non-SRD class missing either ability or progression stays non-caster', () {
      for (final edition in const [RulesetEdition.v2014, RulesetEdition.v2024]) {
        final missingProgression = resolveClassSpellcasterProfile(
          classSlug: 'homebrew_mystic_class',
          classLevel: 5,
          edition: edition,
          fallbackCastingAbility: AbilityType.intelligence,
        );
        expect(missingProgression.isSpellcaster, isFalse);
        expect(missingProgression.highestSpellLevel, equals(0));

        final missingAbility = resolveClassSpellcasterProfile(
          classSlug: 'homebrew_mystic_class',
          classLevel: 5,
          edition: edition,
          casterProgression: CasterProgression.full,
        );
        expect(missingAbility.isSpellcaster, isFalse);
        expect(missingAbility.highestSpellLevel, equals(0));
      }
    });

    test('CasterProgression.tryParse handles known and unknown values', () {
      expect(CasterProgression.tryParse('full'), CasterProgression.full);
      expect(CasterProgression.tryParse('FULL'), CasterProgression.full);
      expect(CasterProgression.tryParse('half'), CasterProgression.half);
      expect(CasterProgression.tryParse('1/2'), CasterProgression.half);
      expect(CasterProgression.tryParse('third'), CasterProgression.third);
      expect(CasterProgression.tryParse('1/3'), CasterProgression.third);
      expect(CasterProgression.tryParse('pact'), CasterProgression.pact);
      expect(CasterProgression.tryParse(null), isNull);
      expect(CasterProgression.tryParse('quarter'), isNull);
    });
  });
}
