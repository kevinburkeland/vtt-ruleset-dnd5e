import 'dart:math';
import 'package:test/test.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_engine_core/simulation/dpr_simulator.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('D&D 5e Combat Resolver & Vitals Invariants', () {
    const resolver = Dnd5eCombatResolver();

    test('resolves attacks against target AC with crits and fumbles', () {
      const attack = AttackIntent(
        attackBonus: 5,
        damageExpression: '1d8+3',
      );
      const defense = TargetDefenseProfile(
        targetDefenseRating: 15,
      );

      final hitRes = resolver.resolveAttack(
        attack: attack,
        defense: defense,
        rng: Random(1),
      );

      expect(hitRes.outcome, isA<AttackOutcomeType>());
      if (hitRes.isHit) {
        expect(hitRes.damageDealt, greaterThan(0));
      }
    });

    test(
        'resolves 5e RAW vitals modifications and massive damage instant death',
        () {
      const initial = EntityVitals(
        currentHp: 20,
        maxHp: 20,
        temporaryHp: 5,
      );

      // 1. Damage absorbs temp HP first
      final damage8 = resolver.resolveVitalsChange(
        currentVitals: initial,
        delta: -8,
      );
      expect(damage8.updatedVitals.temporaryHp, equals(0));
      expect(damage8.updatedVitals.currentHp, equals(17));
      expect(damage8.updatedVitals.isDowned, isFalse);
      expect(damage8.updatedVitals.isDead, isFalse);

      // 2. Damage dropping to 0 sets isDowned = true
      final damage25 = resolver.resolveVitalsChange(
        currentVitals: damage8.updatedVitals,
        delta: -25,
      );
      expect(damage25.updatedVitals.currentHp, equals(0));
      expect(damage25.updatedVitals.isDowned, isTrue);
      expect(damage25.updatedVitals.isDead, isFalse);

      // 3. Massive damage exceeding remaining HP by maxHp triggers instant death
      final massiveDamage = resolver.resolveVitalsChange(
        currentVitals: initial,
        delta: -45, // 5 temp + 20 current + 20 excess = triggers death
      );
      expect(massiveDamage.updatedVitals.currentHp, equals(0));
      expect(massiveDamage.updatedVitals.isDead, isTrue);

      // 4. Standard healing revives downed actor at 0 HP
      final healDowned = resolver.resolveVitalsChange(
        currentVitals: damage25.updatedVitals,
        delta: 10,
      );
      expect(healDowned.updatedVitals.currentHp, equals(10));
      expect(healDowned.updatedVitals.isDowned, isFalse);
      expect(healDowned.revivedFromDefeat, isTrue);

      // 5. Dead actor cannot be revived with standard healing unless allowRevive is true
      final healDead = resolver.resolveVitalsChange(
        currentVitals: massiveDamage.updatedVitals,
        delta: 10,
      );
      expect(healDead.updatedVitals.currentHp, equals(0));
      expect(healDead.updatedVitals.isDead, isTrue);

      final reviveDead = resolver.resolveVitalsChange(
        currentVitals: massiveDamage.updatedVitals,
        delta: 10,
        allowRevive: true,
      );
      expect(reviveDead.updatedVitals.currentHp, equals(10));
      expect(reviveDead.updatedVitals.isDead, isFalse);
    });

    group('Fix 5.4: Massive damage at 0 HP kills', () {
      test('example cases: 0/20 with 25 dmg kills, 1/20 with 25 kills, 0/20 with 19 dmg does not kill', () {
        // current 0, max 20, damage 25 -> dead
        final atZeroExcess25 = resolver.resolveVitalsChange(
          currentVitals: const EntityVitals(currentHp: 0, maxHp: 20, temporaryHp: 0),
          delta: -25,
        );
        expect(atZeroExcess25.updatedVitals.isDead, isTrue, reason: 'Damage 25 >= maxHp 20 at 0 HP must cause death');
        expect(atZeroExcess25.triggeredDeath, isTrue);

        // control: current 1, max 20, damage 25 -> dead (absorbed 1 current, 24 excess >= 20 -> dead)
        final atOneExcess25 = resolver.resolveVitalsChange(
          currentVitals: const EntityVitals(currentHp: 1, maxHp: 20, temporaryHp: 0),
          delta: -25,
        );
        expect(atOneExcess25.updatedVitals.isDead, isTrue, reason: 'Damage 25 from 1 HP causes 24 excess >= 20 max HP -> dead');
        expect(atOneExcess25.triggeredDeath, isTrue);

        // current 0, max 20, damage 19 -> not dead (19 excess < 20 max HP)
        final atZeroExcess19 = resolver.resolveVitalsChange(
          currentVitals: const EntityVitals(currentHp: 0, maxHp: 20, temporaryHp: 0),
          delta: -19,
        );
        expect(atZeroExcess19.updatedVitals.isDead, isFalse, reason: 'Damage 19 < maxHp 20 at 0 HP must NOT cause death');
        expect(atZeroExcess19.triggeredDeath, isFalse);
      });

      test('mathematical law over full parameter grid (767,140 cases)', () {
        for (var maxHp = 1; maxHp <= 40; maxHp++) {
          for (var curHp = 0; curHp <= maxHp; curHp++) {
            for (var tempHp = 0; tempHp <= 10; tempHp++) {
              final initial = EntityVitals(
                currentHp: curHp,
                maxHp: maxHp,
                temporaryHp: tempHp,
                isDowned: curHp <= 0,
                isDead: false,
              );
              for (var dmg = 0; dmg <= 3 * maxHp; dmg++) {
                final result = resolver.resolveVitalsChange(
                  currentVitals: initial,
                  delta: -dmg,
                );
                final tempAbsorbed = min(tempHp, dmg);
                final expectedDead = (dmg - tempAbsorbed - curHp) >= maxHp;
                expect(
                  result.updatedVitals.isDead,
                  equals(expectedDead),
                  reason: 'Failed at maxHp=$maxHp, curHp=$curHp, tempHp=$tempHp, dmg=$dmg',
                );
              }
            }
          }
        }
      });
    });

    test('executes DprSimulator.runWithResolver using Dnd5eCombatResolver', () {
      const simulator = DprSimulator();
      const attack = AttackIntent(
        attackBonus: 7,
        damageExpression: '2d6+4',
      );
      const defense = TargetDefenseProfile(
        targetDefenseRating: 16,
      );

      final result = simulator.runWithResolver(
        resolver: resolver,
        attack: attack,
        defense: defense,
        iterations: 2000,
        rng: Random(42),
      );

      expect(result.iterations, equals(2000));
      expect(result.hitRate, greaterThan(0.4));
      expect(result.meanDamage, greaterThan(4.0));
      expect(result.maxDamage, greaterThanOrEqualTo(16));
    });
  });
}
