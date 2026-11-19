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

  group('Cantrip Allocation Routing & Spellbook Definition Querying Tests', () {
    test(
        'Non-cantrip named grant keys correctly route 0th-level spells to cantrips getter',
        () {
      final thaumaturgyRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'thaumaturgy',
        displayName: 'Thaumaturgy',
        customProperties: {'level': 0, 'isCantrip': true},
      );
      final sacredFlameRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'sacred-flame',
        displayName: 'Sacred Flame',
        customProperties: {'level': 0, 'isCantrip': true},
      );
      final blessRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'bless',
        displayName: 'Bless',
        customProperties: {'level': 1},
      );

      final character = Character(
        id: const EntityId(slug: 'tiefling_cleric', ruleset: RulesetVersion.v2024),
        name: 'Tiefling Cleric',
        speciesRef: const EntityReference.empty(
            refType: EntityType.species,
            slug: 'tiefling',
            displayName: 'Tiefling'),
        baseScores: const AbilityScores(
            strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10),
        progression: const CharacterProgression(classes: []),
        resources: const CharacterResourcePool(),
        allocatedSpells: {
          'infernal_legacy': [thaumaturgyRef],
          'celestial_bloodline': [sacredFlameRef],
          'domain_spells': [blessRef],
        },
      );

      // thaumaturgy and sacred-flame are level 0 (Cantrips), so they must be in cantrips getter
      expect(character.cantrips.map((s) => s.slug),
          containsAll(['thaumaturgy', 'sacred-flame']));
      expect(character.cantrips.map((s) => s.slug), isNot(contains('bless')));

      // bless is level 1, so it must be in spellsKnown and NOT cantrips
      expect(character.spellsKnown.map((s) => s.slug), contains('bless'));
      expect(character.spellsKnown.map((s) => s.slug),
          isNot(contains('thaumaturgy')));
      expect(character.spellsKnown.map((s) => s.slug),
          isNot(contains('sacred-flame')));
    });

    test(
        'Natively granted cantrips and spellsKnown are merged without duplicates',
        () {
      const lightRef = EntityReference<Spell>.empty(
        refType: EntityType.spell,
        slug: 'light',
        displayName: 'Light',
      );

      final character = Character(
        id: const EntityId(slug: 'aasimar_wizard', ruleset: RulesetVersion.v2024),
        name: 'Aasimar Wizard',
        speciesRef: const EntityReference.empty(
            refType: EntityType.species,
            slug: 'aasimar',
            displayName: 'Aasimar'),
        baseScores: const AbilityScores(
            strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10),
        progression: const CharacterProgression(classes: []),
        resources: const CharacterResourcePool(),
        cantrips: [lightRef],
        allocatedSpells: {
          'species_traits': [lightRef],
        },
      );

      // Ensure no duplicate 'light' cantrip is emitted
      expect(character.cantrips.length, equals(1));
      expect(character.cantrips.first.slug, equals('light'));
    });
  });
}
