import 'dart:math';
import 'package:test/test.dart';
import 'package:vtt_engine_core/rules/i_ruleset_module.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_engine_core/currency/i_currency_system.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/simulation/i_simulation_strategy.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('Package Boundary Integration Tests', () {
    test('Dnd5eRulesetModule instantiates and conforms strictly to IRulesetModule', () {
      const IRulesetModule module = Dnd5eRulesetModule.v2024();

      expect(module.moduleId, equals('dnd5e_2024'));
      expect(module.displayName, contains('2024 Revised'));
      expect(module.rulesetVersion, equals('SRD 5.2.1'));
      expect(module.legalCitation, contains('CC-BY-4.0'));

      // Core SPI contracts
      final IAttributeSystem attributes = module.attributeSystem;
      expect(attributes.attributeKeys, containsAll(['strength', 'dexterity', 'constitution', 'intelligence', 'wisdom', 'charisma']));
      expect(attributes.calculateModifier('strength', 16), equals(3));
      expect(attributes.calculateModifier('dexterity', 8), equals(-1));

      final ICurrencySystem currency = module.currencySystem;
      expect(currency.baseDenominationId, equals('gp'));
      expect(currency.convert(amount: 100, fromDenominationId: 'cp', toDenominationId: 'gp'), equals(1.0));

      final ICombatResolver combat = module.combatResolver;
      final resolution = combat.resolveAttack(
        attack: const AttackIntent(attackBonus: 5, damageExpression: '1d8+3'),
        defense: const TargetDefenseProfile(targetDefenseRating: 14),
        rng: Random(42),
      );
      expect(resolution, isNotNull);
      expect(resolution.totalToHit, equals(resolution.naturalRoll + 5));

      // Capabilities
      expect(module.hasCapability<IExhaustionMechanic>(), isTrue);
      final exhaustion = module.getCapability<IExhaustionMechanic>();
      expect(exhaustion, isNotNull);
      expect(exhaustion!.maxExhaustionTiers, equals(6));
      expect(exhaustion.calculateD20Penalty(2), equals(4)); // 2024: -4 to D20 tests
      expect(exhaustion.isFatal(6), isTrue);

      expect(module.hasCapability<IRestMechanic>(), isTrue);
      final rest = module.getCapability<IRestMechanic>();
      expect(rest, isNotNull);
      final restResult = rest!.resolveRest(
        restType: 'long',
        currentVitals: const EntityVitals(currentHp: 5, maxHp: 20, temporaryHp: 4),
      );
      expect(restResult.vitals.currentHp, equals(20));
      expect(restResult.vitals.temporaryHp, equals(0));

      expect(module.hasCapability<IActionEconomy>(), isTrue);
      final economy = module.getCapability<IActionEconomy>();
      expect(economy, isNotNull);
      // 2024 potions are bonus actions (special cost in core abstraction)
      expect(economy!.getConsumableUsageCost('potion'), equals(ActionCost.special));
    });

    test('2014 RAW Module instantiation and divergence behavior', () {
      const IRulesetModule module2014 = Dnd5eRulesetModule.v2014();

      expect(module2014.moduleId, equals('dnd5e_2014'));
      expect(module2014.rulesetVersion, equals('SRD 5.1'));

      final exhaustion2014 = module2014.getCapability<IExhaustionMechanic>()!;
      expect(exhaustion2014.calculateD20Penalty(2), equals(0)); // 2014 uses disadvantage, not linear penalty
      expect(exhaustion2014.calculateSpeedPenalty(2, 30), equals(15)); // 2014 level 2: speed halved

      final economy2014 = module2014.getCapability<IActionEconomy>()!;
      expect(economy2014.getConsumableUsageCost('potion'), equals(ActionCost.standard)); // 2014: Action
    });

    test('Dnd5eDprSimulationStrategy implements ISimulationStrategy from engine', () {
      const ISimulationStrategy<AttackIntent, TargetDefenseProfile> strategy =
          Dnd5eDprSimulationStrategy();

      expect(strategy.strategyId, equals('dnd5e_dpr_standard'));
      final outcome = strategy.simulateStep(
        action: const AttackIntent(attackBonus: 7, damageExpression: '2d6+4'),
        target: const TargetDefenseProfile(targetDefenseRating: 15),
        rng: Random(123),
      );
      expect(outcome, isNotNull);
      if (outcome.isSuccess) {
        expect(outcome.magnitude, greaterThan(0));
      }
    });
  });
}
