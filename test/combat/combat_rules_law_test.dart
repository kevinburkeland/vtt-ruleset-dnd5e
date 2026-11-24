import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

const List<String> _srdDamageTypes = <String>[
  'acid',
  'bludgeoning',
  'cold',
  'fire',
  'force',
  'lightning',
  'necrotic',
  'piercing',
  'poison',
  'psychic',
  'radiant',
  'slashing',
  'thunder',
];

const List<String> _qualifiers = <String>[
  '',
  ' from nonmagical attacks',
  ' from nonmagical attacks that aren\'t silvered',
  ' from nonmagical attacks not made with adamantine weapons',
  ' (from stoneskin)',
];

const List<String> _separators = <String>[', ', '; ', ' and ', ', and '];

String _formatSubset(Random rng, List<String> types) {
  if (types.isEmpty) return '';
  final shuffled = List<String>.from(types)..shuffle(rng);
  final buf = StringBuffer();
  for (var i = 0; i < shuffled.length; i++) {
    var token = shuffled[i];
    if (rng.nextBool()) {
      token = token[0].toUpperCase() + token.substring(1);
    } else if (rng.nextInt(4) == 0) {
      token = token.toUpperCase();
    }
    if (i > 0) {
      buf.write(_separators[rng.nextInt(_separators.length)]);
    }
    buf.write(token);
  }
  buf.write(_qualifiers[rng.nextInt(_qualifiers.length)]);
  return buf.toString();
}

void main() {
  group('Fix 5.1: DamageDefenses.fromStatBlockText laws', () {
    test('550 seeded generated stat-block texts preserve exact sets, case/order invariance, and all semantics',
        () {
      final rng = Random(150501);
      for (var seed = 0; seed < 550; seed++) {
        final immSet = <String>{
          for (final t in _srdDamageTypes)
            if (rng.nextInt(6) == 0) t,
        };
        final resSet = <String>{
          for (final t in _srdDamageTypes)
            if (rng.nextInt(5) == 0) t,
        };
        final vulSet = <String>{
          for (final t in _srdDamageTypes)
            if (rng.nextInt(8) == 0) t,
        };
        final immAll = rng.nextInt(15) == 0;
        final resAll = rng.nextInt(15) == 0;
        final vulAll = rng.nextInt(15) == 0;

        final immTokens = <String>[...immSet, if (immAll) 'all'];
        final resTokens = <String>[...resSet, if (resAll) 'all'];
        final vulTokens = <String>[...vulSet, if (vulAll) 'all'];

        final text1 = DamageDefenses.fromStatBlockText(
          immunities: _formatSubset(rng, immTokens),
          resistances: _formatSubset(rng, resTokens),
          vulnerabilities: _formatSubset(rng, vulTokens),
        );
        final text2 = DamageDefenses.fromStatBlockText(
          immunities: _formatSubset(rng, immTokens.reversed.toList()),
          resistances: _formatSubset(rng, resTokens.reversed.toList()),
          vulnerabilities: _formatSubset(rng, vulTokens.reversed.toList()),
        );

        for (final t in _srdDamageTypes) {
          final expImm = immAll || immSet.contains(t);
          final expRes = resAll || resSet.contains(t);
          final expVul = vulSet.contains(t); // 'all' does NOT grant vulnerability

          expect(text1.isImmune(t), equals(expImm),
              reason: 'seed=$seed type=$t immune');
          expect(text1.isResistant(t), equals(expRes),
              reason: 'seed=$seed type=$t resistant');
          expect(text1.isVulnerable(t), equals(expVul),
              reason: 'seed=$seed type=$t vulnerable');

          // Order and case invariance.
          expect(text2.isImmune(t.toUpperCase()), equals(expImm));
          expect(text2.isResistant(t.toUpperCase()), equals(expRes));
          expect(text2.isVulnerable(t.toUpperCase()), equals(expVul));
        }

        // Empty string and unknown word 'zzz' never match by substring.
        expect(text1.isImmune(''), isFalse, reason: 'seed=$seed empty immune');
        expect(text1.isResistant(''), isFalse, reason: 'seed=$seed empty resistant');
        expect(text1.isVulnerable(''), isFalse, reason: 'seed=$seed empty vulnerable');
        expect(text1.isImmune('zzz'), equals(immAll),
            reason: 'seed=$seed zzz immune (only if all)');
        expect(text1.isResistant('zzz'), equals(resAll),
            reason: 'seed=$seed zzz resistant (only if all)');
        expect(text1.isVulnerable('zzz'), isFalse,
            reason: 'seed=$seed zzz vulnerable');
      }
    });

    test('fixed cases: empty string and unknown word zzz never match by substring',
        () {
      final def = DamageDefenses.fromStatBlockText(
        immunities: 'fire, poison',
        resistances: 'bludgeoning, piercing, and slashing from nonmagical attacks',
        vulnerabilities: 'cold',
      );
      expect(def.isImmune(''), isFalse);
      expect(def.isResistant(''), isFalse);
      expect(def.isVulnerable(''), isFalse);
      expect(def.isImmune('zzz'), isFalse);
      expect(def.isResistant('zzz'), isFalse);
      expect(def.isVulnerable('zzz'), isFalse);
      expect(def.isResistant('bludgeoning'), isTrue);
      expect(def.isResistant('piercing'), isTrue);
      expect(def.isResistant('slashing'), isTrue);

      final exactZzz = DamageDefenses.fromStatBlockText(immunities: 'zzz');
      expect(exactZzz.isImmune('zzz'), isTrue);
      expect(exactZzz.isImmune('zz'), isFalse);

      final spacedNonMagical = DamageDefenses.fromStatBlockText(
        resistances:
            'damage from spells; non magical bludgeoning, piercing, and slashing (from stoneskin)',
      );
      expect(spacedNonMagical.isResistant('bludgeoning'), isTrue);
      expect(spacedNonMagical.isResistant('piercing'), isTrue);
      expect(spacedNonMagical.isResistant('slashing'), isTrue);
      expect(spacedNonMagical.isResistant('fire'), isFalse);
    });
  });

  group('Fix 5.2: Attack roll classification and Shield reaction laws', () {
    test('exhaustive attack roll classification over nat 1..20, total -5..40, AC 5..30, threshold 18..20',
        () {
      for (var threshold = 18; threshold <= 20; threshold++) {
        for (var nat = 1; nat <= 20; nat++) {
          for (var total = -5; total <= 40; total++) {
            bool? prevIsHit;
            for (var ac = 5; ac <= 30; ac++) {
              final outcome = classifyAttackRoll(
                naturalRoll: nat,
                totalToHit: total,
                targetAc: ac,
                critThreshold: threshold,
              );

              final AttackOutcomeType expected;
              if (nat >= threshold) {
                expected = AttackOutcomeType.criticalHit;
              } else if (nat == 1) {
                expected = AttackOutcomeType.criticalMiss;
              } else if (total >= ac) {
                expected = AttackOutcomeType.hit;
              } else {
                expected = AttackOutcomeType.miss;
              }

              expect(
                outcome,
                equals(expected),
                reason:
                    'nat=$nat total=$total ac=$ac threshold=$threshold -> $outcome (expected $expected)',
              );

              final isHit = outcome == AttackOutcomeType.hit ||
                  outcome == AttackOutcomeType.criticalHit;
              if (nat == 1) {
                expect(isHit, isFalse,
                    reason: 'nat 1 must never hit (total=$total ac=$ac)');
              }
              if (nat >= threshold) {
                expect(outcome, equals(AttackOutcomeType.criticalHit),
                    reason: 'nat=$nat >= threshold=$threshold must crit');
              }
              if (prevIsHit == false) {
                expect(isHit, isFalse,
                    reason: 'raising AC to $ac must never turn miss into hit');
              }
              prevIsHit = isHit;
            }
          }
        }
      }
    });

    test('exhaustive Shield reaction law: never blocks crit or miss, blocks hit iff total < AC + 5',
        () {
      for (var total = -5; total <= 40; total++) {
        for (var ac = 5; ac <= 30; ac++) {
          // Critical hits are never blocked by Shield.
          expect(
            doesShieldBlockAttack(
              totalToHit: total,
              targetAc: ac,
              isCriticalHit: true,
            ),
            isFalse,
            reason: 'Shield must never block a crit (total=$total ac=$ac)',
          );

          // Non-critical rolls: blocks iff it was a hit (total >= ac) and total < ac + 5.
          final expectedBlock = total >= ac && total < ac + 5;
          expect(
            doesShieldBlockAttack(
              totalToHit: total,
              targetAc: ac,
              isCriticalHit: false,
            ),
            equals(expectedBlock),
            reason: 'Shield (total=$total ac=$ac non-crit) expected $expectedBlock',
          );
        }
      }
    });
  });

  group('Fix 5.3: Save DC formula law', () {
    test('computeSaveDc equals 8 + pb + mod and rises by 1 with either input',
        () {
      for (var pb = 0; pb <= 12; pb++) {
        for (var mod = -5; mod <= 15; mod++) {
          final dc = computeSaveDc(proficiencyBonus: pb, abilityModifier: mod);
          expect(dc, equals(8 + pb + mod));
          expect(
            computeSaveDc(proficiencyBonus: pb + 1, abilityModifier: mod),
            equals(dc + 1),
          );
          expect(
            computeSaveDc(proficiencyBonus: pb, abilityModifier: mod + 1),
            equals(dc + 1),
          );
        }
      }
    });
  });

  group('Fix 5.4: SRD monster proficiency by CR law', () {
    test('every SRD CR from 0..30 (including 1/8, 1/4, 1/2) matches SRD table, is monotonic, and steps at exact CRs',
        () {
      final expectedTable = <double, int>{
        0: 2,
        0.125: 2,
        0.25: 2,
        0.5: 2,
        1: 2,
        2: 2,
        3: 2,
        4: 2,
        5: 3,
        6: 3,
        7: 3,
        8: 3,
        9: 4,
        10: 4,
        11: 4,
        12: 4,
        13: 5,
        14: 5,
        15: 5,
        16: 5,
        17: 6,
        18: 6,
        19: 6,
        20: 6,
        21: 7,
        22: 7,
        23: 7,
        24: 7,
        25: 8,
        26: 8,
        27: 8,
        28: 8,
        29: 9,
        30: 9,
      };
      final riseCrs = <double>{5, 9, 13, 17, 21, 25, 29};

      int? prev;
      for (final entry in expectedTable.entries) {
        final cr = entry.key;
        final expectedPb = entry.value;
        final actual = proficiencyBonusForChallengeRating(cr);
        expect(actual, equals(expectedPb), reason: 'CR $cr expected +$expectedPb, got +$actual');
        if (prev != null) {
          expect(actual, greaterThanOrEqualTo(prev), reason: 'CR $cr dropped below $prev');
          if (riseCrs.contains(cr)) {
            expect(actual, equals(prev + 1), reason: 'CR $cr must rise by 1');
          } else {
            expect(actual, equals(prev), reason: 'CR $cr must stay flat');
          }
        }
        prev = actual;
      }

      // Invalid CRs throw ArgumentError naming the value.
      for (final bad in const [-1.0, -0.25, 30.5, 31.0, double.nan]) {
        expect(
          () => proficiencyBonusForChallengeRating(bad),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              contains(bad.toString()),
            ),
          ),
          reason: 'Invalid CR $bad must throw ArgumentError naming the value',
        );
      }
    });
  });
}
