import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../helpers/in_memory_entity_resolver.dart';
import '../helpers/test_dnd5e_catalog.dart';

Spell _makeTestSpell(String slug, String name, int level) {
  return Spell(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
    level: level,
    school: 'necromancy',
    castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
    duration: const SpellDuration(type: DurationType.instantaneous),
    range: '60 feet',
    components: const SpellComponents(v: true, s: true, m: false),
    descriptionMarkdown: 'Test spell markdown.',
  );
}

void main() {
  group('SpellAllocationValidator RAW Tests', () {
    setUp(() {
      Dnd5eRuleset.resetForTesting();
      Dnd5eRuleset.install(const TestDnd5eCatalog());
    });

    tearDown(() {
      Dnd5eRuleset.resetForTesting();
    });

    test('Wizard Level 1 spell limits and spellbook initial scribe quota', () {
      final limits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'wizard',
        classLevel: 1,
        abilityModifier: 3, // 16 INT -> +3
        edition: RulesetEdition.v2024,
      );

      expect(limits.isSpellcaster, isTrue);
      expect(limits.maxCantrips, 3);
      expect(limits.maxSpellsPrepared, 4); // 1 + 3 = 4
      expect(limits.maxSpellbookInitialScribe, 6);
      expect(limits.maxSpellbookLevelUpScribe, 2);
      expect(limits.maxSpellSlotLevel, 1);
    });

    test('Wizard Level 1 validates exactly 6 spellbook spells', () {
      final cantrips = [
        const EntityReference<Spell>.empty(
            refType: EntityType.spell,
            slug: 'fire-bolt',
            displayName: 'Fire Bolt'),
        const EntityReference<Spell>.empty(
            refType: EntityType.spell,
            slug: 'mage-hand',
            displayName: 'Mage Hand'),
        const EntityReference<Spell>.empty(
            refType: EntityType.spell, slug: 'light', displayName: 'Light'),
      ];

      final spellbookValid = List.generate(
        6,
        (i) => EntityReference<Spell>.empty(
            refType: EntityType.spell,
            slug: 'spell-$i',
            displayName: 'Spell $i'),
      );

      final preparedValid = spellbookValid.take(4).toList();

      final result = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'wizard',
        targetClassLevel: 1,
        castingAbilityModifier: 3,
        cantrips: cantrips,
        spellsKnown: spellbookValid,
        spellsPrepared: preparedValid,
        edition: RulesetEdition.v2024,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);

      // Invalid: Only 5 spells in spellbook
      final invalidResult = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'wizard',
        targetClassLevel: 1,
        castingAbilityModifier: 3,
        cantrips: cantrips,
        spellsKnown: spellbookValid.take(5).toList(),
        spellsPrepared: preparedValid,
        edition: RulesetEdition.v2024,
      );

      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors.first, contains('6 1st-level spells'));
    });

    test('Sorcerer Spells Known progression across levels', () {
      final lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'sorcerer',
        classLevel: 1,
        abilityModifier: 3,
      );
      expect(lvl1.maxCantrips, 4);
      expect(lvl1.maxSpellsKnown, 2);
      expect(lvl1.maxSpellSlotLevel, 1);

      final lvl5 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'sorcerer',
        classLevel: 5,
        abilityModifier: 4,
      );
      expect(lvl5.maxCantrips, 5);
      expect(lvl5.maxSpellsKnown, 6);
      expect(lvl5.maxSpellSlotLevel, 3);
    });

    test('Paladin spellcasting starts at Level 2 in 2014, Level 1 in 2024', () {
      final paladin2014Lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'paladin',
        classLevel: 1,
        abilityModifier: 2,
        edition: RulesetEdition.v2014,
      );
      expect(paladin2014Lvl1.isSpellcaster, isFalse);
      expect(paladin2014Lvl1.maxSpellSlotLevel, 0);

      final paladin2024Lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'paladin',
        classLevel: 1,
        abilityModifier: 2,
        edition: RulesetEdition.v2024,
      );
      expect(paladin2024Lvl1.isSpellcaster, isTrue);
      expect(paladin2024Lvl1.maxSpellSlotLevel, 1);
      expect(paladin2024Lvl1.maxSpellsPrepared, 3); // ((1+1)~/2) + 2 = 3
    });

    test('Max tier gating prevents selecting higher level spells', () {
      final tierLvl3Wizard = SpellAllocationValidator.getMaxSpellTierForClass(
        classSlug: 'wizard',
        classLevel: 3,
      );
      expect(tierLvl3Wizard,
          2); // 3rd level wizard can cast up to 2nd level spells

      final tierLvl5Ranger2014 =
          SpellAllocationValidator.getMaxSpellTierForClass(
        classSlug: 'ranger',
        classLevel: 5,
        edition: RulesetEdition.v2014,
      );
      expect(tierLvl5Ranger2014, 2);
    });

    test('Bard 2014 Magical Secrets progression at levels 10, 14, 18', () {
      final l10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 10,
        abilityModifier: 4,
        edition: RulesetEdition.v2014,
      );
      expect(l10.magicalSecretsCount, 2);
      expect(l10.allowedMagicalSecretClasses.length, greaterThanOrEqualTo(8));

      final l14 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 14,
        abilityModifier: 4,
        edition: RulesetEdition.v2014,
      );
      expect(l14.magicalSecretsCount, 4);

      final l18 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 18,
        abilityModifier: 5,
        edition: RulesetEdition.v2014,
      );
      expect(l18.magicalSecretsCount, 6);
    });

    test('Lore Bard Additional Magical Secrets at Level 6 (2014 vs 2024)', () {
      final lore2014 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        subclassSlug: 'college_of_lore',
        classLevel: 6,
        abilityModifier: 3,
        edition: RulesetEdition.v2014,
      );
      expect(lore2014.magicalSecretsCount, 2);
      expect(
          lore2014.allowedMagicalSecretClasses.length, greaterThanOrEqualTo(8));

      final lore2024 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        subclassSlug: 'college_of_lore',
        classLevel: 6,
        abilityModifier: 3,
        edition: RulesetEdition.v2024,
      );
      expect(lore2024.magicalSecretsCount, 2);
      expect(
          lore2024.allowedMagicalSecretClasses,
          containsAll(
              [SpellClass.wizard, SpellClass.cleric, SpellClass.druid]));
    });

    test(
        'Bard 2024 Level 10 Magical Secrets unlocks Cleric, Druid, and Wizard spell lists',
        () {
      final bard2024L10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 10,
        abilityModifier: 4,
        edition: RulesetEdition.v2024,
      );
      expect(
          bard2024L10.allowedMagicalSecretClasses,
          containsAll([
            SpellClass.bard,
            SpellClass.cleric,
            SpellClass.druid,
            SpellClass.wizard,
          ]));
    });

    test('Warlock Mystic Arcanum milestones at levels 11, 13, 15, 17', () {
      final w10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 10,
        abilityModifier: 4,
      );
      expect(w10.mysticArcanumLevel, 0);
      expect(w10.mysticArcanumCount, 0);

      final w11 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 11,
        abilityModifier: 4,
      );
      expect(w11.mysticArcanumLevel, 6);
      expect(w11.mysticArcanumCount, 1);
      expect(w11.maxSpellsKnown, 11);
      expect(w11.maxSpellSlotLevel, 5);

      final w13 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 13,
        abilityModifier: 4,
      );
      expect(w13.mysticArcanumLevel, 7);
      expect(w13.mysticArcanumCount, 2);

      final w15 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 15,
        abilityModifier: 4,
      );
      expect(w15.mysticArcanumLevel, 8);
      expect(w15.mysticArcanumCount, 3);

      final w17 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 17,
        abilityModifier: 4,
      );
      expect(w17.mysticArcanumLevel, 9);
      expect(w17.mysticArcanumCount, 4);
    });

    test(
        'Warlock Level 11 validates 11 known spells AND 1 Level 6 Mystic Arcanum spell without quota error',
        () {
      final resolver = InMemoryEntityResolver();

      // Register 11 Level-5 spells
      final regularSpells = <EntityReference<Spell>>[];
      for (int i = 1; i <= 11; i++) {
        final s = _makeTestSpell('pact-spell-$i', 'Pact Spell $i', 5);
        resolver.registerEntity(s);
        regularSpells.add(EntityReference<Spell>.empty(
            refType: EntityType.spell, slug: s.id.slug, displayName: s.name));
      }

      // Register 1 Level-6 Mystic Arcanum spell
      final arcanum = _makeTestSpell('eyebite', 'Eyebite', 6);
      resolver.registerEntity(arcanum);
      final arcanumRef = EntityReference<Spell>.empty(
          refType: EntityType.spell,
          slug: arcanum.id.slug,
          displayName: arcanum.name);

      // Validate with 11 regular + 1 arcanum = 12 total in spellsKnown
      final validResult = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 11,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [...regularSpells, arcanumRef],
        spellsPrepared: const [],
        edition: RulesetEdition.v2024,
        resolver: resolver,
      );

      expect(validResult.isValid, isTrue);
      expect(validResult.errors, isEmpty);

      // Invalid: 12 regular spells + 1 arcanum = exceeds 11 maxSpellsKnown
      final extraSpell = _makeTestSpell('pact-spell-12', 'Pact Spell 12', 5);
      resolver.registerEntity(extraSpell);
      final extraRef = EntityReference<Spell>.empty(
          refType: EntityType.spell,
          slug: extraSpell.id.slug,
          displayName: extraSpell.name);

      final invalidResult = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 11,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [...regularSpells, extraRef, arcanumRef],
        spellsPrepared: const [],
        edition: RulesetEdition.v2024,
        resolver: resolver,
      );

      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors.first,
          contains('exceeding the maximum allowed limit of 11'));
    });

    test(
        'Warlock Level 13 validates lower-tier Level 6 Arcanum alongside new Level 7 Arcanum',
        () {
      final resolver = InMemoryEntityResolver();

      final arcanum6 = _makeTestSpell('eyebite', 'Eyebite', 6);
      final arcanum7 = _makeTestSpell('forcecage', 'Forcecage', 7);
      final invalid8 = _makeTestSpell('demiplane', 'Demiplane', 8);
      resolver.registerAll([arcanum6, arcanum7, invalid8]);

      final ref6 = EntityReference<Spell>.empty(
          refType: EntityType.spell,
          slug: arcanum6.id.slug,
          displayName: arcanum6.name);
      final ref7 = EntityReference<Spell>.empty(
          refType: EntityType.spell,
          slug: arcanum7.id.slug,
          displayName: arcanum7.name);
      final ref8 = EntityReference<Spell>.empty(
          refType: EntityType.spell,
          slug: invalid8.id.slug,
          displayName: invalid8.name);

      // Valid: both Level 6 and Level 7 arcanums pass
      final resultValid = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 13,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [ref6, ref7],
        spellsPrepared: const [],
        edition: RulesetEdition.v2024,
        resolver: resolver,
      );
      expect(resultValid.isValid, isTrue);

      // Invalid: Level 8 spell exceeds mysticArcanumLevel 7 for Level 13 Warlock
      final resultInvalid = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 13,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [ref6, ref7, ref8],
        spellsPrepared: const [],
        edition: RulesetEdition.v2024,
        resolver: resolver,
      );
      expect(resultInvalid.isValid, isFalse);
      expect(resultInvalid.errors.first,
          contains('can only cast up to Level 5 spells'));
    });

    test(
        'validateSpellAllocations accepts class-warlock-mystic-arcanum grant key',
        () {
      final character = Character(
        id: const EntityId(slug: 'warlock-hero', ruleset: RulesetVersion.v2024),
        name: 'Warlock Hero',
        speciesRef: const EntityReference.empty(
            refType: EntityType.species,
            slug: 'tiefling',
            displayName: 'Tiefling'),
        baseScores: const AbilityScores(
            strength: 8,
            dexterity: 14,
            constitution: 14,
            intelligence: 10,
            wisdom: 12,
            charisma: 18),
        resources:
            const CharacterResourcePool(currentHp: 50, currentHitDice: {'d8': 11}),
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference.empty(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock'),
            level: 11,
            hitDie: 'd8',
            isStartingClass: true,
          ),
        ]),
        allocatedSpells: {
          'class-warlock-mystic-arcanum': [
            const EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'eyebite',
                displayName: 'Eyebite'),
          ],
        },
      );

      final res = SpellAllocationValidator.validateSpellAllocations(
          character, const []);
      expect(res.isValid, isTrue);
      expect(res.errors, isEmpty);
    });

    test('Cleric, Druid, Ranger, third-casters, and non-casters limits', () {
      Dnd5eRuleset.resetForTesting();
      Dnd5eRuleset.install(TestDnd5eCatalog(
        onGetAlwaysPreparedSpells: (cls, sub, lvl, ed) {
          if (cls == 'cleric' && sub == 'life_domain' && lvl >= 3) {
            return const ['bless', 'cure-wounds', 'lesser-restoration', 'spiritual-weapon'];
          }
          if (cls == 'druid' && sub == 'circle_of_the_land' && lvl >= 3) {
            return const ['barkskin', 'spider-climb'];
          }
          return const [];
        },
      ));

      final cleric = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'cleric',
        subclassSlug: 'life_domain',
        classLevel: 3,
        abilityModifier: 3,
      );
      expect(cleric.isSpellcaster, isTrue);
      expect(cleric.maxCantrips, 3);
      expect(cleric.maxSpellsPrepared, 6);
      expect(cleric.alwaysPreparedSubclassCount, 4);

      final druid = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'druid',
        subclassSlug: 'circle_of_the_land',
        classLevel: 10,
        abilityModifier: 4,
      );
      expect(druid.isSpellcaster, isTrue);
      expect(druid.maxCantrips, 4);
      expect(druid.maxSpellsPrepared, 14);
      expect(druid.alwaysPreparedSubclassCount, 2);

      final ranger2014 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'ranger',
        classLevel: 1,
        abilityModifier: 2,
        edition: RulesetEdition.v2014,
      );
      expect(ranger2014.isSpellcaster, isFalse);
      expect(ranger2014.maxSpellsKnown, 0);

      final ranger2024 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'ranger',
        classLevel: 1,
        abilityModifier: 2,
        edition: RulesetEdition.v2024,
      );
      expect(ranger2024.isSpellcaster, isTrue);
      expect(ranger2024.maxCantrips, 2);
      expect(ranger2024.maxSpellsPrepared, 3);

      final ek = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'fighter',
        subclassSlug: 'eldritch_knight',
        classLevel: 19,
        abilityModifier: 2,
      );
      expect(ek.isSpellcaster, isTrue);
      expect(ek.maxCantrips, 3);
      expect(ek.maxSpellSlotLevel, 4);

      final at = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'rogue',
        subclassSlug: 'arcane_trickster',
        classLevel: 7,
        abilityModifier: 3,
      );
      expect(at.isSpellcaster, isTrue);
      expect(at.maxCantrips, 2);
      expect(at.maxSpellSlotLevel, 2);

      final fighterChampion = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'fighter',
        subclassSlug: 'champion',
        classLevel: 5,
        abilityModifier: 0,
      );
      expect(fighterChampion.isSpellcaster, isFalse);

      final rogueThief = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'rogue',
        subclassSlug: 'thief',
        classLevel: 5,
        abilityModifier: 0,
      );
      expect(rogueThief.isSpellcaster, isFalse);

      final barbarian = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'barbarian',
        classLevel: 5,
        abilityModifier: 0,
      );
      expect(barbarian.isSpellcaster, isFalse);
    });

    test('validateSpellSelection rejects non-caster, cantrip overflow, prepared overflow, and levelled cantrip', () {
      final resolver = InMemoryEntityResolver([
        _makeTestSpell('fire-bolt', 'Fire Bolt', 0),
        _makeTestSpell('magic-missile', 'Magic Missile', 1),
        _makeTestSpell('fireball', 'Fireball', 3),
      ]);

      const fireBoltRef = EntityReference<Spell>.empty(
        refType: EntityType.spell,
        slug: 'fire-bolt',
        displayName: 'Fire Bolt',
      );
      const mmRef = EntityReference<Spell>.empty(
        refType: EntityType.spell,
        slug: 'magic-missile',
        displayName: 'Magic Missile',
      );
      const fireballRef = EntityReference<Spell>.empty(
        refType: EntityType.spell,
        slug: 'fireball',
        displayName: 'Fireball',
      );

      // Non-caster with spells
      final nonCasterRes = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'barbarian',
        targetClassLevel: 3,
        castingAbilityModifier: 0,
        cantrips: [fireBoltRef],
        spellsKnown: const [],
        spellsPrepared: const [],
        edition: RulesetEdition.v2014,
      );
      expect(nonCasterRes.isValid, isFalse);
      expect(nonCasterRes.errors.first, contains('not a spellcasting class'));

      // Cantrip overflow + levelled spell assigned as cantrip + prepared overflow
      final clericOverflow = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'cleric',
        targetClassLevel: 1,
        castingAbilityModifier: 1, // max 2 prepared, max 3 cantrips
        cantrips: [fireBoltRef, fireBoltRef, fireBoltRef, mmRef],
        spellsKnown: const [],
        spellsPrepared: [mmRef, fireballRef, mmRef],
        edition: RulesetEdition.v2014,
        resolver: resolver,
      );
      expect(clericOverflow.isValid, isFalse);
      expect(clericOverflow.errors, anyElement(contains('allows a maximum of 3')));
      expect(clericOverflow.errors, anyElement(contains('exceeding the prepared limit of 2')));
      expect(clericOverflow.errors, anyElement(contains('was assigned as a cantrip')));
      expect(clericOverflow.errors, anyElement(contains('can only cast up to Level 1 spells')));
    });

    test('validateSpellAllocations flags orphan keys and bonus grant overflows', () {
      final character = Character(
        id: const EntityId(slug: 'wizard-hero', ruleset: RulesetVersion.v2024),
        name: 'Wizard Hero',
        speciesRef: const EntityReference.empty(
            refType: EntityType.species,
            slug: 'elf',
            displayName: 'Elf'),
        baseScores: const AbilityScores(
            strength: 8,
            dexterity: 14,
            constitution: 12,
            intelligence: 16,
            wisdom: 10,
            charisma: 10),
        resources:
            const CharacterResourcePool(currentHp: 12, currentHitDice: {'d6': 1}),
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference.empty(
                refType: EntityType.classDefinition,
                slug: 'wizard',
                displayName: 'Wizard'),
            level: 1,
            hitDie: 'd6',
            isStartingClass: true,
          ),
        ]),
        allocatedSpells: {
          'orphan-key': [
            const EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'light',
                displayName: 'Light'),
          ],
          'grant-cantrips': [
            const EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'light',
                displayName: 'Light'),
            const EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'mage-hand',
                displayName: 'Mage Hand'),
          ],
          'grant-spell': [
            const EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'shield',
                displayName: 'Shield'),
            const EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'detect-magic',
                displayName: 'Detect Magic'),
          ],
        },
      );

      final grants = [
        const FeatureGrant(
          grantId: 'grant-cantrips',
          type: GrantType.bonusCantrip,
          payload: {'count': 1},
        ),
        const FeatureGrant(
          grantId: 'grant-spell',
          type: GrantType.bonusSpell,
          payload: {},
        ),
      ];

      final res = SpellAllocationValidator.validateSpellAllocations(
        character,
        grants,
      );
      expect(res.isValid, isFalse);
      expect(res.errors, anyElement(contains('Orphan spell allocation key "orphan-key"')));
      expect(res.errors, anyElement(contains('allows at most 1 cantrips')));
      expect(res.errors, anyElement(contains('allows at most 1 spells')));
    });
  });
}
