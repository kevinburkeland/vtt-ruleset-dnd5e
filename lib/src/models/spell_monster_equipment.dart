import 'package:meta/meta.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'feature_grant.dart';
import 'core_types.dart';
import '../attributes/dnd5e_attributes.dart';


extension CombatRiderDefinitionSerialization on CombatRiderDefinition {
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'riderType': riderType,
        'params': params,
      };

  static CombatRiderDefinition fromMap(Map<String, dynamic> map) =>
      CombatRiderDefinition(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        riderType: map['riderType']?.toString() ?? 'condition',
        params: map['params'] is Map
            ? Map<String, dynamic>.from(map['params'] as Map)
            : const {},
      );
}


/// Isolated mathematical formula for damage and dice evaluation
@immutable
class EvaluationMath {
  final String diceFormula; // e.g. "8d6"
  final DamageType damageType;
  final String? scalingFormula; // e.g. "+1d6 per slot above 3rd"
  final bool isAttackRoll;
  final bool requiresSave;

  const EvaluationMath({
    required this.diceFormula,
    required this.damageType,
    this.scalingFormula,
    this.isAttackRoll = false,
    this.requiresSave = false,
  });

  Map<String, dynamic> toMap() => {
        'diceFormula': diceFormula,
        'damageType': damageType.name,
        if (scalingFormula != null) 'scalingFormula': scalingFormula,
        'isAttackRoll': isAttackRoll,
        'requiresSave': requiresSave,
      };

  factory EvaluationMath.fromMap(Map<String, dynamic> map) {
    return EvaluationMath(
      diceFormula: map['diceFormula']?.toString() ?? '',
      damageType: DamageType.fromString(map['damageType']?.toString()),
      scalingFormula: map['scalingFormula']?.toString(),
      isAttackRoll: map['isAttackRoll'] == true,
      requiresSave: map['requiresSave'] == true,
    );
  }
}

/// Standardized Spell Components
@immutable
class SpellComponents {
  final bool verbal;
  final bool somatic;
  final bool material;
  final String? materialDescription;
  final int? materialCostGp;
  final bool consumesMaterial;

  const SpellComponents({
    this.verbal = false,
    this.somatic = false,
    this.material = false,
    this.materialDescription,
    this.materialCostGp,
    this.consumesMaterial = false,
  });

  Map<String, dynamic> toMap() => {
        'verbal': verbal,
        'somatic': somatic,
        'material': material,
        if (materialDescription != null) 'materialDescription': materialDescription,
        if (materialCostGp != null) 'materialCostGp': materialCostGp,
        'consumesMaterial': consumesMaterial,
      };

  factory SpellComponents.fromMap(Map<String, dynamic> map) {
    return SpellComponents(
      verbal: map['verbal'] == true,
      somatic: map['somatic'] == true,
      material: map['material'] == true,
      materialDescription: map['materialDescription']?.toString(),
      materialCostGp: (map['materialCostGp'] as num?)?.toInt(),
      consumesMaterial: map['consumesMaterial'] == true,
    );
  }
}

/// Standardized Casting Time
@immutable
class CastingTime {
  final ActionType actionType;
  final int count; // e.g. 1 (action), 10 (minutes)
  final String? conditionDescription; // e.g. "which you take when you see a creature..."

  const CastingTime({
    required this.actionType,
    this.count = 1,
    this.conditionDescription,
  });

  Map<String, dynamic> toMap() => {
        'actionType': actionType.name,
        'count': count,
        if (conditionDescription != null)
          'conditionDescription': conditionDescription,
      };

  factory CastingTime.fromMap(Map<String, dynamic> map) {
    return CastingTime(
      actionType: ActionType.fromString(map['actionType']?.toString()),
      count: (map['count'] as num?)?.toInt() ?? 1,
      conditionDescription: map['conditionDescription']?.toString(),
    );
  }
}

/// Standardized Spell Duration
@immutable
class SpellDuration {
  final String type; // instantaneous, timed, permanent, special
  final int? durationMinutes;
  final bool requiresConcentration;

  const SpellDuration({
    required this.type,
    this.durationMinutes,
    this.requiresConcentration = false,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'requiresConcentration': requiresConcentration,
      };

  factory SpellDuration.fromMap(Map<String, dynamic> map) {
    return SpellDuration(
      type: map['type']?.toString() ?? 'instantaneous',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
      requiresConcentration: map['requiresConcentration'] == true,
    );
  }
}

/// Standardized Spell Domain Entity
@immutable
class Spell extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final int level;
  final String school;
  final CastingTime castingTime;
  final String range;
  final SpellComponents components;
  final SpellDuration duration;
  final String descriptionMarkdown;
  final EvaluationMath? math;
  final List<CombatRiderDefinition> riders;
  @override
  final Map<String, dynamic> customProperties;

  /// Pluggable static parser for extracting riders from text descriptions
  static List<CombatRiderDefinition> Function(String text)? riderExtractor;

  const Spell({
    required this.id,
    required this.name,
    required this.level,
    required this.school,
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.descriptionMarkdown,
    this.math,
    this.riders = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.spell;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'level': level,
        'school': school,
        'castingTime': castingTime.toMap(),
        'range': range,
        'components': components.toMap(),
        'duration': duration.toMap(),
        'descriptionMarkdown': descriptionMarkdown,
        if (math != null) 'math': math!.toMap(),
        'riders': riders.map((r) => r.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Spell.fromMap(Map<String, dynamic> map) {
    final rawRiders = map['riders'] as List?;
    final desc = map['descriptionMarkdown']?.toString() ?? '';
    final extractedRiders = riderExtractor != null && (rawRiders == null || rawRiders.isEmpty)
        ? riderExtractor!(desc)
        : (rawRiders ?? [])
            .map((r) => CombatRiderDefinitionSerialization.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();

    return Spell(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map)),
      name: map['name']?.toString() ?? '',
      level: (map['level'] as num?)?.toInt() ?? 0,
      school: map['school']?.toString() ?? 'evocation',
      castingTime: CastingTime.fromMap(Map<String, dynamic>.from(map['castingTime'] as Map)),
      range: map['range']?.toString() ?? 'self',
      components: SpellComponents.fromMap(Map<String, dynamic>.from(map['components'] as Map)),
      duration: SpellDuration.fromMap(Map<String, dynamic>.from(map['duration'] as Map)),
      descriptionMarkdown: desc,
      math: map['math'] != null
          ? EvaluationMath.fromMap(Map<String, dynamic>.from(map['math'] as Map))
          : null,
      riders: extractedRiders,
      customProperties: map['customProperties'] is Map
          ? Map<String, dynamic>.from(map['customProperties'] as Map)
          : const {},
    );
  }

  Spell copyWith({
    EntityId? id,
    String? name,
    int? level,
    String? school,
    CastingTime? castingTime,
    String? range,
    SpellComponents? components,
    SpellDuration? duration,
    String? descriptionMarkdown,
    EvaluationMath? math,
    List<CombatRiderDefinition>? riders,
    Map<String, dynamic>? customProperties,
  }) {
    return Spell(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      school: school ?? this.school,
      castingTime: castingTime ?? this.castingTime,
      range: range ?? this.range,
      components: components ?? this.components,
      duration: duration ?? this.duration,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      math: math ?? this.math,
      riders: riders ?? this.riders,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}

/// Standardized Monster Action Representation
@immutable
class MonsterAction {
  final String name;
  final String description;
  final int? attackBonus;
  final String? damageFormula;
  final DamageType? damageType;
  final String? reachOrRange;
  final List<CombatRiderDefinition> riders;

  const MonsterAction({
    required this.name,
    required this.description,
    this.attackBonus,
    this.damageFormula,
    this.damageType,
    this.reachOrRange,
    this.riders = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        if (attackBonus != null) 'attackBonus': attackBonus,
        if (damageFormula != null) 'damageFormula': damageFormula,
        if (damageType != null) 'damageType': damageType!.name,
        if (reachOrRange != null) 'reachOrRange': reachOrRange,
        'riders': riders.map((r) => r.toMap()).toList(),
      };

  factory MonsterAction.fromMap(Map<String, dynamic> map) {
    final rawRiders = map['riders'] as List?;
    return MonsterAction(
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      attackBonus: (map['attackBonus'] as num?)?.toInt(),
      damageFormula: map['damageFormula']?.toString(),
      damageType: DamageType.fromString(map['damageType']?.toString()),
      reachOrRange: map['reachOrRange']?.toString(),
      riders: (rawRiders ?? [])
          .map((r) => CombatRiderDefinitionSerialization.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

/// Standardized Monster Trait Representation
@immutable
class MonsterTrait {
  final String name;
  final String description;

  const MonsterTrait({
    required this.name,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
      };

  factory MonsterTrait.fromMap(Map<String, dynamic> map) {
    return MonsterTrait(
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }
}

/// Standardized Monster Domain Entity
@immutable
class Monster extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String size;
  final String creatureType;
  final String alignment;
  final int armorClass;
  final String? armorType;
  final int hitPoints;
  final String hitPointFormula;
  final String speed;
  final Map<AbilityType, int> abilityScores;
  final Map<SkillType, int> skills;
  final List<String> damageImmunities;
  final List<String> damageResistances;
  final List<String> damageVulnerabilities;
  final List<String> conditionImmunities;
  final String senses;
  final String languages;
  final String challengeRating;
  final int experiencePoints;
  final List<MonsterTrait> traits;
  final List<MonsterAction> actions;
  final List<MonsterAction> reactions;
  final List<MonsterAction> legendaryActions;
  @override
  final Map<String, dynamic> customProperties;

  const Monster({
    required this.id,
    required this.name,
    required this.size,
    required this.creatureType,
    required this.alignment,
    required this.armorClass,
    this.armorType,
    required this.hitPoints,
    required this.hitPointFormula,
    required this.speed,
    required this.abilityScores,
    this.skills = const {},
    this.damageImmunities = const [],
    this.damageResistances = const [],
    this.damageVulnerabilities = const [],
    this.conditionImmunities = const [],
    required this.senses,
    required this.languages,
    required this.challengeRating,
    required this.experiencePoints,
    this.traits = const [],
    this.actions = const [],
    this.reactions = const [],
    this.legendaryActions = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.monster;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'size': size,
        'creatureType': creatureType,
        'alignment': alignment,
        'armorClass': armorClass,
        if (armorType != null) 'armorType': armorType,
        'hitPoints': hitPoints,
        'hitPointFormula': hitPointFormula,
        'speed': speed,
        'abilityScores': abilityScores.map((k, v) => MapEntry(k.name, v)),
        'skills': skills.map((k, v) => MapEntry(k.name, v)),
        'damageImmunities': damageImmunities,
        'damageResistances': damageResistances,
        'damageVulnerabilities': damageVulnerabilities,
        'conditionImmunities': conditionImmunities,
        'senses': senses,
        'languages': languages,
        'challengeRating': challengeRating,
        'experiencePoints': experiencePoints,
        'traits': traits.map((t) => t.toMap()).toList(),
        'actions': actions.map((a) => a.toMap()).toList(),
        'reactions': reactions.map((r) => r.toMap()).toList(),
        'legendaryActions': legendaryActions.map((l) => l.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory Monster.fromMap(Map<String, dynamic> map) {
    final rawScores = map['abilityScores'] as Map?;
    final parsedScores = <AbilityType, int>{};
    rawScores?.forEach((k, v) {
      if (v is num) {
        parsedScores[AbilityType.fromString(k.toString())] = v.toInt();
      }
    });

    final rawSkills = map['skills'] as Map?;
    final parsedSkills = <SkillType, int>{};
    rawSkills?.forEach((k, v) {
      if (v is num) {
        parsedSkills[SkillType.fromString(k.toString())] = v.toInt();
      }
    });

    return Monster(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map)),
      name: map['name']?.toString() ?? '',
      size: map['size']?.toString() ?? 'Medium',
      creatureType: map['creatureType']?.toString() ?? 'humanoid',
      alignment: map['alignment']?.toString() ?? 'unaligned',
      armorClass: (map['armorClass'] as num?)?.toInt() ?? 10,
      armorType: map['armorType']?.toString(),
      hitPoints: (map['hitPoints'] as num?)?.toInt() ?? 10,
      hitPointFormula: map['hitPointFormula']?.toString() ?? '2d8',
      speed: map['speed']?.toString() ?? '30 ft.',
      abilityScores: parsedScores,
      skills: parsedSkills,
      damageImmunities: List<String>.from(map['damageImmunities'] ?? []),
      damageResistances: List<String>.from(map['damageResistances'] ?? []),
      damageVulnerabilities: List<String>.from(map['damageVulnerabilities'] ?? []),
      conditionImmunities: List<String>.from(map['conditionImmunities'] ?? []),
      senses: map['senses']?.toString() ?? '',
      languages: map['languages']?.toString() ?? '',
      challengeRating: map['challengeRating']?.toString() ?? '1',
      experiencePoints: (map['experiencePoints'] as num?)?.toInt() ?? 200,
      traits: ((map['traits'] as List?) ?? [])
          .map((t) => MonsterTrait.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
      actions: ((map['actions'] as List?) ?? [])
          .map((a) => MonsterAction.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
      reactions: ((map['reactions'] as List?) ?? [])
          .map((r) => MonsterAction.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
      legendaryActions: ((map['legendaryActions'] as List?) ?? [])
          .map((l) => MonsterAction.fromMap(Map<String, dynamic>.from(l as Map)))
          .toList(),
      customProperties: map['customProperties'] is Map
          ? Map<String, dynamic>.from(map['customProperties'] as Map)
          : const {},
    );
  }
}

/// Standardized Equipment Domain Entity
@immutable
class EquipmentItem extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String itemType; // weapon, armor, adventuring-gear, shield
  final String rarity; // common, uncommon, rare, very rare, legendary, artifact
  final bool requiresAttunement;
  final String descriptionMarkdown;
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  const EquipmentItem({
    required this.id,
    required this.name,
    required this.itemType,
    this.rarity = 'common',
    this.requiresAttunement = false,
    required this.descriptionMarkdown,
    this.grants = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.equipment;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'itemType': itemType,
        'rarity': rarity,
        'requiresAttunement': requiresAttunement,
        'descriptionMarkdown': descriptionMarkdown,
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  factory EquipmentItem.fromMap(Map<String, dynamic> map) {
    return EquipmentItem(
      id: EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map)),
      name: map['name']?.toString() ?? '',
      itemType: map['itemType']?.toString() ?? 'adventuring-gear',
      rarity: map['rarity']?.toString() ?? 'common',
      requiresAttunement: map['requiresAttunement'] == true,
      descriptionMarkdown: map['descriptionMarkdown']?.toString() ?? '',
      grants: ((map['grants'] as List?) ?? [])
          .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g as Map)))
          .toList(),
      customProperties: map['customProperties'] is Map
          ? Map<String, dynamic>.from(map['customProperties'] as Map)
          : const {},
    );
  }

  EquipmentItem copyWith({
    EntityId? id,
    String? name,
    String? itemType,
    String? rarity,
    bool? requiresAttunement,
    String? descriptionMarkdown,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      itemType: itemType ?? this.itemType,
      rarity: rarity ?? this.rarity,
      requiresAttunement: requiresAttunement ?? this.requiresAttunement,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }
}