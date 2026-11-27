import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

import '../helpers/map_diff_helper.dart';

Map<String, dynamic> _traitSnapshot(CreatureTrait t) => {
      'name': t.name,
      'description': t.description,
    };

Map<String, dynamic> _actionSnapshot(CreatureAction a) => {
      'name': a.name,
      'description': a.description,
      'attackType': a.attackType,
      'attackBonus': a.attackBonus,
      'reach': a.reach,
      'hitDamage': a.hitDamage,
    };

Map<String, dynamic> _statBlockFieldSnapshot(MonsterStatBlock sb) => {
      'id': sb.id,
      'name': sb.name,
      'sizeDisplay': sb.sizeDisplay,
      'crDisplay': sb.crDisplay,
      'typeDisplay': sb.typeDisplay,
      'alignment': sb.alignment,
      'ac': sb.ac,
      'armorType': sb.armorType,
      'maxHp': sb.maxHp,
      'hitDice': sb.hitDice,
      'speed': sb.speed,
      'strScore': sb.strScore,
      'dexScore': sb.dexScore,
      'conScore': sb.conScore,
      'intScore': sb.intScore,
      'wisScore': sb.wisScore,
      'chaScore': sb.chaScore,
      'savingThrows': sb.savingThrows,
      'skills': sb.skills,
      'damageVulnerabilities': sb.damageVulnerabilities,
      'damageResistances': sb.damageResistances,
      'damageImmunities': sb.damageImmunities,
      'conditionImmunities': sb.conditionImmunities,
      'senses': sb.senses,
      'languages': sb.languages,
      'xp': sb.xp,
      'traits': sb.traits.map(_traitSnapshot).toList(),
      'actions': sb.actions.map(_actionSnapshot).toList(),
      'reactions': sb.reactions.map(_actionSnapshot).toList(),
      'legendaryActions': sb.legendaryActions.map(_actionSnapshot).toList(),
      'explicitSpellSlots': sb.explicitSpellSlots == null
          ? null
          : {
              for (final e in sb.explicitSpellSlots!.entries)
                '${e.key}': e.value,
            },
      'explicitMeleeReachFt': sb.explicitMeleeReachFt,
      'explicitSavingThrows': sb.explicitSavingThrows == null
          ? null
          : {
              for (final e in sb.explicitSavingThrows!.entries)
                e.key.name: e.value,
            },
      'canFly': sb.canFly,
      'hasHover': sb.hasHover,
      'spellSaveDc': sb.spellSaveDc,
      'spellAttackBonus': sb.spellAttackBonus,
      'attackBonus': sb.attackBonus,
      'damageDiceCount': sb.damageDiceCount,
      'damageDiceSides': sb.damageDiceSides,
      'damageBonus': sb.damageBonus,
      'damageType': sb.damageType,
      'secondaryDamageDiceCount': sb.secondaryDamageDiceCount,
      'secondaryDamageDiceSides': sb.secondaryDamageDiceSides,
      'secondaryDamageType': sb.secondaryDamageType,
      'hasPackTactics': sb.hasPackTactics,
      'specialTrait': sb.specialTrait,
    };

CreatureAction _genAction(Random rng, String prefix, int seed, int idx) {
  return CreatureAction(
    name: '${prefix}_${seed}_$idx',
    description: 'Action description $seed-$idx',
    attackType: rng.nextBool() ? 'Melee Weapon Attack' : null,
    attackBonus: rng.nextBool() ? rng.nextInt(15) - 1 : null,
    reach: rng.nextBool() ? 'reach ${5 + rng.nextInt(3) * 5} ft.' : null,
    hitDamage: rng.nextBool() ? '${4 + rng.nextInt(20)} (2d6 + 2) slashing' : null,
  );
}

MonsterStatBlock _genStatBlock(int seed) {
  final rng = Random(seed);
  const sizes = ['Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Gargantuan'];
  const types = ['Beast', 'Undead', 'Dragon', 'Fiend', 'Elemental', 'Construct'];
  const crs = ['CR 0', 'CR 1/8', 'CR 1/4', 'CR 1/2', 'CR 1', 'CR 5', 'CR 13', 'CR 21'];
  const dmgTypes = ['Slashing', 'Piercing', 'Bludgeoning', 'Fire', 'Cold', 'Acid'];

  // Guarantee seed 1 has non-empty reactions/traits/actions/legendaryActions
  // so single-field omission mutations always trigger cleanly.
  final forceFull = seed == 1;
  final forceEmpty = seed == 2;

  final traitCount = forceFull ? 2 : (forceEmpty ? 0 : rng.nextInt(3));
  final actionCount = forceFull ? 2 : (forceEmpty ? 0 : rng.nextInt(3));
  final reactionCount = forceFull ? 2 : (forceEmpty ? 0 : rng.nextInt(3));
  final legendaryCount = forceFull ? 2 : (forceEmpty ? 0 : rng.nextInt(3));

  final slots = forceFull || (!forceEmpty && rng.nextBool())
      ? <int, int>{1: 4, 2: 3, 3: 2}
      : null;
  final explicitSaves = forceFull || (!forceEmpty && rng.nextBool())
      ? <AbilityType, int>{
          AbilityType.dexterity: 4 + rng.nextInt(6),
          AbilityType.wisdom: 2 + rng.nextInt(6),
        }
      : null;

  return MonsterStatBlock(
    id: 'statblock_seed_$seed',
    name: 'Seed Creature $seed',
    sizeDisplay: sizes[rng.nextInt(sizes.length)],
    crDisplay: crs[rng.nextInt(crs.length)],
    typeDisplay: types[rng.nextInt(types.length)],
    alignment: rng.nextBool() ? 'unaligned' : 'neutral evil',
    ac: 10 + rng.nextInt(14),
    armorType: forceFull || (!forceEmpty && rng.nextBool()) ? 'natural armor' : null,
    maxHp: 5 + rng.nextInt(300),
    hitDice: forceFull || (!forceEmpty && rng.nextBool()) ? '${1 + rng.nextInt(15)}d8 + 10' : null,
    speed: rng.nextBool() ? '30 ft., fly 60 ft.' : '40 ft.',
    strScore: 4 + rng.nextInt(22),
    dexScore: 4 + rng.nextInt(22),
    conScore: 4 + rng.nextInt(22),
    intScore: 2 + rng.nextInt(22),
    wisScore: 4 + rng.nextInt(22),
    chaScore: 2 + rng.nextInt(22),
    savingThrows: forceFull || (!forceEmpty && rng.nextBool()) ? 'DEX +5, WIS +4' : null,
    skills: forceFull || (!forceEmpty && rng.nextBool()) ? 'Perception +5, Stealth +6' : null,
    damageVulnerabilities: forceFull || (!forceEmpty && rng.nextBool()) ? 'cold' : null,
    damageResistances: forceFull || (!forceEmpty && rng.nextBool()) ? 'fire, poison' : null,
    damageImmunities: forceFull || (!forceEmpty && rng.nextBool()) ? 'necrotic' : null,
    conditionImmunities: forceFull || (!forceEmpty && rng.nextBool()) ? 'charmed, frightened' : null,
    senses: rng.nextBool() ? 'darkvision 60 ft., passive Perception 14' : 'passive Perception 10',
    languages: rng.nextBool() ? 'Common, Draconic' : '—',
    xp: forceFull || (!forceEmpty && rng.nextBool()) ? 50 * (1 + rng.nextInt(100)) : null,
    traits: [
      for (var i = 0; i < traitCount; i++)
        CreatureTrait(
          name: i == 0 && forceFull ? 'Legendary Resistance (3/Day)' : 'Trait_${seed}_$i',
          description: 'Trait desc $seed-$i',
        ),
    ],
    actions: [
      for (var i = 0; i < actionCount; i++) _genAction(rng, 'Action', seed, i),
    ],
    reactions: [
      for (var i = 0; i < reactionCount; i++) _genAction(rng, 'Reaction', seed, i),
    ],
    legendaryActions: [
      for (var i = 0; i < legendaryCount; i++) _genAction(rng, 'Legendary', seed, i),
    ],
    explicitSpellSlots: slots,
    explicitMeleeReachFt: forceFull || (!forceEmpty && rng.nextBool()) ? 10 : null,
    explicitSavingThrows: explicitSaves,
    canFly: forceFull || (!forceEmpty && rng.nextBool()) ? rng.nextBool() : null,
    hasHover: forceFull || (!forceEmpty && rng.nextBool()) ? rng.nextBool() : null,
    spellSaveDc: forceFull || (!forceEmpty && rng.nextBool()) ? 12 + rng.nextInt(8) : null,
    spellAttackBonus: forceFull || (!forceEmpty && rng.nextBool()) ? 4 + rng.nextInt(8) : null,
    attackBonus: 2 + rng.nextInt(12),
    damageDiceCount: 1 + rng.nextInt(4),
    damageDiceSides: [4, 6, 8, 10, 12][rng.nextInt(5)],
    damageBonus: rng.nextInt(8) - 1,
    damageType: dmgTypes[rng.nextInt(dmgTypes.length)],
    secondaryDamageDiceCount: forceFull || (!forceEmpty && rng.nextBool()) ? 1 + rng.nextInt(2) : 0,
    secondaryDamageDiceSides: forceFull || (!forceEmpty && rng.nextBool()) ? 6 : 0,
    secondaryDamageType: forceFull || (!forceEmpty && rng.nextBool()) ? 'Fire' : null,
    hasPackTactics: rng.nextBool(),
    specialTrait: forceFull || (!forceEmpty && rng.nextBool()) ? 'Special trait $seed' : null,
  );
}

void main() {
  group('Fix 5.1: MonsterStatBlock round-trip, equality, and hashCode laws', () {
    test('500-seed round-trip law: MonsterStatBlock -> toMap -> fromMap preserves all fields', () {
      for (var seed = 1; seed <= 500; seed++) {
        final original = _genStatBlock(seed);
        final roundTripped = MonsterStatBlock.fromMap(original.toMap());

        expectMapsEqualWithDiff(
          _statBlockFieldSnapshot(roundTripped),
          _statBlockFieldSnapshot(original),
          seed: seed,
          typeName: 'MonsterStatBlock',
        );
        expect(
          roundTripped,
          equals(original),
          reason: 'Equality failed on seed $seed',
        );
        expect(
          roundTripped.hashCode,
          equals(original.hashCode),
          reason: 'hashCode disagreed on seed $seed',
        );
      }
    });

    test('equality and hashCode distinguish field differences and support copyWith', () {
      final a = _genStatBlock(1);
      final b = _genStatBlock(1);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.hasLegendary, isTrue);
      expect(a.hasLegendaryResistance, isTrue);
      expect(a.hasLegendaryActions, isTrue);
      expect(a.strMod, equals(a.strScore.dndModifier));
      expect(a.dexMod, equals(a.dexScore.dndModifier));
      expect(a.conMod, equals(a.conScore.dndModifier));
      expect(a.intMod, equals(a.intScore.dndModifier));
      expect(a.wisMod, equals(a.wisScore.dndModifier));
      expect(a.chaMod, equals(a.chaScore.dndModifier));

      final modified = a.copyWith(name: 'Different Name');
      expect(modified, isNot(equals(a)));
      expect(a.copyWith(reactions: const []), isNot(equals(a)));
      expect(a.copyWith(traits: const []), isNot(equals(a)));
      expect(a.copyWith(actions: const []), isNot(equals(a)));
      expect(a.copyWith(legendaryActions: const []), isNot(equals(a)));
      expect(a.copyWith(explicitSpellSlots: const {1: 9}), isNot(equals(a)));
      expect(
        a.copyWith(explicitSavingThrows: const {AbilityType.strength: 9}),
        isNot(equals(a)),
      );

      expect(SummonCategory.values, [SummonCategory.spell, SummonCategory.magicItem]);
    });
  });
}
