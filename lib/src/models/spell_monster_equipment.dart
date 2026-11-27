import 'package:meta/meta.dart';
import 'core_types.dart';

export 'equipment_item.dart';
export 'monster.dart';
export 'spell.dart';

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

  EvaluationMath copyWith({
    String? diceFormula,
    DamageType? damageType,
    String? scalingFormula,
    bool? isAttackRoll,
    bool? requiresSave,
  }) {
    return EvaluationMath(
      diceFormula: diceFormula ?? this.diceFormula,
      damageType: damageType ?? this.damageType,
      scalingFormula: scalingFormula ?? this.scalingFormula,
      isAttackRoll: isAttackRoll ?? this.isAttackRoll,
      requiresSave: requiresSave ?? this.requiresSave,
    );
  }

  Map<String, dynamic> toMap() => {
        'diceFormula': diceFormula,
        'damageType': damageType.name,
        'isAttackRoll': isAttackRoll,
        'requiresSave': requiresSave,
        'scalingFormula': scalingFormula,
      };

  factory EvaluationMath.fromMap(Map<String, dynamic> map) {
    final dmgStr = map['damageType']?.toString() ?? 'untyped';
    final damageType = DamageType.values.firstWhere(
      (d) => d.name == dmgStr,
      orElse: () => DamageType.untyped,
    );
    return EvaluationMath(
      diceFormula: map['diceFormula']?.toString() ?? '',
      damageType: damageType,
      scalingFormula: map['scalingFormula']?.toString(),
      isAttackRoll: map['isAttackRoll'] == true,
      requiresSave: map['requiresSave'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationMath &&
          runtimeType == other.runtimeType &&
          diceFormula == other.diceFormula &&
          damageType == other.damageType &&
          scalingFormula == other.scalingFormula &&
          isAttackRoll == other.isAttackRoll &&
          requiresSave == other.requiresSave;

  @override
  int get hashCode =>
      diceFormula.hashCode ^
      damageType.hashCode ^
      scalingFormula.hashCode ^
      isAttackRoll.hashCode ^
      requiresSave.hashCode;

  @override
  String toString() {
    final delivery =
        isAttackRoll ? ' (attack)' : (requiresSave ? ' (save)' : '');
    return '$diceFormula ${damageType.name}$delivery';
  }
}

/// Standardized spell component flags
@immutable
class SpellComponents {
  final bool v;
  final bool s;
  final bool m;
  final String? materialDescription;
  final int materialCostGp;
  final bool consumesMaterial;

  const SpellComponents({
    this.v = false,
    this.s = false,
    this.m = false,
    this.materialDescription,
    this.materialCostGp = 0,
    this.consumesMaterial = false,
  });

  Map<String, dynamic> toMap() => {
        'v': v,
        's': s,
        'm': m,
        'materialDescription': materialDescription,
        'materialCostGp': materialCostGp,
        'consumesMaterial': consumesMaterial,
      };

  factory SpellComponents.fromMap(Map<String, dynamic> map) {
    return SpellComponents(
      v: map['v'] == true,
      s: map['s'] == true,
      m: map['m'] == true,
      materialDescription: map['materialDescription']?.toString(),
      materialCostGp: (map['materialCostGp'] as num?)?.toInt() ?? 0,
      consumesMaterial: map['consumesMaterial'] == true,
    );
  }
}

/// Flattened casting time model
@immutable
class CastingTime {
  final int cost;
  final ActionType actionType;
  final String? triggerCondition;

  const CastingTime({
    required this.cost,
    required this.actionType,
    this.triggerCondition,
  });

  Map<String, dynamic> toMap() => {
        'cost': cost,
        'actionType': actionType.name,
        'triggerCondition': triggerCondition,
      };

  factory CastingTime.fromMap(Map<String, dynamic> map) {
    final typeStr = map['actionType']?.toString() ?? 'action';
    final actionType = ActionType.values.firstWhere(
      (a) => a.name == typeStr,
      orElse: () => ActionType.action,
    );
    return CastingTime(
      cost: (map['cost'] as num?)?.toInt() ?? 1,
      actionType: actionType,
      triggerCondition: map['triggerCondition']?.toString(),
    );
  }
}

/// Flattened duration model with concentration flag
@immutable
class SpellDuration {
  final DurationType type;
  final int durationSeconds;
  final bool requiresConcentration;
  final String? rawText;

  const SpellDuration({
    required this.type,
    this.durationSeconds = 0,
    this.requiresConcentration = false,
    this.rawText,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'durationSeconds': durationSeconds,
        'requiresConcentration': requiresConcentration,
        'rawText': rawText,
      };

  factory SpellDuration.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type']?.toString() ?? 'instantaneous';
    final type = DurationType.values.firstWhere(
      (d) => d.name == typeStr,
      orElse: () => DurationType.instantaneous,
    );
    return SpellDuration(
      type: type,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      requiresConcentration: map['requiresConcentration'] == true,
      rawText: map['rawText']?.toString(),
    );
  }
}
