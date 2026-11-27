import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../attributes/dnd5e_attributes.dart';
import '../attributes/dnd_5e_rules_engine.dart';

/// Source category for a summonable creature preset or monster entry.
enum SummonCategory {
  spell,
  magicItem;

  static SummonCategory fromString(String? value) {
    if (value == null) return SummonCategory.spell;
    final clean = value.trim().toLowerCase();
    for (final cat in SummonCategory.values) {
      if (cat.name.toLowerCase() == clean) return cat;
    }
    return SummonCategory.spell;
  }
}

/// A named passive trait on a creature stat block.
@immutable
class CreatureTrait {
  final String name;
  final String description;

  const CreatureTrait({
    required this.name,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
      };

  factory CreatureTrait.fromMap(Map<String, dynamic> map) {
    return CreatureTrait(
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatureTrait &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description;

  @override
  int get hashCode => Object.hash(name, description);
}

/// An action, reaction, or legendary action on a creature stat block.
@immutable
class CreatureAction {
  final String name;
  final String description;
  final String? attackType;
  final int? attackBonus;
  final String? reach;
  final String? hitDamage;

  const CreatureAction({
    required this.name,
    required this.description,
    this.attackType,
    this.attackBonus,
    this.reach,
    this.hitDamage,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        if (attackType != null) 'attackType': attackType,
        if (attackBonus != null) 'attackBonus': attackBonus,
        if (reach != null) 'reach': reach,
        if (hitDamage != null) 'hitDamage': hitDamage,
      };

  factory CreatureAction.fromMap(Map<String, dynamic> map) {
    return CreatureAction(
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      attackType: map['attackType']?.toString(),
      attackBonus: (map['attackBonus'] as num?)?.toInt(),
      reach: map['reach']?.toString(),
      hitDamage: map['hitDamage']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatureAction &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          attackType == other.attackType &&
          attackBonus == other.attackBonus &&
          reach == other.reach &&
          hitDamage == other.hitDamage;

  @override
  int get hashCode => Object.hash(
        name,
        description,
        attackType,
        attackBonus,
        reach,
        hitDamage,
      );
}

/// Pure-Dart D&D 5e creature stat block shared across codex, arena, DPR,
/// and summon presets.
@immutable
class MonsterStatBlock {
  final String id;
  final String name;
  final String? sizeDisplay;
  final String? crDisplay;
  final String? typeDisplay;
  final String? alignment;
  final int? ac;
  final String? armorType;
  final int? maxHp;
  final String? hitDice;
  final String speed;
  final int strScore;
  final int dexScore;
  final int conScore;
  final int intScore;
  final int wisScore;
  final int chaScore;
  final String? savingThrows;
  final String? skills;
  final String? damageVulnerabilities;
  final String? damageResistances;
  final String? damageImmunities;
  final String? conditionImmunities;
  final String senses;
  final String languages;
  final int? xp;
  final List<CreatureTrait> traits;
  final List<CreatureAction> actions;
  final List<CreatureAction> reactions;
  final List<CreatureAction> legendaryActions;

  // Pre-calculated & strongly-typed ingestion fields
  final Map<int, int>? explicitSpellSlots;
  final int? explicitMeleeReachFt;
  final Map<AbilityType, int>? explicitSavingThrows;
  final bool? canFly;
  final bool? hasHover;
  final int? spellSaveDc;
  final int? spellAttackBonus;

  // Rapid batch dice roller fields
  final int attackBonus;
  final int damageDiceCount;
  final int damageDiceSides;
  final int damageBonus;
  final String damageType;
  final int secondaryDamageDiceCount;
  final int secondaryDamageDiceSides;
  final String? secondaryDamageType;
  final bool hasPackTactics;
  final String? specialTrait;

  const MonsterStatBlock({
    required this.id,
    required this.name,
    this.sizeDisplay,
    this.crDisplay,
    this.typeDisplay,
    this.alignment,
    this.ac,
    this.armorType,
    this.maxHp,
    this.hitDice,
    this.speed = '30 ft.',
    this.strScore = 10,
    this.dexScore = 10,
    this.conScore = 10,
    this.intScore = 10,
    this.wisScore = 10,
    this.chaScore = 10,
    this.savingThrows,
    this.skills,
    this.damageVulnerabilities,
    this.damageResistances,
    this.damageImmunities,
    this.conditionImmunities,
    this.senses = 'passive Perception 10',
    this.languages = '—',
    this.xp,
    this.traits = const [],
    this.actions = const [],
    this.reactions = const [],
    this.legendaryActions = const [],
    this.explicitSpellSlots,
    this.explicitMeleeReachFt,
    this.explicitSavingThrows,
    this.canFly,
    this.hasHover,
    this.spellSaveDc,
    this.spellAttackBonus,
    required this.attackBonus,
    required this.damageDiceCount,
    required this.damageDiceSides,
    required this.damageBonus,
    required this.damageType,
    this.secondaryDamageDiceCount = 0,
    this.secondaryDamageDiceSides = 0,
    this.secondaryDamageType,
    this.hasPackTactics = false,
    this.specialTrait,
  });

  bool get hasLegendary =>
      legendaryActions.isNotEmpty ||
      hasLegendaryResistance ||
      hasLegendaryActions;

  bool get hasLegendaryResistance =>
      traits.any((t) => t.name.toLowerCase().contains('legendary resistance'));

  bool get hasLegendaryActions =>
      legendaryActions.isNotEmpty ||
      traits.any((t) => t.name.toLowerCase().contains('legendary action')) ||
      actions.any((a) => a.name.toLowerCase().contains('legendary action'));

  int get strMod => strScore.dndModifier;
  int get dexMod => dexScore.dndModifier;
  int get conMod => conScore.dndModifier;
  int get intMod => intScore.dndModifier;
  int get wisMod => wisScore.dndModifier;
  int get chaMod => chaScore.dndModifier;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (sizeDisplay != null) 'sizeDisplay': sizeDisplay,
        if (crDisplay != null) 'crDisplay': crDisplay,
        if (typeDisplay != null) 'typeDisplay': typeDisplay,
        if (alignment != null) 'alignment': alignment,
        if (ac != null) 'ac': ac,
        if (armorType != null) 'armorType': armorType,
        if (maxHp != null) 'maxHp': maxHp,
        if (hitDice != null) 'hitDice': hitDice,
        'speed': speed,
        'strScore': strScore,
        'dexScore': dexScore,
        'conScore': conScore,
        'intScore': intScore,
        'wisScore': wisScore,
        'chaScore': chaScore,
        if (savingThrows != null) 'savingThrows': savingThrows,
        if (skills != null) 'skills': skills,
        if (damageVulnerabilities != null)
          'damageVulnerabilities': damageVulnerabilities,
        if (damageResistances != null) 'damageResistances': damageResistances,
        if (damageImmunities != null) 'damageImmunities': damageImmunities,
        if (conditionImmunities != null)
          'conditionImmunities': conditionImmunities,
        'senses': senses,
        'languages': languages,
        if (xp != null) 'xp': xp,
        'traits': traits.map((t) => t.toMap()).toList(),
        'actions': actions.map((a) => a.toMap()).toList(),
        'legendaryActions': legendaryActions.map((l) => l.toMap()).toList(),
        if (explicitSpellSlots != null)
          'explicitSpellSlots': {
            for (final e in explicitSpellSlots!.entries) '${e.key}': e.value,
          },
        if (explicitMeleeReachFt != null)
          'explicitMeleeReachFt': explicitMeleeReachFt,
        if (explicitSavingThrows != null)
          'explicitSavingThrows': {
            for (final e in explicitSavingThrows!.entries) e.key.name: e.value,
          },
        if (canFly != null) 'canFly': canFly,
        if (hasHover != null) 'hasHover': hasHover,
        if (spellSaveDc != null) 'spellSaveDc': spellSaveDc,
        if (spellAttackBonus != null) 'spellAttackBonus': spellAttackBonus,
        'attackBonus': attackBonus,
        'damageDiceCount': damageDiceCount,
        'damageDiceSides': damageDiceSides,
        'damageBonus': damageBonus,
        'damageType': damageType,
        'secondaryDamageDiceCount': secondaryDamageDiceCount,
        'secondaryDamageDiceSides': secondaryDamageDiceSides,
        if (secondaryDamageType != null)
          'secondaryDamageType': secondaryDamageType,
        'hasPackTactics': hasPackTactics,
        if (specialTrait != null) 'specialTrait': specialTrait,
      };

  factory MonsterStatBlock.fromMap(Map<String, dynamic> map) {
    Map<int, int>? parsedSlots;
    final rawSlots = map['explicitSpellSlots'];
    if (rawSlots is Map) {
      parsedSlots = <int, int>{};
      rawSlots.forEach((key, value) {
        final k = key is int ? key : int.tryParse(key.toString());
        final v = value is num ? value.toInt() : int.tryParse(value.toString());
        if (k != null && v != null) {
          parsedSlots![k] = v;
        }
      });
    }

    Map<AbilityType, int>? parsedSaves;
    final rawSaves = map['explicitSavingThrows'];
    if (rawSaves is Map) {
      parsedSaves = <AbilityType, int>{};
      rawSaves.forEach((key, value) {
        final v = value is num ? value.toInt() : int.tryParse(value.toString());
        if (v != null) {
          parsedSaves![AbilityType.fromString(key.toString())] = v;
        }
      });
    }

    List<CreatureTrait> parseTraits(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => CreatureTrait.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }

    List<CreatureAction> parseActions(Object? raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => CreatureAction.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }

    return MonsterStatBlock(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sizeDisplay: map['sizeDisplay']?.toString(),
      crDisplay: map['crDisplay']?.toString(),
      typeDisplay: map['typeDisplay']?.toString(),
      alignment: map['alignment']?.toString(),
      ac: (map['ac'] as num?)?.toInt(),
      armorType: map['armorType']?.toString(),
      maxHp: (map['maxHp'] as num?)?.toInt(),
      hitDice: map['hitDice']?.toString(),
      speed: map['speed']?.toString() ?? '30 ft.',
      strScore: (map['strScore'] as num?)?.toInt() ?? 10,
      dexScore: (map['dexScore'] as num?)?.toInt() ?? 10,
      conScore: (map['conScore'] as num?)?.toInt() ?? 10,
      intScore: (map['intScore'] as num?)?.toInt() ?? 10,
      wisScore: (map['wisScore'] as num?)?.toInt() ?? 10,
      chaScore: (map['chaScore'] as num?)?.toInt() ?? 10,
      savingThrows: map['savingThrows']?.toString(),
      skills: map['skills']?.toString(),
      damageVulnerabilities: map['damageVulnerabilities']?.toString(),
      damageResistances: map['damageResistances']?.toString(),
      damageImmunities: map['damageImmunities']?.toString(),
      conditionImmunities: map['conditionImmunities']?.toString(),
      senses: map['senses']?.toString() ?? 'passive Perception 10',
      languages: map['languages']?.toString() ?? '—',
      xp: (map['xp'] as num?)?.toInt(),
      traits: parseTraits(map['traits']),
      actions: parseActions(map['actions']),
      reactions: parseActions(map['reactions']),
      legendaryActions: parseActions(map['legendaryActions']),
      explicitSpellSlots: parsedSlots,
      explicitMeleeReachFt: (map['explicitMeleeReachFt'] as num?)?.toInt(),
      explicitSavingThrows: parsedSaves,
      canFly: map['canFly'] is bool ? map['canFly'] as bool : null,
      hasHover: map['hasHover'] is bool ? map['hasHover'] as bool : null,
      spellSaveDc: (map['spellSaveDc'] as num?)?.toInt(),
      spellAttackBonus: (map['spellAttackBonus'] as num?)?.toInt(),
      attackBonus: (map['attackBonus'] as num?)?.toInt() ?? 0,
      damageDiceCount: (map['damageDiceCount'] as num?)?.toInt() ?? 0,
      damageDiceSides: (map['damageDiceSides'] as num?)?.toInt() ?? 0,
      damageBonus: (map['damageBonus'] as num?)?.toInt() ?? 0,
      damageType: map['damageType']?.toString() ?? '',
      secondaryDamageDiceCount:
          (map['secondaryDamageDiceCount'] as num?)?.toInt() ?? 0,
      secondaryDamageDiceSides:
          (map['secondaryDamageDiceSides'] as num?)?.toInt() ?? 0,
      secondaryDamageType: map['secondaryDamageType']?.toString(),
      hasPackTactics: map['hasPackTactics'] == true,
      specialTrait: map['specialTrait']?.toString(),
    );
  }

  MonsterStatBlock copyWith({
    String? id,
    String? name,
    String? sizeDisplay,
    String? crDisplay,
    String? typeDisplay,
    String? alignment,
    int? ac,
    String? armorType,
    int? maxHp,
    String? hitDice,
    String? speed,
    int? strScore,
    int? dexScore,
    int? conScore,
    int? intScore,
    int? wisScore,
    int? chaScore,
    String? savingThrows,
    String? skills,
    String? damageVulnerabilities,
    String? damageResistances,
    String? damageImmunities,
    String? conditionImmunities,
    String? senses,
    String? languages,
    int? xp,
    List<CreatureTrait>? traits,
    List<CreatureAction>? actions,
    List<CreatureAction>? reactions,
    List<CreatureAction>? legendaryActions,
    Map<int, int>? explicitSpellSlots,
    int? explicitMeleeReachFt,
    Map<AbilityType, int>? explicitSavingThrows,
    bool? canFly,
    bool? hasHover,
    int? spellSaveDc,
    int? spellAttackBonus,
    int? attackBonus,
    int? damageDiceCount,
    int? damageDiceSides,
    int? damageBonus,
    String? damageType,
    int? secondaryDamageDiceCount,
    int? secondaryDamageDiceSides,
    String? secondaryDamageType,
    bool? hasPackTactics,
    String? specialTrait,
  }) {
    return MonsterStatBlock(
      id: id ?? this.id,
      name: name ?? this.name,
      sizeDisplay: sizeDisplay ?? this.sizeDisplay,
      crDisplay: crDisplay ?? this.crDisplay,
      typeDisplay: typeDisplay ?? this.typeDisplay,
      alignment: alignment ?? this.alignment,
      ac: ac ?? this.ac,
      armorType: armorType ?? this.armorType,
      maxHp: maxHp ?? this.maxHp,
      hitDice: hitDice ?? this.hitDice,
      speed: speed ?? this.speed,
      strScore: strScore ?? this.strScore,
      dexScore: dexScore ?? this.dexScore,
      conScore: conScore ?? this.conScore,
      intScore: intScore ?? this.intScore,
      wisScore: wisScore ?? this.wisScore,
      chaScore: chaScore ?? this.chaScore,
      savingThrows: savingThrows ?? this.savingThrows,
      skills: skills ?? this.skills,
      damageVulnerabilities:
          damageVulnerabilities ?? this.damageVulnerabilities,
      damageResistances: damageResistances ?? this.damageResistances,
      damageImmunities: damageImmunities ?? this.damageImmunities,
      conditionImmunities: conditionImmunities ?? this.conditionImmunities,
      senses: senses ?? this.senses,
      languages: languages ?? this.languages,
      xp: xp ?? this.xp,
      traits: traits ?? this.traits,
      actions: actions ?? this.actions,
      reactions: reactions ?? this.reactions,
      legendaryActions: legendaryActions ?? this.legendaryActions,
      explicitSpellSlots: explicitSpellSlots ?? this.explicitSpellSlots,
      explicitMeleeReachFt: explicitMeleeReachFt ?? this.explicitMeleeReachFt,
      explicitSavingThrows: explicitSavingThrows ?? this.explicitSavingThrows,
      canFly: canFly ?? this.canFly,
      hasHover: hasHover ?? this.hasHover,
      spellSaveDc: spellSaveDc ?? this.spellSaveDc,
      spellAttackBonus: spellAttackBonus ?? this.spellAttackBonus,
      attackBonus: attackBonus ?? this.attackBonus,
      damageDiceCount: damageDiceCount ?? this.damageDiceCount,
      damageDiceSides: damageDiceSides ?? this.damageDiceSides,
      damageBonus: damageBonus ?? this.damageBonus,
      damageType: damageType ?? this.damageType,
      secondaryDamageDiceCount:
          secondaryDamageDiceCount ?? this.secondaryDamageDiceCount,
      secondaryDamageDiceSides:
          secondaryDamageDiceSides ?? this.secondaryDamageDiceSides,
      secondaryDamageType: secondaryDamageType ?? this.secondaryDamageType,
      hasPackTactics: hasPackTactics ?? this.hasPackTactics,
      specialTrait: specialTrait ?? this.specialTrait,
    );
  }

  static const _listEq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MonsterStatBlock || runtimeType != other.runtimeType) {
      return false;
    }
    return id == other.id &&
        name == other.name &&
        sizeDisplay == other.sizeDisplay &&
        crDisplay == other.crDisplay &&
        typeDisplay == other.typeDisplay &&
        alignment == other.alignment &&
        ac == other.ac &&
        armorType == other.armorType &&
        maxHp == other.maxHp &&
        hitDice == other.hitDice &&
        speed == other.speed &&
        strScore == other.strScore &&
        dexScore == other.dexScore &&
        conScore == other.conScore &&
        intScore == other.intScore &&
        wisScore == other.wisScore &&
        chaScore == other.chaScore &&
        savingThrows == other.savingThrows &&
        skills == other.skills &&
        damageVulnerabilities == other.damageVulnerabilities &&
        damageResistances == other.damageResistances &&
        damageImmunities == other.damageImmunities &&
        conditionImmunities == other.conditionImmunities &&
        senses == other.senses &&
        languages == other.languages &&
        xp == other.xp &&
        _listEq.equals(traits, other.traits) &&
        _listEq.equals(actions, other.actions) &&
        _listEq.equals(reactions, other.reactions) &&
        _listEq.equals(legendaryActions, other.legendaryActions) &&
        _listEq.equals(explicitSpellSlots, other.explicitSpellSlots) &&
        explicitMeleeReachFt == other.explicitMeleeReachFt &&
        _listEq.equals(explicitSavingThrows, other.explicitSavingThrows) &&
        canFly == other.canFly &&
        hasHover == other.hasHover &&
        spellSaveDc == other.spellSaveDc &&
        spellAttackBonus == other.spellAttackBonus &&
        attackBonus == other.attackBonus &&
        damageDiceCount == other.damageDiceCount &&
        damageDiceSides == other.damageDiceSides &&
        damageBonus == other.damageBonus &&
        damageType == other.damageType &&
        secondaryDamageDiceCount == other.secondaryDamageDiceCount &&
        secondaryDamageDiceSides == other.secondaryDamageDiceSides &&
        secondaryDamageType == other.secondaryDamageType &&
        hasPackTactics == other.hasPackTactics &&
        specialTrait == other.specialTrait;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        sizeDisplay,
        crDisplay,
        typeDisplay,
        alignment,
        ac,
        armorType,
        maxHp,
        hitDice,
        speed,
        strScore,
        dexScore,
        conScore,
        intScore,
        wisScore,
        chaScore,
        savingThrows,
        skills,
        damageVulnerabilities,
        damageResistances,
        damageImmunities,
        conditionImmunities,
        senses,
        languages,
        xp,
        _listEq.hash(traits),
        _listEq.hash(actions),
        _listEq.hash(reactions),
        _listEq.hash(legendaryActions),
        _listEq.hash(explicitSpellSlots),
        explicitMeleeReachFt,
        _listEq.hash(explicitSavingThrows),
        canFly,
        hasHover,
        spellSaveDc,
        spellAttackBonus,
        attackBonus,
        damageDiceCount,
        damageDiceSides,
        damageBonus,
        damageType,
        secondaryDamageDiceCount,
        secondaryDamageDiceSides,
        secondaryDamageType,
        hasPackTactics,
        specialTrait,
      ]);
}
