import 'package:meta/meta.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'package:vtt_engine_core/simulation/combat_rider.dart';

import '../catalog/dnd5e_catalog.dart';
import '../spellcasting/spellcasting_rules_engine.dart'
    show SpellClass, SpellMaterialComponent, SpellScalingFormula;
import 'core_types.dart';
import 'spell_monster_equipment.dart';

/// Detailed rules information for a specific rules edition of a spell.
@immutable
class SpellEditionDetails {
  final SpellSchool? schoolOverride;
  final String castingTime;
  final String range;
  final String
      components; // e.g. "V, S, M (a tiny ball of bat guano and pitch)"
  final SpellMaterialComponent? materialDetails;
  final String duration;
  final bool concentration;
  final bool ritual;
  final List<String> description;
  final String? higherLevels;
  final List<SpellClass> classes;
  final String? rollFormula; // e.g. "8d6" or "2d8 + mod"
  final SpellScalingFormula? scalingFormula;
  final String? damageOrHealType; // e.g. "Fire", "Healing", "Radiant"
  final String? savingThrow; // e.g. "Dexterity", "Wisdom"
  final String? reactionTrigger;

  const SpellEditionDetails({
    this.schoolOverride,
    required this.castingTime,
    required this.range,
    required this.components,
    this.materialDetails,
    required this.duration,
    this.concentration = false,
    this.ritual = false,
    required this.description,
    this.higherLevels,
    required this.classes,
    this.rollFormula,
    this.scalingFormula,
    this.damageOrHealType,
    this.savingThrow,
    this.reactionTrigger,
  });

  const SpellEditionDetails.empty()
      : schoolOverride = null,
        castingTime = '1 Action',
        range = 'Self',
        components = '',
        materialDetails = null,
        duration = 'Instantaneous',
        concentration = false,
        ritual = false,
        description = const [],
        higherLevels = null,
        classes = const [],
        rollFormula = null,
        scalingFormula = null,
        damageOrHealType = null,
        savingThrow = null,
        reactionTrigger = null;

  Map<String, dynamic> toMap() => {
        'schoolOverride': schoolOverride?.name,
        'castingTime': castingTime,
        'range': range,
        'components': components,
        'materialDetails': materialDetails?.toMap(),
        'duration': duration,
        'concentration': concentration,
        'ritual': ritual,
        'description': description,
        'higherLevels': higherLevels,
        'classes': classes.map((c) => c.name).toList(),
        'rollFormula': rollFormula,
        'scalingFormula': scalingFormula?.toMap(),
        'damageOrHealType': damageOrHealType,
        'savingThrow': savingThrow,
        'reactionTrigger': reactionTrigger,
      };

  factory SpellEditionDetails.fromMap(Map<String, dynamic> map) {
    final overrideStr = map['schoolOverride']?.toString();
    final schoolOverride = overrideStr == null
        ? null
        : SpellSchool.values
            .where((s) => s.name == overrideStr)
            .firstOrNull;
    final rawClasses = map['classes'] as List? ?? const [];
    final classes = <SpellClass>[];
    for (final c in rawClasses) {
      final name = c.toString().toLowerCase().trim();
      final match = SpellClass.values
          .where((sc) =>
              sc.name.toLowerCase() == name || sc.label.toLowerCase() == name)
          .firstOrNull;
      if (match != null && !classes.contains(match)) {
        classes.add(match);
      }
    }
    return SpellEditionDetails(
      schoolOverride: schoolOverride,
      castingTime: map['castingTime']?.toString() ?? '1 Action',
      range: map['range']?.toString() ?? 'Self',
      components: map['components']?.toString() ?? '',
      materialDetails: map['materialDetails'] is Map
          ? SpellMaterialComponent.fromMap(
              Map<String, dynamic>.from(map['materialDetails'] as Map))
          : null,
      duration: map['duration']?.toString() ?? 'Instantaneous',
      concentration: map['concentration'] == true,
      ritual: map['ritual'] == true,
      description: (map['description'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      higherLevels: map['higherLevels']?.toString(),
      classes: classes,
      rollFormula: map['rollFormula']?.toString(),
      scalingFormula: map['scalingFormula'] is Map
          ? SpellScalingFormula.fromMap(
              Map<String, dynamic>.from(map['scalingFormula'] as Map))
          : null,
      damageOrHealType: map['damageOrHealType']?.toString(),
      savingThrow: map['savingThrow']?.toString(),
      reactionTrigger: map['reactionTrigger']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SpellEditionDetails) return false;
    return schoolOverride == other.schoolOverride &&
        castingTime == other.castingTime &&
        range == other.range &&
        components == other.components &&
        materialDetails == other.materialDetails &&
        duration == other.duration &&
        concentration == other.concentration &&
        ritual == other.ritual &&
        _listEquals(description, other.description) &&
        higherLevels == other.higherLevels &&
        _listEquals(classes, other.classes) &&
        rollFormula == other.rollFormula &&
        scalingFormula == other.scalingFormula &&
        damageOrHealType == other.damageOrHealType &&
        savingThrow == other.savingThrow &&
        reactionTrigger == other.reactionTrigger;
  }

  @override
  int get hashCode => Object.hash(
        schoolOverride,
        castingTime,
        range,
        components,
        materialDetails,
        duration,
        concentration,
        ritual,
        Object.hashAll(description),
        higherLevels,
        Object.hashAll(classes),
        rollFormula,
        scalingFormula,
        damageOrHealType,
        savingThrow,
        reactionTrigger,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k)) return false;
    final av = a[k];
    final bv = b[k];
    if (av is Map<String, dynamic> && bv is Map<String, dynamic>) {
      if (!_mapEquals(av, bv)) return false;
    } else if (av is List && bv is List) {
      if (!_listEquals(av, bv)) return false;
    } else if (av != bv) {
      return false;
    }
  }
  return true;
}

/// Legacy compatibility helper for pre-Cleanup slice 17 [Spell] records.
SpellSchool? _tryParseSpellSchool(String raw) {
  final clean = raw.trim().toLowerCase();
  for (final s in SpellSchool.values) {
    if (s.name.toLowerCase() == clean || s.displayName.toLowerCase() == clean) {
      return s;
    }
  }
  return null;
}

/// Legacy compatibility helper for pre-Cleanup slice 17 [Spell] records.
List<SpellClass> _extractLegacySpellClasses(Map<String, dynamic> cp) {
  final extracted = <SpellClass>[];
  final rawClasses = cp['classes'] ??
      (cp['customProperties'] is Map
          ? (cp['customProperties'] as Map)['classes']
          : null);
  final candidates = <dynamic>[];
  if (rawClasses is List) {
    candidates.addAll(rawClasses);
  } else if (rawClasses is Map) {
    if (rawClasses['fromClassList'] is List) {
      candidates.addAll(rawClasses['fromClassList'] as List);
    }
    if (rawClasses['fromClassListVariant'] is List) {
      candidates.addAll(rawClasses['fromClassListVariant'] as List);
    }
    if (rawClasses['fromSubclass'] is List) {
      for (final sub in (rawClasses['fromSubclass'] as List)) {
        if (sub is Map && sub['class'] != null) {
          candidates.add(sub['class']);
        }
      }
    }
  }
  for (final c in candidates) {
    if (c is SpellClass) {
      if (!extracted.contains(c)) extracted.add(c);
      continue;
    }
    final name = (c is Map && c['name'] != null ? c['name'] : c)
        .toString()
        .replaceFirst('SpellClass.', '')
        .toLowerCase()
        .trim();
    final match = SpellClass.values
        .where((sc) =>
            sc.name.toLowerCase() == name || sc.label.toLowerCase() == name)
        .firstOrNull;
    if (match != null && !extracted.contains(match)) {
      extracted.add(match);
    }
  }
  return extracted;
}

/// Legacy compatibility helper for pre-Cleanup slice 17 [Spell] records.
List<String> _extractLegacySpellTags(Map<String, dynamic> cp) {
  final tags = <String>[];
  if (cp['areaTags'] is List) {
    for (final t in (cp['areaTags'] as List)) {
      tags.add(t.toString());
    }
  }
  if (cp['miscTags'] is List) {
    for (final t in (cp['miscTags'] as List)) {
      tags.add(t.toString());
    }
  }
  if (cp['source'] != null) {
    tags.add(cp['source'].toString());
  }
  if (cp['otherSources'] is List) {
    for (final item in (cp['otherSources'] as List)) {
      if (item is Map && item['source'] != null) {
        tags.add(item['source'].toString());
      } else if (item != null) {
        tags.add(item.toString());
      }
    }
  }
  if (cp['referenceSources'] is List) {
    for (final item in (cp['referenceSources'] as List)) {
      tags.add(item.toString());
    }
  }
  return tags;
}

/// Unified Spell Domain Model (both 2014 RAW and 2024 Revised).
@immutable
class Spell extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String? name2014;
  final String? name2024;
  final int level;
  final String school;
  final SpellSchool? schoolEnum;
  final CastingTime castingTime;
  final SpellDuration duration;
  final String range;
  final int rangeDistanceFeet;
  final String rangeType;
  final String? damageType;
  final SpellComponents components;
  final String descriptionMarkdown;
  final String? higherLevelsMarkdown;
  final List<EvaluationMath> damageMath;
  final List<EntityReference<DomainEntity>> relatedEntityRefs;
  final List<CombatEffectRider> riders;
  final SpellEditionDetails rules2014;
  final SpellEditionDetails rules2024;
  final bool isChangedIn2024;
  final String? diffSummary;
  final List<String> diffHighlights;
  final List<String> tags;
  @override
  final Map<String, dynamic> customProperties;

  const Spell({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required this.level,
    required this.school,
    this.schoolEnum,
    required this.castingTime,
    required this.duration,
    required this.range,
    this.rangeDistanceFeet = 0,
    this.rangeType = 'ranged',
    this.damageType,
    required this.components,
    required this.descriptionMarkdown,
    this.higherLevelsMarkdown,
    this.damageMath = const [],
    this.relatedEntityRefs = const [],
    this.riders = const [],
    this.rules2014 = const SpellEditionDetails.empty(),
    this.rules2024 = const SpellEditionDetails.empty(),
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.tags = const [],
    this.customProperties = const {},
  });

  @override
  EntityType get entityType => EntityType.spell;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'name2014': name2014,
        'name2024': name2024,
        'level': level,
        'school': school,
        'schoolEnum': schoolEnum?.name,
        'castingTime': castingTime.toMap(),
        'duration': duration.toMap(),
        'range': range,
        'rangeDistanceFeet': rangeDistanceFeet,
        'rangeType': rangeType,
        if (damageType != null) 'damageType': damageType,
        'components': components.toMap(),
        'descriptionMarkdown': descriptionMarkdown,
        'higherLevelsMarkdown': higherLevelsMarkdown,
        'damageMath': damageMath.map((d) => d.toMap()).toList(),
        'relatedEntityRefs': relatedEntityRefs.map((r) => r.toMap()).toList(),
        'rules2014': rules2014.toMap(),
        'isChangedIn2024': isChangedIn2024,
        'diffSummary': diffSummary,
        'diffHighlights': diffHighlights,
        'tags': tags,
        if (customProperties.containsKey('classes'))
          'classes': customProperties['classes'],
        'customProperties': customProperties,
      };

  /// Decodes a [Spell] from a serialized map.
  ///
  /// Supports both unified Cleanup slice 17 maps and legacy pre-Cleanup slice 17
  /// records (which lack `rules2014`/`rules2024` and are hydrated from the
  /// legacy single-edition fields without losing unknown school names).
  factory Spell.fromMap(Map<String, dynamic> map) {
    final cp = Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});
    if (cp.containsKey('customProperties') && cp['customProperties'] is Map) {
      final nested = Map<String, dynamic>.from(cp['customProperties'] as Map);
      cp.remove('customProperties');
      cp.addAll(nested);
    }
    if (map.containsKey('classes') && !cp.containsKey('classes')) {
      cp['classes'] = map['classes'];
    }
    final rawRange = map['range']?.toString() ?? 'Self';
    int distFeet = (map['rangeDistanceFeet'] as num?)?.toInt() ?? 0;
    String rType = map['rangeType']?.toString() ?? 'ranged';
    if (distFeet <= 0 && rawRange.isNotEmpty) {
      final lower = rawRange.toLowerCase();
      if (lower.contains('touch')) {
        rType = 'touch';
        distFeet = 0;
      } else if (lower.contains('self')) {
        rType = 'self';
        distFeet = 0;
      } else {
        if (lower.contains('line')) {
          rType = 'line';
        } else if (lower.contains('cone')) {
          rType = 'cone';
        } else if (lower.contains('radius') || lower.contains('sphere')) {
          rType = 'radius';
        }
        final digitMatch = RegExp(r'\d+').firstMatch(rawRange);
        if (digitMatch != null) {
          distFeet = int.tryParse(digitMatch.group(0) ?? '0') ?? 0;
          if (distFeet > 0 && lower.contains('mile')) {
            distFeet *= 5280;
          }
        }
      }
    }

    final id = EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {}));
    final name = map['name']?.toString() ?? '';
    final level = (map['level'] as num?)?.toInt() ?? 0;
    final school = map['school']?.toString() ?? 'Universal';
    final castingTime = CastingTime.fromMap(
        Map<String, dynamic>.from(map['castingTime'] as Map? ?? {}));
    final duration = SpellDuration.fromMap(
        Map<String, dynamic>.from(map['duration'] as Map? ?? {}));
    final components = SpellComponents.fromMap(
        Map<String, dynamic>.from(map['components'] as Map? ?? {}));
    final desc = map['descriptionMarkdown']?.toString() ?? '';
    final higherLevels = map['higherLevelsMarkdown']?.toString();
    final damageMath = (map['damageMath'] as List? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((d) => EvaluationMath.fromMap(Map<String, dynamic>.from(d)))
        .toList();
    final relatedEntityRefs = (map['relatedEntityRefs'] as List? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((r) => EntityReference.fromMap(Map<String, dynamic>.from(r)))
        .toList();
    final extractedRiders = Dnd5eRuleset.catalog.extractRiders(desc);

    final isUnified =
        map.containsKey('rules2014') || map.containsKey('rules2024');
    if (isUnified) {
      final rawEnum = map['schoolEnum']?.toString();
      final schoolEnum = rawEnum != null
          ? _tryParseSpellSchool(rawEnum)
          : (map.containsKey('schoolEnum') ? null : _tryParseSpellSchool(school));
      final r14 = map['rules2014'] is Map
          ? SpellEditionDetails.fromMap(
              Map<String, dynamic>.from(map['rules2014'] as Map))
          : const SpellEditionDetails.empty();
      final r24 = map['rules2024'] is Map
          ? SpellEditionDetails.fromMap(
              Map<String, dynamic>.from(map['rules2024'] as Map))
          : r14;
      return Spell(
        id: id,
        name: name,
        name2014: map['name2014']?.toString(),
        name2024: map['name2024']?.toString(),
        level: level,
        school: school,
        schoolEnum: schoolEnum,
        castingTime: castingTime,
        duration: duration,
        range: rawRange,
        rangeDistanceFeet: distFeet,
        rangeType: rType,
        damageType: map['damageType']?.toString(),
        components: components,
        descriptionMarkdown: desc,
        higherLevelsMarkdown: higherLevels,
        damageMath: damageMath,
        relatedEntityRefs: relatedEntityRefs,
        riders: extractedRiders,
        rules2014: r14,
        rules2024: r24,
        isChangedIn2024: map['isChangedIn2024'] == true,
        diffSummary: map['diffSummary']?.toString(),
        diffHighlights: (map['diffHighlights'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        tags: (map['tags'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        customProperties: cp,
      );
    }

    // Legacy pre-Cleanup slice 17 record hydration.
    final compList = <String>[];
    if (components.v) compList.add('V');
    if (components.s) compList.add('S');
    if (components.m) {
      final mDesc = components.materialDescription;
      compList.add(mDesc != null && mDesc.isNotEmpty ? 'M ($mDesc)' : 'M');
    }
    final durationText = duration.rawText ??
        (duration.type == DurationType.instantaneous
            ? 'Instantaneous'
            : (duration.type == DurationType.permanent
                ? 'Permanent'
                : (duration.type == DurationType.special
                    ? 'Special'
                    : '${duration.durationSeconds} seconds')));
    final meta = cp['meta'];
    final isRitual = (meta is Map && meta['ritual'] == true) || cp['ritual'] == true;
    String? savingThrow;
    final rawSt = cp['savingThrow'];
    if (rawSt is List && rawSt.isNotEmpty) {
      savingThrow = rawSt.map((e) => e.toString().trim()).join(', ');
    } else if (rawSt is String && rawSt.isNotEmpty) {
      savingThrow = rawSt.trim();
    }
    final legacyDetails = SpellEditionDetails(
      castingTime: castingTime.cost > 0
          ? '${castingTime.cost} ${castingTime.actionType.name}'
          : '1 Action',
      range: rawRange.isNotEmpty ? rawRange : 'Self',
      components: compList.join(', '),
      duration: durationText,
      concentration: duration.requiresConcentration,
      ritual: isRitual,
      savingThrow: savingThrow,
      description: [desc],
      higherLevels: higherLevels,
      classes: _extractLegacySpellClasses(cp),
      rollFormula: damageMath.isNotEmpty ? damageMath.first.diceFormula : null,
      damageOrHealType:
          damageMath.isNotEmpty ? damageMath.first.damageType.name : null,
    );

    return Spell(
      id: id,
      name: name,
      level: level,
      school: school,
      schoolEnum: _tryParseSpellSchool(school),
      castingTime: castingTime,
      duration: duration,
      range: rawRange,
      rangeDistanceFeet: distFeet,
      rangeType: rType,
      damageType: map['damageType']?.toString(),
      components: components,
      descriptionMarkdown: desc,
      higherLevelsMarkdown: higherLevels,
      damageMath: damageMath,
      relatedEntityRefs: relatedEntityRefs,
      riders: extractedRiders,
      rules2014: legacyDetails,
      rules2024: legacyDetails,
      tags: _extractLegacySpellTags(cp),
      customProperties: cp,
    );
  }

  Spell copyWith({
    EntityId? id,
    String? name,
    String? name2014,
    String? name2024,
    int? level,
    String? school,
    SpellSchool? schoolEnum,
    CastingTime? castingTime,
    SpellDuration? duration,
    String? range,
    int? rangeDistanceFeet,
    String? rangeType,
    String? damageType,
    SpellComponents? components,
    String? descriptionMarkdown,
    String? higherLevelsMarkdown,
    List<EvaluationMath>? damageMath,
    List<EntityReference<DomainEntity>>? relatedEntityRefs,
    List<CombatEffectRider>? riders,
    SpellEditionDetails? rules2014,
    SpellEditionDetails? rules2024,
    bool? isChangedIn2024,
    String? diffSummary,
    List<String>? diffHighlights,
    List<String>? tags,
    Map<String, dynamic>? customProperties,
  }) {
    return Spell(
      id: id ?? this.id,
      name: name ?? this.name,
      name2014: name2014 ?? this.name2014,
      name2024: name2024 ?? this.name2024,
      level: level ?? this.level,
      school: school ?? this.school,
      schoolEnum: schoolEnum ?? this.schoolEnum,
      castingTime: castingTime ?? this.castingTime,
      duration: duration ?? this.duration,
      range: range ?? this.range,
      rangeDistanceFeet: rangeDistanceFeet ?? this.rangeDistanceFeet,
      rangeType: rangeType ?? this.rangeType,
      damageType: damageType ?? this.damageType,
      components: components ?? this.components,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      higherLevelsMarkdown: higherLevelsMarkdown ?? this.higherLevelsMarkdown,
      damageMath: damageMath ?? this.damageMath,
      relatedEntityRefs: relatedEntityRefs ?? this.relatedEntityRefs,
      riders: riders ?? this.riders,
      rules2014: rules2014 ?? this.rules2014,
      rules2024: rules2024 ?? this.rules2024,
      isChangedIn2024: isChangedIn2024 ?? this.isChangedIn2024,
      diffSummary: diffSummary ?? this.diffSummary,
      diffHighlights: diffHighlights ?? this.diffHighlights,
      tags: tags ?? this.tags,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Spell) return false;
    return id == other.id &&
        name == other.name &&
        name2014 == other.name2014 &&
        name2024 == other.name2024 &&
        level == other.level &&
        school == other.school &&
        schoolEnum == other.schoolEnum &&
        castingTime.cost == other.castingTime.cost &&
        castingTime.actionType == other.castingTime.actionType &&
        castingTime.triggerCondition == other.castingTime.triggerCondition &&
        duration.type == other.duration.type &&
        duration.durationSeconds == other.duration.durationSeconds &&
        duration.requiresConcentration == other.duration.requiresConcentration &&
        duration.rawText == other.duration.rawText &&
        range == other.range &&
        rangeDistanceFeet == other.rangeDistanceFeet &&
        rangeType == other.rangeType &&
        damageType == other.damageType &&
        components.v == other.components.v &&
        components.s == other.components.s &&
        components.m == other.components.m &&
        components.materialDescription == other.components.materialDescription &&
        components.materialCostGp == other.components.materialCostGp &&
        components.consumesMaterial == other.components.consumesMaterial &&
        descriptionMarkdown == other.descriptionMarkdown &&
        higherLevelsMarkdown == other.higherLevelsMarkdown &&
        rules2014 == other.rules2014 &&
        rules2024 == other.rules2024 &&
        isChangedIn2024 == other.isChangedIn2024 &&
        diffSummary == other.diffSummary &&
        _listEquals(diffHighlights, other.diffHighlights) &&
        _listEquals(tags, other.tags) &&
        _mapEquals(customProperties, other.customProperties);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        level,
        school,
        schoolEnum,
        range,
        descriptionMarkdown,
        rules2014,
        rules2024,
        isChangedIn2024,
        Object.hashAll(tags),
      );
}
