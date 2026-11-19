import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

EntityId _id(String slug) => EntityId(slug: slug, ruleset: RulesetVersion.v2024);

EntityReference<DomainEntity> _ref(String slug, String name) =>
    EntityReference<DomainEntity>.empty(
      refType: EntityType.species,
      slug: slug,
      displayName: name,
    );

void main() {
  group('Step 8 Typed Contract Laws (Fixes 8.2, 8.3, 8.5)', () {
    test('Fix 8.2: calling calculateDerivedStat through core IRulesetModule with plain TabletopCharacter throws TypeError', () {
      const IRulesetModule<TabletopCharacter> coreRef =
          Dnd5eRulesetModule.v2024() as IRulesetModule<TabletopCharacter>;
      final plain = TabletopCharacter(
        id: _id('plain-1'),
        name: 'Plain Character',
      );

      expect(
        () => coreRef.calculateDerivedStat(character: plain, statKey: 'ac'),
        throwsA(isA<TypeError>()),
      );
    });

    test('Fix 8.3: 200 seeded characters return identical getter instances and identical inventory reads', () {
      for (var seed = 0; seed < 200; seed++) {
        final rng = Random(seed + 8300);
        final baseScores = AbilityScores(
          strength: 8 + rng.nextInt(13),
          dexterity: 8 + rng.nextInt(13),
          constitution: 8 + rng.nextInt(13),
          intelligence: 8 + rng.nextInt(13),
          wisdom: 8 + rng.nextInt(13),
          charisma: 8 + rng.nextInt(13),
        );
        final bonusScores = AbilityScores(
          strength: rng.nextInt(3),
          dexterity: rng.nextInt(3),
          constitution: rng.nextInt(3),
          intelligence: rng.nextInt(3),
          wisdom: rng.nextInt(3),
          charisma: rng.nextInt(3),
        );
        final progression = CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: _ref('fighter_$seed', 'Fighter'),
              level: 1 + rng.nextInt(20),
            ),
          ],
        );
        final resources = CharacterResourcePool(
          currentHp: 10 + rng.nextInt(50),
          tempHp: rng.nextInt(10),
          exhaustionLevel: rng.nextInt(6),
        );
        final inventory = List<InventoryItemInstance>.unmodifiable([
          for (var j = 0; j < 1 + rng.nextInt(3); j++)
            InventoryItemInstance(
              itemRef: _ref(j == 0 ? 'chain-shirt' : 'shield', j == 0 ? 'Chain Shirt' : 'Shield'),
              instanceId: 'inst_${seed}_$j',
              isEquipped: rng.nextBool(),
              equippedSlot: j == 0 ? EquipmentSlot.armor : EquipmentSlot.shield,
            ),
        ]);

        final c = Character(
          id: _id('char_$seed'),
          name: 'Hero $seed',
          speciesRef: _ref('human', 'Human'),
          progression: progression,
          baseScores: baseScores,
          bonusScores: bonusScores,
          inventory: inventory,
          resources: resources,
        );

        expect(identical(c.progression, progression), isTrue, reason: 'seed $seed progression');
        expect(identical(c.resources, resources), isTrue, reason: 'seed $seed resources');
        expect(identical(c.baseScores, baseScores), isTrue, reason: 'seed $seed baseScores');
        expect(identical(c.bonusScores, bonusScores), isTrue, reason: 'seed $seed bonusScores');
        expect(identical(c.inventory, inventory), isTrue, reason: 'seed $seed inventory');
        expect(identical(c.inventory, c.inventory), isTrue, reason: 'seed $seed two inventory reads');
      }
    });

    test('Fix 8.5: queryStat throws ArgumentError on unknown key and defaults to edition module for ac', () {
      final dex18Rogue = Character(
        id: _id('rogue-1'),
        name: 'Dex 18 Rogue',
        speciesRef: _ref('human', 'Human'),
        baseScores: const AbilityScores(dexterity: 18),
        rulesEdition: RulesetEdition.v2024,
      );

      expect(
        () => dex18Rogue.queryStat('zz_unknown'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('zz_unknown'),
          ),
        ),
      );

      const module = Dnd5eRulesetModule.v2024();
      expect(
        dex18Rogue.queryStat('ac'),
        equals(dex18Rogue.queryStat('ac', module: module)),
      );
      expect(dex18Rogue.queryStat('ac'), equals(14));
    });
  });
}
