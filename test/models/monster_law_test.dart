import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

import '../helpers/map_diff_helper.dart';
import '../helpers/test_dnd5e_catalog.dart';

/// Independent reference copy of the pre-Cleanup slice 18 app converter
/// (`MonsterHomebrewExt.toMinionStatBlock` from app head
/// `591b12489f9eadfb411d5f434923b882b5b71241`,
/// `lib/models/monster_codex_data.dart` lines 607-938).
MonsterStatBlock _referenceLegacyToStatBlock(
  Map<String, dynamic> map, {
  MonsterStatBlock? Function(String name)? baseLookup,
}) {
  final id = EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {}));
  final name = map['name']?.toString() ?? '';
  final size = map['size']?.toString() ?? 'Medium';
  final monsterType = map['monsterType']?.toString() ?? 'Humanoid';
  final alignment = map['alignment']?.toString() ?? 'unaligned';
  var ac = (map['armorClass'] as num?)?.toInt() ?? 10;
  var hp = (map['hitPoints'] as num?)?.toInt() ?? 10;
  var hitDice = map['hitDieFormula']?.toString() ?? '2d8';
  final challengeRating = map['challengeRating']?.toString() ?? '1';
  final actionsMarkdown = map['actionsMarkdown']?.toString() ?? '';
  final attackMath = (map['attackMath'] as List? ?? [])
      .whereType<Map<dynamic, dynamic>>()
      .map((a) => EvaluationMath.fromMap(Map<String, dynamic>.from(a)))
      .toList();
  final customProperties =
      Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});

  final parsedCr = parseChallengeRating(challengeRating) ?? 0;
  final crStr = challengeRating.trim().toLowerCase().startsWith('cr')
      ? challengeRating.trim()
      : 'CR $challengeRating';

  int parseScore(String key, String legacyKey) {
    final val = customProperties[key] ?? customProperties[legacyKey];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 10;
    return 10;
  }

  var str = parseScore('str', 'strScore');
  var dex = parseScore('dex', 'dexScore');
  var con = parseScore('con', 'conScore');
  var intSc = parseScore('int', 'intScore');
  var wis = parseScore('wis', 'wisScore');
  var cha = parseScore('cha', 'chaScore');

  final parsedActions = <CreatureAction>[];
  final parsedTraits = <CreatureTrait>[];

  final blocks = actionsMarkdown
      .split(RegExp(r'\n{2,}|\n(?=#{1,6}\s+)|(?<=\n)(?=[-*•]\s+|\*\*)'));
  for (final rawBlock in blocks) {
    final block = rawBlock.trim();
    if (block.isEmpty) continue;

    final isPureSectionHeader = RegExp(
      r'^#{1,6}\s*(actions?|traits?|reactions?|bonus\s*actions?|legendary\s*actions?)\s*$',
      caseSensitive: false,
    ).hasMatch(block);
    if (isPureSectionHeader) continue;

    String? title;
    String? desc;

    final headingMatch =
        RegExp(r'^#{1,6}\s+([^\n:]+?)(?:\s*:\s*|\s*\n\s*)([\s\S]*)$')
            .firstMatch(block);
    if (headingMatch != null) {
      title = headingMatch.group(1)!.trim();
      desc = headingMatch.group(2)!.trim();
    }

    if (title == null) {
      final prefixMatch = RegExp(
              r'^(?:[-*•\s]*)[\*_]{1,3}([^\*_:.\n]+?)[\*_]{1,3}[:.]\s*([\s\S]*)$')
          .firstMatch(block);
      if (prefixMatch != null) {
        title = prefixMatch.group(1)!.trim();
        desc = prefixMatch.group(2)!.trim();
      }
    }

    if (title == null) {
      final colonMatch =
          RegExp(r'^(?:[-*•\s]*)([^:\n]+?):\s*([\s\S]*)$').firstMatch(block);
      if (colonMatch != null) {
        title = colonMatch.group(1)!.trim();
        desc = colonMatch.group(2)!.trim();
      }
    }

    if (title == null) {
      if (block.startsWith('#')) {
        final cleanTitle = block.replaceAll(RegExp(r'^#{1,6}\s*'), '').trim();
        if (cleanTitle.isNotEmpty) {
          title = cleanTitle;
          desc = '';
        }
      } else if (block.contains('\n')) {
        final firstLine = block.substring(0, block.indexOf('\n')).trim();
        if (firstLine.isNotEmpty && firstLine.length < 50) {
          title =
              firstLine.replaceAll(RegExp(r'^[#*\-•\s]+|[*_:]+$'), '').trim();
          desc = block.substring(block.indexOf('\n')).trim();
        }
      }
    }

    if (title != null && title.isNotEmpty) {
      title = title.replaceAll(RegExp(r'^[#*\-•\s]+|[*_:]+$'), '').trim();
      desc = (desc ?? '').trim();

      if (RegExp(
                  r'^(actions?|traits?|reactions?|bonus\s*actions?|legendary\s*actions?)$',
                  caseSensitive: false)
              .hasMatch(title) &&
          desc.isEmpty) {
        continue;
      }

      final isAction = title.toLowerCase().contains('multiattack') ||
          desc.toLowerCase().contains('weapon attack') ||
          desc.toLowerCase().contains('spell attack') ||
          desc.toLowerCase().contains('to hit') ||
          desc.toLowerCase().contains('hit:');

      if (isAction) {
        final atkBonusMatch = RegExp(r'([+-]\d+)\s+to\s+hit').firstMatch(desc);
        final reachMatch =
            RegExp(r'(?:reach|range)\s+([^,\n]+)').firstMatch(desc);
        final reachRaw = reachMatch?.group(1)?.trim();
        final reachClean = reachRaw != null
            ? (reachRaw.endsWith('ft') ? '$reachRaw.' : reachRaw)
            : null;
        final hitDmgMatch =
            RegExp(r'(?:Hit:?\s*)?(\d+\s*\([^)]+\)[^.\n]*)').firstMatch(desc);

        parsedActions.add(CreatureAction(
          name: title,
          description: desc.isNotEmpty ? desc : title,
          attackBonus: int.tryParse(atkBonusMatch?.group(1) ?? ''),
          reach: reachClean,
          hitDamage: hitDmgMatch?.group(1)?.trim(),
        ));
      } else {
        parsedTraits.add(CreatureTrait(
          name: title,
          description: desc.isNotEmpty ? desc : title,
        ));
      }
    } else {
      final clean = block.replaceAll(RegExp(r'^[#*\-•\s]+'), '').trim();
      if (clean.isNotEmpty) {
        parsedTraits.add(CreatureTrait(name: 'Feature', description: clean));
      }
    }
  }

  var atkBonus = ((parsedCr * 1.5).round() + 2).clamp(2, 14);
  var dmgCount = 1;
  var dmgSides = 6;
  var dmgBonus = 2;
  var dmgType = 'Slashing';
  final packTactics = actionsMarkdown.toLowerCase().contains('pack tactics');

  if (parsedActions.isNotEmpty) {
    final firstWithBonus = parsedActions.firstWhere(
      (a) => a.attackBonus != null,
      orElse: () => parsedActions.first,
    );
    if (firstWithBonus.attackBonus != null) {
      atkBonus = firstWithBonus.attackBonus!;
    }
    final fullText =
        '${firstWithBonus.hitDamage ?? ""} ${firstWithBonus.description}';
    final dmgExpr = DiceExpression.tryParse(fullText.trim()) ??
        DiceExpression.findAll(fullText).firstOrNull?.expression;
    final d = dmgExpr?.singleDieGroup;
    if (d != null) {
      dmgCount = d.count;
      dmgSides = d.sides;
      dmgBonus = dmgExpr!.constantSum;
    }
    final typeMatch = RegExp(
      r'(bludgeoning|piercing|slashing|fire|cold|lightning|thunder|acid|poison|necrotic|radiant|force|psychic)',
      caseSensitive: false,
    ).firstMatch(fullText);
    if (typeMatch != null) {
      final t = typeMatch.group(1)!;
      dmgType = t[0].toUpperCase() + t.substring(1).toLowerCase();
    }
  } else if (attackMath.isNotEmpty) {
    final math = attackMath.first;
    final dmgExpr = DiceExpression.tryParse(math.diceFormula.trim()) ??
        DiceExpression.findAll(math.diceFormula).firstOrNull?.expression;
    final d = dmgExpr?.singleDieGroup;
    if (d != null) {
      dmgCount = d.count;
      dmgSides = d.sides;
      dmgBonus = dmgExpr!.constantSum;
    }
    final typeName = math.damageType.name;
    if (typeName.isNotEmpty) {
      dmgType = typeName[0].toUpperCase() + typeName.substring(1);
    }
  }

  if (parsedActions.isEmpty && customProperties.containsKey('_copy')) {
    final copyObj = customProperties['_copy'];
    if (copyObj is Map && copyObj['name'] != null) {
      final baseName = copyObj['name'].toString().trim();
      final baseSb = baseLookup?.call(baseName);
      if (baseSb != null) {
        if (parsedTraits.isEmpty) {
          parsedTraits.addAll(baseSb.traits);
        }
        parsedActions.addAll(baseSb.actions);
        if (ac == 10 && baseSb.ac > 10) {
          ac = baseSb.ac;
        }
        if (hp <= 10 && baseSb.maxHp > 10) {
          hp = baseSb.maxHp;
          hitDice = baseSb.hitDice ?? hitDice;
        }
        if (str == 10 &&
            dex == 10 &&
            con == 10 &&
            intSc == 10 &&
            wis == 10 &&
            cha == 10) {
          str = baseSb.strScore;
          dex = baseSb.dexScore;
          con = baseSb.conScore;
          intSc = baseSb.intScore;
          wis = baseSb.wisScore;
          cha = baseSb.chaScore;
        }
      }
    }
  }

  String? formatDefenses(Object? val) {
    if (val == null) return null;
    if (val is List) {
      if (val.isEmpty) return null;
      return val
          .map((e) => e is Map
              ? (e['note'] != null
                  ? '${e['resist'] ?? e['immune'] ?? ''} (${e['note']})'
                  : e.toString())
              : e.toString())
          .join(', ');
    }
    final s = val.toString().trim();
    return s.isNotEmpty ? s : null;
  }

  String? formatMapValues(Object? val) {
    if (val is Map) {
      if (val.isEmpty) return null;
      return val.entries
          .map((e) => '${e.key.toString().toUpperCase()} ${e.value}')
          .join(', ');
    }
    if (val is String && val.trim().isNotEmpty) return val.trim();
    return null;
  }

  String? extractSpeed(String md) {
    final m = RegExp(r'\*\*Speed:\*\*\s*([^\n]+)', caseSensitive: false)
        .firstMatch(md);
    return m?.group(1)?.trim();
  }

  final speed = customProperties['speed']?.toString() ??
      extractSpeed(actionsMarkdown) ??
      '30 ft.';
  final saves = customProperties['savingThrows']?.toString() ??
      formatMapValues(customProperties['save']);
  final skills = customProperties['skills']?.toString() ??
      formatMapValues(customProperties['skill']);
  final vuln = customProperties['damageVulnerabilities']?.toString() ??
      formatDefenses(customProperties['vulnerable']);
  final resist = customProperties['damageResistances']?.toString() ??
      formatDefenses(customProperties['resist']);
  final immune = customProperties['damageImmunities']?.toString() ??
      formatDefenses(customProperties['immune']);
  final condImmune = customProperties['conditionImmunities']?.toString() ??
      formatDefenses(customProperties['conditionImmune']);

  String? senses = customProperties['senses']?.toString();
  if (senses == null || senses.isEmpty) {
    final rawSenses = formatDefenses(customProperties['senses']);
    final passive = customProperties['passive'];
    final parts = [
      if (rawSenses != null && rawSenses.isNotEmpty) rawSenses,
      if (passive != null) 'passive Perception $passive',
    ];
    if (parts.isNotEmpty) {
      senses = parts.join(', ');
    }
  }
  senses ??= 'passive Perception 10';

  final languages = customProperties['languages']?.toString() ??
      formatDefenses(customProperties['languages']) ??
      '—';

  return MonsterStatBlock(
    id: id.slug,
    name: name,
    sizeDisplay: size,
    crDisplay: crStr,
    typeDisplay: monsterType,
    alignment: alignment,
    ac: ac,
    maxHp: hp,
    hitDice: hitDice.isNotEmpty ? hitDice : null,
    speed: speed,
    strScore: str,
    dexScore: dex,
    conScore: con,
    intScore: intSc,
    wisScore: wis,
    chaScore: cha,
    savingThrows: saves,
    skills: skills,
    damageVulnerabilities: vuln,
    damageResistances: resist,
    damageImmunities: immune,
    conditionImmunities: condImmune,
    senses: senses,
    languages: languages,
    traits: parsedTraits,
    actions: parsedActions,
    attackBonus: atkBonus,
    damageDiceCount: dmgCount,
    damageDiceSides: dmgSides,
    damageBonus: dmgBonus,
    damageType: dmgType,
    hasPackTactics: packTactics,
  );
}

Map<String, dynamic> _monsterFieldSnapshot(Monster m) => {
      'id': m.id.toMap(),
      'name': m.name,
      'name2014': m.name2014,
      'name2024': m.name2024,
      'statBlock2014': m.statBlock2014.toMap(),
      'statBlock2024': m.statBlock2024.toMap(),
      'isChangedIn2024': m.isChangedIn2024,
      'diffSummary': m.diffSummary,
      'diffHighlights': m.diffHighlights,
      'sourcePresetId': m.sourcePresetId,
      'sourcePresetName': m.sourcePresetName,
      'sourceSpellId': m.sourceSpellId,
      'sourceCategory': m.sourceCategory.name,
      'actionsMarkdown': m.actionsMarkdown,
      'innateSpells': m.innateSpells.map((s) => s.toMap()).toList(),
      'attackMath': m.attackMath.map((a) => a.toMap()).toList(),
      'customProperties': m.customProperties,
      'size': m.size,
      'monsterType': m.monsterType,
      'alignment': m.alignment,
      'armorClass': m.armorClass,
      'hitPoints': m.hitPoints,
      'hitDieFormula': m.hitDieFormula,
      'challengeRating': m.challengeRating,
    };

MonsterStatBlock _genStatBlock(Random rng, int seed, String tag) {
  const sizes = ['Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Gargantuan'];
  const types = ['Beast', 'Undead', 'Dragon', 'Fiend', 'Elemental', 'Construct'];
  const crs = ['CR 0', 'CR 1/8', 'CR 1/4', 'CR 1/2', 'CR 1', 'CR 5', 'CR 13'];
  return MonsterStatBlock(
    id: 'mon_${seed}_$tag',
    name: 'Monster $seed $tag',
    sizeDisplay: sizes[rng.nextInt(sizes.length)],
    crDisplay: crs[rng.nextInt(crs.length)],
    typeDisplay: types[rng.nextInt(types.length)],
    alignment: rng.nextBool() ? 'unaligned' : 'neutral evil',
    ac: 11 + rng.nextInt(12),
    armorType: rng.nextBool() ? 'natural armor' : null,
    maxHp: 8 + rng.nextInt(250),
    hitDice: rng.nextBool() ? '${1 + rng.nextInt(12)}d8 + 4' : null,
    speed: rng.nextBool() ? '30 ft., fly 50 ft.' : '30 ft.',
    strScore: 6 + rng.nextInt(18),
    dexScore: 6 + rng.nextInt(18),
    conScore: 6 + rng.nextInt(18),
    intScore: 3 + rng.nextInt(18),
    wisScore: 6 + rng.nextInt(18),
    chaScore: 4 + rng.nextInt(18),
    savingThrows: rng.nextBool() ? 'CON +5' : null,
    skills: rng.nextBool() ? 'Perception +4' : null,
    damageVulnerabilities: rng.nextBool() ? 'cold' : null,
    damageResistances: rng.nextBool() ? 'fire' : null,
    damageImmunities: rng.nextBool() ? 'poison' : null,
    conditionImmunities: rng.nextBool() ? 'poisoned' : null,
    senses: 'darkvision 60 ft., passive Perception 12',
    languages: rng.nextBool() ? 'Common' : '—',
    xp: rng.nextBool() ? 450 : null,
    traits: [
      if (rng.nextBool())
        CreatureTrait(name: 'Trait_$seed', description: 'Desc $seed'),
    ],
    actions: const [
      CreatureAction(
        name: 'Strike',
        description: 'Melee Weapon Attack: +5 to hit, reach 5 ft. Hit: 8 (1d8 + 4) slashing damage.',
        attackType: 'Melee Weapon Attack',
        attackBonus: 5,
        reach: '5 ft.',
        hitDamage: '8 (1d8 + 4) slashing damage',
      ),
    ],
    reactions: [
      if (rng.nextBool())
        const CreatureAction(name: 'Parry', description: 'Adds 2 to AC.'),
    ],
    legendaryActions: [
      if (rng.nextBool())
        const CreatureAction(name: 'Swipe', description: 'Makes a strike.'),
    ],
    attackBonus: 5,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 4,
    damageType: 'Slashing',
    hasPackTactics: rng.nextBool(),
    specialTrait: rng.nextBool() ? 'Special $seed' : null,
  );
}

class _CopyTestCatalog extends TestDnd5eCatalog {
  const _CopyTestCatalog();

  static const stoneGolemBlock = MonsterStatBlock(
    id: 'stone_golem',
    name: 'Stone Golem',
    sizeDisplay: 'Large',
    crDisplay: 'CR 10',
    typeDisplay: 'Construct',
    alignment: 'unaligned',
    ac: 17,
    maxHp: 178,
    hitDice: '17d10 + 85',
    speed: '30 ft.',
    strScore: 22,
    dexScore: 9,
    conScore: 20,
    intScore: 3,
    wisScore: 11,
    chaScore: 1,
    traits: [
      CreatureTrait(name: 'Immutable Form', description: 'Immune to form-altering spells.'),
    ],
    actions: [
      CreatureAction(
        name: 'Slam',
        description: 'Melee Weapon Attack: +10 to hit, reach 5 ft. Hit: 19 (3d8 + 6) bludgeoning damage.',
        attackBonus: 10,
        reach: '5 ft.',
        hitDamage: '19 (3d8 + 6) bludgeoning damage',
      ),
    ],
    attackBonus: 10,
    damageDiceCount: 3,
    damageDiceSides: 8,
    damageBonus: 6,
    damageType: 'Bludgeoning',
  );

  @override
  MonsterStatBlock? findMonsterStatBlockByName(String name) {
    if (name.trim().toLowerCase() == 'stone golem') return stoneGolemBlock;
    return null;
  }
}

void main() {
  setUpAll(() {
    Dnd5eRuleset.resetForTesting();
    Dnd5eRuleset.install(const _CopyTestCatalog());
  });

  tearDownAll(() {
    Dnd5eRuleset.resetForTesting();
  });

  group('Fix 6.1: Unified Monster round-trip, equality, and hashCode laws', () {
    test('500-seed round-trip law: Monster -> toMap -> fromMap preserves all fields', () {
      for (var seed = 1; seed <= 500; seed++) {
        final rng = Random(seed);
        final sb14 = _genStatBlock(rng, seed, '2014');
        final sb24 = rng.nextBool() ? _genStatBlock(rng, seed, '2024') : sb14;
        final original = Monster(
          id: EntityId(
            slug: 'monster-seed-$seed',
            ruleset: RulesetVersion.values[seed % RulesetVersion.values.length],
          ),
          name: 'Seed Monster $seed',
          name2014: rng.nextBool() ? 'Old Monster $seed' : null,
          name2024: rng.nextBool() ? 'New Monster $seed' : null,
          statBlock2014: sb14,
          statBlock2024: sb24,
          isChangedIn2024: rng.nextBool(),
          diffSummary: rng.nextBool() ? 'Summary $seed' : null,
          diffHighlights: rng.nextBool() ? ['HP changed', 'AC changed'] : const [],
          sourcePresetId: rng.nextBool() ? 'srd_bestiary' : 'homebrew',
          sourcePresetName: rng.nextBool() ? '5e SRD Bestiary' : 'Homebrew & Custom Creatures',
          sourceSpellId: rng.nextBool() ? 'spell_conjure_animals' : null,
          sourceCategory: SummonCategory.values[rng.nextInt(SummonCategory.values.length)],
          actionsMarkdown: rng.nextBool() ? '**Strike.** +5 to hit.' : '',
          innateSpells: [
            if (rng.nextBool())
              EntityReference<Spell>(
                refType: EntityType.spell,
                slug: 'light',
                displayName: 'Light',
              ),
          ],
          attackMath: [
            if (rng.nextBool())
              const EvaluationMath(
                diceFormula: '2d6 + 3',
                damageType: DamageType.fire,
              ),
          ],
          customProperties: rng.nextBool() ? {'note': 'seed-$seed'} : const {},
        );

        final map = original.toMap();
        // Legacy keys are still emitted from statBlock2024
        expect(map['size'], equals(sb24.sizeDisplay));
        expect(map['monsterType'], equals(sb24.typeDisplay));
        expect(map['alignment'], equals(sb24.alignment));
        expect(map['armorClass'], equals(sb24.ac));
        expect(map['hitPoints'], equals(sb24.maxHp));
        expect(map['hitDieFormula'], equals(sb24.hitDice ?? ''));

        final roundTripped = Monster.fromMap(map);
        expectMapsEqualWithDiff(
          _monsterFieldSnapshot(roundTripped),
          _monsterFieldSnapshot(original),
          seed: seed,
          typeName: 'Monster',
        );
        expect(roundTripped, equals(original), reason: 'Equality failed on seed $seed');
        expect(
          roundTripped.hashCode,
          equals(original.hashCode),
          reason: 'hashCode disagreed on seed $seed',
        );
      }
    });
  });

  group('Fix 6.2: Pre-Cleanup slice 18 legacy Monster.fromMap parity law', () {
    test('200-seed legacy map parity law matches pre-Step-6 converter rules', () {
      const sizes = ['Tiny', 'Small', 'Medium', 'Large', 'Huge'];
      const types = ['Beast', 'Undead', 'Fiend', 'Dragon', 'Construct', 'Aberration'];
      const crs = ['0', '1/8', '1/4', '1/2', '1', '3', '7', '12', 'varies'];
      const mdShapes = [
        '### Traits\n\n### Smoke Aura\nBlinds nearby foes.\n\n**Pack Tactics.** Advantage with allies.\n\n### Actions\n\n**Bite.** Melee Weapon Attack: +6 to hit, reach 5 ft., one target. Hit: 11 (2d6 + 4) piercing damage.',
        '**Speed:** 40 ft., fly 60 ft.\n\n### Storm Shroud: Ranged attacks have disadvantage.\n\n- **Wind Walk**: Moves freely.\n\n*Cold Aura.* Deals 3 cold.\n\nHollow Echo: Cannot be tracked.\n\n- Misty Form: Squeezes through cracks.\n\n### Silent Drift\n\nGale Surge\nPushes foes 10 ft.\n\nLingering wind.\n\n**Slash.** Melee Weapon Attack: +5 to hit, reach 10 ft, one target. Hit: 9 (1d10 + 4) cold damage.\n\n### Reactions',
        '**Carapace.** Hard shell.',
        '',
      ];

      for (var seed = 1; seed <= 200; seed++) {
        final rng = Random(seed);
        final useLegacyCopy = seed % 20 == 0;
        final useStringProps = rng.nextBool();
        final customProps = <String, dynamic>{};

        if (useLegacyCopy) {
          customProps['_copy'] = {'name': 'Stone Golem', 'source': 'MM'};
        } else {
          if (rng.nextBool()) {
            customProps['speed'] = '${25 + rng.nextInt(4) * 5} ft.';
          }
          if (useStringProps) {
            customProps['str'] = 8 + rng.nextInt(14);
            customProps['dex'] = 8 + rng.nextInt(14);
            customProps['con'] = 8 + rng.nextInt(14);
            customProps['int'] = 4 + rng.nextInt(14);
            customProps['wis'] = 8 + rng.nextInt(14);
            customProps['cha'] = 6 + rng.nextInt(14);
            if (rng.nextBool()) customProps['savingThrows'] = 'DEX +5, WIS +4';
            if (rng.nextBool()) customProps['skills'] = 'Stealth +5';
            if (rng.nextBool()) customProps['damageVulnerabilities'] = 'cold';
            if (rng.nextBool()) customProps['damageResistances'] = 'fire, poison';
            if (rng.nextBool()) customProps['damageImmunities'] = 'necrotic';
            if (rng.nextBool()) customProps['conditionImmunities'] = 'charmed';
            if (rng.nextBool()) customProps['senses'] = 'darkvision 60 ft., passive Perception 14';
            if (rng.nextBool()) customProps['languages'] = 'Common, Draconic';
          } else {
            customProps['strScore'] = 8 + rng.nextInt(14);
            customProps['dexScore'] = 8 + rng.nextInt(14);
            customProps['conScore'] = 8 + rng.nextInt(14);
            customProps['intScore'] = 4 + rng.nextInt(14);
            customProps['wisScore'] = 8 + rng.nextInt(14);
            customProps['chaScore'] = 6 + rng.nextInt(14);
            if (rng.nextBool()) customProps['save'] = {'dex': '+5', 'wis': '+4'};
            if (rng.nextBool()) customProps['skill'] = {'stealth': '+5'};
            if (rng.nextBool()) customProps['vulnerable'] = ['radiant'];
            if (rng.nextBool()) {
              customProps['resist'] = [
                'cold',
                {'resist': 'slashing', 'note': 'nonmagical'},
              ];
            }
            if (rng.nextBool()) customProps['immune'] = ['poison'];
            if (rng.nextBool()) customProps['conditionImmune'] = ['exhaustion'];
            if (rng.nextBool()) customProps['senses'] = ['tremorsense 30 ft.'];
            if (rng.nextBool()) customProps['passive'] = 15;
            if (rng.nextBool()) customProps['languages'] = ['Common'];
          }
        }

        final legacyMap = <String, dynamic>{
          'id': {'slug': 'legacy-mon-$seed', 'ruleset': 'homebrew'},
          'name': 'Legacy Creature $seed',
          if (rng.nextBool()) 'size': sizes[rng.nextInt(sizes.length)],
          if (rng.nextBool()) 'monsterType': types[rng.nextInt(types.length)],
          if (rng.nextBool()) 'alignment': 'neutral evil',
          if (!useLegacyCopy && rng.nextBool()) 'armorClass': 11 + rng.nextInt(10),
          if (!useLegacyCopy && rng.nextBool()) 'hitPoints': 15 + rng.nextInt(120),
          if (rng.nextBool()) 'hitDieFormula': '${2 + rng.nextInt(10)}d8 + 4',
          if (rng.nextBool()) 'challengeRating': crs[rng.nextInt(crs.length)],
          'actionsMarkdown': useLegacyCopy ? '' : mdShapes[rng.nextInt(mdShapes.length)],
          'attackMath': [
            if (!useLegacyCopy && rng.nextBool())
              const EvaluationMath(
                diceFormula: '2d4 + 3',
                damageType: DamageType.piercing,
              ).toMap(),
          ],
          'customProperties': customProps,
        };

        final expectedSb = _referenceLegacyToStatBlock(
          legacyMap,
          baseLookup: const _CopyTestCatalog().findMonsterStatBlockByName,
        );
        final actual = Monster.fromMap(legacyMap);

        expectMapsEqualWithDiff(
          actual.statBlock2014.toMap(),
          expectedSb.toMap(),
          seed: seed,
          typeName: 'Monster.fromMap(legacy).statBlock2014',
        );
        expectMapsEqualWithDiff(
          actual.statBlock2024.toMap(),
          expectedSb.toMap(),
          seed: seed,
          typeName: 'Monster.fromMap(legacy).statBlock2024',
        );
        expect(actual.statBlock2014, equals(expectedSb));
        expect(actual.statBlock2024, equals(expectedSb));
        expect(actual.sourcePresetId, equals('homebrew'));
      }
    });
  });
}
