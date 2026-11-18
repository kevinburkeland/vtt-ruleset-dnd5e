import 'dart:io';
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

/// Exact brute-force enumeration oracle for single-die outcome probabilities.
({double hit, double crit}) _oracleAttack1Die({
  required double attackBonus,
  required int targetAc,
  required int critThreshold,
  required bool rerollOnes,
}) {
  bool isCrit(int face) => face != 1 && face >= critThreshold;
  bool isHit(int face) =>
      face == 20 || (face != 1 && (face + attackBonus >= targetAc || face >= critThreshold));

  var hitProb = 0.0;
  var critProb = 0.0;
  for (var f1 = 1; f1 <= 20; f1++) {
    if (rerollOnes && f1 == 1) {
      for (var f2 = 1; f2 <= 20; f2++) {
        if (isHit(f2)) hitProb += 1.0 / 400.0;
        if (isCrit(f2)) critProb += 1.0 / 400.0;
      }
    } else {
      if (isHit(f1)) hitProb += 1.0 / 20.0;
      if (isCrit(f1)) critProb += 1.0 / 20.0;
    }
  }
  return (hit: hitProb, crit: critProb);
}

({double hit, double crit}) _oracleAttack({
  required double attackBonus,
  required int targetAc,
  required int critThreshold,
  required D20RollMode mode,
  required bool rerollOnes,
}) {
  final single = _oracleAttack1Die(
    attackBonus: attackBonus,
    targetAc: targetAc,
    critThreshold: critThreshold,
    rerollOnes: rerollOnes,
  );
  // Enumerate combinations of 1, 2, or 3 independent dice using exact outcome buckets:
  // M (miss: 1 - hit), R (regular hit: hit - crit), C (crit: crit).
  final pC = single.crit;
  final pR = single.hit - single.crit;
  final pM = 1.0 - single.hit;
  final buckets = [pM, pR, pC]; // 0 = miss, 1 = reg, 2 = crit

  if (mode == D20RollMode.normal) {
    return single;
  } else if (mode == D20RollMode.advantage) {
    var hit = 0.0;
    var crit = 0.0;
    for (var a = 0; a < 3; a++) {
      for (var b = 0; b < 3; b++) {
        final w = buckets[a] * buckets[b];
        final best = a > b ? a : b;
        if (best >= 1) hit += w;
        if (best == 2) crit += w;
      }
    }
    return (hit: hit, crit: crit);
  } else if (mode == D20RollMode.disadvantage) {
    var hit = 0.0;
    var crit = 0.0;
    for (var a = 0; a < 3; a++) {
      for (var b = 0; b < 3; b++) {
        final w = buckets[a] * buckets[b];
        final worst = a < b ? a : b;
        if (worst >= 1) hit += w;
        if (worst == 2) crit += w;
      }
    }
    return (hit: hit, crit: crit);
  } else {
    var hit = 0.0;
    var crit = 0.0;
    for (var a = 0; a < 3; a++) {
      for (var b = 0; b < 3; b++) {
        for (var c = 0; c < 3; c++) {
          final w = buckets[a] * buckets[b] * buckets[c];
          final best = a > b ? (a > c ? a : c) : (b > c ? b : c);
          if (best >= 1) hit += w;
          if (best == 2) crit += w;
        }
      }
    }
    return (hit: hit, crit: crit);
  }
}

double _oracleSaveFail({
  required int saveDc,
  required int saveBonus,
  required D20RollMode mode,
  required bool rerollOnes,
}) {
  var p1Pass = 0.0;
  for (var f1 = 1; f1 <= 20; f1++) {
    if (rerollOnes && f1 == 1) {
      for (var f2 = 1; f2 <= 20; f2++) {
        if (f2 + saveBonus >= saveDc) p1Pass += 1.0 / 400.0;
      }
    } else {
      if (f1 + saveBonus >= saveDc) p1Pass += 1.0 / 20.0;
    }
  }
  final pPass = switch (mode) {
    D20RollMode.normal => p1Pass,
    D20RollMode.advantage => 1.0 - (1.0 - p1Pass) * (1.0 - p1Pass),
    D20RollMode.disadvantage => p1Pass * p1Pass,
    D20RollMode.threeDiceKeepHighest =>
      1.0 - (1.0 - p1Pass) * (1.0 - p1Pass) * (1.0 - p1Pass),
  };
  return 1.0 - pPass;
}

void main() {
  group('Fix 7.1: AttackOdds Exact Oracle Law', () {
    test('rejects critThreshold outside 2..20', () {
      expect(
        () => computeAttackOdds(attackBonus: 5, targetAc: 15, critThreshold: 1),
        throwsArgumentError,
      );
      expect(
        () => computeAttackOdds(attackBonus: 5, targetAc: 15, critThreshold: 21),
        throwsArgumentError,
      );
    });

    test('examples: +5 vs AC 30 with threshold 19 and 20', () {
      final ex19 = computeAttackOdds(attackBonus: 5, targetAc: 30, critThreshold: 19);
      expect(ex19.hit, closeTo(0.10, 1e-12));
      expect(ex19.crit, closeTo(0.10, 1e-12));
      expect(ex19.regularHit, closeTo(0.0, 1e-12));

      final ex20 = computeAttackOdds(attackBonus: 5, targetAc: 30, critThreshold: 20);
      expect(ex20.hit, closeTo(0.05, 1e-12));
      expect(ex20.crit, closeTo(0.05, 1e-12));
      expect(ex20.regularHit, closeTo(0.0, 1e-12));
    });

    test('matches exact enumeration oracle across full parameter grid', () {
      final bonuses = <double>[
        for (var b = -5; b <= 20; b++) b.toDouble(),
        2.5,
        -1.5,
        7.5,
      ];
      var cases = 0;

      for (final bonus in bonuses) {
        for (var ac = 1; ac <= 35; ac++) {
          for (var threshold = 2; threshold <= 20; threshold++) {
            for (final mode in D20RollMode.values) {
              for (final reroll in const [false, true]) {
                cases++;
                final got = computeAttackOdds(
                  attackBonus: bonus,
                  targetAc: ac,
                  critThreshold: threshold,
                  mode: mode,
                  rerollOnes: reroll,
                );
                final exp = _oracleAttack(
                  attackBonus: bonus,
                  targetAc: ac,
                  critThreshold: threshold,
                  mode: mode,
                  rerollOnes: reroll,
                );
                expect(got.hit, closeTo(exp.hit, 1e-12),
                    reason: 'hit mismatch: bonus=$bonus ac=$ac thr=$threshold mode=$mode reroll=$reroll');
                expect(got.crit, closeTo(exp.crit, 1e-12),
                    reason: 'crit mismatch: bonus=$bonus ac=$ac thr=$threshold mode=$mode reroll=$reroll');
                expect(got.crit, lessThanOrEqualTo(got.hit + 1e-12));
                expect(got.hit, lessThanOrEqualTo(1.0 + 1e-12));
                expect(got.crit, greaterThanOrEqualTo(0.0));
                expect(got.regularHit + got.crit + got.miss, closeTo(1.0, 1e-12));
              }
            }
          }
        }
      }
      stdout.writeln('Fix 7.1 AttackOdds oracle law verified $cases cases.');
    });
  });

  group('Fix 7.2: SaveFailureProbability Exact Oracle Law', () {
    test('examples: DC 30 +0 gives 1.0, DC 5 +10 gives 0.0', () {
      expect(computeSaveFailureProbability(saveDc: 30, saveBonus: 0), closeTo(1.0, 1e-12));
      expect(computeSaveFailureProbability(saveDc: 5, saveBonus: 10), closeTo(0.0, 1e-12));
    });

    test('matches exact enumeration oracle over DC 1..35, bonus -10..20, all modes', () {
      var cases = 0;
      for (var dc = 1; dc <= 35; dc++) {
        for (var bonus = -10; bonus <= 20; bonus++) {
          for (final mode in D20RollMode.values) {
            for (final reroll in const [false, true]) {
              cases++;
              final got = computeSaveFailureProbability(
                saveDc: dc,
                saveBonus: bonus,
                mode: mode,
                rerollOnes: reroll,
              );
              final exp = _oracleSaveFail(
                saveDc: dc,
                saveBonus: bonus,
                mode: mode,
                rerollOnes: reroll,
              );
              expect(got, closeTo(exp, 1e-12),
                  reason: 'save fail mismatch: dc=$dc bonus=$bonus mode=$mode reroll=$reroll');
            }
          }
        }
      }
      stdout.writeln('Fix 7.2 SaveFailureProbability oracle law verified $cases cases.');
    });
  });

  group('Fix 7.3: SaveDamage & Evasion Exact Law', () {
    test('rejects negative rawDamage', () {
      expect(
        () => computeSaveDamage(rawDamage: -1, saved: false, halfOnSuccess: true, hasEvasion: false),
        throwsArgumentError,
      );
    });

    test('matches exact Evasion and save damage table over raw 0..500 and all 8 flag combinations', () {
      var cases = 0;
      for (var raw = 0; raw <= 500; raw++) {
        for (final saved in const [false, true]) {
          for (final halfOnSuccess in const [false, true]) {
            for (final hasEvasion in const [false, true]) {
              cases++;
              final res = computeSaveDamage(
                rawDamage: raw,
                saved: saved,
                halfOnSuccess: halfOnSuccess,
                hasEvasion: hasEvasion,
              );
              expect(res.damageTaken, greaterThanOrEqualTo(0));
              expect(res.damageTaken, lessThanOrEqualTo(raw));

              if (hasEvasion && halfOnSuccess) {
                if (saved) {
                  expect(res.outcome, equals(SaveDamageOutcome.none));
                  expect(res.damageTaken, equals(0));
                } else {
                  expect(res.outcome, equals(SaveDamageOutcome.half));
                  expect(res.damageTaken, equals(raw ~/ 2));
                }
              } else if (saved) {
                if (halfOnSuccess) {
                  expect(res.outcome, equals(SaveDamageOutcome.half));
                  expect(res.damageTaken, equals(raw ~/ 2));
                } else {
                  expect(res.outcome, equals(SaveDamageOutcome.none));
                  expect(res.damageTaken, equals(0));
                }
              } else {
                expect(res.outcome, equals(SaveDamageOutcome.full));
                expect(res.damageTaken, equals(raw));
              }
            }
          }
        }
      }
      stdout.writeln('Fix 7.3 SaveDamage law verified $cases cases.');
    });
  });
}
