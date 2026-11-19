import 'package:test/test.dart';
import '../helpers/in_memory_entity_resolver.dart';
import '../helpers/test_dnd5e_catalog.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('LevelUpPipeline Tests', () {
    late InMemoryEntityResolver resolver;
    late Character baseWizard;

    setUp(() {
      Dnd5eRuleset.resetForTesting();
      Dnd5eRuleset.install(const TestDnd5eCatalog());
      resolver = InMemoryEntityResolver();

      baseWizard = Character(
        id: const EntityId(slug: 'alden', ruleset: RulesetVersion.v2024),
        name: 'Alden',
        speciesRef: const EntityReference.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference.empty(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 1,
            hitDie: 'd6',
            hitPointsRolled: [],
            isStartingClass: true,
          ),
        ]),
        baseScores: const AbilityScores(
          strength: 8,
          dexterity: 14,
          constitution: 14, // +2 mod
          intelligence: 16, // +3 mod
          wisdom: 12,
          charisma: 10,
        ),
        resources: const CharacterResourcePool(
          currentHp: 8, // 6 max + 2 CON
          currentHitDice: {'d6': 1},
        ),
      );
    });

    tearDown(() {
      Dnd5eRuleset.resetForTesting();
    });

    test('advances current class with fixed average HP', () {
      final updated = CharacterProgressionEngine.applyLevelUp(
        baseWizard,
        const LevelUpRequest(
          targetClassSlug: 'wizard',
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );

      expect(updated.totalLevel, equals(2));
      expect(updated.progression.classes.first.level, equals(2));
      expect(
          updated.progression.classes.first.hitPointsRolled.length, equals(1));
      expect(updated.progression.classes.first.hitPointsRolled.first,
          equals(4)); // d6 avg is 4

      final stats = CharacterStatCalculator.compute(updated, resolver);
      // Level 1: 6 + 2 = 8
      // Level 2: 4 + 2 = 6 -> Total 14
      expect(stats.maxHp, equals(14));
      expect(updated.resources.currentHitDice['d6'], equals(2));
    });

    test('advances level with ASI (+2 to INT)', () {
      final updated = CharacterProgressionEngine.applyLevelUp(
        baseWizard,
        const LevelUpRequest(
          targetClassSlug: 'wizard',
          hpChoice: HpProgressionChoice.average(),
          asiOrFeat: AsiOrFeatChoice.asi({AbilityType.intelligence: 2}),
        ),
        resolver: resolver,
      );

      expect(updated.bonusScores.intelligence, equals(2));
      final stats = CharacterStatCalculator.compute(updated, resolver);
      expect(stats.effectiveScores.intelligence, equals(18));
      expect(stats.abilityModifiers[AbilityType.intelligence], equals(4));
    });

    test('advances level with Tough Feat (+2 HP per level)', () {
      final updated = CharacterProgressionEngine.applyLevelUp(
        baseWizard,
        const LevelUpRequest(
          targetClassSlug: 'wizard',
          hpChoice: HpProgressionChoice.average(),
          asiOrFeat: AsiOrFeatChoice.feat(EntityReference.empty(
            refType: EntityType.feat,
            slug: 'tough',
            displayName: 'Tough',
          )),
        ),
        resolver: resolver,
      );

      expect(updated.feats.length, equals(1));
      expect(updated.feats.first.slug, equals('tough'));

      final stats = CharacterStatCalculator.compute(updated, resolver);
      // Max HP: Base 8 + Level 2 (4+2=6) + Tough (2 levels * 2 = 4) = 18
      expect(stats.maxHp, equals(18));
    });

    test('multiclassing validates prerequisites and rejects if below 13', () {
      // Wizard STR 8, DEX 14, CON 14, INT 16, WIS 12, CHA 10
      // Trying to multiclass into Paladin (requires STR 13 and CHA 13)
      final validation =
          CharacterProgressionEngine.validateMulticlass(baseWizard, 'paladin');
      expect(validation.isValid, isFalse);
      expect(validation.errors.any((e) => e.contains('paladin')), isTrue);
    });

    test('multiclassing succeeds when prerequisites are satisfied', () {
      // Character has DEX 14 (satisfies Rogue requirement) and INT 16 (satisfies Wizard requirement)
      final validation =
          CharacterProgressionEngine.validateMulticlass(baseWizard, 'rogue');
      expect(validation.isValid, isTrue);

      final multiclassChar = CharacterProgressionEngine.applyLevelUp(
        baseWizard,
        const LevelUpRequest(
          targetClassSlug: 'rogue',
          targetClassDisplayName: 'Rogue',
          targetClassHitDie: 'd8',
          isMulticlass: true,
          hpChoice: HpProgressionChoice.average(),
        ),
        resolver: resolver,
      );

      expect(multiclassChar.totalLevel, equals(2));
      expect(multiclassChar.progression.classes.length, equals(2));
      expect(multiclassChar.progression.classes[0].classRef.slug,
          equals('wizard'));
      expect(
          multiclassChar.progression.classes[1].classRef.slug, equals('rogue'));
      expect(multiclassChar.progression.classes[1].hitDie, equals('d8'));
      expect(multiclassChar.resources.currentHitDice['d8'], equals(1));
      expect(multiclassChar.resources.currentHitDice['d6'], equals(1));
    });

    test('multiclass spell slots aggregate correctly (Wizard 3 / Paladin 2)',
        () {
      var char = Character(
        id: const EntityId(slug: 'gish', ruleset: RulesetVersion.v2024),
        name: 'Gish',
        speciesRef: const EntityReference.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference.empty(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 3,
            hitDie: 'd6',
            isStartingClass: true,
          ),
          ClassLevelProgression(
            classRef: EntityReference.empty(
              refType: EntityType.classDefinition,
              slug: 'paladin',
              displayName: 'Paladin',
            ),
            level: 2,
            hitDie: 'd10',
          ),
        ]),
        baseScores: const AbilityScores(
          strength: 14,
          dexterity: 10,
          constitution: 14,
          intelligence: 16,
          wisdom: 10,
          charisma: 14,
        ),
        resources: const CharacterResourcePool(currentHp: 35),
      );

      // ECL = Wizard 3 + floor(Paladin 2 / 2 = 1) = 4
      final stats = CharacterStatCalculator.compute(char, resolver);
      // Level 4 full caster slots: 4 1st-level, 3 2nd-level
      expect(stats.computedSpellSlots.maxSlots[1], equals(4));
      expect(stats.computedSpellSlots.maxSlots[2], equals(3));
    });
  });
}
