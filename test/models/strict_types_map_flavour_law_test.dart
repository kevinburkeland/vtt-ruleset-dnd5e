import 'dart:convert';
import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_engine_core/crdt/pn_counter.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

import '../helpers/test_dnd5e_catalog.dart';

String _canonicalJson(Object? value) {
  return jsonEncode(_canonicalize(value));
}

Object? _canonicalize(Object? value) {
  if (value is Map<Object?, Object?>) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    final result = <String, Object?>{};
    for (final k in sortedKeys) {
      Object? matchedVal;
      for (final entry in value.entries) {
        if (entry.key.toString() == k) {
          matchedVal = entry.value;
          break;
        }
      }
      result[k] = _canonicalize(matchedVal);
    }
    return result;
  }
  if (value is Iterable<Object?>) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

Map<String, dynamic> _toDynamicFlavourTop(Map<String, dynamic> source) {
  final out = <String, dynamic>{};
  source.forEach((key, value) {
    out[key] = _toDynamicFlavourValue(value);
  });
  return out;
}

dynamic _toDynamicFlavourValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    final copy = <dynamic, dynamic>{};
    value.forEach((k, v) {
      copy[k] = _toDynamicFlavourValue(v);
    });
    return copy;
  }
  if (value is Iterable<Object?>) {
    final copy = <dynamic>[];
    for (final item in value) {
      copy.add(_toDynamicFlavourValue(item));
    }
    return copy;
  }
  return value;
}

Map<String, dynamic> _toObjectQuestionFlavourTop(Map<String, dynamic> source) {
  final out = <String, dynamic>{};
  source.forEach((key, value) {
    out[key] = _toObjectQuestionFlavourValue(value);
  });
  return out;
}

Object? _toObjectQuestionFlavourValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    final copy = <Object?, Object?>{};
    value.forEach((k, v) {
      copy[k] = _toObjectQuestionFlavourValue(v);
    });
    return copy;
  }
  if (value is Iterable<Object?>) {
    final copy = <Object?>[];
    for (final item in value) {
      copy.add(_toObjectQuestionFlavourValue(item));
    }
    return copy;
  }
  return value;
}

void _assertFourFlavoursMatch({
  required String typeName,
  required int seed,
  required Map<String, dynamic> originalMap,
  required Map<String, dynamic> Function(Map<String, dynamic> input) roundTrip,
}) {
  final f1Input = originalMap;
  final f2Input = Map<String, dynamic>.from(
    jsonDecode(jsonEncode(originalMap)) as Map<dynamic, dynamic>,
  );
  final f3Input = _toDynamicFlavourTop(originalMap);
  final f4Input = _toObjectQuestionFlavourTop(originalMap);

  final f1Out = roundTrip(f1Input);
  final f2Out = roundTrip(f2Input);
  final f3Out = roundTrip(f3Input);
  final f4Out = roundTrip(f4Input);

  final flavours = <String, Map<String, dynamic>>{
    'jsonDecode(jsonEncode)': f2Out,
    'Map<dynamic, dynamic>': f3Out,
    'Map<Object?, Object?>': f4Out,
  };

  final allKeys = <String>{
    ...f1Out.keys,
    ...f2Out.keys,
    ...f3Out.keys,
    ...f4Out.keys,
  }.toList()
    ..sort();

  for (final entry in flavours.entries) {
    final flavourName = entry.key;
    final candidate = entry.value;
    for (final field in allKeys) {
      final c1 = _canonicalJson(f1Out[field]);
      final cOther = _canonicalJson(candidate[field]);
      if (c1 != cOther) {
        fail(
          '$typeName map-flavour mismatch at seed=$seed '
          '(flavour "$flavourName"), first differing field "$field":\n'
          '  as-produced: $c1\n'
          '  $flavourName: $cOther',
        );
      }
    }
    final full1 = _canonicalJson(f1Out);
    final fullOther = _canonicalJson(candidate);
    if (full1 != fullOther) {
      fail(
        '$typeName map-flavour mismatch at seed=$seed '
        '(flavour "$flavourName")',
      );
    }
  }
}

int _variedCount(Random rng, int seed) {
  if (seed == 0) return 2;
  if (seed == 1) return 0;
  return rng.nextInt(4); // 0, 1, 2, or 3
}

EntityReference<T> _randomRef<T extends DomainEntity>(
  Random rng,
  EntityType refType,
  String prefix,
  int index,
) {
  final propCount = rng.nextInt(3);
  final props = <String, dynamic>{};
  for (var i = 0; i < propCount; i++) {
    props['prop_$i'] = i.isEven ? 'val_${rng.nextInt(50)}' : rng.nextInt(20);
  }
  final skillCount = rng.nextInt(3);
  final skills = List<String>.generate(skillCount, (i) => 'athletics_$i');
  return EntityReference<T>(
    refType: refType,
    slug: '$prefix-$index-${rng.nextInt(1000)}',
    displayName: '$prefix Name $index',
    rulesetPreferred:
        RulesetVersion.values[rng.nextInt(RulesetVersion.values.length)],
    grantedSkills: skills,
    customProperties: props,
  );
}

EvaluationMath _randomEvalMath(Random rng, int index) {
  return EvaluationMath(
    diceFormula: '${1 + rng.nextInt(4)}d${6 + (rng.nextInt(3) * 2)}',
    damageType: DamageType.values[rng.nextInt(DamageType.values.length)],
    scalingFormula: rng.nextBool() ? '+1d6 per slot' : null,
    isAttackRoll: index.isEven,
    requiresSave: index.isOdd,
  );
}

FeatureGrant _randomGrant(Random rng, int index) {
  return FeatureGrant(
    type: GrantType.values[rng.nextInt(GrantType.values.length)],
    grantId: 'grant-$index-${rng.nextInt(1000)}',
    payload: <String, dynamic>{
      'amount': 1 + rng.nextInt(5),
      if (rng.nextBool()) 'ability': 'strength',
    },
    label: rng.nextBool() ? 'Grant Label $index' : null,
  );
}

InventoryItemInstance _randomInventoryItem(Random rng, int index) {
  final isEq = rng.nextBool();
  return InventoryItemInstance(
    itemRef: _randomRef<DomainEntity>(rng, EntityType.equipment, 'eq', index),
    instanceId: 'inst-$index-${rng.nextInt(1000)}',
    quantity: 1 + rng.nextInt(4),
    isEquipped: isEq,
    equippedSlot: isEq
        ? EquipmentSlot.values[rng.nextInt(EquipmentSlot.values.length)]
        : null,
    customProperties: <String, dynamic>{
      'weight': 1 + rng.nextInt(10),
      if (rng.nextBool()) 'nested': <String, dynamic>{'bonus': 1},
    },
    customName: rng.nextBool() ? 'Custom Item $index' : null,
    notes: rng.nextBool() ? 'Item note $index' : null,
    isAttuned: rng.nextBool(),
    requiresAttunement: rng.nextBool(),
  );
}

PartyPurse _randomPurse(Random rng, int seed) {
  if (seed == 1 || (seed > 1 && rng.nextInt(4) == 0)) {
    return const PartyPurse.empty();
  }
  return PartyPurse(
    denominationCounters: <String, PnCounter>{
      'gp': PnCounter(
        positive: <String, int>{'node-a': 10 + rng.nextInt(100)},
      ),
      if (rng.nextBool())
        'sp': PnCounter(
          positive: <String, int>{'node-b': 1 + rng.nextInt(50)},
        ),
    },
  );
}

Character _buildRandomCharacter(int seed) {
  final rng = Random(seed ^ 0x5F3759DF);
  final classCount = seed == 1 ? 0 : (1 + rng.nextInt(2));
  final invCount = _variedCount(rng, seed);
  final cantripCount = _variedCount(rng, seed);
  final knownCount = _variedCount(rng, seed);
  final prepCount = _variedCount(rng, seed);
  final featCount = _variedCount(rng, seed);
  final condCount = _variedCount(rng, seed);
  final toolCount = _variedCount(rng, seed);
  final langCount = _variedCount(rng, seed);

  final classes = List<ClassLevelProgression>.generate(classCount, (i) {
    return ClassLevelProgression(
      classRef: _randomRef<DomainEntity>(
        rng,
        EntityType.classDefinition,
        'class',
        i,
      ),
      subclassRef: rng.nextBool()
          ? _randomRef<DomainEntity>(rng, EntityType.subclass, 'sub', i)
          : null,
      level: 1 + rng.nextInt(5),
      isStartingClass: i == 0,
      selectedFeatureOptions: <String, List<String>>{
        'fighting_style': <String>['defense_$i'],
      },
      customProperties: <String, dynamic>{'caster': i.isEven},
      hitDie: 'd${8 + (i % 3) * 2}',
      hitPointsRolled: <int>[8, 5 + rng.nextInt(4)],
    );
  });

  final cantrips = List<EntityReference<Spell>>.generate(
    cantripCount,
    (i) => _randomRef<Spell>(rng, EntityType.spell, 'cantrip', i),
  );
  final spellsKnown = List<EntityReference<Spell>>.generate(
    knownCount,
    (i) => _randomRef<Spell>(rng, EntityType.spell, 'known', i),
  );
  final spellsPrepared = List<EntityReference<Spell>>.generate(
    prepCount,
    (i) => _randomRef<Spell>(rng, EntityType.spell, 'prep', i),
  );

  final allocated = <String, List<EntityReference<Spell>>>{
    if (cantrips.isNotEmpty) 'cantrips': cantrips,
    if (spellsKnown.isNotEmpty) 'spellsKnown': spellsKnown,
    if (seed == 0 || (seed > 1 && rng.nextBool()))
      'class_bonus': List<EntityReference<Spell>>.generate(
        1 + rng.nextInt(2),
        (i) => _randomRef<Spell>(rng, EntityType.spell, 'alloc', i),
      ),
  };

  return Character(
    id: EntityId(
      slug: 'char-$seed-${rng.nextInt(1000)}',
      ruleset: RulesetVersion.values[rng.nextInt(RulesetVersion.values.length)],
    ),
    name: 'Adventurer $seed',
    speciesRef: _randomRef<DomainEntity>(rng, EntityType.species, 'spec', seed),
    backgroundRef: (seed == 0 || rng.nextBool())
        ? _randomRef<DomainEntity>(rng, EntityType.background, 'bg', seed)
        : null,
    progression: CharacterProgression(
      classes: classes,
      experiencePoints: rng.nextInt(10000),
      manualHpRolls: seed == 1
          ? const <int, int>{}
          : <int, int>{1: 8, 2: 5 + rng.nextInt(4)},
    ),
    baseScores: AbilityScores(
      strength: 8 + rng.nextInt(10),
      dexterity: 8 + rng.nextInt(10),
      constitution: 8 + rng.nextInt(10),
      intelligence: 8 + rng.nextInt(10),
      wisdom: 8 + rng.nextInt(10),
      charisma: 8 + rng.nextInt(10),
    ),
    bonusScores: AbilityScores(
      strength: seed == 1 ? 0 : rng.nextInt(3),
      dexterity: seed == 1 ? 0 : rng.nextInt(2),
    ),
    traitProficiencies: seed == 1
        ? const <String, double>{}
        : <String, double>{'athletics': 1.0, 'stealth': 2.0},
    savingThrowProficiencies: seed == 1
        ? const <String>{}
        : <String>{'strength', 'constitution'},
    toolProficiencies: List<String>.generate(toolCount, (i) => 'tool_$i'),
    languages: List<String>.generate(
      langCount == 0 ? 1 : langCount,
      (i) => 'Lang_$i',
    ),
    inventory: List<InventoryItemInstance>.generate(
      invCount,
      (i) => _randomInventoryItem(rng, i),
    ),
    purse: _randomPurse(rng, seed),
    allocatedSpells: allocated,
    cantrips: cantrips,
    spellsKnown: spellsKnown,
    spellsPrepared: spellsPrepared,
    feats: List<EntityReference<DomainEntity>>.generate(
      featCount,
      (i) => _randomRef<DomainEntity>(rng, EntityType.feat, 'feat', i),
    ),
    resources: CharacterResourcePool(
      currentHp: 12 + rng.nextInt(30),
      tempHp: rng.nextInt(8),
      currentHitDice: seed == 1
          ? const <String, int>{}
          : <String, int>{'d8': 1 + rng.nextInt(3)},
      spellSlots: SpellSlotPool(
        currentSlots: seed == 1
            ? const <int, int>{}
            : <int, int>{1: 2, 2: 1},
        maxSlots: seed == 1
            ? const <int, int>{}
            : <int, int>{1: 4, 2: 2},
        pactMagicSlotLevel: rng.nextInt(3),
        pactMagicMax: rng.nextInt(3),
        pactMagicCurrent: rng.nextInt(2),
      ),
      customResourcesCurrent: seed == 1
          ? const <String, int>{}
          : <String, int>{'ki': 2},
      customResourcesMax: seed == 1
          ? const <String, int>{}
          : <String, int>{'ki': 4},
      deathSaveSuccesses: rng.nextInt(3),
      deathSaveFailures: rng.nextInt(3),
      exhaustionLevel: rng.nextInt(4),
      hasHeroicInspiration: rng.nextBool(),
    ),
    conditions: List<CharacterCondition>.generate(
      condCount,
      (i) => CharacterCondition(
        conditionId: 'cond_$i',
        name: 'Condition $i',
        durationRounds: 1 + rng.nextInt(5),
        sourceEntityId: rng.nextBool() ? 'src_$i' : null,
        customProperties: <String, dynamic>{'tier': 1 + i},
      ),
    ),
    maxAttunementSlots: 3 + rng.nextInt(2),
    baseSpeedFeet: 25 + (rng.nextInt(3) * 5),
    rulesetId: seed.isEven ? 'dnd5e_2014' : 'dnd5e_2024',
    customProperties: seed == 1
        ? const <String, dynamic>{}
        : <String, dynamic>{
            'notes': 'hero_notes_$seed',
            'nested': <String, dynamic>{'chapter': seed},
          },
  );
}

Spell _buildRandomSpell(int seed) {
  final rng = Random(seed ^ 0x9E3779B9);
  final mathCount = _variedCount(rng, seed);
  final refCount = _variedCount(rng, seed);
  final propCount = _variedCount(rng, seed);

  final props = <String, dynamic>{};
  for (var i = 0; i < propCount; i++) {
    props['k_$i'] = i.isEven ? <String>['wizard', 'cleric'] : 'val_$i';
  }
  if (rng.nextBool()) {
    props['classes'] = <String>['Wizard', 'Sorcerer'];
  }

  final dist = (1 + rng.nextInt(12)) * 10;
  return Spell(
    id: EntityId(
      slug: 'spell-$seed-${rng.nextInt(1000)}',
      ruleset: RulesetVersion.values[rng.nextInt(RulesetVersion.values.length)],
    ),
    name: 'Arcane Burst $seed',
    level: rng.nextInt(10),
    school: SpellSchool.values[rng.nextInt(SpellSchool.values.length)].displayName,
    castingTime: CastingTime(
      cost: 1 + rng.nextInt(2),
      actionType: ActionType.values[rng.nextInt(ActionType.values.length)],
      triggerCondition: rng.nextBool() ? 'when hit' : null,
    ),
    duration: SpellDuration(
      type: DurationType.values[rng.nextInt(DurationType.values.length)],
      durationSeconds: rng.nextInt(600),
      requiresConcentration: rng.nextBool(),
      rawText: rng.nextBool() ? '1 minute' : null,
    ),
    range: '$dist feet',
    rangeDistanceFeet: dist,
    rangeType: 'ranged',
    damageType: rng.nextBool() ? 'fire' : null,
    components: SpellComponents(
      v: rng.nextBool(),
      s: rng.nextBool(),
      m: rng.nextBool(),
      materialDescription: rng.nextBool() ? 'a pinch of sulfur' : null,
      materialCostGp: rng.nextInt(100),
      consumesMaterial: rng.nextBool(),
    ),
    descriptionMarkdown: 'Deals damage in a burst ($seed).',
    higherLevelsMarkdown: rng.nextBool() ? '+1d6 per level' : null,
    damageMath: List<EvaluationMath>.generate(
      mathCount,
      (i) => _randomEvalMath(rng, i),
    ),
    relatedEntityRefs: List<EntityReference<DomainEntity>>.generate(
      refCount,
      (i) => _randomRef<DomainEntity>(rng, EntityType.monster, 'summon', i),
    ),
    customProperties: props,
  );
}

Monster _buildRandomMonster(int seed) {
  final rng = Random(seed ^ 0x85EBCA6B);
  final spellCount = _variedCount(rng, seed);
  final attackCount = _variedCount(rng, seed);
  final propCount = _variedCount(rng, seed);

  final props = <String, dynamic>{};
  for (var i = 0; i < propCount; i++) {
    props['trait_$i'] = <String, dynamic>{'keen': i.isEven};
  }

  return Monster(
    id: EntityId(
      slug: 'monster-$seed-${rng.nextInt(1000)}',
      ruleset: RulesetVersion.values[rng.nextInt(RulesetVersion.values.length)],
    ),
    name: 'Guardian Beast $seed',
    size: const <String>['Small', 'Medium', 'Large'][seed % 3],
    monsterType: const <String>['Beast', 'Construct', 'Undead'][seed % 3],
    alignment: 'unaligned',
    armorClass: 10 + rng.nextInt(10),
    hitPoints: 10 + rng.nextInt(100),
    hitDieFormula: '${2 + rng.nextInt(8)}d8',
    challengeRating: '${1 + (seed % 10)}',
    actionsMarkdown: '**Claw.** Melee Weapon Attack ($seed).',
    innateSpells: List<EntityReference<Spell>>.generate(
      spellCount,
      (i) => _randomRef<Spell>(rng, EntityType.spell, 'innate', i),
    ),
    attackMath: List<EvaluationMath>.generate(
      attackCount,
      (i) => _randomEvalMath(rng, i),
    ),
    customProperties: props,
  );
}

EquipmentItem _buildRandomEquipmentItem(int seed) {
  final rng = Random(seed ^ 0xC2B2AE35);
  final grantCount = _variedCount(rng, seed);
  final propCount = _variedCount(rng, seed);

  final props = <String, dynamic>{};
  for (var i = 0; i < propCount; i++) {
    props['prop_$i'] = <String, dynamic>{'charges': 1 + i};
  }

  return EquipmentItem(
    id: EntityId(
      slug: 'equip-$seed-${rng.nextInt(1000)}',
      ruleset: RulesetVersion.values[rng.nextInt(RulesetVersion.values.length)],
    ),
    name: 'Relic Blade $seed',
    itemType: const <String>['Weapon', 'Armor', 'Wondrous Item'][seed % 3],
    rarity: const <String>['Common', 'Uncommon', 'Rare'][seed % 3],
    requiresAttunement: rng.nextBool(),
    descriptionMarkdown: 'A finely wrought item ($seed).',
    grants: List<FeatureGrant>.generate(
      grantCount,
      (i) => _randomGrant(rng, i),
    ),
    customProperties: props,
  );
}

void main() {
  group('Part S4: Ruleset strict-types map-flavour law', () {
    setUp(() {
      Dnd5eRuleset.resetForTesting();
      Dnd5eRuleset.install(const TestDnd5eCatalog());
    });

    tearDown(() {
      Dnd5eRuleset.resetForTesting();
    });

    test('Character.fromMap produces identical toMap across all 4 map flavours (100 seeds)', () {
      for (var seed = 0; seed < 100; seed++) {
        final character = _buildRandomCharacter(seed);
        final originalMap = character.toMap();
        _assertFourFlavoursMatch(
          typeName: 'Character',
          seed: seed,
          originalMap: originalMap,
          roundTrip: (input) => Character.fromMap(input).toMap(),
        );
      }
    });

    test('Spell.fromMap produces identical toMap across all 4 map flavours (100 seeds)', () {
      for (var seed = 0; seed < 100; seed++) {
        final spell = _buildRandomSpell(seed);
        final originalMap = spell.toMap();
        _assertFourFlavoursMatch(
          typeName: 'Spell',
          seed: seed,
          originalMap: originalMap,
          roundTrip: (input) => Spell.fromMap(input).toMap(),
        );
      }
    });

    test('Monster.fromMap produces identical toMap across all 4 map flavours (100 seeds)', () {
      for (var seed = 0; seed < 100; seed++) {
        final monster = _buildRandomMonster(seed);
        final originalMap = monster.toMap();
        _assertFourFlavoursMatch(
          typeName: 'Monster',
          seed: seed,
          originalMap: originalMap,
          roundTrip: (input) => Monster.fromMap(input).toMap(),
        );
      }
    });

    test('EquipmentItem.fromMap produces identical toMap across all 4 map flavours (100 seeds)', () {
      for (var seed = 0; seed < 100; seed++) {
        final item = _buildRandomEquipmentItem(seed);
        final originalMap = item.toMap();
        _assertFourFlavoursMatch(
          typeName: 'EquipmentItem',
          seed: seed,
          originalMap: originalMap,
          roundTrip: (input) => EquipmentItem.fromMap(input).toMap(),
        );
      }
    });
  });
}
