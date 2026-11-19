import 'dart:math';

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

  group('EvaluatedCharacterStats.spellcastingModifiers law', () {
    const casterClasses = <(String slug, String name)>[
      ('wizard', 'Wizard'),
      ('cleric', 'Cleric'),
      ('druid', 'Druid'),
      ('ranger', 'Ranger'),
      ('bard', 'Bard'),
      ('paladin', 'Paladin'),
      ('sorcerer', 'Sorcerer'),
      ('warlock', 'Warlock'),
    ];
    const martialClasses = <(String slug, String name)>[
      ('fighter', 'Fighter'),
      ('barbarian', 'Barbarian'),
      ('monk', 'Monk'),
      ('rogue', 'Rogue'),
    ];
    const allClasses = <(String slug, String name)>[
      ...casterClasses,
      ...martialClasses,
    ];

    const humanRef = EntityReference<DomainEntity>.empty(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    );

    ClassLevelProgression makeClass(
      String slug,
      String name,
      int level, {
      EntityReference<DomainEntity>? subclassRef,
    }) {
      return ClassLevelProgression(
        classRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.classDefinition,
          slug: slug,
          displayName: name,
        ),
        subclassRef: subclassRef,
        level: level,
        hitDie: 'd8',
      );
    }

    test(
      '360 seeded characters: key sets match spellAttackBonuses and '
      'spellAttackBonuses[k] == proficiencyBonus + spellcastingModifiers[k]',
      () {
        final rng = Random(140301);

        for (var i = 0; i < 360; i++) {
          final edition =
              i.isEven ? RulesetEdition.v2014 : RulesetEdition.v2024;
          final scores = AbilityScores(
            strength: 3 + rng.nextInt(18),
            dexterity: 3 + rng.nextInt(18),
            constitution: 3 + rng.nextInt(18),
            intelligence: 3 + rng.nextInt(18),
            wisdom: 3 + rng.nextInt(18),
            charisma: 3 + rng.nextInt(18),
          );

          final classes = <ClassLevelProgression>[];
          final totalLevel = 1 + rng.nextInt(20);
          final mode = i % 4;

          if (mode == 0) {
            final cls = casterClasses[rng.nextInt(casterClasses.length)];
            classes.add(makeClass(cls.$1, cls.$2, totalLevel));
          } else if (mode == 1) {
            final cls = martialClasses[rng.nextInt(martialClasses.length)];
            classes.add(makeClass(cls.$1, cls.$2, totalLevel));
          } else if (mode == 2 && totalLevel >= 2) {
            final firstIdx = rng.nextInt(allClasses.length);
            var secondIdx = rng.nextInt(allClasses.length);
            if (secondIdx == firstIdx) {
              secondIdx = (firstIdx + 1) % allClasses.length;
            }
            final lvl1 = 1 + rng.nextInt(totalLevel - 1);
            final lvl2 = totalLevel - lvl1;
            final c1 = allClasses[firstIdx];
            final c2 = allClasses[secondIdx];
            classes.add(makeClass(c1.$1, c1.$2, lvl1));
            classes.add(makeClass(c2.$1, c2.$2, lvl2));
          } else {
            final cls = allClasses[rng.nextInt(allClasses.length)];
            EntityReference<DomainEntity>? subRef;
            if (cls.$1 == 'fighter' && totalLevel >= 3 && rng.nextBool()) {
              subRef = const EntityReference<DomainEntity>.empty(
                refType: EntityType.subclass,
                slug: 'eldritch_knight',
                displayName: 'Eldritch Knight',
              );
            } else if (cls.$1 == 'rogue' && totalLevel >= 3 && rng.nextBool()) {
              subRef = const EntityReference<DomainEntity>.empty(
                refType: EntityType.subclass,
                slug: 'arcane_trickster',
                displayName: 'Arcane Trickster',
              );
            }
            classes.add(
              makeClass(cls.$1, cls.$2, totalLevel, subclassRef: subRef),
            );
          }

          final character = Character(
            id: EntityId(
              slug: 'char-$i',
              ruleset: edition == RulesetEdition.v2024
                  ? RulesetVersion.v2024
                  : RulesetVersion.v2014,
            ),
            name: 'Seeded Character $i',
            rulesEdition: edition,
            speciesRef: humanRef,
            baseScores: scores,
            progression: CharacterProgression(classes: classes),
            resources: const CharacterResourcePool(currentHp: 10),
          );

          final stats = CharacterEvaluationEngine.evaluate(character);

          expect(
            stats.spellcastingModifiers.keys.toSet(),
            equals(stats.spellAttackBonuses.keys.toSet()),
            reason: 'Seed $i: key sets must match',
          );

          if (mode == 1) {
            expect(
              stats.spellcastingModifiers,
              isEmpty,
              reason: 'Seed $i: non-spellcasting martial must have empty map',
            );
          }

          for (final key in stats.spellAttackBonuses.keys) {
            expect(
              stats.spellAttackBonuses[key],
              equals(stats.proficiencyBonus + stats.spellcastingModifiers[key]!),
              reason:
                  'Seed $i key "$key": attack bonus must equal prof + castMod',
            );
          }
        }
      },
    );

    test('character with no classes has empty spellcastingModifiers', () {
      const character = Character(
        id: EntityId(slug: 'empty-char', ruleset: RulesetVersion.v2024),
        name: 'Commoner',
        rulesEdition: RulesetEdition.v2024,
        speciesRef: humanRef,
        baseScores: AbilityScores(
          strength: 10,
          dexterity: 10,
          constitution: 10,
          intelligence: 14,
          wisdom: 16,
          charisma: 12,
        ),
        progression: CharacterProgression(classes: []),
        resources: CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.spellcastingModifiers, isEmpty);
      expect(stats.spellAttackBonuses, isEmpty);
    });
  });
}
