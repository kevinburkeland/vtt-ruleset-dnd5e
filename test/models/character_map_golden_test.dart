import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:vtt_engine_core/rules/i_ruleset_module.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

import '../helpers/test_dnd5e_catalog.dart';

const _fixturePath = 'test/fixtures/character_map_goldens/character_map_goldens.json';

/// Recursively sorts all map keys so JSON serialization is deterministic.
dynamic _canonicalize(dynamic value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return <String, dynamic>{
      for (final k in sortedKeys) k: _canonicalize(value[k]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

String _canonicalJson(dynamic value) =>
    const JsonEncoder.withIndent('  ').convert(_canonicalize(value));

List<Map<String, dynamic>> _buildExistingTestCharacterMaps() {
  final list = <Map<String, dynamic>>[];

  // 1. Minimal bare-bones character
  list.add(Character(
    id: const EntityId(slug: 'existing-minimal', ruleset: RulesetVersion.v2014),
    name: 'Minimal Hero',
    speciesRef: const EntityReference.empty(
        refType: EntityType.species, slug: 'human', displayName: 'Human'),
    baseScores: const AbilityScores(
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    ),
    resources: const CharacterResourcePool(currentHp: 10),
    progression: const CharacterProgression(classes: []),
  ).toMap());

  // 2. Level 1 Fighter (2014) with armor and shield
  list.add(Character(
    id: const EntityId(slug: 'existing-fighter-2014', ruleset: RulesetVersion.v2014),
    name: 'Fighter 2014',
    speciesRef: const EntityReference.empty(
        refType: EntityType.species, slug: 'human', displayName: 'Human'),
    backgroundRef: const EntityReference.empty(
        refType: EntityType.background, slug: 'soldier', displayName: 'Soldier'),
    baseScores: const AbilityScores(
      strength: 16,
      dexterity: 12,
      constitution: 14,
      intelligence: 10,
      wisdom: 10,
      charisma: 8,
    ),
    savingThrowProficiencies: const {'strength', 'constitution'},
    skillProficiencies: const {'athletics': 1, 'intimidation': 1},
    toolProficiencies: const ['land_vehicles'],
    languages: const ['Common'],
    resources: const CharacterResourcePool(currentHp: 12, currentHitDice: {'d10': 1}),
    progression: const CharacterProgression(classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
            refType: EntityType.classDefinition,
            slug: 'fighter',
            displayName: 'Fighter'),
        level: 1,
        hitDie: 'd10',
        isStartingClass: true,
      ),
    ]),
    inventory: [
      InventoryItemInstance(
        instanceId: 'inv-chain',
        itemRef: const EntityReference.empty(
            refType: EntityType.equipment,
            slug: 'chain-mail',
            displayName: 'Chain Mail'),
        isEquipped: true,
      ),
      InventoryItemInstance(
        instanceId: 'inv-shield',
        itemRef: const EntityReference.empty(
            refType: EntityType.equipment,
            slug: 'shield',
            displayName: 'Shield'),
        isEquipped: true,
      ),
    ],
  ).toMap());

  // 3. Level 5 Rogue (2024) with DEX 18 unarmored
  list.add(Character(
    id: const EntityId(slug: 'existing-rogue-2024', ruleset: RulesetVersion.v2024),
    name: 'Rogue 2024',
    speciesRef: const EntityReference.empty(
        refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
    baseScores: const AbilityScores(
      strength: 8,
      dexterity: 18,
      constitution: 12,
      intelligence: 14,
      wisdom: 12,
      charisma: 10,
    ),
    savingThrowProficiencies: {'dexterity', 'intelligence'},
    skillProficiencies: {'stealth': 2, 'perception': 1, 'acrobatics': 1, 'sleightOfHand': 1},
    toolProficiencies: ['thieves_tools'],
    languages: ['Common', 'Elvish'],
    resources: const CharacterResourcePool(currentHp: 33, currentHitDice: {'d8': 5}),
    progression: const CharacterProgression(classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
            refType: EntityType.classDefinition,
            slug: 'rogue',
            displayName: 'Rogue'),
        level: 5,
        hitDie: 'd8',
        isStartingClass: true,
      ),
    ]),
  ).toMap());

  // 4. Multiclass Wizard 3 / Cleric 2 with spell slots
  list.add(Character(
    id: const EntityId(slug: 'existing-multiclass', ruleset: RulesetVersion.v2024),
    name: 'Mage Cleric',
    speciesRef: const EntityReference.empty(
        refType: EntityType.species, slug: 'dwarf', displayName: 'Dwarf'),
    backgroundRef: const EntityReference.empty(
        refType: EntityType.background, slug: 'sage', displayName: 'Sage'),
    baseScores: const AbilityScores(
      strength: 10,
      dexterity: 14,
      constitution: 14,
      intelligence: 16,
      wisdom: 16,
      charisma: 8,
    ),
    resources: const CharacterResourcePool(
      currentHp: 34,
      tempHp: 5,
      currentHitDice: {'d6': 3, 'd8': 2},
    ),
    progression: const CharacterProgression(classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
            refType: EntityType.classDefinition,
            slug: 'wizard',
            displayName: 'Wizard'),
        level: 3,
        hitDie: 'd6',
        isStartingClass: true,
      ),
      ClassLevelProgression(
        classRef: EntityReference.empty(
            refType: EntityType.classDefinition,
            slug: 'cleric',
            displayName: 'Cleric'),
        level: 2,
        hitDie: 'd8',
      ),
    ]),
    allocatedSpells: {
      'class-wizard-cantrips': [
        const EntityReference<Spell>.empty(
            refType: EntityType.spell,
            slug: 'fire-bolt',
            displayName: 'Fire Bolt'),
      ],
    },
  ).toMap());

  // 5. Warlock 11 with Mystic Arcanum and customProperties['ac']
  list.add(Character(
    id: const EntityId(slug: 'existing-warlock-11', ruleset: RulesetVersion.v2024),
    name: 'Warlock Hero',
    speciesRef: const EntityReference.empty(
        refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
    baseScores: const AbilityScores(
      strength: 8,
      dexterity: 14,
      constitution: 14,
      intelligence: 10,
      wisdom: 12,
      charisma: 18,
    ),
    resources: const CharacterResourcePool(currentHp: 50, currentHitDice: {'d8': 11}),
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
    customProperties: {'ac': 17},
  ).toMap());

  // 6. Barbarian with Unarmored Defense (10 + DEX + CON)
  list.add(Character(
    id: const EntityId(slug: 'existing-barbarian', ruleset: RulesetVersion.v2014),
    name: 'Barbarian Hero',
    speciesRef: const EntityReference.empty(
        refType: EntityType.species, slug: 'human', displayName: 'Human'),
    baseScores: const AbilityScores(
      strength: 18,
      dexterity: 14,
      constitution: 16,
      intelligence: 8,
      wisdom: 10,
      charisma: 10,
    ),
    resources: const CharacterResourcePool(currentHp: 45, currentHitDice: {'d12': 4}),
    progression: const CharacterProgression(classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
            refType: EntityType.classDefinition,
            slug: 'barbarian',
            displayName: 'Barbarian'),
        level: 4,
        hitDie: 'd12',
        isStartingClass: true,
      ),
    ]),
  ).toMap());

  // 7. Monk with Unarmored Defense (10 + DEX + WIS)
  list.add(Character(
    id: const EntityId(slug: 'existing-monk', ruleset: RulesetVersion.v2024),
    name: 'Monk Hero',
    speciesRef: const EntityReference.empty(
        refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
    baseScores: const AbilityScores(
      strength: 10,
      dexterity: 16,
      constitution: 14,
      intelligence: 10,
      wisdom: 16,
      charisma: 8,
    ),
    resources: const CharacterResourcePool(currentHp: 28, currentHitDice: {'d8': 3}),
    progression: const CharacterProgression(classes: [
      ClassLevelProgression(
        classRef: EntityReference.empty(
            refType: EntityType.classDefinition,
            slug: 'monk',
            displayName: 'Monk'),
        level: 3,
        hitDie: 'd8',
        isStartingClass: true,
      ),
    ]),
  ).toMap());

  // 8. Legacy map with flat hp + skillProficiencies + unknown keys
  list.add({
    'id': 'legacy-flat-1',
    'name': 'Legacy Flat Hero',
    'hp': 27,
    'skillProficiencies': ['perception', 'stealth'],
    'savingThrowProficiencies': ['dexterity'],
    'unknownLegacyField': 'keep-me',
    'extraNumeric': 99,
  });

  return list;
}

List<Map<String, dynamic>> _generateSeededCharacterMaps(int count) {
  final rng = math.Random(13061);
  const speciesPool = ['human', 'elf', 'dwarf', 'halfling', 'dragonborn', 'gnome', 'tiefling'];
  const bgPool = ['acolyte', 'criminal', 'folk_hero', 'noble', 'sage', 'soldier'];
  const classPool = [
    ('fighter', 'd10'),
    ('wizard', 'd6'),
    ('rogue', 'd8'),
    ('cleric', 'd8'),
    ('barbarian', 'd12'),
    ('monk', 'd8'),
    ('paladin', 'd10'),
    ('ranger', 'd10'),
    ('bard', 'd8'),
    ('sorcerer', 'd6'),
    ('warlock', 'd8'),
    ('druid', 'd8'),
  ];
  const skillStrings = [
    'acrobatics',
    'animal_handling',
    'arcana',
    'athletics',
    'deception',
    'history',
    'insight',
    'intimidation',
    'investigation',
    'medicine',
    'nature',
    'perception',
    'performance',
    'persuasion',
    'religion',
    'sleight_of_hand',
    'stealth',
    'survival',
  ];
  const saveNames = [
    'strength',
    'dexterity',
    'constitution',
    'intelligence',
    'wisdom',
    'charisma',
  ];
  const toolPool = ['thieves_tools', 'smiths_tools', 'herbalism_kit', 'lute', 'navigators_tools'];
  const langPool = ['Common', 'Elvish', 'Dwarvish', 'Draconic', 'Giant', 'Sylvan'];
  const itemPool = [
    ('leather-armor', 'Leather Armor'),
    ('chain-shirt', 'Chain Shirt'),
    ('breastplate', 'Breastplate'),
    ('chain-mail', 'Chain Mail'),
    ('plate-armor', 'Plate Armor'),
    ('shield', 'Shield'),
    ('longsword', 'Longsword'),
    ('dagger', 'Dagger'),
    ('backpack', 'Backpack'),
  ];

  final maps = <Map<String, dynamic>>[];

  for (var i = 0; i < count; i++) {
    final is2024 = rng.nextBool();
    final rulesetStr = is2024 ? 'v2024' : 'v2014';

    final map = <String, dynamic>{
      'id': {
        'slug': 'gen-char-$i',
        'ruleset': rulesetStr,
      },
      'name': 'Generated Hero $i',
      'baseScores': {
        'strength': 8 + rng.nextInt(13),
        'dexterity': 8 + rng.nextInt(13),
        'constitution': 8 + rng.nextInt(13),
        'intelligence': 8 + rng.nextInt(13),
        'wisdom': 8 + rng.nextInt(13),
        'charisma': 8 + rng.nextInt(13),
      },
    };

    // Optional speciesRef
    if (rng.nextInt(4) != 0) {
      final sp = speciesPool[rng.nextInt(speciesPool.length)];
      map['speciesRef'] = {
        'refType': 'species',
        'slug': sp,
        'displayName': sp,
      };
    }

    // Optional backgroundRef
    if (rng.nextInt(3) != 0) {
      final bg = bgPool[rng.nextInt(bgPool.length)];
      map['backgroundRef'] = {
        'refType': 'background',
        'slug': bg,
        'displayName': bg,
      };
    }

    // Progression: 0, 1, 2, or 3 classes
    final classCount = i % 15 == 0 ? 0 : (1 + rng.nextInt(3));
    final chosenClasses = <Map<String, dynamic>>[];
    final usedSlugs = <String>{};
    for (var c = 0; c < classCount; c++) {
      final entry = classPool[rng.nextInt(classPool.length)];
      if (!usedSlugs.add(entry.$1)) continue;
      chosenClasses.add({
        'classRef': {
          'refType': 'classDefinition',
          'slug': entry.$1,
          'displayName': entry.$1,
        },
        'level': 1 + rng.nextInt(8),
        'hitDie': entry.$2,
        'isStartingClass': c == 0,
      });
    }
    map['progression'] = {'classes': chosenClasses};

    // Skill proficiencies: mix of snake_case strings and camelCase enum names
    final skillCount = rng.nextInt(5);
    final skills = <String, int>{};
    const skillEnumNames = [
      'acrobatics',
      'animalHandling',
      'arcana',
      'athletics',
      'deception',
      'history',
      'insight',
      'intimidation',
      'investigation',
      'medicine',
      'nature',
      'perception',
      'performance',
      'persuasion',
      'religion',
      'sleightOfHand',
      'stealth',
      'survival',
    ];
    for (var s = 0; s < skillCount; s++) {
      final k = rng.nextBool()
          ? skillStrings[rng.nextInt(skillStrings.length)]
          : skillEnumNames[rng.nextInt(skillEnumNames.length)];
      skills[k] = 1 + rng.nextInt(2);
    }
    map['skillProficiencies'] = skills;

    // Saving throw proficiencies: mix of full strings and short enum-style names
    const saveShortNames = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    final saveCount = rng.nextInt(3);
    final saves = <String>{};
    for (var s = 0; s < saveCount; s++) {
      if (rng.nextBool()) {
        saves.add(saveNames[rng.nextInt(saveNames.length)]);
      } else {
        saves.add(saveShortNames[rng.nextInt(saveShortNames.length)]);
      }
    }
    map['savingThrowProficiencies'] = saves.toList()..sort();

    // Tools and languages
    final tools = <String>{};
    for (var t = 0; t < rng.nextInt(3); t++) {
      tools.add(toolPool[rng.nextInt(toolPool.length)]);
    }
    if (tools.isNotEmpty) {
      map['toolProficiencies'] = tools.toList()..sort();
    }

    final langs = <String>{'Common'};
    for (var l = 0; l < rng.nextInt(3); l++) {
      langs.add(langPool[rng.nextInt(langPool.length)]);
    }
    map['languages'] = langs.toList()..sort();

    // Inventory with equipped and unequipped items
    final invCount = rng.nextInt(5);
    final inv = <Map<String, dynamic>>[];
    for (var it = 0; it < invCount; it++) {
      final pick = itemPool[rng.nextInt(itemPool.length)];
      inv.add({
        'instanceId': 'item-$i-$it',
        'itemRef': {
          'refType': 'equipment',
          'slug': pick.$1,
          'displayName': pick.$2,
        },
        'quantity': 1 + rng.nextInt(3),
        'isEquipped': rng.nextBool(),
        'isAttuned': rng.nextInt(5) == 0,
      });
    }
    map['inventory'] = inv;

    // Resources with spell slots & hit dice OR legacy flat hp
    if (i % 7 == 0) {
      map['hp'] = 10 + rng.nextInt(80);
    } else {
      final hitDice = <String, int>{};
      for (final cl in chosenClasses) {
        final hd = cl['hitDie'] as String;
        hitDice[hd] = (hitDice[hd] ?? 0) + (cl['level'] as int);
      }
      final slots = <String, int>{};
      if (rng.nextBool()) {
        slots['1'] = rng.nextInt(5);
        slots['2'] = rng.nextInt(4);
      }
      map['resources'] = {
        'currentHp': 5 + rng.nextInt(95),
        'tempHp': rng.nextInt(10),
        'currentHitDice': hitDice,
        'currentSpellSlots': slots,
        'deathSaveSuccesses': rng.nextInt(4),
        'deathSaveFailures': rng.nextInt(4),
        'exhaustionLevel': rng.nextInt(4),
      };
    }

    // Custom properties (sometimes AC override)
    if (i % 6 == 0) {
      map['customProperties'] = {'ac': 12 + rng.nextInt(9)};
    } else if (i % 11 == 0) {
      map['customProperties'] = {'armorClass': 13 + rng.nextInt(8)};
    }

    // Unknown extra keys
    if (i % 5 == 0) {
      map['zzUnknownKey'] = 'opaque-$i';
      map['zzNestedExtra'] = {'flag': i.isEven, 'count': i};
    }

    maps.add(map);
  }

  return maps;
}

Map<String, dynamic> _buildGoldenPayload() {
  final existingMaps = _buildExistingTestCharacterMaps();
  final seededMaps = _generateSeededCharacterMaps(320);

  final cases = <Map<String, dynamic>>[];

  void addCase(String caseId, Map<String, dynamic> input) {
    final c1 = Character.fromMap(input);
    final c2 = Character.fromMap(input);
    final serialized = c1.toMap();
    final roundTrip = Character.fromMap(serialized);
    cases.add({
      'id': caseId,
      'input': _canonicalize(input),
      'toMap': _canonicalize(serialized),
      'roundTripEqual': roundTrip == c1,
      'separateFromMapEqual': c1 == c2 && c1.hashCode == c2.hashCode,
    });
  }

  for (var i = 0; i < existingMaps.length; i++) {
    addCase('existing_$i', existingMaps[i]);
  }
  for (var i = 0; i < seededMaps.length; i++) {
    addCase('seeded_$i', seededMaps[i]);
  }

  final modules = <String, IRulesetModule<Character>>{
    'Dnd5eRulesetModule': const Dnd5eRulesetModule(),
    'Dnd5e2014Module': const Dnd5e2014Module(),
    'Dnd5e2024Module': const Dnd5e2024Module(),
  };
  const statKeys = ['ac', 'initiative', 'perception', 'zz_unknown'];

  Object evalStat(Character c, String k, {IRulesetModule<Character>? module}) {
    try {
      return c.queryStat(k, module: module);
    } on ArgumentError {
      return 'ArgumentError';
    }
  }

  final queryStatCases = <Map<String, dynamic>>[];
  for (var i = 0; i < 30; i++) {
    final c = Character.fromMap(seededMaps[i]);
    final byModule = <String, Map<String, Object>>{};
    for (final entry in modules.entries) {
      byModule[entry.key] = {
        for (final k in statKeys) k: evalStat(c, k, module: entry.value),
      };
    }
    final noModule = <String, Object>{
      for (final k in statKeys) k: evalStat(c, k),
    };
    queryStatCases.add({
      'id': 'seeded_$i',
      'byModule': byModule,
      'noModule': noModule,
    });
  }

  return {
    'existingCount': existingMaps.length,
    'seededCount': seededMaps.length,
    'totalCases': cases.length,
    'queryStatCount': queryStatCases.length,
    'cases': cases,
    'queryStatCases': queryStatCases,
  };
}

void main() {
  group('Step 6 Character Map Goldens (Fix 6.1)', () {
    setUp(() {
      Dnd5eRuleset.resetForTesting();
      Dnd5eRuleset.install(const TestDnd5eCatalog());
    });

    tearDown(() {
      Dnd5eRuleset.resetForTesting();
    });

    test('Character.fromMap/toMap and queryStat match recorded goldens (328 cases + 30 queryStat)', () {
      final file = File(_fixturePath);
      final actual = _buildGoldenPayload();

      if (Platform.environment['GENERATE_CHARACTER_GOLDENS'] == '1') {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('${_canonicalJson(actual)}\n');
        return;
      }

      expect(file.existsSync(), isTrue,
          reason: 'Missing golden fixture at $_fixturePath');

      final expected =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(actual['existingCount'], expected['existingCount']);
      expect(actual['seededCount'], expected['seededCount']);
      expect(actual['totalCases'], expected['totalCases']);
      expect(actual['queryStatCount'], expected['queryStatCount']);

      final expectedCases = expected['cases'] as List<dynamic>;
      final actualCases = actual['cases'] as List<dynamic>;
      expect(actualCases.length, expectedCases.length);
      for (var i = 0; i < expectedCases.length; i++) {
        expect(
          _canonicalJson(actualCases[i]),
          _canonicalJson(expectedCases[i]),
          reason: 'Mismatch at case ${(expectedCases[i] as Map)['id']}',
        );
      }

      final expectedQs = expected['queryStatCases'] as List<dynamic>;
      final actualQs = actual['queryStatCases'] as List<dynamic>;
      expect(actualQs.length, expectedQs.length);
      for (var i = 0; i < expectedQs.length; i++) {
        expect(
          _canonicalJson(actualQs[i]),
          _canonicalJson(expectedQs[i]),
          reason: 'Mismatch at queryStat case ${(expectedQs[i] as Map)['id']}',
        );
      }
    });

    test('Fix 8.5 diff-guard: Step 8 golden differs from Step 6 baseline only in armorClass and Fix 8.5 queryStat semantics', () {
      final gitRes = Process.runSync('git', [
        'show',
        '983beb8be6ab3dc9262e3e2fe85c3b3ca11c8656:$_fixturePath',
      ]);
      expect(
        gitRes.exitCode,
        0,
        reason: 'Could not read Step 6 baseline fixture from git history: ${gitRes.stderr}',
      );
      final oldDoc = jsonDecode(gitRes.stdout as String) as Map<String, dynamic>;
      final newDoc =
          jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

      expect(newDoc['existingCount'], oldDoc['existingCount']);
      expect(newDoc['seededCount'], oldDoc['seededCount']);
      expect(newDoc['totalCases'], oldDoc['totalCases']);
      expect(newDoc['queryStatCount'], oldDoc['queryStatCount']);

      final oldCases = oldDoc['cases'] as List<dynamic>;
      final newCases = newDoc['cases'] as List<dynamic>;
      expect(newCases.length, oldCases.length);
      for (var i = 0; i < oldCases.length; i++) {
        final o = Map<String, dynamic>.from(oldCases[i] as Map);
        final n = Map<String, dynamic>.from(newCases[i] as Map);
        final oToMap = Map<String, dynamic>.from(o['toMap'] as Map)..remove('armorClass');
        final nToMap = Map<String, dynamic>.from(n['toMap'] as Map)..remove('armorClass');
        final oInput = Map<String, dynamic>.from(o['input'] as Map)..remove('armorClass');
        final nInput = Map<String, dynamic>.from(n['input'] as Map)..remove('armorClass');
        o['toMap'] = oToMap;
        n['toMap'] = nToMap;
        o['input'] = oInput;
        n['input'] = nInput;
        expect(
          _canonicalJson(n),
          _canonicalJson(o),
          reason: 'Unexpected non-armorClass diff at case ${o['id']}',
        );
      }

      final oldQs = oldDoc['queryStatCases'] as List<dynamic>;
      final newQs = newDoc['queryStatCases'] as List<dynamic>;
      expect(newQs.length, oldQs.length);
      for (var i = 0; i < oldQs.length; i++) {
        final o = oldQs[i] as Map<String, dynamic>;
        final n = newQs[i] as Map<String, dynamic>;
        expect(n['id'], o['id']);
        final oByMod = o['byModule'] as Map<String, dynamic>;
        final nByMod = n['byModule'] as Map<String, dynamic>;
        expect(nByMod.keys.toSet(), oByMod.keys.toSet());
        final caseInput = (newCases[8 + i] as Map)['input'] as Map<String, dynamic>;
        final customProps = caseInput['customProperties'] as Map<String, dynamic>? ?? const {};
        final hasAcOverride = customProps['ac'] is num;
        for (final mod in oByMod.keys) {
          final om = oByMod[mod] as Map<String, dynamic>;
          final nm = nByMod[mod] as Map<String, dynamic>;
          expect(nm['initiative'], om['initiative'], reason: '${o['id']} $mod initiative');
          if (!hasAcOverride) {
            expect(nm['ac'], om['ac'], reason: '${o['id']} $mod ac');
          }
          expect(nm['perception'], 'ArgumentError', reason: '${o['id']} $mod perception');
          expect(nm['zz_unknown'], 'ArgumentError', reason: '${o['id']} $mod zz_unknown');
        }
      }
    });
  });
}
