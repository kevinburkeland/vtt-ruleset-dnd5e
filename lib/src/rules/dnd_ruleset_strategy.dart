import 'dart:math' as math;
import 'ruleset_edition.dart';
import '../models/character_models.dart';
import '../models/spell_monster_equipment.dart';
import '../mechanics/weapon_mastery.dart';



/// Encumbrance Tiers
enum EncumbranceTier {
  unencumbered,
  encumbered,
  heavilyEncumbered,
  overCapacity;

  String get displayName => switch (this) {
        EncumbranceTier.unencumbered => 'Unencumbered',
        EncumbranceTier.encumbered => 'Encumbered',
        EncumbranceTier.heavilyEncumbered => 'Heavily Encumbered',
        EncumbranceTier.overCapacity => 'Over Capacity',
      };
}

/// Structured Encumbrance Status
class EncumbranceStatus {
  final double totalWeightLbs;
  final double carryCapacityLbs;
  final double pushDragLiftLbs;
  final EncumbranceTier variantTier;
  final int speedPenaltyFeet;
  final bool hasDisadvantageOnD20;

  const EncumbranceStatus({
    required this.totalWeightLbs,
    required this.carryCapacityLbs,
    required this.pushDragLiftLbs,
    required this.variantTier,
    required this.speedPenaltyFeet,
    required this.hasDisadvantageOnD20,
  });
}

/// Structured Exhaustion Evaluation
class ExhaustionEffects {
  final int level;
  final int d20TestPenalty; // 2024: -2 * level; 2014: 0 (uses disadvantage flags)
  final int speedReductionFeet; // 2024: 5 * level; 2014: 0 (uses speedMultiplier)
  final double speedMultiplier; // 2014: 0.5 at lvl 2, 0.0 at lvl 5
  final double maxHpMultiplier; // 2014: 0.5 at lvl 4
  final bool hasDisadvantageOnAbilityChecks; // 2014: lvl >= 1
  final bool hasDisadvantageOnAttacksAndSaves; // 2014: lvl >= 3
  final bool isDead; // Both: lvl >= 6

  const ExhaustionEffects({
    required this.level,
    this.d20TestPenalty = 0,
    this.speedReductionFeet = 0,
    this.speedMultiplier = 1.0,
    this.maxHpMultiplier = 1.0,
    this.hasDisadvantageOnAbilityChecks = false,
    this.hasDisadvantageOnAttacksAndSaves = false,
    this.isDead = false,
  });
}

/// Strategy pattern governing ruleset-specific mechanical divergence
/// between 2014 RAW and 2024 Revised D&D 5e rules.
abstract class RulesetStrategy {
  RulesetEdition get edition;

  /// Effective Caster Level calculation for multiclass spellcasters
  int calculateEffectiveCasterLevel({
    int fullCasterLevels = 0,
    int paladinLevels = 0,
    int rangerLevels = 0,
    int roundUpHalfCasterLevels = 0,
    int thirdCasterLevels = 0,
  });

  /// Evaluates mechanical exhaustion penalties and death states
  ExhaustionEffects evaluateExhaustion(int exhaustionLevel);

  /// Computes Grapple / Shove DC or description
  ({int? dc, String formulaDescription}) calculateGrappleShoveDc({
    required int strengthModifier,
    required int dexterityModifier,
    required int proficiencyBonus,
  });

  /// Validates whether a character can use Weapon Mastery for a given weapon
  bool canUseWeaponMastery({
    required Character character,
    required EquipmentItem weapon,
    required WeaponMasteryProperty mastery,
  });

  /// Evaluates inventory encumbrance and push/drag/lift capacities
  EncumbranceStatus calculateEncumbrance({
    required int strengthScore,
    required List<InventoryItemInstance> inventory,
    required int totalCoinCount,
    bool isPowerfulBuildOrLarge = false,
  });

  /// Factory helper to obtain strategy by edition
  static RulesetStrategy forEdition(RulesetEdition edition) {
    return switch (edition) {
      RulesetEdition.v2014 => const Ruleset2014Strategy(),
      RulesetEdition.v2024 => const Ruleset2024Strategy(),
    };
  }
}

/// 2014 Legacy Rules Strategy
class Ruleset2014Strategy implements RulesetStrategy {
  const Ruleset2014Strategy();

  @override
  RulesetEdition get edition => RulesetEdition.v2014;

  @override
  int calculateEffectiveCasterLevel({
    int fullCasterLevels = 0,
    int paladinLevels = 0,
    int rangerLevels = 0,
    int roundUpHalfCasterLevels = 0,
    int thirdCasterLevels = 0,
  }) {
    final halfCastersRoundUp = roundUpHalfCasterLevels;
    final effective = fullCasterLevels +
        (paladinLevels ~/ 2) +
        (rangerLevels ~/ 2) +
        ((halfCastersRoundUp + 1) ~/ 2) +
        (thirdCasterLevels ~/ 3);
    return effective.clamp(0, 20);
  }

  @override
  ExhaustionEffects evaluateExhaustion(int exhaustionLevel) {
    final lvl = exhaustionLevel.clamp(0, 6);
    if (lvl == 0) return const ExhaustionEffects(level: 0);

    return ExhaustionEffects(
      level: lvl,
      d20TestPenalty: 0,
      speedReductionFeet: 0,
      speedMultiplier: lvl >= 5 ? 0.0 : (lvl >= 2 ? 0.5 : 1.0),
      maxHpMultiplier: lvl >= 4 ? 0.5 : 1.0,
      hasDisadvantageOnAbilityChecks: lvl >= 1,
      hasDisadvantageOnAttacksAndSaves: lvl >= 3,
      isDead: lvl >= 6,
    );
  }

  @override
  ({int? dc, String formulaDescription}) calculateGrappleShoveDc({
    required int strengthModifier,
    required int dexterityModifier,
    required int proficiencyBonus,
  }) {
    final strAthleticsBonus = strengthModifier + proficiencyBonus;
    final bonusStr =
        strAthleticsBonus >= 0 ? '+$strAthleticsBonus' : '$strAthleticsBonus';
    return (
      dc: null,
      formulaDescription:
          'Contested Athletics ($bonusStr) vs Target Athletics/Acrobatics',
    );
  }

  @override
  bool canUseWeaponMastery({
    required Character character,
    required EquipmentItem weapon,
    required WeaponMasteryProperty mastery,
  }) {
    return false;
  }

  @override
  EncumbranceStatus calculateEncumbrance({
    required int strengthScore,
    required List<InventoryItemInstance> inventory,
    required int totalCoinCount,
    bool isPowerfulBuildOrLarge = false,
  }) {
    final multiplier = isPowerfulBuildOrLarge ? 2 : 1;
    final carryCapacity = (strengthScore * 15 * multiplier).toDouble();
    final pushDragLift = (strengthScore * 30 * multiplier).toDouble();

    double totalWeight = 0.0;
    for (final item in inventory) {
      final weightPerUnit =
          (item.customProperties['weightLbs'] as num?)?.toDouble() ??
              (item.customProperties['weight'] as num?)?.toDouble() ??
              0.0;
      totalWeight += weightPerUnit * item.quantity;
    }
    totalWeight += (totalCoinCount / 50.0);

    final encumberedThreshold = strengthScore * 5 * multiplier;
    final heavilyEncumberedThreshold = strengthScore * 10 * multiplier;

    EncumbranceTier tier;
    int speedPenalty = 0;
    bool hasDisadvantage = false;

    if (totalWeight > carryCapacity) {
      tier = EncumbranceTier.overCapacity;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > heavilyEncumberedThreshold) {
      tier = EncumbranceTier.heavilyEncumbered;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > encumberedThreshold) {
      tier = EncumbranceTier.encumbered;
      speedPenalty = 10;
      hasDisadvantage = false;
    } else {
      tier = EncumbranceTier.unencumbered;
    }

    return EncumbranceStatus(
      totalWeightLbs: totalWeight,
      carryCapacityLbs: carryCapacity,
      pushDragLiftLbs: pushDragLift,
      variantTier: tier,
      speedPenaltyFeet: speedPenalty,
      hasDisadvantageOnD20: hasDisadvantage,
    );
  }
}

/// 2024 Revised Rules Strategy
class Ruleset2024Strategy implements RulesetStrategy {
  const Ruleset2024Strategy();

  @override
  RulesetEdition get edition => RulesetEdition.v2024;

  @override
  int calculateEffectiveCasterLevel({
    int fullCasterLevels = 0,
    int paladinLevels = 0,
    int rangerLevels = 0,
    int roundUpHalfCasterLevels = 0,
    int thirdCasterLevels = 0,
  }) {
    final halfCastersRoundUp = roundUpHalfCasterLevels;
    final paladinEcl = (paladinLevels + 1) ~/ 2;
    final rangerEcl = (rangerLevels + 1) ~/ 2;
    final roundUpEcl = (halfCastersRoundUp + 1) ~/ 2;
    final thirdEcl = thirdCasterLevels > 0 ? ((thirdCasterLevels + 2) ~/ 3) : 0;

    final effective =
        fullCasterLevels + paladinEcl + rangerEcl + roundUpEcl + thirdEcl;
    return effective.clamp(0, 20);
  }

  @override
  ExhaustionEffects evaluateExhaustion(int exhaustionLevel) {
    final lvl = exhaustionLevel.clamp(0, 6);
    if (lvl == 0) return const ExhaustionEffects(level: 0);

    return ExhaustionEffects(
      level: lvl,
      d20TestPenalty: -2 * lvl,
      speedReductionFeet: 5 * lvl,
      speedMultiplier: 1.0,
      maxHpMultiplier: 1.0,
      hasDisadvantageOnAbilityChecks: false,
      hasDisadvantageOnAttacksAndSaves: false,
      isDead: lvl >= 6,
    );
  }

  @override
  ({int? dc, String formulaDescription}) calculateGrappleShoveDc({
    required int strengthModifier,
    required int dexterityModifier,
    required int proficiencyBonus,
  }) {
    final bestMod = math.max(strengthModifier, dexterityModifier);
    final dc = 8 + proficiencyBonus + bestMod;
    return (
      dc: dc,
      formulaDescription:
          'DC $dc (8 + PB + ${bestMod == strengthModifier ? "STR" : "DEX"} Mod)',
    );
  }

  static const _masteryEligibleClasses = {
    'fighter',
    'barbarian',
    'rogue',
    'paladin',
    'ranger',
  };

  @override
  bool canUseWeaponMastery({
    required Character character,
    required EquipmentItem weapon,
    required WeaponMasteryProperty mastery,
  }) {
    final hasMasteryClass = character.progression.classes.any(
      (c) => _masteryEligibleClasses.contains(c.classRef.slug.toLowerCase()),
    );
    if (!hasMasteryClass) return false;

    final weaponMasteryProp =
        weapon.customProperties['mastery']?.toString().toLowerCase() ??
            weapon.customProperties['weaponMastery']?.toString().toLowerCase();

    if (weaponMasteryProp == null) return false;
    return weaponMasteryProp == mastery.name.toLowerCase();
  }

  @override
  EncumbranceStatus calculateEncumbrance({
    required int strengthScore,
    required List<InventoryItemInstance> inventory,
    required int totalCoinCount,
    bool isPowerfulBuildOrLarge = false,
  }) {
    final multiplier = isPowerfulBuildOrLarge ? 2 : 1;
    final carryCapacity = (strengthScore * 15 * multiplier).toDouble();
    final pushDragLift = (strengthScore * 30 * multiplier).toDouble();

    double totalWeight = 0.0;
    for (final item in inventory) {
      final weightPerUnit =
          (item.customProperties['weightLbs'] as num?)?.toDouble() ??
              (item.customProperties['weight'] as num?)?.toDouble() ??
              0.0;
      totalWeight += weightPerUnit * item.quantity;
    }
    totalWeight += (totalCoinCount / 50.0);

    final encumberedThreshold = strengthScore * 5 * multiplier;
    final heavilyEncumberedThreshold = strengthScore * 10 * multiplier;

    EncumbranceTier tier;
    int speedPenalty = 0;
    bool hasDisadvantage = false;

    if (totalWeight > carryCapacity) {
      tier = EncumbranceTier.overCapacity;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > heavilyEncumberedThreshold) {
      tier = EncumbranceTier.heavilyEncumbered;
      speedPenalty = 20;
      hasDisadvantage = true;
    } else if (totalWeight > encumberedThreshold) {
      tier = EncumbranceTier.encumbered;
      speedPenalty = 10;
      hasDisadvantage = false;
    } else {
      tier = EncumbranceTier.unencumbered;
    }

    return EncumbranceStatus(
      totalWeightLbs: totalWeight,
      carryCapacityLbs: carryCapacity,
      pushDragLiftLbs: pushDragLift,
      variantTier: tier,
      speedPenaltyFeet: speedPenalty,
      hasDisadvantageOnD20: hasDisadvantage,
    );
  }
}
