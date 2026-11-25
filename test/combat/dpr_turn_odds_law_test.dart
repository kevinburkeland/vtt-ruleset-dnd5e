import 'dart:io';
import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('Fix 4.3 Guard Laws (computeAttackOdds)', () {
    test('for every single attack on the grid, crit <= hit and hit + miss = 1',
        () {
      var cases = 0;
      for (var bonus = -5; bonus <= 15; bonus++) {
        for (var ac = 5; ac <= 30; ac++) {
          for (final critThreshold in const [18, 19, 20]) {
            for (final mode in D20RollMode.values) {
              for (final rerollOnes in const [false, true]) {
                cases++;
                final odds = computeAttackOdds(
                  attackBonus: bonus.toDouble(),
                  targetAc: ac,
                  critThreshold: critThreshold,
                  mode: mode,
                  rerollOnes: rerollOnes,
                );
                expect(
                  odds.crit,
                  lessThanOrEqualTo(odds.hit + 1e-12),
                  reason:
                      'crit > hit for bonus=$bonus ac=$ac thr=$critThreshold mode=$mode reroll=$rerollOnes',
                );
                expect(
                  odds.hit + odds.miss,
                  closeTo(1.0, 1e-12),
                  reason:
                      'hit + miss != 1 for bonus=$bonus ac=$ac thr=$critThreshold mode=$mode reroll=$rerollOnes',
                );
              }
            }
          }
        }
      }
      stdout.writeln('Guard law verified $cases single-attack cases.');
    });
  });

  group('Fix 4.3 Buff-Die Attack Odds Law', () {
    test('rejects negative buffDieSides and matches computeAttackOdds at 0',
        () {
      expect(
        () => computeAttackOddsWithBuffDie(
          attackBonus: 5,
          targetAc: 15,
          buffDieSides: -4,
        ),
        throwsArgumentError,
      );
      final plain = computeAttackOdds(attackBonus: 5, targetAc: 15);
      final zero = computeAttackOddsWithBuffDie(
        attackBonus: 5,
        targetAc: 15,
        buffDieSides: 0,
      );
      expect(zero.hit, closeTo(plain.hit, 1e-12));
      expect(zero.crit, closeTo(plain.crit, 1e-12));
      expect(zero.regularHit, closeTo(plain.regularHit, 1e-12));
      expect(zero.miss, closeTo(plain.miss, 1e-12));
    });

    test('fixed case: +5 vs AC 15 with Bless (1d4) is 0.675 (old average 0.65)',
        () {
      final oldMeanBonus = computeAttackOdds(
        attackBonus: 5 + 2.5,
        targetAc: 15,
        critThreshold: 20,
        mode: D20RollMode.normal,
        rerollOnes: false,
      );
      final exactBless = computeAttackOddsWithBuffDie(
        attackBonus: 5,
        targetAc: 15,
        buffDieSides: 4,
        critThreshold: 20,
        mode: D20RollMode.normal,
        rerollOnes: false,
      );
      expect(oldMeanBonus.hit, closeTo(0.65, 1e-12));
      expect(exactBless.hit, closeTo(0.675, 1e-12));
      expect(exactBless.crit, closeTo(0.05, 1e-12));
      expect(exactBless.regularHit, closeTo(0.625, 1e-12));
      expect(exactBless.miss, closeTo(0.325, 1e-12));
    });

    test(
        'matches face-by-face average, never lowers hit, preserves crit over grid',
        () {
      var cases = 0;
      const modes = [
        D20RollMode.normal,
        D20RollMode.advantage,
        D20RollMode.disadvantage,
      ];
      for (var bonus = -5; bonus <= 15; bonus++) {
        for (var ac = 5; ac <= 30; ac++) {
          for (final sides in const [4, 6, 8]) {
            for (final mode in modes) {
              cases++;
              final base = computeAttackOdds(
                attackBonus: bonus.toDouble(),
                targetAc: ac,
                mode: mode,
              );
              final got = computeAttackOddsWithBuffDie(
                attackBonus: bonus.toDouble(),
                targetAc: ac,
                buffDieSides: sides,
                mode: mode,
              );

              var avgHit = 0.0;
              var avgCrit = 0.0;
              for (var face = 1; face <= sides; face++) {
                final fOdds = computeAttackOdds(
                  attackBonus: (bonus + face).toDouble(),
                  targetAc: ac,
                  mode: mode,
                );
                avgHit += fOdds.hit;
                avgCrit += fOdds.crit;
              }
              avgHit /= sides;
              avgCrit /= sides;

              expect(got.hit, closeTo(avgHit, 1e-12));
              expect(got.crit, closeTo(avgCrit, 1e-12));
              expect(got.hit, greaterThanOrEqualTo(base.hit - 1e-12));
              expect(got.crit, closeTo(base.crit, 1e-12));
              expect(got.crit, lessThanOrEqualTo(got.hit + 1e-12));
              expect(got.hit + got.miss, closeTo(1.0, 1e-12));
            }
          }
        }
      }
      stdout.writeln('Buff-die law verified $cases cases.');
    });
  });

  group('Fix 4.3 Vex Conditional Odds Law', () {
    test('rejects priorHitProbability outside 0..1', () {
      const dummy = AttackOdds(hit: 0.5, crit: 0.05, regularHit: 0.45, miss: 0.5);
      expect(
        () => computeVexConditionalOdds(
          priorHitProbability: -0.01,
          oddsWithAdvantage: dummy,
          oddsWithoutVex: dummy,
        ),
        throwsArgumentError,
      );
      expect(
        () => computeVexConditionalOdds(
          priorHitProbability: 1.01,
          oddsWithAdvantage: dummy,
          oddsWithoutVex: dummy,
        ),
        throwsArgumentError,
      );
    });

    test('lies between no-Vex and always-advantage and matches exact formula',
        () {
      var cases = 0;
      const modes = [
        D20RollMode.normal,
        D20RollMode.advantage,
        D20RollMode.disadvantage,
      ];
      for (var bonus = -5; bonus <= 15; bonus++) {
        for (var ac = 5; ac <= 30; ac++) {
          for (final mode in modes) {
            final noVex = computeAttackOdds(
              attackBonus: bonus.toDouble(),
              targetAc: ac,
              mode: mode,
            );
            final withAdv = computeAttackOdds(
              attackBonus: bonus.toDouble(),
              targetAc: ac,
              mode: D20RollMode.advantage,
            );
            final p = noVex.hit;
            cases++;
            final got = computeVexConditionalOdds(
              priorHitProbability: p,
              oddsWithAdvantage: withAdv,
              oddsWithoutVex: noVex,
            );

            final expHit = p * withAdv.hit + (1.0 - p) * noVex.hit;
            final expCrit = p * withAdv.crit + (1.0 - p) * noVex.crit;
            final loHit = math.min(noVex.hit, withAdv.hit);
            final hiHit = math.max(noVex.hit, withAdv.hit);
            final loCrit = math.min(noVex.crit, withAdv.crit);
            final hiCrit = math.max(noVex.crit, withAdv.crit);

            expect(got.hit, closeTo(expHit, 1e-12));
            expect(got.crit, closeTo(expCrit, 1e-12));
            expect(got.hit, greaterThanOrEqualTo(loHit - 1e-12));
            expect(got.hit, lessThanOrEqualTo(hiHit + 1e-12));
            expect(got.crit, greaterThanOrEqualTo(loCrit - 1e-12));
            expect(got.crit, lessThanOrEqualTo(hiCrit + 1e-12));
            expect(got.crit, lessThanOrEqualTo(got.hit + 1e-12));
            expect(got.hit + got.miss, closeTo(1.0, 1e-12));
          }
        }
      }
      stdout.writeln('Vex conditional odds law verified $cases cases.');
    });
  });

  group('Fix 4.3 Sneak Attack First-Hit Law', () {
    test('rejects negative expectedSneakDamage and handles empty attack list',
        () {
      expect(
        () => computeFirstHitSneakAttackExpectedDamage(
          attackOdds: const [],
          expectedSneakDamage: -1.0,
        ),
        throwsArgumentError,
      );
      expect(
        computeFirstHitSneakAttackExpectedDamage(
          attackOdds: const [],
          expectedSneakDamage: 10.5,
        ),
        equals(0.0),
      );
    });

    test('matches exact first-hit formula and is strictly below old overcount on multi-attack',
        () {
      final atk1 = computeAttackOdds(attackBonus: 7, targetAc: 15);
      final atk2 = computeAttackOdds(attackBonus: 7, targetAc: 15);
      const sneakEv = 10.5; // 3d6

      final got = computeFirstHitSneakAttackExpectedDamage(
        attackOdds: [atk1, atk2],
        expectedSneakDamage: sneakEv,
      );

      final expected = (atk1.regularHit * sneakEv + atk1.crit * 2 * sneakEv) +
          atk1.miss * (atk2.regularHit * sneakEv + atk2.crit * 2 * sneakEv);
      expect(got, closeTo(expected, 1e-12));

      // Old formula: (P(>=1 hit) + P(>=1 crit)) * D overcounts when attack 1 hits normally and attack 2 crits.
      final pAtLeastOneHit = 1.0 - atk1.miss * atk2.miss;
      final pAtLeastOneCrit = 1.0 - (1.0 - atk1.crit) * (1.0 - atk2.crit);
      final oldOvercount = (pAtLeastOneHit + pAtLeastOneCrit) * sneakEv;
      expect(got, lessThan(oldOvercount));
    });
  });

  group('Fix 4.3 Seeded Monte Carlo Cross-Check (60 turns x 200,000 trials)', () {
    test('closed-form turn damage matches 200,000-trial simulation within max(0.5%, 4 SE)',
        () {
      const turnCount = 60;
      const trialsPerTurn = 200000;
      final gen = math.Random(16043);
      var maxRelDiff = 0.0;
      var maxZScore = 0.0;

      for (var t = 0; t < turnCount; t++) {
        final numAttacks = 1 + gen.nextInt(4); // 1..4 attacks
        final targetAc = 10 + gen.nextInt(13); // 10..22
        final baseMode = const [
          D20RollMode.normal,
          D20RollMode.advantage,
          D20RollMode.disadvantage,
        ][gen.nextInt(3)];
        final rerollOnes = gen.nextBool();
        final sneakDice = gen.nextBool() ? (1 + gen.nextInt(5)) : 0; // 0 or 1..5 d6
        final sneakEv = sneakDice * 3.5;

        final bonuses = <int>[];
        final buffSides = <int>[];
        final isVex = <bool>[];
        final critThresholds = <int>[];
        final weaponDieSides = <int>[];
        final flatDamages = <int>[];

        for (var a = 0; a < numAttacks; a++) {
          bonuses.add(2 + gen.nextInt(10)); // +2..+11
          buffSides.add(const [0, 0, 4, 6, 8][gen.nextInt(5)]);
          isVex.add(gen.nextBool());
          critThresholds.add(gen.nextInt(4) == 0 ? 19 : 20);
          weaponDieSides.add(const [6, 8, 10][gen.nextInt(3)]);
          flatDamages.add(3 + gen.nextInt(3)); // +3..+5
        }

        // Closed-form expected turn damage using ruleset functions.
        var closedFormTotal = 0.0;
        var priorVexHitProb = 0.0;
        final baseOddsList = <AttackOdds>[];

        for (var a = 0; a < numAttacks; a++) {
          final baseOdds = computeAttackOddsWithBuffDie(
            attackBonus: bonuses[a].toDouble(),
            targetAc: targetAc,
            buffDieSides: buffSides[a],
            critThreshold: critThresholds[a],
            mode: baseMode,
            rerollOnes: rerollOnes,
          );
          baseOddsList.add(baseOdds);

          final AttackOdds effectiveOdds;
          if (priorVexHitProb > 0.0 && baseMode == D20RollMode.normal) {
            final advOdds = computeAttackOddsWithBuffDie(
              attackBonus: bonuses[a].toDouble(),
              targetAc: targetAc,
              buffDieSides: buffSides[a],
              critThreshold: critThresholds[a],
              mode: D20RollMode.advantage,
              rerollOnes: rerollOnes,
            );
            effectiveOdds = computeVexConditionalOdds(
              priorHitProbability: priorVexHitProb,
              oddsWithAdvantage: advOdds,
              oddsWithoutVex: baseOdds,
            );
          } else {
            effectiveOdds = baseOdds;
          }

          final dieEv = (weaponDieSides[a] + 1) / 2.0;
          final hitDmg = dieEv + flatDamages[a];
          final critDmg = 2.0 * dieEv + flatDamages[a];
          closedFormTotal +=
              effectiveOdds.regularHit * hitDmg + effectiveOdds.crit * critDmg;

          if (isVex[a] && baseMode == D20RollMode.normal) {
            priorVexHitProb = effectiveOdds.hit;
          } else {
            priorVexHitProb = 0.0;
          }
        }

        // Conditioned on attacks 1..i-1 all missing, no prior attack triggered Vex,
        // so Sneak Attack on the first hit uses the base (non-Vex) odds.
        if (sneakDice > 0) {
          closedFormTotal += computeFirstHitSneakAttackExpectedDamage(
            attackOdds: baseOddsList,
            expectedSneakDamage: sneakEv,
          );
        }

        // Seeded Monte Carlo simulation of trialsPerTurn turns.
        final simRng = math.Random(100000 + t);
        var sum = 0.0;
        var sumSq = 0.0;

        int rollD20(D20RollMode mode) {
          int single() {
            var r = simRng.nextInt(20) + 1;
            if (rerollOnes && r == 1) {
              r = simRng.nextInt(20) + 1;
            }
            return r;
          }

          return switch (mode) {
            D20RollMode.normal => single(),
            D20RollMode.advantage => math.max(single(), single()),
            D20RollMode.disadvantage => math.min(single(), single()),
            D20RollMode.threeDiceKeepHighest =>
              math.max(single(), math.max(single(), single())),
          };
        }

        for (var trial = 0; trial < trialsPerTurn; trial++) {
          var turnDmg = 0.0;
          var vexActive = false;
          var sneakUsed = false;

          for (var a = 0; a < numAttacks; a++) {
            final mode = (vexActive && baseMode == D20RollMode.normal)
                ? D20RollMode.advantage
                : baseMode;
            final face = rollD20(mode);
            final buff = buffSides[a] > 0 ? (simRng.nextInt(buffSides[a]) + 1) : 0;
            final isCrit = face != 1 && face >= critThresholds[a];
            final isHit = face == 20 ||
                (face != 1 &&
                    (face + bonuses[a] + buff >= targetAc ||
                        face >= critThresholds[a]));

            if (isHit) {
              final die1 = simRng.nextInt(weaponDieSides[a]) + 1;
              final die2 = isCrit ? (simRng.nextInt(weaponDieSides[a]) + 1) : 0;
              turnDmg += die1 + die2 + flatDamages[a];

              if (sneakDice > 0 && !sneakUsed) {
                sneakUsed = true;
                final rolls = isCrit ? sneakDice * 2 : sneakDice;
                for (var s = 0; s < rolls; s++) {
                  turnDmg += simRng.nextInt(6) + 1;
                }
              }
              vexActive = isVex[a] && baseMode == D20RollMode.normal;
            } else {
              vexActive = false;
            }
          }

          sum += turnDmg;
          sumSq += turnDmg * turnDmg;
        }

        final mean = sum / trialsPerTurn;
        final variance = math.max(0.0, (sumSq / trialsPerTurn) - mean * mean);
        final se = math.sqrt(variance / trialsPerTurn);
        final tol = math.max(0.005 * closedFormTotal, 4.0 * se);
        final diff = (closedFormTotal - mean).abs();
        final rel = closedFormTotal > 0 ? diff / closedFormTotal : 0.0;
        final z = se > 0 ? diff / se : 0.0;
        if (rel > maxRelDiff) maxRelDiff = rel;
        if (z > maxZScore) maxZScore = z;

        expect(
          diff,
          lessThanOrEqualTo(tol),
          reason:
              'Turn $t mismatch: closed=$closedFormTotal sim=$mean diff=$diff tol=$tol (0.5%=${0.005 * closedFormTotal}, 4SE=${4.0 * se})',
        );
      }

      stdout.writeln(
        'Monte Carlo cross-check passed: $turnCount turns x $trialsPerTurn trials; '
        'maxRelDiff=${(maxRelDiff * 100).toStringAsFixed(4)}%, maxZ=${maxZScore.toStringAsFixed(2)} SE.',
      );
    });
  });
}
