import 'package:vtt_engine_core/utils/deep_immutable.dart';
import '../modules/dnd5e_ruleset_module.dart';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/rules/i_ruleset_module.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/value_objects/hit_points.dart';
import 'package:meta/meta.dart';
import 'package:vtt_engine_core/models/character_models.dart' as core;
import 'package:vtt_engine_core/models/character_models.dart'
    hide Character, CharacterResourcePool, StartingEquipmentItemRequest, InventoryItemInstance;
export 'package:vtt_engine_core/models/character_models.dart'
    hide Character, CharacterResourcePool, StartingEquipmentItemRequest, InventoryItemInstance;
export '../attributes/dnd5e_attributes.dart';
import '../attributes/dnd5e_attributes.dart';
import '../rules/ruleset_edition.dart';
import 'core_types.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'feature_grant.dart';
import 'spell_monster_equipment.dart';


bool _listEquals<T>(List<T>? a, List<T>? b) => const ListEquality().equals(a, b);
bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) => const MapEquality().equals(a, b);
bool _setEquals<T>(Set<T>? a, Set<T>? b) => const SetEquality().equals(a, b);

@immutable

@immutable
class ClassLevelProgression {
  final EntityReference<DomainEntity> classRef;
  final EntityReference<DomainEntity>? subclassRef;
  final int level;
  final bool isStartingClass;
  final Map<String, List<String>> selectedFeatureOptions;
  final Map<String, dynamic> customProperties;
  final String hitDie;
  final List<int> hitPointsRolled;

  const ClassLevelProgression({
    required this.classRef,
    this.subclassRef,
    this.level = 1,
    this.isStartingClass = false,
    this.selectedFeatureOptions = const {},
    this.customProperties = const {},
    this.hitDie = 'd8',
    this.hitPointsRolled = const [],
  });

  int get hitDieSides {
    final clean = hitDie.toLowerCase().replaceAll('d', '').trim();
    return int.tryParse(clean) ?? 8;
  }

  int get averageHpPerLevel => (hitDieSides ~/ 2) + 1;

  ClassLevelProgression copyWith({
    EntityReference<DomainEntity>? classRef,
    EntityReference<DomainEntity>? subclassRef,
    int? level,
    bool? isStartingClass,
    Map<String, List<String>>? selectedFeatureOptions,
    Map<String, dynamic>? customProperties,
    String? hitDie,
    List<int>? hitPointsRolled,
  }) {
    return ClassLevelProgression(
      classRef: classRef ?? this.classRef,
      subclassRef: subclassRef ?? this.subclassRef,
      level: level ?? this.level,
      isStartingClass: isStartingClass ?? this.isStartingClass,
      selectedFeatureOptions:
          selectedFeatureOptions ?? this.selectedFeatureOptions,
      customProperties: customProperties ?? this.customProperties,
      hitDie: hitDie ?? this.hitDie,
      hitPointsRolled: hitPointsRolled ?? this.hitPointsRolled,
    );
  }

  Map<String, dynamic> toMap() => {
        'classRef': classRef.toMap(),
        'subclassRef': subclassRef?.toMap(),
        'level': level,
        'isStartingClass': isStartingClass,
        'selectedFeatureOptions': selectedFeatureOptions,
        'customProperties': customProperties,
        'hitDie': hitDie,
        'hitPointsRolled': hitPointsRolled,
      };

  factory ClassLevelProgression.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['selectedFeatureOptions'];
    final parsedOptions = <String, List<String>>{};
    if (rawOptions is Map) {
      rawOptions.forEach((key, val) {
        if (val is List) {
          parsedOptions[key.toString()] = val.map((e) => e.toString()).toList();
        } else if (val != null) {
          parsedOptions[key.toString()] = [val.toString()];
        }
      });
    }

    return ClassLevelProgression(
      classRef: EntityReference<DomainEntity>.fromMap(
          Map<String, dynamic>.from(map['classRef'] as Map? ?? {})),
      subclassRef: map['subclassRef'] != null
          ? EntityReference<DomainEntity>.fromMap(
              Map<String, dynamic>.from(map['subclassRef'] as Map? ?? {}))
          : null,
      level: (map['level'] as num?)?.toInt() ?? 1,
      isStartingClass: map['isStartingClass'] == true,
      selectedFeatureOptions: parsedOptions,
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
      hitDie: map['hitDie']?.toString() ?? 'd8',
      hitPointsRolled: (map['hitPointsRolled'] as List? ?? [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassLevelProgression &&
          runtimeType == other.runtimeType &&
          classRef == other.classRef &&
          subclassRef == other.subclassRef &&
          level == other.level &&
          isStartingClass == other.isStartingClass &&
          _mapEquals(selectedFeatureOptions, other.selectedFeatureOptions) &&
          _mapEquals(customProperties, other.customProperties) &&
          hitDie == other.hitDie &&
          _listEquals(hitPointsRolled, other.hitPointsRolled);

  @override
  int get hashCode =>
      classRef.hashCode ^
      (subclassRef?.hashCode ?? 0) ^
      level.hashCode ^
      isStartingClass.hashCode ^
      selectedFeatureOptions.length.hashCode ^
      customProperties.length.hashCode ^
      hitDie.hashCode ^
      hitPointsRolled.length.hashCode;
}

@immutable
class CharacterProgression {
  final List<ClassLevelProgression> classes;
  final int experiencePoints;
  final Map<int, int> manualHpRolls;

  const CharacterProgression({
    required this.classes,
    this.experiencePoints = 0,
    this.manualHpRolls = const {},
  });

  int get totalLevel => classes.fold(0, (sum, c) => sum + c.level);

  ClassLevelProgression? get startingClass =>
      classes.where((c) => c.isStartingClass).firstOrNull ?? classes.firstOrNull;

  ClassLevelProgression? getClass(String classSlug) =>
      classes.where((c) => c.classRef.slug == classSlug).firstOrNull;

  List<String> getSelectedOptionsForDecision(String decisionId) {
    final results = <String>[];
    for (final c in classes) {
      final opts = c.selectedFeatureOptions[decisionId];
      if (opts != null) results.addAll(opts);
    }
    return results;
  }

  Map<String, List<String>> getAllSelectedFeatureOptions() {
    final merged = <String, List<String>>{};
    for (final c in classes) {
            final customDecisions = c.classRef.customProperties['featureDecisions']
              is List
          ? (c.classRef.customProperties['featureDecisions'] as List).toSet()
          : null;

      c.selectedFeatureOptions.forEach((k, v) {
        final normK = k.toLowerCase().replaceAll('-', '_');
        if (k.startsWith('-') ||
            k.startsWith('feat-') ||
            k.contains('invocation') ||
            normK == 'fighting_style' ||
            normK.contains('fighting_style') ||
            (customDecisions != null &&
                (customDecisions.contains(k) ||
                    customDecisions.contains(normK)))) {
          merged.putIfAbsent(k, () => []).addAll(v);
        }
      });
    }
    return merged;
  }

  CharacterProgression copyWith({
    List<ClassLevelProgression>? classes,
    int? experiencePoints,
    Map<int, int>? manualHpRolls,
  }) {
    return CharacterProgression(
      classes: classes != null
          ? List.unmodifiable(classes)
          : this.classes,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      manualHpRolls: manualHpRolls != null
          ? Map.unmodifiable(manualHpRolls)
          : this.manualHpRolls,
    );
  }

  Map<String, dynamic> toMap() => {
        'classes': classes.map((c) => c.toMap()).toList(),
        'experiencePoints': experiencePoints,
        'manualHpRolls': manualHpRolls.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory CharacterProgression.fromMap(Map<String, dynamic> map) {
    final rawClasses = (map['classes'] as List? ?? [])
        .map((c) => ClassLevelProgression.fromMap(
            Map<String, dynamic>.from(c as Map? ?? {})))
        .toList();
    final rawManualHp = map['manualHpRolls'];
    final parsedManualHp = <int, int>{};
    if (rawManualHp is Map) {
      rawManualHp.forEach((key, val) {
        final k = int.tryParse(key.toString());
        final v = int.tryParse(val.toString());
        if (k != null && v != null) parsedManualHp[k] = v;
      });
    }
    return CharacterProgression(
      classes: rawClasses,
      experiencePoints: (map['experiencePoints'] as num?)?.toInt() ?? 0,
      manualHpRolls: parsedManualHp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterProgression &&
          runtimeType == other.runtimeType &&
          _listEquals(classes, other.classes) &&
          experiencePoints == other.experiencePoints &&
          _mapEquals(manualHpRolls, other.manualHpRolls);

  @override
  int get hashCode =>
      Object.hashAll(classes) ^
      experiencePoints.hashCode ^
      manualHpRolls.length.hashCode;
}


@immutable
class InventoryItemInstance extends core.InventoryItemInstance {
  final bool isAttuned;
  final bool requiresAttunement;
  final String? customName;
  final String? notes;

  InventoryItemInstance({
    required super.itemRef,
    required super.instanceId,
    super.quantity = 1,
    super.isEquipped = false,
    super.equippedSlot,
    super.customProperties = const {},
    this.customName,
    this.notes,
    this.isAttuned = false,
    this.requiresAttunement = false,
  });

  const InventoryItemInstance.constant({
    required super.itemRef,
    required super.instanceId,
    super.quantity = 1,
    super.isEquipped = false,
    super.equippedSlot,
    this.customName,
    this.notes,
    this.isAttuned = false,
    this.requiresAttunement = false,
  }) : super.constant();

  @override
  String get displayName => customName ?? itemRef.displayName;

  @override
  InventoryItemInstance copyWith({
    EntityReference<DomainEntity>? itemRef,
    String? instanceId,
    int? quantity,
    bool? isEquipped,
    dynamic equippedSlot,
    Map<String, dynamic>? customProperties,
    String? customName,
    String? notes,
    bool? isAttuned,
    bool? requiresAttunement,
  }) {
    return InventoryItemInstance(
      itemRef: itemRef ?? this.itemRef,
      instanceId: instanceId ?? this.instanceId,
      quantity: quantity ?? this.quantity,
      isEquipped: isEquipped ?? this.isEquipped,
      equippedSlot:
          isEquipped == false ? null : (equippedSlot ?? this.equippedSlot),
      customProperties: customProperties ?? this.customProperties,
      customName: customName ?? this.customName,
      notes: notes ?? this.notes,
      isAttuned: isAttuned ?? this.isAttuned,
      requiresAttunement: requiresAttunement ?? this.requiresAttunement,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'isAttuned': isAttuned,
        'requiresAttunement': requiresAttunement,
        if (customName != null) 'customName': customName,
        if (notes != null) 'notes': notes,
      };

  factory InventoryItemInstance.fromMap(Map<String, dynamic> map) {
    final base = core.InventoryItemInstance.fromMap(map);
    return InventoryItemInstance(
      itemRef: base.itemRef,
      instanceId: base.instanceId,
      quantity: base.quantity,
      isEquipped: base.isEquipped,
      equippedSlot: base.equippedSlot,
      customProperties: base.customProperties,
      customName: map['customName']?.toString() ?? base.customProperties['customName']?.toString(),
      notes: map['notes']?.toString() ?? base.customProperties['notes']?.toString(),
      isAttuned: map['isAttuned'] == true,
      requiresAttunement: map['requiresAttunement'] == true ||
          map['attunement'] == true ||
          base.customProperties['requiresAttunement'] == true,
    );
  }
}

class StartingEquipmentItemRequest {
  final EntityReference<EquipmentItem> itemRef;
  final int quantity;
  final bool equipImmediately;
  final dynamic defaultSlot;
  final bool requiresAttunement;

  const StartingEquipmentItemRequest({
    required this.itemRef,
    this.quantity = 1,
    this.equipImmediately = false,
    this.defaultSlot,
    this.requiresAttunement = false,
  });
}

/// Generic, ruleset-agnostic attribute pool operating dynamically over keys
/// defined by an [IAttributeSystem].

@immutable
class SpellSlotPool {
  final Map<int, int> currentSlots; // Level 1-9 available slots
  final Map<int, int> maxSlots; // Level 1-9 max slots
  final int pactMagicSlotLevel; // 1-5
  final int pactMagicMax;
  final int pactMagicCurrent;

  const SpellSlotPool({
    this.currentSlots = const {},
    this.maxSlots = const {},
    this.pactMagicSlotLevel = 0,
    this.pactMagicMax = 0,
    this.pactMagicCurrent = 0,
  });

  SpellSlotPool copyWith({
    Map<int, int>? currentSlots,
    Map<int, int>? maxSlots,
    int? pactMagicSlotLevel,
    int? pactMagicMax,
    int? pactMagicCurrent,
  }) {
    return SpellSlotPool(
      currentSlots: currentSlots != null
          ? Map.unmodifiable(currentSlots)
          : this.currentSlots,
      maxSlots: maxSlots != null ? Map.unmodifiable(maxSlots) : this.maxSlots,
      pactMagicSlotLevel: pactMagicSlotLevel ?? this.pactMagicSlotLevel,
      pactMagicMax: pactMagicMax ?? this.pactMagicMax,
      pactMagicCurrent: pactMagicCurrent ?? this.pactMagicCurrent,
    );
  }

  Map<String, dynamic> toMap() => {
        'currentSlots': currentSlots.map((k, v) => MapEntry(k.toString(), v)),
        'maxSlots': maxSlots.map((k, v) => MapEntry(k.toString(), v)),
        'pactMagicSlotLevel': pactMagicSlotLevel,
        'pactMagicMax': pactMagicMax,
        'pactMagicCurrent': pactMagicCurrent,
      };

  factory SpellSlotPool.fromMap(Map<String, dynamic> map) {
    final cur = <int, int>{};
    if (map['currentSlots'] is Map) {
      (map['currentSlots'] as Map).forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null && v is num) cur[key] = v.toInt();
      });
    }

    final max = <int, int>{};
    if (map['maxSlots'] is Map) {
      (map['maxSlots'] as Map).forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null && v is num) max[key] = v.toInt();
      });
    }

    return SpellSlotPool(
      currentSlots: cur,
      maxSlots: max,
      pactMagicSlotLevel: (map['pactMagicSlotLevel'] as num?)?.toInt() ?? 0,
      pactMagicMax: (map['pactMagicMax'] as num?)?.toInt() ?? 0,
      pactMagicCurrent: (map['pactMagicCurrent'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellSlotPool &&
          runtimeType == other.runtimeType &&
          _mapEquals(currentSlots, other.currentSlots) &&
          _mapEquals(maxSlots, other.maxSlots) &&
          pactMagicSlotLevel == other.pactMagicSlotLevel &&
          pactMagicMax == other.pactMagicMax &&
          pactMagicCurrent == other.pactMagicCurrent;

  @override
  int get hashCode =>
      const MapEquality().hash(currentSlots) ^
      currentSlots.length.hashCode ^
      maxSlots.length.hashCode ^
      pactMagicSlotLevel.hashCode ^
      pactMagicMax.hashCode ^
      pactMagicCurrent.hashCode;
}

/// Character resource pools (HP, Hit Dice, Spell Slots, Class charges, Death Saves, Exhaustion, Inspiration)
@immutable
class CharacterResourcePool extends core.CharacterResourcePool {
  final EntityVitals? _vitals;
  final int _currentHp;
  final int _tempHp;
  final Map<String, int> currentHitDice; // e.g. {"d8": 3, "d10": 1}
  final SpellSlotPool spellSlots;
  final int _deathSaveSuccesses; // clamped 0-3
  final int _deathSaveFailures; // clamped 0-3
  final int _exhaustionLevel; // clamped 0-10
  final bool hasHeroicInspiration;

  int get deathSaveSuccesses =>
      (_vitals?.auxiliaryPools['deathSaveSuccesses'] as num?)?.toInt() ??
      (_vitals?.auxiliaryPools['death_save_successes'] as num?)?.toInt() ??
      _deathSaveSuccesses;

  int get deathSaveFailures =>
      (_vitals?.auxiliaryPools['deathSaveFailures'] as num?)?.toInt() ??
      (_vitals?.auxiliaryPools['death_save_failures'] as num?)?.toInt() ??
      _deathSaveFailures;

  int get exhaustionLevel =>
      (_vitals?.auxiliaryPools['exhaustionLevel'] as num?)?.toInt() ??
      (_vitals?.auxiliaryPools['exhaustion_level'] as num?)?.toInt() ??
      _exhaustionLevel;

  @override
  EntityVitals get vitals =>
      _vitals ??
      EntityVitals(
        currentHp: _currentHp,
        maxHp: 9999,
        temporaryHp: _tempHp,
        isDowned: _currentHp <= 0,
        isDead: deathSaveFailures >= 3,
        auxiliaryPools: {
          'deathSaveSuccesses': deathSaveSuccesses,
          'death_save_successes': deathSaveSuccesses,
          'deathSaveFailures': deathSaveFailures,
          'death_save_failures': deathSaveFailures,
          'exhaustionLevel': exhaustionLevel,
          ...spellSlots.currentSlots
              .map((k, v) => MapEntry('spell_slot_cur_$k', v)),
          ...spellSlots.maxSlots
              .map((k, v) => MapEntry('spell_slot_max_$k', v)),
          if (spellSlots.pactMagicMax > 0) ...{
            'spell_slot_pact_max': spellSlots.pactMagicMax,
            'spell_slot_pact_cur': spellSlots.pactMagicCurrent,
          },
          ...customResourcesCurrent.map((k, v) => MapEntry('resource_$k', v)),
        },
      );

  @override
  int get currentHp => _vitals?.currentHp ?? _currentHp;
  @override
  int get tempHp => _vitals?.temporaryHp ?? _tempHp;

  HitPoints get hitPoints => HitPoints(
        currentHp: currentHp,
        maxHp: 9999,
        tempHp: tempHp,
      );

  const CharacterResourcePool.empty()
      : _vitals = const EntityVitals(currentHp: 10, maxHp: 9999),
        _currentHp = 10,
        _tempHp = 0,
        currentHitDice = const {},
        spellSlots = const SpellSlotPool(),
        _deathSaveSuccesses = 0,
        _deathSaveFailures = 0,
        _exhaustionLevel = 0,
        hasHeroicInspiration = false,
        super(
          vitals: const EntityVitals(currentHp: 10, maxHp: 9999),
          currentHp: 10,
          tempHp: 0,
          customResourcesCurrent: const {},
          customResourcesMax: const {},
        );

  const CharacterResourcePool({
    super.vitals,
    int currentHp = 10,
    int tempHp = 0,
    this.currentHitDice = const {},
    this.spellSlots = const SpellSlotPool(),
    super.customResourcesCurrent = const {},
    super.customResourcesMax = const {},
    int deathSaveSuccesses = 0,
    int deathSaveFailures = 0,
    int exhaustionLevel = 0,
    this.hasHeroicInspiration = false,
  })  : _vitals = vitals,
        _currentHp = currentHp,
        _tempHp = tempHp,
        _deathSaveSuccesses = deathSaveSuccesses < 0
            ? 0
            : (deathSaveSuccesses > 3 ? 3 : deathSaveSuccesses),
        _deathSaveFailures = deathSaveFailures < 0
            ? 0
            : (deathSaveFailures > 3 ? 3 : deathSaveFailures),
        _exhaustionLevel = exhaustionLevel < 0
            ? 0
            : (exhaustionLevel > 10 ? 10 : exhaustionLevel),
        super(
          currentHp: currentHp,
          tempHp: tempHp,
        );

  CharacterResourcePool withVitals(EntityVitals newVitals) {
    return copyWith(
      vitals: newVitals,
      currentHp: newVitals.currentHp,
      tempHp: newVitals.temporaryHp,
      deathSaveSuccesses: newVitals.auxiliaryPools['deathSaveSuccesses'] ??
          newVitals.auxiliaryPools['death_save_successes'] ??
          deathSaveSuccesses,
      deathSaveFailures: newVitals.isDead
          ? 3
          : (newVitals.auxiliaryPools['deathSaveFailures'] ??
              newVitals.auxiliaryPools['death_save_failures'] ??
              deathSaveFailures),
      exhaustionLevel: newVitals.auxiliaryPools['exhaustionLevel'] ??
          newVitals.auxiliaryPools['exhaustion_level'] ??
          exhaustionLevel,
    );
  }

  @override
  CharacterResourcePool copyWith({
    EntityVitals? vitals,
    HitPoints? hitPoints,
    int? currentHp,
    int? tempHp,
    Map<String, int>? currentHitDice,
    SpellSlotPool? spellSlots,
    Map<String, int>? customResourcesCurrent,
    Map<String, int>? customResourcesMax,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    int? exhaustionLevel,
    bool? hasHeroicInspiration,
    Map<String, dynamic>? auxiliaryData,
  }) {
    final resolvedCurrentHp = vitals?.currentHp ??
        hitPoints?.currentHp ??
        currentHp ??
        this.currentHp;
    final resolvedTempHp =
        vitals?.temporaryHp ?? hitPoints?.tempHp ?? tempHp ?? this.tempHp;
    final resolvedDeathSaveSuccesses =
        deathSaveSuccesses ?? this.deathSaveSuccesses;
    final resolvedDeathSaveFailures =
        deathSaveFailures ?? this.deathSaveFailures;
    final resolvedExhaustionLevel = exhaustionLevel ?? this.exhaustionLevel;
    final resolvedVitals = vitals ??
        this.vitals.copyWith(
          currentHp: resolvedCurrentHp,
          temporaryHp: resolvedTempHp,
          isDowned: resolvedCurrentHp <= 0,
          isDead: (vitals?.isDead ?? false) || resolvedDeathSaveFailures >= 3,
          auxiliaryPools: {
            ...this.vitals.auxiliaryPools,
            'deathSaveSuccesses': resolvedDeathSaveSuccesses,
            'deathSaveFailures': resolvedDeathSaveFailures,
            'exhaustionLevel': resolvedExhaustionLevel,
          },
        );

    return CharacterResourcePool(
      vitals: resolvedVitals,
      currentHp: resolvedCurrentHp,
      tempHp: resolvedTempHp,
      currentHitDice: currentHitDice != null
          ? Map.unmodifiable(currentHitDice)
          : this.currentHitDice,
      spellSlots: spellSlots ?? this.spellSlots,
      customResourcesCurrent: customResourcesCurrent != null
          ? Map.unmodifiable(customResourcesCurrent)
          : this.customResourcesCurrent,
      customResourcesMax: customResourcesMax != null
          ? Map.unmodifiable(customResourcesMax)
          : this.customResourcesMax,
      deathSaveSuccesses: deathSaveSuccesses ?? this.deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures ?? this.deathSaveFailures,
      exhaustionLevel: exhaustionLevel ?? this.exhaustionLevel,
      hasHeroicInspiration: hasHeroicInspiration ?? this.hasHeroicInspiration,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'currentHp': currentHp,
        'tempHp': tempHp,
        'currentHitDice': currentHitDice,
        'spellSlots': spellSlots.toMap(),
        'customResourcesCurrent': customResourcesCurrent,
        'customResourcesMax': customResourcesMax,
        'deathSaveSuccesses': deathSaveSuccesses,
        'deathSaveFailures': deathSaveFailures,
        'exhaustionLevel': exhaustionLevel,
        'hasHeroicInspiration': hasHeroicInspiration,
      };

  factory CharacterResourcePool.fromMap(Map<String, dynamic> map) {
    final rawHp = map['currentHp'] ?? map['hp'];
    final curHp = (rawHp as num?)?.toInt() ?? 10;
    final rawThp = map['tempHp'] ?? map['thp'];
    final tHp = (rawThp as num?)?.toInt() ?? 0;
    final hp = map['hitPoints'] is Map
        ? HitPoints(
            currentHp:
                ((map['hitPoints'] as Map)['currentHp'] as num?)?.toInt() ??
                    ((map['hitPoints'] as Map)['hp'] as num?)?.toInt() ??
                    curHp,
            maxHp: ((map['hitPoints'] as Map)['maxHp'] as num?)?.toInt() ??
                ((map['hitPoints'] as Map)['mhp'] as num?)?.toInt() ??
                (map['maxHp'] as num?)?.toInt() ??
                (map['mhp'] as num?)?.toInt() ??
                9999,
            tempHp: ((map['hitPoints'] as Map)['tempHp'] as num?)?.toInt() ??
                ((map['hitPoints'] as Map)['thp'] as num?)?.toInt() ??
                tHp,
          )
        : HitPoints(currentHp: curHp, maxHp: 9999, tempHp: tHp);

    return CharacterResourcePool(
      currentHp: hp.currentHp,
      tempHp: hp.tempHp,
      currentHitDice:
          Map<String, int>.from(map['currentHitDice'] as Map? ?? {}),
      spellSlots: SpellSlotPool.fromMap(
          Map<String, dynamic>.from(map['spellSlots'] as Map? ?? {})),
      customResourcesCurrent:
          Map<String, int>.from(map['customResourcesCurrent'] as Map? ?? {}),
      customResourcesMax:
          Map<String, int>.from(map['customResourcesMax'] as Map? ?? {}),
      deathSaveSuccesses: (map['deathSaveSuccesses'] as num?)?.toInt() ?? 0,
      deathSaveFailures: (map['deathSaveFailures'] as num?)?.toInt() ?? 0,
      exhaustionLevel: (map['exhaustionLevel'] as num?)?.toInt() ?? 0,
      hasHeroicInspiration: map['hasHeroicInspiration'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterResourcePool &&
          runtimeType == other.runtimeType &&
          vitals == other.vitals &&
          _mapEquals(currentHitDice, other.currentHitDice) &&
          spellSlots == other.spellSlots &&
          _mapEquals(customResourcesCurrent, other.customResourcesCurrent) &&
          _mapEquals(customResourcesMax, other.customResourcesMax) &&
          deathSaveSuccesses == other.deathSaveSuccesses &&
          deathSaveFailures == other.deathSaveFailures &&
          exhaustionLevel == other.exhaustionLevel &&
          hasHeroicInspiration == other.hasHeroicInspiration;

  @override
  int get hashCode =>
      vitals.hashCode ^
      currentHitDice.length.hashCode ^
      spellSlots.hashCode ^
      customResourcesCurrent.length.hashCode ^
      customResourcesMax.length.hashCode ^
      deathSaveSuccesses.hashCode ^
      deathSaveFailures.hashCode ^
      exhaustionLevel.hashCode ^
      hasHeroicInspiration.hashCode;
}

/// Active Condition and Temporary Status Effect

class Character extends core.Character {
  final Map<String, List<EntityReference<Spell>>> allocatedSpells;
  final List<EntityReference<Spell>> _cantrips;
  final List<EntityReference<Spell>> _spellsKnown;
  final List<EntityReference<Spell>> spellsPrepared;
  final int maxAttunementSlots;

  @override
  CharacterProgression get progression =>
      super.progression is CharacterProgression
          ? super.progression as CharacterProgression
          : CharacterProgression.fromMap(super.progression.toMap());

  @override
  CharacterResourcePool get resources =>
      super.resources is CharacterResourcePool
          ? super.resources as CharacterResourcePool
          : CharacterResourcePool.fromMap(super.resources.toMap());

  @override
  List<InventoryItemInstance> get inventory =>
      List<InventoryItemInstance>.unmodifiable(
        super.inventory.map((i) => i is InventoryItemInstance
            ? i
            : InventoryItemInstance.fromMap(i.toMap())),
      );

  @override
  AbilityScores get baseScores =>
      super.baseScores is AbilityScores
          ? super.baseScores as AbilityScores
          : AbilityScores.fromMap(super.baseScores.toMap());

  @override
  AbilityScores get bonusScores =>
      super.bonusScores is AbilityScores
          ? super.bonusScores as AbilityScores
          : AbilityScores.fromMap(super.bonusScores.toMap());

  int get baseSpeedFeet => baseSpeed ?? 30;

  const Character({
    required super.id,
    required super.name,
    required super.speciesRef,
    super.backgroundRef,
    super.progression = const CharacterProgression(classes: []),
    AbilityScores baseScores = const AbilityScores.standardArray(),
    AbilityScores bonusScores = const AbilityScores.zero(),
    Map<dynamic, dynamic>? traitProficiencies,
    Map<dynamic, dynamic>? skillProficiencies,
    super.savingThrowProficiencies = const <dynamic>{},
    super.toolProficiencies = const [],
    super.languages = const ['Common'],
    List<InventoryItemInstance> inventory = const [],
    super.purse = const PartyPurse.empty(),
    this.allocatedSpells = const {},
    List<EntityReference<Spell>> cantrips = const [],
    List<EntityReference<Spell>> spellsKnown = const [],
    this.spellsPrepared = const [],
    super.feats = const [],
    CharacterResourcePool resources = const CharacterResourcePool(),
    super.conditions = const [],
    this.maxAttunementSlots = 3,
    int baseSpeedFeet = 30,
    String rulesetId = 'dnd5e_2014',
    RulesetEdition? rulesEdition,
    super.customProperties = const {},
  })  : _cantrips = cantrips,
        _spellsKnown = spellsKnown,
        super(
          baseScores: baseScores,
          bonusScores: bonusScores,
          traitProficiencies:
              traitProficiencies ?? skillProficiencies ?? const {},
          inventory: inventory,
          resources: resources,
          baseSpeed: baseSpeedFeet,
          rulesetId: rulesEdition == RulesetEdition.v2024
              ? 'dnd5e_2024'
              : (rulesEdition == RulesetEdition.v2014 ? 'dnd5e_2014' : rulesetId),
        );

  @override
  EntityType get entityType => EntityType.character;

  Map<SkillType, SkillProficiencyLevel> get skillProficiencies {
    final result = <SkillType, SkillProficiencyLevel>{};
    traitProficiencies.forEach((k, v) {
      final skill =
          k is SkillType ? k : SkillType.tryParse(k.toString());
      if (skill != null) {
        if (v is SkillProficiencyLevel) {
          result[skill] = v;
        } else if (v is String) {
          result[skill] = SkillProficiencyLevel.fromLooseString(v);
        } else if (v is num) {
          result[skill] = SkillProficiencyLevel.fromMultiplier(v);
        }
      }
    });
    return result;
  }

  int get totalLevel => progression.totalLevel;
  int get proficiencyBonus => totalLevel <= 0 ? 2 : ((totalLevel - 1) ~/ 4) + 2;

  String get classesSummary {
    if (progression.classes.isEmpty) return 'Adventurer';
    return progression.classes
        .map((c) => '${c.classRef.displayName} ${c.level}')
        .join(' / ');
  }

  /// Machine-readable identifier of the active ruleset module.
  @override
  String get activeModuleId =>
      rulesetId.contains('2024') ? 'dnd5e_2024' : 'dnd5e_2014';

  /// Canonical ruleset edition of this character.
  RulesetEdition get rulesEdition => switch (rulesetId) {
        'dnd5e_2014' || 'v2014' || '5e-2014' => RulesetEdition.v2014,
        _ => RulesetEdition.v2024,
      };

  /// Optional injected evaluator for complex ruleset-specific max HP calculations.
  static int Function(Character character)? maxHpEvaluator;

  /// Evaluated maximum Hit Points, checking customProperties, injected evaluator, or vitals.
  int get evaluatedMaxHp {
    if (customProperties['maxHp'] is num) {
      return (customProperties['maxHp'] as num).toInt();
    }
    if (maxHpEvaluator != null) {
      try {
        return maxHpEvaluator!(this);
      } catch (_) {}
    }
    final mhp = resources.hitPoints.maxHp;
    if (mhp > 0 && mhp != 9999) return mhp;
    return math.max(10, resources.currentHp);
  }

  /// Ruleset-agnostic vitals model exposing current HP, max HP, temp HP, downed, and death states.
  @override
  EntityVitals get vitals => EntityVitals(
        currentHp: resources.currentHp,
        maxHp: resources.hitPoints.maxHp,
        temporaryHp: resources.tempHp,
        isDowned: resources.hitPoints.isDowned,
        isDead: resources.deathSaveFailures >= 3 || resources.hitPoints.isDead,
        auxiliaryPools: {
          'death_save_successes': resources.deathSaveSuccesses,
          'death_save_failures': resources.deathSaveFailures,
          'exhaustion_level': resources.exhaustionLevel,
        },
      );

  /// Map of canonical attribute keys to effective score values.
  Map<String, int> get attributeScores => {
        'strength': effectiveAbilityScores.strength,
        'dexterity': effectiveAbilityScores.dexterity,
        'constitution': effectiveAbilityScores.constitution,
        'intelligence': effectiveAbilityScores.intelligence,
        'wisdom': effectiveAbilityScores.wisdom,
        'charisma': effectiveAbilityScores.charisma,
      };

  /// Retrieves an attribute score by key (e.g. 'strength', 'dexterity', etc.).
  @override
  int getAttributeScore(String key, [int fallback = 10]) =>
      attributeScores[key.trim().toLowerCase()] ?? fallback;

  /// Pluggable resolver callback to determine a spell's level from its slug
  /// when entity references lack embedded level metadata.
  static int? Function(String slug)? spellLevelResolver;

  bool _isCantripRef(String? slotGroupKey, EntityReference<Spell> ref) {
    if (ref.customProperties['isCantrip'] == true) return true;
    final level =
        ref.customProperties['level'] ?? spellLevelResolver?.call(ref.slug);
    if (level is num && level == 0) return true;
    if (level is String && (level == '0' || level.toLowerCase() == 'cantrip'))
      return true;
    if (slotGroupKey != null) {
      final k = slotGroupKey.toLowerCase().trim();
      if (k.contains('cantrip') || k == '0') return true;
    }
    if (ref.slug.toLowerCase().contains('cantrip')) return true;
    return false;
  }

  bool _isLeveledSpellRef(String? slotGroupKey, EntityReference<Spell> ref) {
    if (_isCantripRef(slotGroupKey, ref)) return false;
    final level =
        ref.customProperties['level'] ?? spellLevelResolver?.call(ref.slug);
    if (level is num && level > 0) return true;
    if (level is String && int.tryParse(level) != null && int.parse(level) > 0)
      return true;
    if (slotGroupKey != null) {
      final k = slotGroupKey.toLowerCase().trim();
      if (k.contains('cantrip') || k == '0') return false;
      if (k.contains('spell') ||
          k.contains('known') ||
          k.contains('prep') ||
          k.contains('domain') ||
          k.contains('legacy') ||
          k.contains('bloodline')) {
        return true;
      }
    }
    return true;
  }

  List<EntityReference<Spell>> get cantrips {
    final list = <EntityReference<Spell>>[];
    for (final entry in allocatedSpells.entries) {
      final groupKey = entry.key;
      final spells = entry.value;
      for (final s in spells) {
        if (_isCantripRef(groupKey, s) && !list.any((e) => e.slug == s.slug)) {
          list.add(s);
        }
      }
    }
    for (final c in _cantrips) {
      if (!list.any((e) => e.slug == c.slug)) {
        list.add(c);
      }
    }
    return List.unmodifiable(list);
  }

  List<EntityReference<Spell>> get spellsKnown {
    final list = <EntityReference<Spell>>[];
    for (final entry in allocatedSpells.entries) {
      final groupKey = entry.key;
      final spells = entry.value;
      for (final s in spells) {
        if (_isLeveledSpellRef(groupKey, s) &&
            !list.any((e) => e.slug == s.slug)) {
          list.add(s);
        }
      }
    }
    for (final s in _spellsKnown) {
      if (!list.any((e) => e.slug == s.slug)) {
        list.add(s);
      }
    }
    return List.unmodifiable(list);
  }

  /// Raw ability scores (base scores with permanent bonuses from species/ASI/feats)
  @override
  AbilityScores get rawAbilityScores => baseScores.withBonus(bonusScores);

  /// Returns the inherent maximum score allowed for [attributeKey].
  /// Defaults to standard tabletop 20, but accounts for Level 20 Barbarian capstone (24 for STR/CON)
  /// and any permanent inherent maximum increases stored in [customProperties] under 'abilityMaximums'.
  int getAbilityScoreMaximum(dynamic attributeKey) {
    int maxCap = 20;
    final clean = (attributeKey is String
            ? attributeKey
            : (attributeKey is Enum
                ? attributeKey.name
                : attributeKey.toString()))
        .trim()
        .toLowerCase();
    // Check Barbarian Level 20 Capstone
    final isBarbarian20 = progression.classes.any(
      (c) => c.classRef.slug.toLowerCase() == 'barbarian' && c.level >= 20,
    );
    if (isBarbarian20 && (clean == 'strength' || clean == 'constitution')) {
      maxCap = math.max(maxCap, 24);
    }
    // Check customProperties / permanent inherent tomes
    if (customProperties['abilityMaximums'] is Map) {
      final map = customProperties['abilityMaximums'] as Map;
      final val = (map[clean] as num?)?.toInt();
      if (val != null) {
        maxCap = math.max(maxCap, val);
      }
    }
    return maxCap.clamp(20, 30);
  }

  /// Effective ability scores (evaluates rawAbilityScores and applies hard overrides from attuned/equipped items or custom properties)
  @override
  AbilityScores get effectiveAbilityScores {
    final scores = Map<String, int>.from(rawAbilityScores.attributes);

    for (final instance in equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final props = instance.customProperties;
      if (props['abilityOverrides'] is Map) {
        final overrides = props['abilityOverrides'] as Map;
        overrides.forEach((k, v) {
          if (v is num) {
            final key = k.toString().toLowerCase().trim();
            scores[key] = math.max(scores[key] ?? 10, v.toInt());
          }
        });
      }
      if (props['abilityBonuses'] is Map) {
        final bonuses = props['abilityBonuses'] as Map;
        bonuses.forEach((k, v) {
          if (v is num) {
            final key = k.toString().toLowerCase().trim();
            scores[key] = (scores[key] ?? 10) + v.toInt();
          }
        });
      }
    }

    if (customProperties['abilityOverrides'] is Map) {
      final overrides = customProperties['abilityOverrides'] as Map;
      overrides.forEach((k, v) {
        if (v is num) {
          final key = k.toString().toLowerCase().trim();
          scores[key] = math.max(scores[key] ?? 10, v.toInt());
        }
      });
    }

    return AbilityScores(
      strength: scores['strength'] ?? 10,
      dexterity: scores['dexterity'] ?? 10,
      constitution: scores['constitution'] ?? 10,
      intelligence: scores['intelligence'] ?? 10,
      wisdom: scores['wisdom'] ?? 10,
      charisma: scores['charisma'] ?? 10,
      customAttributes: Map.unmodifiable(scores),
    );
  }

  int get attunedItemCount => inventory.where((item) => item.isAttuned).length;

  List<InventoryItemInstance> get equippedItems =>
      inventory.where((item) => item.isEquipped).toList();

  /// Returns all active [FeatureGrant]s attached to this character from custom properties,
  /// granted feats, classes, subclasses, and inventory equipment.
  @override
  List<FeatureGrant> get activeGrants {
    final list = <FeatureGrant>[];

    void extractGrants(dynamic rawGrants) {
      if (rawGrants is! List) return;
      for (final item in rawGrants) {
        if (item is FeatureGrant) {
          list.add(item);
        } else if (item is Map) {
          list.add(FeatureGrant.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // 1. Direct grants in customProperties['grants']
    extractGrants(customProperties['grants']);

    // 2. Feats embedded grants
    for (final featRef in feats) {
      extractGrants(featRef.customProperties['grants']);
    }

    // 3. Classes and Subclasses embedded grants
    for (final c in progression.classes) {
      extractGrants(c.classRef.customProperties['grants']);
      if (c.subclassRef != null) {
        extractGrants(c.subclassRef!.customProperties['grants']);
      }
    }

    // 4. Equipped items embedded grants
    for (final item in equippedItems) {
      if (item.requiresAttunement && !item.isAttuned) continue;
      extractGrants(item.customProperties['grants']);
      extractGrants(item.itemRef.customProperties['grants']);
    }

    return List.unmodifiable(list);
  }

  /// Evaluates whether the character has a specific capability flag enabled from any selected
  /// feature option, feat, class feature, active FeatureGrant, or custom properties.
  @override
  bool hasCapabilityFlag(String flagKey) {
    if (customProperties[flagKey] == true) return true;
    final normalizedKey = flagKey.toLowerCase().replaceAll('-', '_');
    if (customProperties[normalizedKey] == true) return true;

    // Check customProperties['flags']
    if (customProperties['flags'] is Map) {
      final flagsMap = customProperties['flags'] as Map;
      if (flagsMap[flagKey] == true || flagsMap[normalizedKey] == true) {
        return true;
      }
    }

    // Check active FeatureGrants
    for (final g in activeGrants) {
      if (g.type == GrantType.capabilityFlag) {
        final key =
            g.payload['flagKey']?.toString().toLowerCase().replaceAll('-', '_');
        if (key == normalizedKey || key == flagKey.toLowerCase()) {
          return true;
        }
      }
    }

    // Feature Options (fighting styles, invocations, pact boons, etc.)
    final allSelectedOptions = progression.getAllSelectedFeatureOptions();
    for (final optionIds in allSelectedOptions.values) {
      for (final optId in optionIds) {
        final normOptId = optId.toLowerCase().replaceAll('-', '_');
        if (normOptId == normalizedKey) return true;
        if ((flagKey == 'eldritchBlastChaDamage' ||
                flagKey == 'agonizing_blast') &&
            normOptId == 'agonizing_blast') {
          return true;
        }
      }
    }

    // Generic SRD mechanics
    if (flagKey == 'jackOfAllTrades' || normalizedKey == 'jack_of_all_trades') {
      final bardClass = progression.classes
          .where((c) =>
              c.classRef.slug.toLowerCase().contains('bard') ||
              c.classRef.displayName.toLowerCase().contains('bard'))
          .firstOrNull;
      if (bardClass != null && bardClass.level >= 2) {
        return true;
      }
    }

    // Generic capability mapping aliases
    if (flagKey == 'homebrewArmorExpert') {
      return hasCapabilityFlag('mediumArmorDexCapBonus');
    }
    if (flagKey == 'homebrewInitiativeBoost') {
      return hasCapabilityFlag('initiativeBonusMode');
    }

    return false;
  }

  /// Generic stat query interface allowing ruleset modules or external engines
  /// to resolve derived statistics dynamically without hardcoded rules in the entity.
  @override
  int queryStat(String statKey,
      {IRulesetModule? module, Map<String, dynamic> context = const {}}) {
    if (module != null) {
      return module.calculateDerivedStat(
          character: this, statKey: statKey, context: context);
    }
    if (customProperties[statKey] is num) {
      return (customProperties[statKey] as num).toInt();
    }
    return 10;
  }

  /// Resolves an attribute modifier dynamically by string key using [effectiveAbilityScores],
  /// optionally evaluated via the provided [IAttributeSystem].
  @override
  int getAttributeModifier(String key, [IAttributeSystem? system]) =>
      effectiveAbilityScores.getModifierByKey(key, system);

  /// Resolves trait proficiency multiplier dynamically (e.g. 1.0 for proficient, 2.0 for expertise).
  @override
  double getTraitProficiency(dynamic traitKey) {
    final clean = (traitKey is Enum ? traitKey.name : traitKey.toString())
        .trim()
        .toLowerCase();
    for (final entry in traitProficiencies.entries) {
      final key = entry.key;
      final keyStr =
          (key is Enum ? key.name : key.toString()).trim().toLowerCase();
      if (keyStr == clean) {
        final val = entry.value;
        if (val is num) return val.toDouble();
        if (val is Enum) {
          if (val.name == 'expertise') return 2.0;
          if (val.name == 'proficient') return 1.0;
          if (val.name == 'jackOfAllTrades') return 0.5;
        }
        final valStr = val.toString().toLowerCase();
        if (valStr.contains('expertise')) return 2.0;
        if (valStr.contains('proficient')) return 1.0;
        if (valStr.contains('jackofalltrades') ||
            valStr.contains('jack_of_all_trades')) return 0.5;
        return 0.0;
      }
    }
    return 0.0;
  }

  /// Whether the character is proficient in saving throws for [key].
  @override
  bool hasSavingThrowProficiency(dynamic key) =>
      savingThrowProficiencies.contains(key);

  /// Resolves skill or trait modifier dynamically from generic [ITraitDefinition].
  @override
  int getTraitModifier(ITraitDefinition trait,
      [IAttributeSystem? attributeSystem]) {
    final attrKey = trait.governedAttribute;
    final baseMod =
        attrKey != null ? getAttributeModifier(attrKey, attributeSystem) : 0;
    final mult = getTraitProficiency(trait.id);
    final bonus = (proficiencyBonus * mult).floor();
    return baseMod + bonus;
  }

  /// Dynamic Saving Throw Modifier calculation factoring in ability modifiers and proficiency.
  int get armorClass => Dnd5eRulesetModule.calculateCharacterArmorClass(this);
  int get initiativeBonus => Dnd5eRulesetModule.calculateCharacterInitiativeBonus(this);
  int get passivePerception => Dnd5eRulesetModule.calculateCharacterPassivePerception(this);
  int get passiveInvestigation => Dnd5eRulesetModule.calculateCharacterPassiveInvestigation(this);
  int get passiveInsight => Dnd5eRulesetModule.calculateCharacterPassiveInsight(this);

  int getSkillModifier(SkillType skill, [IAttributeSystem? system]) {
    return Dnd5eRulesetModule.calculateSkillModifier(this, skill);
  }

  AbilityType getEffectiveAttackAbility(
    InventoryItemInstance instance, {
    core.AttributePool? scores,
    List<FeatureGrant>? additionalGrants,
  }) {
    return Dnd5eRulesetModule.resolveEffectiveAttackAbility(
      scores: scores ?? effectiveAbilityScores,
      weapon: instance,
      character: this,
      additionalGrants: additionalGrants,
    );
  }

  @override
  int getSaveModifier(dynamic attributeKey, [IAttributeSystem? attributeSystem]) {
    final keyStr =
        (attributeKey is Enum ? attributeKey.name : attributeKey.toString())
            .trim()
            .toLowerCase();
    final baseMod = getAttributeModifier(keyStr);
    final isProficient = hasSavingThrowProficiency(attributeKey);
    return baseMod + (isProficient ? proficiencyBonus : 0);
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'speciesRef': speciesRef.toMap(),
        'backgroundRef': backgroundRef?.toMap(),
        'progression': progression.toMap(),
        'baseScores': baseScores.toMap(),
        'bonusScores': bonusScores.toMap(),
        'traitProficiencies': traitProficiencies,
        'skillProficiencies': traitProficiencies,
        'savingThrowProficiencies': savingThrowProficiencies.toList(),
        'toolProficiencies': toolProficiencies,
        'languages': languages,
        'inventory': inventory.map((i) => i.toMap()).toList(),
        'purse': purse.toMap(),
        'allocatedSpells': allocatedSpells.map(
          (k, v) => MapEntry(k, v.map((s) => s.toMap()).toList()),
        ),
        'cantrips': cantrips.map((c) => c.toMap()).toList(),
        'spellsKnown': spellsKnown.map((s) => s.toMap()).toList(),
        'spellsPrepared': spellsPrepared.map((s) => s.toMap()).toList(),
        'feats': feats.map((f) => f.toMap()).toList(),
        'resources': resources.toMap(),
        'currentHp': resources.currentHp,
        'maxHp': evaluatedMaxHp,
        'tempHp': resources.tempHp,
        'armorClass': queryStat('ac'),
        'conditions': conditions.map((c) => c.toMap()).toList(),
        'maxAttunementSlots': maxAttunementSlots,
        'baseSpeedFeet': baseSpeedFeet,
        'rulesetId': rulesetId,
        'rulesEdition': rulesEdition.name,
        'customProperties': customProperties,
      };

  factory Character.fromMap(Map<String, dynamic> map) {
    final traits = <String, double>{};
    if (map['traitProficiencies'] is Map) {
      (map['traitProficiencies'] as Map).forEach((k, v) {
        if (v is num) traits[k.toString().toLowerCase().trim()] = v.toDouble();
      });
    } else if (map['skillProficiencies'] is Map) {
      (map['skillProficiencies'] as Map).forEach((k, v) {
        final valStr = v.toString().toLowerCase().trim();
        final mult = switch (valStr) {
          'expertise' => 2.0,
          'proficient' => 1.0,
          'jackofalltrades' => 0.5,
          _ => (v is num) ? v.toDouble() : 1.0,
        };
        traits[k.toString().toLowerCase().trim()] = mult;
      });
    }

    final saves = <String>{};
    if (map['savingThrowProficiencies'] is List) {
      for (final s in (map['savingThrowProficiencies'] as List)) {
        saves.add(s.toString().toLowerCase().trim());
      }
    }

    final resolvedRulesetId = map['rulesetId']?.toString() ??
        map['rulesEdition']?.toString() ??
        'dnd5e_2014';

    final rawAllocated = map['allocatedSpells'];
    final parsedAllocated = <String, List<EntityReference<Spell>>>{};
    if (rawAllocated is Map) {
      rawAllocated.forEach((k, v) {
        if (v is List) {
          parsedAllocated[k.toString()] = v
              .whereType<Map>()
              .map((s) =>
                  EntityReference<Spell>.fromMap(Map<String, dynamic>.from(s)))
              .toList();
        }
      });
    }

    final parsedCantrips = (map['cantrips'] as List? ?? [])
        .whereType<Map>()
        .map(
            (c) => EntityReference<Spell>.fromMap(Map<String, dynamic>.from(c)))
        .toList();

    final parsedSpellsKnown = (map['spellsKnown'] as List? ?? [])
        .whereType<Map>()
        .map(
            (s) => EntityReference<Spell>.fromMap(Map<String, dynamic>.from(s)))
        .toList();

    if (parsedAllocated.isEmpty) {
      if (parsedCantrips.isNotEmpty) {
        parsedAllocated['cantrips'] = parsedCantrips;
      }
      if (parsedSpellsKnown.isNotEmpty) {
        parsedAllocated['spellsKnown'] = parsedSpellsKnown;
      }
    }

    return Character(
      id: map['id'] is Map
          ? EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map))
          : EntityId(
              slug: map['id']?.toString() ?? '', ruleset: RulesetVersion.v2024),
      name: map['name']?.toString() ?? '',
      speciesRef: EntityReference<DomainEntity>.fromMap(
          Map<String, dynamic>.from(map['speciesRef'] as Map? ?? {})),
      backgroundRef: map['backgroundRef'] != null
          ? EntityReference<DomainEntity>.fromMap(
              Map<String, dynamic>.from(map['backgroundRef'] as Map? ?? {}))
          : null,
      progression: CharacterProgression.fromMap(
          Map<String, dynamic>.from(map['progression'] as Map? ?? {})),
      baseScores: AbilityScores.fromMap(
          Map<String, dynamic>.from(map['baseScores'] as Map? ?? {})),
      bonusScores: AbilityScores.fromMap(
          Map<String, dynamic>.from(map['bonusScores'] as Map? ?? {})),
      traitProficiencies: traits,
      savingThrowProficiencies: AttributeKeySet.from(saves),
      toolProficiencies: (map['toolProficiencies'] as List? ?? [])
          .whereType<String>()
          .toList(),
      languages: (map['languages'] as List? ?? ['Common'])
          .whereType<String>()
          .toList(),
      inventory: (map['inventory'] as List? ?? [])
          .whereType<Map>()
          .map((i) =>
              InventoryItemInstance.fromMap(Map<String, dynamic>.from(i)))
          .toList(),
      purse: map['purse'] != null
          ? PartyPurse.fromMap(
              Map<String, dynamic>.from(map['purse'] as Map? ?? {}))
          : const PartyPurse.empty(),
      allocatedSpells: parsedAllocated,
      cantrips: parsedCantrips,
      spellsKnown: parsedSpellsKnown,
      spellsPrepared: (map['spellsPrepared'] as List? ?? [])
          .whereType<Map>()
          .map((s) =>
              EntityReference<Spell>.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      feats: (map['feats'] as List? ?? [])
          .whereType<Map>()
          .map((f) => EntityReference<DomainEntity>.fromMap(
              Map<String, dynamic>.from(f)))
          .toList(),
      resources: CharacterResourcePool.fromMap(
          map['resources'] is Map && (map['resources'] as Map).isNotEmpty
              ? Map<String, dynamic>.from(map['resources'] as Map)
              : <String, dynamic>{
                  if (map['currentHp'] != null) 'currentHp': map['currentHp'],
                  if (map['hp'] != null) 'currentHp': map['hp'],
                  if (map['maxHp'] != null) 'maxHp': map['maxHp'],
                  if (map['tempHp'] != null) 'tempHp': map['tempHp'],
                  if (map['thp'] != null) 'tempHp': map['thp'],
                  if (map['deathSaveSuccesses'] != null)
                    'deathSaveSuccesses': map['deathSaveSuccesses'],
                  if (map['dss'] != null) 'deathSaveSuccesses': map['dss'],
                  if (map['deathSaveFailures'] != null)
                    'deathSaveFailures': map['deathSaveFailures'],
                  if (map['dsf'] != null) 'deathSaveFailures': map['dsf'],
                  if (map['exhaustionLevel'] != null)
                    'exhaustionLevel': map['exhaustionLevel'],
                  if (map['ex'] != null) 'exhaustionLevel': map['ex'],
                }),
      conditions: (map['conditions'] as List? ?? [])
          .whereType<Map>()
          .map((c) => CharacterCondition.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
      maxAttunementSlots: (map['maxAttunementSlots'] as num?)?.toInt() ?? 3,
      baseSpeedFeet: (map['baseSpeedFeet'] as num?)?.toInt() ?? 30,
      rulesetId: resolvedRulesetId,
      customProperties:
          Map<String, dynamic>.from(map['customProperties'] as Map? ?? {}),
    );
  }

  @override
  Character copyWith({
    EntityId? id,
    String? name,
    EntityReference<DomainEntity>? speciesRef,
    EntityReference<DomainEntity>? backgroundRef,
    dynamic progression,
    core.AttributePool? baseScores,
    core.AttributePool? bonusScores,
    Map<dynamic, dynamic>? traitProficiencies,
    dynamic skillProficiencies,
    Set<dynamic>? savingThrowProficiencies,
    List<String>? toolProficiencies,
    List<String>? languages,
    List<core.InventoryItemInstance>? inventory,
    PartyPurse? purse,
    Map<String, List<EntityReference<Spell>>>? allocatedSpells,
    List<EntityReference<Spell>>? cantrips,
    List<EntityReference<Spell>>? spellsKnown,
    List<EntityReference<Spell>>? spellsPrepared,
    List<EntityReference<DomainEntity>>? feats,
    core.CharacterResourcePool? resources,
    List<core.CharacterCondition>? conditions,
    int? maxAttunementSlots,
    int? baseSpeedFeet,
    int? baseSpeed,
    String? rulesetId,
    dynamic rulesEdition,
    Map<String, dynamic>? customProperties,
  }) {
    Map<dynamic, dynamic>? effectiveTraits = traitProficiencies;
    if (skillProficiencies is Map) {
      effectiveTraits = Map<dynamic, dynamic>.from(skillProficiencies);
    }

    AttributeKeySet? effectiveSaves;
    if (savingThrowProficiencies != null) {
      effectiveSaves = AttributeKeySet.from(savingThrowProficiencies);
    }

    final effectiveRulesetId = rulesEdition != null
        ? (rulesEdition is Enum ? rulesEdition.name : rulesEdition.toString())
        : (rulesetId ?? this.rulesetId);

    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      speciesRef: speciesRef ?? this.speciesRef,
      backgroundRef: backgroundRef ?? this.backgroundRef,
      progression: progression != null
          ? (progression is CharacterProgression ? progression : CharacterProgression.fromMap(progression.toMap()))
          : this.progression,
      baseScores: baseScores != null
          ? (baseScores is AbilityScores ? baseScores : AbilityScores.fromMap(baseScores.toMap()))
          : this.baseScores,
      bonusScores: bonusScores != null
          ? (bonusScores is AbilityScores ? bonusScores : AbilityScores.fromMap(bonusScores.toMap()))
          : this.bonusScores,
      traitProficiencies: effectiveTraits != null
          ? Map.unmodifiable(effectiveTraits)
          : this.traitProficiencies,
      savingThrowProficiencies: effectiveSaves ?? this.savingThrowProficiencies,
      toolProficiencies: toolProficiencies != null
          ? List.unmodifiable(toolProficiencies)
          : this.toolProficiencies,
      languages:
          languages != null ? List.unmodifiable(languages) : this.languages,
      inventory: inventory != null
          ? List<InventoryItemInstance>.unmodifiable(inventory.map((i) =>
              i is InventoryItemInstance ? i : InventoryItemInstance.fromMap(i.toMap())))
          : this.inventory,
      purse: purse ?? this.purse,
      allocatedSpells: allocatedSpells != null
          ? Map.unmodifiable(allocatedSpells.map((k, v) =>
              MapEntry(k, List<EntityReference<Spell>>.unmodifiable(v))))
          : this.allocatedSpells,
      cantrips: cantrips != null ? List.unmodifiable(cantrips) : _cantrips,
      spellsKnown:
          spellsKnown != null ? List.unmodifiable(spellsKnown) : _spellsKnown,
      spellsPrepared: spellsPrepared != null
          ? List.unmodifiable(spellsPrepared)
          : this.spellsPrepared,
      feats: feats != null ? List.unmodifiable(feats) : this.feats,
      resources: resources != null
          ? (resources is CharacterResourcePool ? resources : CharacterResourcePool.fromMap(resources.toMap()))
          : this.resources,
      conditions: conditions != null
          ? List<CharacterCondition>.unmodifiable(conditions.map((co) =>
              co))
          : this.conditions,
      maxAttunementSlots: maxAttunementSlots ?? this.maxAttunementSlots,
      baseSpeedFeet: baseSpeedFeet ?? this.baseSpeedFeet,
      rulesetId: effectiveRulesetId,
      customProperties: customProperties != null
          ? deepFreezeMap(customProperties)
          : this.customProperties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Character &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          speciesRef == other.speciesRef &&
          backgroundRef == other.backgroundRef &&
          progression == other.progression &&
          baseScores == other.baseScores &&
          bonusScores == other.bonusScores &&
          _mapEquals(traitProficiencies, other.traitProficiencies) &&
          _setEquals(savingThrowProficiencies, other.savingThrowProficiencies) &&
          _listEquals(toolProficiencies, other.toolProficiencies) &&
          _listEquals(languages, other.languages) &&
          _listEquals(inventory, other.inventory) &&
          purse == other.purse &&
          _mapEquals(allocatedSpells, other.allocatedSpells) &&
          _listEquals(spellsPrepared, other.spellsPrepared) &&
          _listEquals(feats, other.feats) &&
          resources == other.resources &&
          _listEquals(conditions, other.conditions) &&
          maxAttunementSlots == other.maxAttunementSlots &&
          baseSpeedFeet == other.baseSpeedFeet &&
          rulesetId == other.rulesetId &&
          _mapEquals(customProperties, other.customProperties);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      speciesRef.hashCode ^
      (backgroundRef?.hashCode ?? 0) ^
      progression.hashCode ^
      baseScores.hashCode ^
      bonusScores.hashCode ^
      traitProficiencies.length.hashCode ^
      savingThrowProficiencies.length.hashCode ^
      toolProficiencies.length.hashCode ^
      languages.length.hashCode ^
      inventory.length.hashCode ^
      purse.hashCode ^
      allocatedSpells.length.hashCode ^
      spellsPrepared.length.hashCode ^
      feats.length.hashCode ^
      resources.hashCode ^
      conditions.length.hashCode ^
      maxAttunementSlots.hashCode ^
      baseSpeedFeet.hashCode ^
      rulesetId.hashCode ^
      customProperties.length.hashCode;
}
