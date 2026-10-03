import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
void main() {
  group('CharacterEvaluationEngine Tests', () {
    test('Calculates standard unarmored AC (10 + DEX)', () {
      const character = Character(
        id: EntityId(slug: 'hero-1', ruleset: RulesetVersion.v2024),
        name: 'Rogue Hero',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'rogue',
                displayName: 'Rogue',
              ),
              level: 1,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(dexterity: 16), // Mod +3
        resources: CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.abilityModifiers[AbilityType.dexterity], equals(3));
      expect(stats.armorClass, equals(13)); // 10 + 3
    });

    test('Plate Armor sets flat AC 18 and ignores DEX bonus', () {
      final character = Character(
        id: const EntityId(slug: 'hero-plate', ruleset: RulesetVersion.v2024),
        name: 'Knight',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 1,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: const AbilityScores(dexterity: 18), // Mod +4
        inventory: [
          InventoryItemInstance(
            instanceId: 'plate-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'plate',
              displayName: 'Plate Armor',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
            customProperties: {
              'baseAc': 18,
              'armorType': 'heavy',
            },
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.armorClass, equals(18));
      expect(stats.armorClassBreakdown, contains('18 (Plate Armor)'));
    });

    test('Medium Armor (Breastplate) caps DEX contribution at maxDexBonus (+2)',
        () {
      final character = Character(
        id: const EntityId(slug: 'hero-med', ruleset: RulesetVersion.v2024),
        name: 'Ranger',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'ranger',
                displayName: 'Ranger',
              ),
              level: 1,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: const AbilityScores(dexterity: 18), // Mod +4
        inventory: [
          InventoryItemInstance(
            instanceId: 'breastplate-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'breastplate',
              displayName: 'Breastplate',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
            customProperties: {
              'baseAc': 14,
              'armorType': 'medium',
              'maxDexBonus': 2,
            },
          ),
          InventoryItemInstance(
            instanceId: 'shield-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
            customProperties: {
              'acBonus': 2,
            },
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      // 14 + min(4, 2) + 2 = 18
      expect(stats.armorClass, equals(18));
    });

    test(
        'Barbarian Unarmored Defense calculates 10 + DEX + CON (allows shield)',
        () {
      final character = Character(
        id: const EntityId(slug: 'barb-1', ruleset: RulesetVersion.v2024),
        name: 'Krag',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'goliath',
          displayName: 'Goliath',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'barbarian',
                displayName: 'Barbarian',
              ),
              level: 1,
              hitDie: 'd12',
            ),
          ],
        ),
        baseScores: const AbilityScores(
          dexterity: 14, // Mod +2
          constitution: 16, // Mod +3
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'shield-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
            customProperties: {
              'acBonus': 2,
            },
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 15),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      // 10 + 2 (DEX) + 3 (CON) + 2 (Shield) = 17
      expect(stats.armorClass, equals(17));
    });

    test(
        'Monk Unarmored Defense calculates 10 + DEX + WIS (disallowed if shield equipped)',
        () {
      const characterNoShield = Character(
        id: EntityId(slug: 'monk-1', ruleset: RulesetVersion.v2024),
        name: 'Li',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'monk',
                displayName: 'Monk',
              ),
              level: 1,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 16, // Mod +3
          wisdom: 16, // Mod +3
        ),
        resources: CharacterResourcePool(currentHp: 10),
      );

      final statsNoShield =
          CharacterEvaluationEngine.evaluate(characterNoShield);
      // 10 + 3 (DEX) + 3 (WIS) = 16
      expect(statsNoShield.armorClass, equals(16));

      final characterWithShield = Character(
        id: const EntityId(slug: 'monk-2', ruleset: RulesetVersion.v2024),
        name: 'Li With Shield',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'monk',
                displayName: 'Monk',
              ),
              level: 1,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: const AbilityScores(
          dexterity: 16, // Mod +3
          wisdom: 16, // Mod +3
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'shield-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
            customProperties: {'acBonus': 2},
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 10),
      );

      final statsWithShield =
          CharacterEvaluationEngine.evaluate(characterWithShield);
      // Monk Unarmored Defense disabled: fallback to 10 + 3 (DEX) + 2 (Shield) = 15
      expect(statsWithShield.armorClass, equals(15));
    });

    test(
        'Stat Overrides (Belt of Giant Strength) correctly override lower base stat when attuned',
        () {
      final character = Character(
        id: const EntityId(slug: 'hero-belt', ruleset: RulesetVersion.v2024),
        name: 'Thorek',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'dwarf',
          displayName: 'Dwarf',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 5,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 14), // Base Mod +2
        inventory: [
          InventoryItemInstance(
            instanceId: 'belt-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'belt-hill-giant',
              displayName: 'Belt of Hill Giant Strength',
            ),
            isEquipped: true,
            isAttuned: true,
            requiresAttunement: true,
            customProperties: {
              'overrideStrength': 21,
            },
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 40),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.effectiveScores.strength, equals(21));
      expect(stats.abilityModifiers[AbilityType.strength],
          equals(5)); // (21-10)/2 = 5
    });

    test('Attunement item bonuses are ignored if item is not attuned', () {
      final character = Character(
        id: const EntityId(slug: 'hero-unattuned', ruleset: RulesetVersion.v2024),
        name: 'Unattuned Hero',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 1,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 14),
        inventory: [
          InventoryItemInstance(
            instanceId: 'ring-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'ring-protection',
              displayName: 'Ring of Protection',
            ),
            isEquipped: true,
            isAttuned: false, // Unattuned
            requiresAttunement: true,
            customProperties: {
              'acBonus': 1,
            },
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.armorClass, equals(10)); // AC bonus not applied
    });

    test(
        'Character evaluation scales attunement slots dynamically via customProperties and feats',
        () {
      // Base character: standard 3 slots
      const baseChar = Character(
        id: EntityId(slug: 'hero-1', ruleset: RulesetVersion.v2024),
        name: 'Novice Hero',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'gnome',
          displayName: 'Gnome',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'wizard',
                displayName: 'Wizard',
              ),
              level: 5,
              hitDie: 'd6',
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(currentHp: 30),
      );
      expect(
          CharacterEvaluationEngine.evaluate(baseChar)
              .effectiveMaxAttunementSlots,
          equals(3));

      // Character with overrideMaxAttunementSlots = 4
      final charOverride = baseChar.copyWith(
        customProperties: {'overrideMaxAttunementSlots': 4},
      );
      expect(
          CharacterEvaluationEngine.evaluate(charOverride)
              .effectiveMaxAttunementSlots,
          equals(4));

      // Character with attunementSlotBonus = 2
      final charBonus = baseChar.copyWith(
        customProperties: {'attunementSlotBonus': 2},
      );
      expect(
          CharacterEvaluationEngine.evaluate(charBonus)
              .effectiveMaxAttunementSlots,
          equals(5));

      // Character with feat granting attunementSlotBonus = 3
      final charFeat = baseChar.copyWith(
        feats: const [
          EntityReference<DomainEntity>(
            refType: EntityType.feat,
            slug: 'attunement-master',
            displayName: 'Attunement Master',
            customProperties: {'attunementSlotBonus': 3},
          ),
        ],
      );
      expect(
          CharacterEvaluationEngine.evaluate(charFeat)
              .effectiveMaxAttunementSlots,
          equals(6));
    });

    test(
        'Calculates Skill modifiers and Proficiency multipliers (Proficient & Expertise)',
        () {
      const character = Character(
        id: EntityId(slug: 'rogue-expert', ruleset: RulesetVersion.v2024),
        name: 'Master Thief',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'halfling',
          displayName: 'Halfling',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'rogue',
                displayName: 'Rogue',
              ),
              level: 5, // PB = +3
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 16, // Mod +3
          wisdom: 12, // Mod +1
        ),
        skillProficiencies: {
          SkillType.stealth:
              SkillProficiencyLevel.expertise, // DEX Mod + (2 * 3) = +9
          SkillType.perception:
              SkillProficiencyLevel.proficient, // WIS Mod + (1 * 3) = +4
          SkillType.athletics: SkillProficiencyLevel.none, // STR Mod 0 = 0
        },
        resources: CharacterResourcePool(currentHp: 30),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.proficiencyBonus, equals(3));
      expect(stats.skillModifiers[SkillType.stealth], equals(9));
      expect(stats.skillModifiers[SkillType.perception], equals(4));
      expect(stats.skillModifiers[SkillType.athletics], equals(0));
      expect(stats.passivePerception, equals(14)); // 10 + 4
    });

    test(
        'Subclass with attackAbilitySubstitution grant wielding magic weapon uses INT when INT > STR/DEX',
        () {
      final character = Character(
        id: const EntityId(slug: 'artisan-hero', ruleset: RulesetVersion.v2024),
        name: 'Gnome Crafter',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'gnome',
          displayName: 'Gnome',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'arcane-crafter',
                displayName: 'Arcane Crafter',
              ),
              subclassRef: EntityReference<DomainEntity>(
                refType: EntityType.subclass,
                slug: 'steel-artisan',
                displayName: 'Steel Artisan',
              ),
              level: 3,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 10, // Mod 0
          dexterity: 12, // Mod +1
          intelligence: 18, // Mod +4
        ),
        customProperties: {
          'grants': [
            FeatureGrant.attackAbilitySubstitution(
              grantId: 'artisan-battle-ready',
              ability: AbilityType.intelligence,
              requiresMagicWeapon: true,
              label: 'Battle Ready',
            ),
          ],
        },
        inventory: [
          InventoryItemInstance(
            instanceId: 'magic-longsword',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'longsword-plus-1',
              displayName: 'Longsword +1',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.mainHand,
            customProperties: {
              'isWeapon': true,
              'weaponType': 'martial',
              'damageDice': '1d8',
              'damageType': 'slashing',
              'isMagic': true,
              'attackBonus': 1,
              'magicBonus': 1,
            },
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 25),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.attackProfiles.length, equals(1));
      final atk = stats.attackProfiles.first;
      // PB (+2) + INT Mod (+4) + Magic (+1) = +7
      expect(atk.attackBonus, equals(7));
      expect(atk.attackBonusString, equals('+7'));
      // 1d8 + 4 (INT) + 1 (Magic) = 1d8 + 5
      expect(atk.damageFormula, equals('1d8 + 5'));
    });

    test(
        'Handaxe (Thrown) uses STR whereas Dagger (Finesse, Thrown) uses DEX if DEX > STR',
        () {
      final character = Character(
        id: const EntityId(slug: 'ranger-skirmisher', ruleset: RulesetVersion.v2024),
        name: 'Skirmisher',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'ranger',
                displayName: 'Ranger',
              ),
              level: 2,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 12, // Mod +1
          dexterity: 16, // Mod +3
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'handaxe-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'handaxe',
              displayName: 'Handaxe',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.mainHand,
            customProperties: {
              'isWeapon': true,
              'damageDice': '1d6',
              'damageType': 'slashing',
              'isThrown': true,
            },
          ),
          InventoryItemInstance(
            instanceId: 'dagger-1',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'dagger',
              displayName: 'Dagger',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.offHand,
            customProperties: {
              'isWeapon': true,
              'damageDice': '1d4',
              'damageType': 'piercing',
              'isFinesse': true,
              'isThrown': true,
            },
          ),
        ],
        resources: const CharacterResourcePool(currentHp: 20),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.attackProfiles.length, equals(2));

      final handaxeAtk =
          stats.attackProfiles.firstWhere((a) => a.weaponName == 'Handaxe');
      // PB (+2) + STR (+1) = +3
      expect(handaxeAtk.attackBonus, equals(3));
      expect(handaxeAtk.damageFormula, equals('1d6 + 1'));

      final daggerAtk =
          stats.attackProfiles.firstWhere((a) => a.weaponName == 'Dagger');
      // PB (+2) + DEX (+3) = +5
      expect(daggerAtk.attackBonus, equals(5));
      expect(daggerAtk.isOffhand, isTrue);
    });
  });
}