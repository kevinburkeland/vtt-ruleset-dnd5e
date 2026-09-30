import 'dart:math';
import 'package:vtt_engine_core/currency/i_currency_system.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_engine_core/rules/i_ruleset_module.dart';
import '../attributes/dnd_5e_attribute_system.dart';
import '../combat/dnd_5e_combat_resolver.dart';
import '../currency/dnd_5e_currency_system.dart';
import 'dnd5e_ruleset_module.dart';

// ============================================================================
// 2014 RAW (SRD 5.1) Module
// ============================================================================

/// 2014 Ruleset (SRD 5.1) module implementation.
class Dnd5e2014Module implements IRulesetModule {
  const Dnd5e2014Module();

  @override
  bool hasCapability<T extends IRulesetCapability>() => getCapability<T>() != null;

  @override
  T? getCapability<T extends IRulesetCapability>() {
    if (this is T) return this as T;
    if (exhaustionMechanic is T) return exhaustionMechanic as T;
    if (restMechanic is T) return restMechanic as T;
    if (actionEconomy is T) return actionEconomy as T;
    return null;
  }


  @override
  String get moduleId => 'dnd5e_2014';

  @override
  String get displayName => '5E (2014 Rules / SRD 5.1)';

  @override
  String get rulesetVersion => 'SRD 5.1';

  String get srdCitation => 'System Reference Document 5.1 (CC-BY-4.0)';
  @override
  String? get legalCitation => srdCitation;

  @override
  IAttributeSystem get attributeSystem => const Dnd5eAttributeSystem();

  @override
  ICurrencySystem get currencySystem => const Dnd5eCurrencySystem();

  @override
  IExhaustionMechanic get exhaustionMechanic =>
      const Dnd5e2014ExhaustionMechanic();

  @override
  IRestMechanic get restMechanic => const Dnd5eRestMechanic();

  @override
  IActionEconomy get actionEconomy => const Dnd5e2014ActionEconomy();

  @override
  ICombatResolver get combatResolver => const Dnd5eCombatResolver();

  @override
  Set<String> get defaultPinnedRules => const {
        'concentration',
        'falling',
        'grapple_shove',
        'cover',
        'resting',
      };

  @override
  int calculateDerivedStat({
    required dynamic character,
    required String statKey,
    Map<String, dynamic> context = const {},
  }) {
    return const Dnd5eRulesetModule.v2014().calculateDerivedStat(
      character: character,
      statKey: statKey,
      context: context,
    );
  }

  @override
  bool supportsFeature(String featureKey) {
    return switch (featureKey.toLowerCase().trim()) {
      'weapon_masteries' => false,
      'bonus_action_potions' => false,
      'tactical_mind' => false,
      _ => true,
    };
  }
}

class Dnd5e2014ExhaustionMechanic implements IExhaustionMechanic {
  const Dnd5e2014ExhaustionMechanic();

  @override
  int get maxExhaustionTiers => 6;

  @override
  int calculateD20Penalty(int tier) =>
      0; // 2014 imposes disadvantage rather than linear penalty

  @override
  int calculateSpeedPenalty(int tier, int baseSpeed) {
    if (tier >= 5) return baseSpeed;
    if (tier >= 2) return baseSpeed ~/ 2;
    return 0;
  }

  @override
  bool isFatal(int tier) => tier >= 6;

  @override
  String describeTierEffects(int tier) {
    return switch (tier) {
      1 => 'Disadvantage on ability checks',
      2 => 'Speed halved',
      3 => 'Disadvantage on attack rolls and saving throws',
      4 => 'Hit point maximum halved',
      5 => 'Speed reduced to 0',
      >= 6 => 'Death',
      _ => 'Normal state',
    };
  }
}

class Dnd5e2014ActionEconomy implements IActionEconomy {
  const Dnd5e2014ActionEconomy();

  @override
  ActionCost getConsumableUsageCost(String consumableType) {
    // 2014 RAW: Consuming a potion is a standard Action
    return ActionCost.standard;
  }

  @override
  bool canTakeAction({
    required String actionType,
    required Set<String> activeConditions,
    required ActionBudget currentBudget,
  }) {
    if (activeConditions.contains('incapacitated') ||
        activeConditions.contains('paralyzed') ||
        activeConditions.contains('petrified') ||
        activeConditions.contains('stunned') ||
        activeConditions.contains('unconscious')) {
      return false;
    }
    return switch (actionType) {
      'action' => currentBudget.actionsRemaining > 0,
      'bonus_action' => (currentBudget.customPools['bonus_actions'] ?? currentBudget.actionsRemaining) > 0,
      'reaction' => currentBudget.reactionsRemaining > 0,
      _ => true,
    };
  }
}

// ============================================================================
// 2024 Revised (SRD 5.2.1) Module
// ============================================================================

/// 2024 Revised Ruleset (SRD 5.2.1) module implementation.
class Dnd5e2024Module implements IRulesetModule {
  const Dnd5e2024Module();

  @override
  bool hasCapability<T extends IRulesetCapability>() => getCapability<T>() != null;

  @override
  T? getCapability<T extends IRulesetCapability>() {
    if (this is T) return this as T;
    if (exhaustionMechanic is T) return exhaustionMechanic as T;
    if (restMechanic is T) return restMechanic as T;
    if (actionEconomy is T) return actionEconomy as T;
    return null;
  }


  @override
  String get moduleId => 'dnd5e_2024';

  @override
  String get displayName => '5E (2024 Revised / SRD 5.2.1)';

  @override
  String get rulesetVersion => 'SRD 5.2.1';

  String get srdCitation => 'System Reference Document 5.2.1 (CC-BY-4.0)';
  @override
  String? get legalCitation => srdCitation;

  @override
  IAttributeSystem get attributeSystem => const Dnd5eAttributeSystem();

  @override
  ICurrencySystem get currencySystem => const Dnd5eCurrencySystem();

  @override
  IExhaustionMechanic get exhaustionMechanic =>
      const Dnd5e2024ExhaustionMechanic();

  @override
  IRestMechanic get restMechanic => const Dnd5eRestMechanic();

  @override
  IActionEconomy get actionEconomy => const Dnd5e2024ActionEconomy();

  @override
  ICombatResolver get combatResolver => const Dnd5eCombatResolver();

  @override
  Set<String> get defaultPinnedRules => const {
        'concentration',
        'falling',
        'grapple_shove',
        'cover',
        'resting',
      };

  @override
  int calculateDerivedStat({
    required dynamic character,
    required String statKey,
    Map<String, dynamic> context = const {},
  }) {
    return const Dnd5eRulesetModule.v2024().calculateDerivedStat(
      character: character,
      statKey: statKey,
      context: context,
    );
  }

  @override
  bool supportsFeature(String featureKey) {
    return switch (featureKey.toLowerCase().trim()) {
      'weapon_masteries' => true,
      'bonus_action_potions' => true,
      'tactical_mind' => true,
      _ => true,
    };
  }
}

class Dnd5e2024ExhaustionMechanic implements IExhaustionMechanic {
  const Dnd5e2024ExhaustionMechanic();

  @override
  int get maxExhaustionTiers => 6;

  @override
  int calculateD20Penalty(int tier) => (tier.clamp(0, 6)) * 2;

  @override
  int calculateSpeedPenalty(int tier, int baseSpeed) => (tier.clamp(0, 6)) * 5;

  @override
  bool isFatal(int tier) => tier >= 6;

  @override
  String describeTierEffects(int tier) {
    if (tier <= 0) return 'Normal state';
    if (tier >= 6) return 'Exhaustion Level 6: Death';
    return 'Exhaustion Level $tier: -${tier * 2} to all D20 Tests, -${tier * 5} ft Speed';
  }
}

class Dnd5e2024ActionEconomy implements IActionEconomy {
  const Dnd5e2024ActionEconomy();

  @override
  ActionCost getConsumableUsageCost(String consumableType) {
    // 2024 Revised: Drinking or administering a potion is a Bonus Action
    return ActionCost.special;
  }

  @override
  bool canTakeAction({
    required String actionType,
    required Set<String> activeConditions,
    required ActionBudget currentBudget,
  }) {
    if (activeConditions.contains('incapacitated') ||
        activeConditions.contains('paralyzed') ||
        activeConditions.contains('petrified') ||
        activeConditions.contains('stunned') ||
        activeConditions.contains('unconscious')) {
      return false;
    }
    return switch (actionType) {
      'action' => currentBudget.actionsRemaining > 0,
      'bonus_action' => (currentBudget.customPools['bonus_actions'] ?? currentBudget.actionsRemaining) > 0,
      'reaction' => currentBudget.reactionsRemaining > 0,
      _ => true,
    };
  }
}

// ============================================================================
// Shared 5e Rest Mechanic
// ============================================================================

class Dnd5eRestMechanic implements IRestMechanic {
  const Dnd5eRestMechanic();

  @override
  RestResult resolveRest({
    required String restType,
    required EntityVitals currentVitals,
    Map<String, int> spentRecoveryResources = const {},
  }) {
    if (restType == 'short' || restType == 'shortRest') {
      return resolveShortRest(
        currentVitals: currentVitals,
        spentRecoveryResources: spentRecoveryResources,
      );
    }
    return resolveLongRest(currentVitals: currentVitals);
  }

  RestResult resolveShortRest({
    required EntityVitals currentVitals,
    required Map<String, int> spentRecoveryResources,
  }) {
    // 5e Short Rest restores HP based on spent hit dice
    final recoveredHp = spentRecoveryResources['recovered_hp'] ?? 0;
    final updatedHp =
        min(currentVitals.maxHp, currentVitals.currentHp + recoveredHp);

    return RestResult(
      vitals: currentVitals.copyWith(currentHp: updatedHp),
      restoredResources: {'hp_recovered': recoveredHp},
      summary: 'Short rest completed. Recovered $recoveredHp HP.',
    );
  }

  RestResult resolveLongRest({
    required EntityVitals currentVitals,
  }) {
    // 5e Long Rest fully restores HP and removes temporary HP
    return RestResult(
      vitals: currentVitals.copyWith(
        currentHp: currentVitals.maxHp,
        temporaryHp: 0,
        isDowned: false,
      ),
      summary: 'Long rest completed. HP fully restored.',
    );
  }
}
