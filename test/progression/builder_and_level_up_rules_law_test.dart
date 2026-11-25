import 'dart:io';
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../helpers/test_dnd5e_catalog.dart';

void main() {
  setUp(() {
    Dnd5eRuleset.resetForTesting();
    Dnd5eRuleset.install(const TestDnd5eCatalog());
  });

  tearDown(() {
    Dnd5eRuleset.resetForTesting();
  });

  group('Fix 7.1: ClassSpellcasterProfile Law', () {
    test('2024 Paladin is a level-1 Charisma caster with highest spell level 1; 2014 Paladin starts at level 2',
        () {
      final p2024L1 = resolveClassSpellcasterProfile(
        classSlug: 'paladin',
        classLevel: 1,
        edition: RulesetEdition.v2024,
      );
      expect(p2024L1.isSpellcaster, isTrue);
      expect(p2024L1.castingAbility, equals(AbilityType.charisma));
      expect(p2024L1.highestSpellLevel, equals(1));
      expect(p2024L1.spellList, equals(SpellClass.paladin));

      final p2014L1 = resolveClassSpellcasterProfile(
        classSlug: 'paladin',
        classLevel: 1,
        edition: RulesetEdition.v2014,
      );
      expect(p2014L1.isSpellcaster, isFalse);
      expect(p2014L1.highestSpellLevel, equals(0));

      final p2014L2 = resolveClassSpellcasterProfile(
        classSlug: 'paladin',
        classLevel: 2,
        edition: RulesetEdition.v2014,
      );
      expect(p2014L2.isSpellcaster, isTrue);
      expect(p2014L2.castingAbility, equals(AbilityType.charisma));
      expect(p2014L2.highestSpellLevel, equals(1));
    });

    test('covers all SRD classes and third-casters across levels 1..20 in both editions',
        () {
      const classes = [
        'barbarian',
        'bard',
        'cleric',
        'druid',
        'fighter',
        'monk',
        'paladin',
        'ranger',
        'rogue',
        'sorcerer',
        'warlock',
        'wizard',
      ];
      var cases = 0;
      for (final edition in RulesetEdition.values) {
        for (final slug in classes) {
          for (var lvl = 1; lvl <= 20; lvl++) {
            cases++;
            final profile = resolveClassSpellcasterProfile(
              classSlug: slug,
              classLevel: lvl,
              edition: edition,
            );
            final limits = SpellAllocationValidator.getLimitsForClass(
              classSlug: slug,
              classLevel: lvl,
              abilityModifier: 0,
              edition: edition,
            );
            expect(profile.isSpellcaster, equals(limits.isSpellcaster));
            expect(profile.highestSpellLevel, equals(limits.maxSpellSlotLevel));
            if (profile.isSpellcaster) {
              expect(profile.castingAbility, isNotNull);
              expect(profile.spellList, isNotNull);
              expect(profile.highestSpellLevel, inInclusiveRange(1, 9));
              if (slug == 'paladin' || slug == 'ranger') {
                expect(profile.highestSpellLevel, equals(((lvl + 3) ~/ 4).clamp(1, 5)));
              }
            } else {
              expect(profile.castingAbility, isNull);
              expect(profile.spellList, isNull);
            }
          }
        }
        // Third casters: Eldritch Knight & Arcane Trickster
        for (final pair in const [
          ('fighter', 'eldritch_knight'),
          ('rogue', 'arcane_trickster'),
        ]) {
          for (var lvl = 1; lvl <= 20; lvl++) {
            cases++;
            final profile = resolveClassSpellcasterProfile(
              classSlug: pair.$1,
              classLevel: lvl,
              subclassSlug: pair.$2,
              edition: edition,
            );
            if (lvl < 3) {
              expect(profile.isSpellcaster, isFalse);
              expect(profile.highestSpellLevel, equals(0));
            } else {
              expect(profile.isSpellcaster, isTrue);
              expect(profile.castingAbility, equals(AbilityType.intelligence));
              expect(profile.spellList, equals(SpellClass.wizard));
              expect(profile.highestSpellLevel, inInclusiveRange(1, 4));
            }
          }
        }
      }
      stdout.writeln('Fix 7.1 caster profile law verified $cases cases.');
    });
  });

  group('Fix 7.2: Ability Score Increase & Origin Bonus Laws', () {
    test('applyAbilityScoreIncreases caps at 20 for +2 and +1/+1 across scores 1..22',
        () {
      var cases = 0;
      for (var base = 1; base <= 22; base++) {
        for (final ab in AbilityType.values) {
          cases++;
          final current = AbilityScores(
            strength: base,
            dexterity: base,
            constitution: base,
            intelligence: base,
            wisdom: base,
            charisma: base,
          );
          final afterPlus2 = applyAbilityScoreIncreases(
            currentScores: current,
            increases: {ab: 2},
          );
          final expectedScore = base >= 20 ? base : (base + 2).clamp(1, 20);
          expect(afterPlus2.getScore(ab), equals(expectedScore));

          // Other abilities unchanged
          for (final other in AbilityType.values) {
            if (other != ab) {
              expect(afterPlus2.getScore(other), equals(base));
            }
          }
        }
      }

      // +1 to two distinct abilities
      const start = AbilityScores(
        strength: 19,
        dexterity: 18,
        constitution: 20,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
      );
      final afterDual = applyAbilityScoreIncreases(
        currentScores: start,
        increases: const {AbilityType.strength: 1, AbilityType.constitution: 1},
      );
      expect(afterDual.strength, equals(20));
      expect(afterDual.constitution, equals(20));
      expect(afterDual.dexterity, equals(18));

      // Negative increase rejected
      expect(
        () => applyAbilityScoreIncreases(
          currentScores: start,
          increases: const {AbilityType.strength: -1},
        ),
        throwsArgumentError,
      );

      stdout.writeln('Fix 7.2 ASI cap law verified $cases cases.');
    });

    test('computeOriginAbilityBonuses handles 2014 fixed+flexible and 2024 +2/+1 and +1/+1/+1',
        () {
      // 2014 fixed + flexible (e.g., Half-Elf: +2 CHA fixed, +1 to two distinct picks)
      final b2014 = computeOriginAbilityBonuses(
        edition: RulesetEdition.v2014,
        fixedBonuses2014: const {'charisma': 2},
        flexibleChoiceCount2014: 2,
        flexibleBonusValue2014: 1,
        flexibleChoices2014: const [
          AbilityType.dexterity,
          AbilityType.constitution,
          AbilityType.strength, // ignored: beyond count 2
        ],
      );
      expect(b2014.charisma, equals(2));
      expect(b2014.dexterity, equals(1));
      expect(b2014.constitution, equals(1));
      expect(b2014.strength, equals(0));

      // 2024 +2/+1
      final b2024TwoOne = computeOriginAbilityBonuses(
        edition: RulesetEdition.v2024,
        backgroundPrimary2024: AbilityType.charisma,
        backgroundSecondary2024: AbilityType.wisdom,
      );
      expect(b2024TwoOne.charisma, equals(2));
      expect(b2024TwoOne.wisdom, equals(1));
      expect(b2024TwoOne.strength, equals(0));

      // 2024 +1/+1/+1
      final b2024Triple = computeOriginAbilityBonuses(
        edition: RulesetEdition.v2024,
        backgroundTriplePlusOne2024: const [
          AbilityType.strength,
          AbilityType.dexterity,
          AbilityType.constitution,
        ],
      );
      expect(b2024Triple.strength, equals(1));
      expect(b2024Triple.dexterity, equals(1));
      expect(b2024Triple.constitution, equals(1));
      expect(b2024Triple.intelligence, equals(0));
    });
  });

  group('Fix 7.3: Level-Up HP Gain Law', () {
    test('exhaustive law over every hit die, every roll, and CON modifiers -5..+10',
        () {
      const dice = {'d6': 6, 'd8': 8, 'd10': 10, 'd12': 12};
      var cases = 0;

      for (final entry in dice.entries) {
        final die = entry.key;
        final sides = entry.value;
        final fixedAvg = (sides ~/ 2) + 1;

        for (var conMod = -5; conMod <= 10; conMod++) {
          // Fixed average
          cases++;
          final avgGain = computeLevelUpHpGain(
            hitDie: die,
            constitutionModifier: conMod,
            useFixedAverage: true,
          );
          final expectedAvg = (fixedAvg + conMod) < 1 ? 1 : (fixedAvg + conMod);
          expect(avgGain, equals(expectedAvg));
          expect(avgGain, greaterThanOrEqualTo(1));

          // Every rolled value 1..sides
          for (var roll = 1; roll <= sides; roll++) {
            cases++;
            final rollGain = computeLevelUpHpGain(
              hitDie: die,
              constitutionModifier: conMod,
              useFixedAverage: false,
              rolledValue: roll,
            );
            final expectedRoll = (roll + conMod) < 1 ? 1 : (roll + conMod);
            expect(rollGain, equals(expectedRoll));
            expect(rollGain, greaterThanOrEqualTo(1));
          }
        }
      }

      // Invalid die / roll throws ArgumentError
      expect(
        () => computeLevelUpHpGain(
          hitDie: 'invalid',
          constitutionModifier: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => computeLevelUpHpGain(
          hitDie: 'd8',
          constitutionModifier: 0,
          useFixedAverage: false,
          rolledValue: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => computeLevelUpHpGain(
          hitDie: 'd8',
          constitutionModifier: 0,
          useFixedAverage: false,
          rolledValue: 9,
        ),
        throwsArgumentError,
      );

      stdout.writeln('Fix 7.3 level-up HP gain law verified $cases cases.');
    });
  });
}
