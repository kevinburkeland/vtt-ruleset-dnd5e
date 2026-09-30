import 'package:test/test.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
void main() {
  group('D&D 5e Ruleset Modules (2014 RAW vs 2024 Revised) Invariants', () {
    const module2014 = Dnd5e2014Module();
    const module2024 = Dnd5e2024Module();

    test('verifies potion consumption action cost inversion', () {
      // 2014 RAW: Action
      expect(
        module2014.actionEconomy.getConsumableUsageCost('potion'),
        equals(ActionCost.standard),
      );

      // 2024 Revised: Bonus Action
      expect(
        module2024.actionEconomy.getConsumableUsageCost('potion'),
        equals(ActionCost.special),
      );
    });

    test('verifies exhaustion mechanics differences', () {
      final exhaust2014 = module2014.exhaustionMechanic;
      final exhaust2024 = module2024.exhaustionMechanic;

      // 2014: Disadvantage rather than flat penalty
      expect(exhaust2014.calculateD20Penalty(1), equals(0));
      expect(exhaust2014.calculateD20Penalty(3), equals(0));
      expect(exhaust2014.calculateSpeedPenalty(1, 30), equals(0));
      expect(exhaust2014.calculateSpeedPenalty(2, 30), equals(15)); // Halved
      expect(exhaust2014.calculateSpeedPenalty(5, 30), equals(30)); // 0 speed

      // 2024: Linear -2 per tier to d20 tests, -5 ft speed per tier
      expect(exhaust2024.calculateD20Penalty(1), equals(2));
      expect(exhaust2024.calculateD20Penalty(3), equals(6));
      expect(exhaust2024.calculateD20Penalty(5), equals(10));
      expect(exhaust2024.calculateSpeedPenalty(1, 30), equals(5));
      expect(exhaust2024.calculateSpeedPenalty(2, 30), equals(10));

      // Both fatal at tier 6
      expect(exhaust2014.isFatal(6), isTrue);
      expect(exhaust2024.isFatal(6), isTrue);
    });

    test('verifies weapon masteries capability gating', () {
      expect(module2014.supportsFeature('weapon_masteries'), isFalse);
      expect(module2024.supportsFeature('weapon_masteries'), isTrue);
    });

    test('verifies 5e attribute modifier calculations', () {
      final attrSystem = module2024.attributeSystem;

      expect(attrSystem.calculateModifier('strength', 10), equals(0));
      expect(attrSystem.calculateModifier('strength', 11), equals(0));
      expect(attrSystem.calculateModifier('strength', 12), equals(1));
      expect(attrSystem.calculateModifier('dexterity', 15), equals(2));
      expect(attrSystem.calculateModifier('constitution', 8), equals(-1));
      expect(attrSystem.calculateModifier('intelligence', 20), equals(5));
    });
  });
}