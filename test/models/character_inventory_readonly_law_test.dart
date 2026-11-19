import 'dart:convert';
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

  group('Fix 4.1 Law: Character read-only collection getters on every construction path', () {
    const humanRef = EntityReference<DomainEntity>.empty(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    );
    const probeSpell = EntityReference<Spell>.empty(
      refType: EntityType.spell,
      slug: 'light',
      displayName: 'Light',
    );
    final probeItem = InventoryItemInstance(
      instanceId: 'probe-item',
      itemRef: const EntityReference<DomainEntity>.empty(
        refType: EntityType.equipment,
        slug: 'dagger',
        displayName: 'Dagger',
      ),
      quantity: 1,
    );

    List<InventoryItemInstance> genItems(Random rng, int count, int seed) {
      return [
        for (var j = 0; j < count; j++)
          InventoryItemInstance(
            instanceId: 'item-$seed-$j',
            itemRef: EntityReference<DomainEntity>.empty(
              refType: EntityType.equipment,
              slug: 'item-slug-$j',
              displayName: 'Item $j',
            ),
            quantity: 1 + rng.nextInt(5),
          ),
      ];
    }

    void assertReadOnly(Character ch, String label) {
      final before = jsonEncode(ch.toMap());

      expect(
        () => ch.inventory.add(probeItem),
        throwsUnsupportedError,
        reason: '$label: inventory.add must throw UnsupportedError',
      );
      if (ch.inventory.isNotEmpty) {
        expect(
          () => ch.inventory.removeAt(0),
          throwsUnsupportedError,
          reason: '$label: inventory.removeAt must throw UnsupportedError',
        );
      }
      expect(
        () => ch.cantrips.add(probeSpell),
        throwsUnsupportedError,
        reason: '$label: cantrips.add must throw UnsupportedError',
      );
      expect(
        () => ch.spellsKnown.add(probeSpell),
        throwsUnsupportedError,
        reason: '$label: spellsKnown.add must throw UnsupportedError',
      );
      expect(
        () => ch.activeGrants.clear(),
        throwsUnsupportedError,
        reason: '$label: activeGrants.clear must throw UnsupportedError',
      );

      expect(
        jsonEncode(ch.toMap()),
        equals(before),
        reason: '$label: toMap must be unchanged after failed mutation attempts',
      );
    }

    test(
      '120 seeded characters across constructor, fromMap, copyWith (without/with new inventory)',
      () {
        final rng = Random(140401);

        for (var seed = 0; seed < 120; seed++) {
          final edition =
              seed.isEven ? RulesetEdition.v2014 : RulesetEdition.v2024;
          final items = genItems(rng, rng.nextInt(6), seed); // 0..5 items
          final cantrips = [
            for (var k = 0; k < rng.nextInt(3); k++)
              EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'cantrip-$k',
                displayName: 'Cantrip $k',
              ),
          ];
          final known = [
            for (var k = 0; k < rng.nextInt(3); k++)
              EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: 'known-$k',
                displayName: 'Known $k',
              ),
          ];

          // 1. Constructor
          final constructed = Character(
            id: EntityId(
              slug: 'char-$seed',
              ruleset: edition == RulesetEdition.v2024
                  ? RulesetVersion.v2024
                  : RulesetVersion.v2014,
            ),
            name: 'Hero $seed',
            rulesEdition: edition,
            speciesRef: humanRef,
            inventory: items,
            cantrips: cantrips,
            spellsKnown: known,
          );
          assertReadOnly(constructed, 'seed=$seed constructor');

          // 2. fromMap(toMap())
          final fromMap = Character.fromMap(constructed.toMap());
          assertReadOnly(fromMap, 'seed=$seed fromMap');

          // 3. copyWith without new inventory
          final copiedSame = constructed.copyWith(name: 'Hero $seed Renamed');
          assertReadOnly(copiedSame, 'seed=$seed copyWith(no inventory)');

          // 4. copyWith with new mutable inventory
          final newItems = genItems(rng, rng.nextInt(6), seed + 1000);
          final copiedNew = constructed.copyWith(inventory: newItems);
          assertReadOnly(copiedNew, 'seed=$seed copyWith(new inventory)');
        }
      },
    );
  });
}
