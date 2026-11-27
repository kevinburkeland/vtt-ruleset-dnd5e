import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../catalog/dnd5e_catalog.dart';
import '../combat/combat_rules.dart';
import '../dice/dice_expression.dart';
import '../rules/ruleset_edition.dart';
import 'core_types.dart';
import 'monster_stat_block.dart';
import 'spell_monster_equipment.dart';

String _stripCrPrefix(String crDisplay) {
  final trimmed = crDisplay.trim();
  if (trimmed.length >= 3 && trimmed.substring(0, 3).toLowerCase() == 'cr ') {
    return trimmed.substring(3);
  }
  if (trimmed.toLowerCase() == 'cr') {
    return '';
  }
  return trimmed;
}

/// Reads monster records saved before Cleanup slice 18 (without embedded stat
/// blocks) — and single-edition construction inputs — into a unified
/// [MonsterStatBlock].
MonsterStatBlock hydrateLegacyMonsterStatBlock({
  required EntityId id,
  required String name,
  String? size,
  String? monsterType,
  String? alignment,
  int? armorClass,
  int? hitPoints,
  String? hitDieFormula,
  String? challengeRating,
  required String actionsMarkdown,
  required List<EvaluationMath> attackMath,
  required Map<String, dynamic> customProperties,
  MonsterStatBlock? Function(String name)? baseStatBlockLookup,
}) {
  final crTrimmed = challengeRating?.trim();
  final parsedCr = (crTrimmed == null || crTrimmed.isEmpty)
      ? null
      : parseChallengeRating(crTrimmed);
  final String? crStr = (crTrimmed == null || crTrimmed.isEmpty)
      ? null
      : (parsedCr != null
          ? (crTrimmed.toLowerCase().startsWith('cr')
              ? crTrimmed
              : 'CR $crTrimmed')
          : crTrimmed);

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

  var ac = armorClass;
  var hp = hitPoints;
  var hitDice = hitDieFormula;

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

  var atkBonus =
      parsedCr == null ? 2 : ((parsedCr * 1.5).round() + 2).clamp(2, 14);
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
      final baseSb = baseStatBlockLookup != null
          ? baseStatBlockLookup(baseName)
          : (Dnd5eRuleset.isInstalled
              ? Dnd5eRuleset.catalog.findMonsterStatBlockByName(baseName)
              : null);
      if (baseSb != null) {
        if (parsedTraits.isEmpty) {
          parsedTraits.addAll(baseSb.traits);
        }
        parsedActions.addAll(baseSb.actions);
        final baseAc = baseSb.ac;
        if ((ac == null || ac == 10) && baseAc != null && baseAc > 10) {
          ac = baseAc;
        }
        final baseHp = baseSb.maxHp;
        if ((hp == null || hp <= 10) && baseHp != null && baseHp > 10) {
          hp = baseHp;
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

  final hdTrimmed = hitDice?.trim();
  return MonsterStatBlock(
    id: id.slug,
    name: name,
    sizeDisplay: size,
    crDisplay: crStr,
    typeDisplay: monsterType,
    alignment: alignment,
    ac: ac,
    maxHp: hp,
    hitDice: (hdTrimmed != null && hdTrimmed.isNotEmpty) ? hdTrimmed : null,
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

/// Unified D&D 5e Monster domain model holding dual-edition stat blocks
/// (`statBlock2014` and `statBlock2024`) and deriving shared combat facts
/// from `statBlock2024` as the single source of truth.
@immutable
class Monster extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String? name2014;
  final String? name2024;
  final MonsterStatBlock statBlock2014;
  final MonsterStatBlock statBlock2024;
  final bool isChangedIn2024;
  final String? diffSummary;
  final List<String> diffHighlights;
  final String sourcePresetId;
  final String sourcePresetName;
  final String? sourceSpellId;
  final SummonCategory sourceCategory;
  final String actionsMarkdown;
  final List<EntityReference<Spell>> innateSpells;
  final List<EvaluationMath> attackMath;
  @override
  final Map<String, dynamic> customProperties;

  const Monster({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required this.statBlock2014,
    required this.statBlock2024,
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.sourcePresetId = 'srd_bestiary',
    this.sourcePresetName = '5e SRD Bestiary',
    this.sourceSpellId,
    this.sourceCategory = SummonCategory.spell,
    this.actionsMarkdown = '',
    this.innateSpells = const [],
    this.attackMath = const [],
    this.customProperties = const {},
  });

  const Monster.simple({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required MonsterStatBlock statBlock,
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.sourcePresetId = 'srd_bestiary',
    this.sourcePresetName = '5e SRD Bestiary',
    this.sourceSpellId,
    this.sourceCategory = SummonCategory.spell,
    this.actionsMarkdown = '',
    this.innateSpells = const [],
    this.attackMath = const [],
    this.customProperties = const {},
  })  : statBlock2014 = statBlock,
        statBlock2024 = statBlock;

  /// Constructs a single-edition (e.g. homebrew or imported) [Monster] whose
  /// 2014 and 2024 stat blocks are hydrated identically via
  /// [hydrateLegacyMonsterStatBlock].
  factory Monster.singleEdition({
    required EntityId id,
    required String name,
    String? size,
    String? monsterType,
    String? alignment,
    int? armorClass,
    int? hitPoints,
    String? hitDieFormula,
    String? challengeRating,
    required String actionsMarkdown,
    List<EntityReference<Spell>> innateSpells = const [],
    List<EvaluationMath> attackMath = const [],
    Map<String, dynamic> customProperties = const {},
    String sourcePresetId = 'homebrew',
    String sourcePresetName = 'Homebrew & Custom Creatures',
    String? sourceSpellId,
    SummonCategory sourceCategory = SummonCategory.spell,
    MonsterStatBlock? Function(String name)? baseStatBlockLookup,
  }) {
    final statBlock = hydrateLegacyMonsterStatBlock(
      id: id,
      name: name,
      size: size,
      monsterType: monsterType,
      alignment: alignment,
      armorClass: armorClass,
      hitPoints: hitPoints,
      hitDieFormula: hitDieFormula,
      challengeRating: challengeRating,
      actionsMarkdown: actionsMarkdown,
      attackMath: attackMath,
      customProperties: customProperties,
      baseStatBlockLookup: baseStatBlockLookup,
    );
    return Monster(
      id: id,
      name: name,
      statBlock2014: statBlock,
      statBlock2024: statBlock,
      sourcePresetId: sourcePresetId,
      sourcePresetName: sourcePresetName,
      sourceSpellId: sourceSpellId,
      sourceCategory: sourceCategory,
      actionsMarkdown: actionsMarkdown,
      innateSpells: innateSpells,
      attackMath: attackMath,
      customProperties: customProperties,
    );
  }

  @override
  EntityType get entityType => EntityType.monster;

  MonsterStatBlock get sourceStatBlock => statBlock2024;
  bool get isHomebrew => sourcePresetId == 'homebrew';

  // Shared facts derived from statBlock2024 as the single source of truth
  String? get size => statBlock2024.sizeDisplay;
  String? get monsterType => statBlock2024.typeDisplay;
  String? get alignment => statBlock2024.alignment;
  int? get armorClass => statBlock2024.ac;
  int? get hitPoints => statBlock2024.maxHp;
  String? get hitDieFormula => statBlock2024.hitDice;
  String? get challengeRating {
    final cr = statBlock2024.crDisplay;
    if (cr == null) return null;
    return _stripCrPrefix(cr);
  }

  MonsterStatBlock getStatBlockForEdition(RulesetEdition edition) {
    return edition == RulesetEdition.v2014 ? statBlock2014 : statBlock2024;
  }

  String getNameForEdition(RulesetEdition edition) {
    if (edition == RulesetEdition.v2014 && name2014 != null) return name2014!;
    if (edition == RulesetEdition.v2024 && name2024 != null) return name2024!;
    return name;
  }

  @override
  Map<String, dynamic> toMap() => {
        // Legacy keys emitted from statBlock2024 for backwards compatibility
        'id': id.toMap(),
        'name': name,
        if (size != null) 'size': size,
        if (monsterType != null) 'monsterType': monsterType,
        if (alignment != null) 'alignment': alignment,
        if (armorClass != null) 'armorClass': armorClass,
        if (hitPoints != null) 'hitPoints': hitPoints,
        if (hitDieFormula != null) 'hitDieFormula': hitDieFormula,
        if (challengeRating != null) 'challengeRating': challengeRating,
        'actionsMarkdown': actionsMarkdown,
        'innateSpells': innateSpells.map((s) => s.toMap()).toList(),
        'attackMath': attackMath.map((a) => a.toMap()).toList(),
        'customProperties': customProperties,
        // Unified dual-edition fields
        if (name2014 != null) 'name2014': name2014,
        if (name2024 != null) 'name2024': name2024,
        'statBlock2014': statBlock2014.toMap(),
        'statBlock2024': statBlock2024.toMap(),
        'isChangedIn2024': isChangedIn2024,
        if (diffSummary != null) 'diffSummary': diffSummary,
        'diffHighlights': diffHighlights,
        'sourcePresetId': sourcePresetId,
        'sourcePresetName': sourcePresetName,
        if (sourceSpellId != null) 'sourceSpellId': sourceSpellId,
        'sourceCategory': sourceCategory.name,
      };

  /// Deserializes both unified Cleanup slice 18+ monster maps (with embedded
  /// `statBlock2014` / `statBlock2024`) and legacy records saved before Cleanup
  /// slice 18 (without embedded stat blocks, hydrated via
  /// [hydrateLegacyMonsterStatBlock]).
  factory Monster.fromMap(
    Map<String, dynamic> map, {
    MonsterStatBlock? Function(String name)? baseStatBlockLookup,
  }) {
    final id = EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {}));
    final name = map['name']?.toString() ?? '';
    final actionsMarkdown = map['actionsMarkdown']?.toString() ?? '';
    final innateSpells = (map['innateSpells'] as List? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((s) =>
            EntityReference<Spell>.fromMap(Map<String, dynamic>.from(s)))
        .toList();
    final attackMath = (map['attackMath'] as List? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((a) => EvaluationMath.fromMap(Map<String, dynamic>.from(a)))
        .toList();
    final customProperties =
        Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});

    final hasEmbeddedStatBlocks =
        map.containsKey('statBlock2014') || map.containsKey('statBlock2024');
    if (hasEmbeddedStatBlocks) {
      final raw2014 = map['statBlock2014'];
      final raw2024 = map['statBlock2024'];
      final sb2014 = raw2014 is Map
          ? MonsterStatBlock.fromMap(Map<String, dynamic>.from(raw2014))
          : MonsterStatBlock.fromMap(Map<String, dynamic>.from(raw2024 as Map));
      final sb2024 = raw2024 is Map
          ? MonsterStatBlock.fromMap(Map<String, dynamic>.from(raw2024))
          : sb2014;
      final diffHighlights = (map['diffHighlights'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      return Monster(
        id: id,
        name: name,
        name2014: map['name2014']?.toString(),
        name2024: map['name2024']?.toString(),
        statBlock2014: sb2014,
        statBlock2024: sb2024,
        isChangedIn2024: map['isChangedIn2024'] == true,
        diffSummary: map['diffSummary']?.toString(),
        diffHighlights: diffHighlights,
        sourcePresetId: map['sourcePresetId']?.toString() ?? 'srd_bestiary',
        sourcePresetName:
            map['sourcePresetName']?.toString() ?? '5e SRD Bestiary',
        sourceSpellId: map['sourceSpellId']?.toString(),
        sourceCategory:
            SummonCategory.fromString(map['sourceCategory']?.toString()),
        actionsMarkdown: actionsMarkdown,
        innateSpells: innateSpells,
        attackMath: attackMath,
        customProperties: customProperties,
      );
    }

    // Legacy records saved before Cleanup slice 18 (no statBlock2014/statBlock2024)
    final size = map['size']?.toString();
    final monsterType = map['monsterType']?.toString();
    final alignment = map['alignment']?.toString();
    final armorClass = (map['armorClass'] as num?)?.toInt();
    final hitPoints = (map['hitPoints'] as num?)?.toInt();
    final hitDieFormula = map['hitDieFormula']?.toString();
    final challengeRating = map['challengeRating']?.toString();

    final statBlock = hydrateLegacyMonsterStatBlock(
      id: id,
      name: name,
      size: size,
      monsterType: monsterType,
      alignment: alignment,
      armorClass: armorClass,
      hitPoints: hitPoints,
      hitDieFormula: hitDieFormula,
      challengeRating: challengeRating,
      actionsMarkdown: actionsMarkdown,
      attackMath: attackMath,
      customProperties: customProperties,
      baseStatBlockLookup: baseStatBlockLookup,
    );

    return Monster(
      id: id,
      name: name,
      statBlock2014: statBlock,
      statBlock2024: statBlock,
      sourcePresetId: 'homebrew',
      sourcePresetName: 'Homebrew & Custom Creatures',
      sourceCategory: SummonCategory.spell,
      actionsMarkdown: actionsMarkdown,
      innateSpells: innateSpells,
      attackMath: attackMath,
      customProperties: customProperties,
    );
  }

  Monster copyWith({
    EntityId? id,
    String? name,
    String? name2014,
    String? name2024,
    MonsterStatBlock? statBlock2014,
    MonsterStatBlock? statBlock2024,
    bool? isChangedIn2024,
    String? diffSummary,
    List<String>? diffHighlights,
    String? sourcePresetId,
    String? sourcePresetName,
    String? sourceSpellId,
    SummonCategory? sourceCategory,
    String? actionsMarkdown,
    List<EntityReference<Spell>>? innateSpells,
    List<EvaluationMath>? attackMath,
    Map<String, dynamic>? customProperties,
  }) {
    return Monster(
      id: id ?? this.id,
      name: name ?? this.name,
      name2014: name2014 ?? this.name2014,
      name2024: name2024 ?? this.name2024,
      statBlock2014: statBlock2014 ?? this.statBlock2014,
      statBlock2024: statBlock2024 ?? this.statBlock2024,
      isChangedIn2024: isChangedIn2024 ?? this.isChangedIn2024,
      diffSummary: diffSummary ?? this.diffSummary,
      diffHighlights: diffHighlights ?? this.diffHighlights,
      sourcePresetId: sourcePresetId ?? this.sourcePresetId,
      sourcePresetName: sourcePresetName ?? this.sourcePresetName,
      sourceSpellId: sourceSpellId ?? this.sourceSpellId,
      sourceCategory: sourceCategory ?? this.sourceCategory,
      actionsMarkdown: actionsMarkdown ?? this.actionsMarkdown,
      innateSpells: innateSpells ?? this.innateSpells,
      attackMath: attackMath ?? this.attackMath,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  static const _eq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Monster || runtimeType != other.runtimeType) return false;
    return id == other.id &&
        name == other.name &&
        name2014 == other.name2014 &&
        name2024 == other.name2024 &&
        statBlock2014 == other.statBlock2014 &&
        statBlock2024 == other.statBlock2024 &&
        isChangedIn2024 == other.isChangedIn2024 &&
        diffSummary == other.diffSummary &&
        _eq.equals(diffHighlights, other.diffHighlights) &&
        sourcePresetId == other.sourcePresetId &&
        sourcePresetName == other.sourcePresetName &&
        sourceSpellId == other.sourceSpellId &&
        sourceCategory == other.sourceCategory &&
        actionsMarkdown == other.actionsMarkdown &&
        _eq.equals(innateSpells, other.innateSpells) &&
        _eq.equals(attackMath, other.attackMath) &&
        _eq.equals(customProperties, other.customProperties);
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        name2014,
        name2024,
        statBlock2014,
        statBlock2024,
        isChangedIn2024,
        diffSummary,
        _eq.hash(diffHighlights),
        sourcePresetId,
        sourcePresetName,
        sourceSpellId,
        sourceCategory,
        actionsMarkdown,
        _eq.hash(innateSpells),
        _eq.hash(attackMath),
        _eq.hash(customProperties),
      ]);
}
