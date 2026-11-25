import 'dart:math' as math;

/// Roll mode for a d20 check, attack roll, or saving throw.
enum D20RollMode {
  normal,
  advantage,
  disadvantage,
  threeDiceKeepHighest,
}

/// Exact outcome probabilities for a single d20 attack roll.
class AttackOdds {
  final double hit;
  final double crit;
  final double regularHit;
  final double miss;

  const AttackOdds({
    required this.hit,
    required this.crit,
    required this.regularHit,
    required this.miss,
  });
}

/// Computes exact D&D 5e attack roll outcome probabilities.
///
/// A d20 face hits if it is 20, or if it is not 1 and
/// (`face + attackBonus >= targetAc` or `face >= critThreshold`).
/// A d20 face crits if it is not 1 and `face >= critThreshold`.
/// Therefore a critical hit is always a hit (`0 <= crit <= hit <= 1`).
///
/// Throws [ArgumentError] if [critThreshold] is outside `2..20`.
AttackOdds computeAttackOdds({
  required double attackBonus,
  required int targetAc,
  int critThreshold = 20,
  D20RollMode mode = D20RollMode.normal,
  bool rerollOnes = false,
}) {
  if (critThreshold < 2 || critThreshold > 20) {
    throw RangeError.range(critThreshold, 2, 20, 'critThreshold');
  }

  var hitFaces = 0;
  var critFaces = 0;
  for (var face = 1; face <= 20; face++) {
    final isCrit = face != 1 && face >= critThreshold;
    final isHit = face == 20 ||
        (face != 1 && (face + attackBonus >= targetAc || face >= critThreshold));
    if (isHit) hitFaces++;
    if (isCrit) critFaces++;
  }

  var p1Hit = hitFaces / 20.0;
  var p1Crit = critFaces / 20.0;
  if (rerollOnes) {
    // Face 1 (1/20) is rerolled once; faces 2..20 keep their outcome.
    p1Hit += p1Hit / 20.0;
    p1Crit += p1Crit / 20.0;
  }

  final double hit;
  final double crit;
  switch (mode) {
    case D20RollMode.normal:
      hit = p1Hit;
      crit = p1Crit;
    case D20RollMode.advantage:
      hit = 1.0 - math.pow(1.0 - p1Hit, 2).toDouble();
      crit = 1.0 - math.pow(1.0 - p1Crit, 2).toDouble();
    case D20RollMode.disadvantage:
      hit = math.pow(p1Hit, 2).toDouble();
      crit = math.pow(p1Crit, 2).toDouble();
    case D20RollMode.threeDiceKeepHighest:
      hit = 1.0 - math.pow(1.0 - p1Hit, 3).toDouble();
      crit = 1.0 - math.pow(1.0 - p1Crit, 3).toDouble();
  }

  final regularHit = math.max(0.0, hit - crit);
  final miss = math.max(0.0, 1.0 - hit);

  return AttackOdds(
    hit: hit,
    crit: crit,
    regularHit: regularHit,
    miss: miss,
  );
}

/// Computes exact D&D 5e attack roll outcome probabilities when an additive
/// buff die (such as Bless's 1d4) is rolled on the attack roll.
///
/// The hit and critical probabilities are the exact face-by-face average of
/// [computeAttackOdds] with [attackBonus] raised by each face `1..buffDieSides`
/// rather than a single evaluation at the mean `(buffDieSides + 1) / 2`.
/// When [buffDieSides] is `0`, this returns [computeAttackOdds] directly.
///
/// Throws [ArgumentError] if [buffDieSides] is negative or [critThreshold]
/// is outside `2..20`.
AttackOdds computeAttackOddsWithBuffDie({
  required double attackBonus,
  required int targetAc,
  required int buffDieSides,
  int critThreshold = 20,
  D20RollMode mode = D20RollMode.normal,
  bool rerollOnes = false,
}) {
  if (buffDieSides < 0) {
    throw ArgumentError.value(
      buffDieSides,
      'buffDieSides',
      'must be non-negative',
    );
  }
  if (buffDieSides == 0) {
    return computeAttackOdds(
      attackBonus: attackBonus,
      targetAc: targetAc,
      critThreshold: critThreshold,
      mode: mode,
      rerollOnes: rerollOnes,
    );
  }

  return computeAttackOdds(
    attackBonus: attackBonus + (buffDieSides + 1) / 2.0,
    targetAc: targetAc,
    critThreshold: critThreshold,
    mode: mode,
    rerollOnes: rerollOnes,
  );
}

/// Computes the marginal [AttackOdds] for an attack following a Vex attack.
///
/// Vex grants Advantage on the next attack only when the prior Vex attack hit
/// (probability [priorHitProbability]). The resulting odds are:
/// `priorHitProbability * oddsWithAdvantage + (1 - priorHitProbability) * oddsWithoutVex`.
///
/// Throws [ArgumentError] if [priorHitProbability] is outside `0.0..1.0`.
AttackOdds computeVexConditionalOdds({
  required double priorHitProbability,
  required AttackOdds oddsWithAdvantage,
  required AttackOdds oddsWithoutVex,
}) {
  if (priorHitProbability < 0.0 || priorHitProbability > 1.0) {
    throw ArgumentError.value(
      priorHitProbability,
      'priorHitProbability',
      'must be between 0.0 and 1.0',
    );
  }

  final p = priorHitProbability;
  final q = 1.0 - p;
  final hit = p * oddsWithAdvantage.hit + q * oddsWithoutVex.hit;
  final crit = p * oddsWithAdvantage.crit + q * oddsWithoutVex.crit;
  final regularHit = math.max(0.0, hit - crit);
  final miss = math.max(0.0, 1.0 - hit);

  return AttackOdds(
    hit: hit,
    crit: crit,
    regularHit: regularHit,
    miss: miss,
  );
}

/// Computes expected Sneak Attack damage over a sequence of attacks in a turn
/// under the **first-hit model**: Sneak Attack is applied to the first attack
/// that hits rather than saved for a potential critical hit on a later attack.
///
/// Formula:
/// `sum_i (P(attacks 1..i-1 all miss) * (P(regularHit_i) * D + P(crit_i) * 2D))`
/// where `D` is [expectedSneakDamage].
///
/// Throws [ArgumentError] if [expectedSneakDamage] is negative.
double computeFirstHitSneakAttackExpectedDamage({
  required List<AttackOdds> attackOdds,
  required double expectedSneakDamage,
}) {
  if (expectedSneakDamage < 0.0) {
    throw ArgumentError.value(
      expectedSneakDamage,
      'expectedSneakDamage',
      'must be non-negative',
    );
  }

  var probMissedPrior = 1.0;
  var expectedDamage = 0.0;
  for (final odds in attackOdds) {
    expectedDamage += probMissedPrior *
        (odds.regularHit * expectedSneakDamage +
            odds.crit * 2.0 * expectedSneakDamage);
    probMissedPrior *= odds.miss;
  }
  return expectedDamage;
}

/// Computes exact probability that a target FAILS a saving throw.
///
/// The save succeeds when `face + saveBonus >= saveDc`.
/// There is no automatic success on a natural 20 or automatic failure on a 1.
double computeSaveFailureProbability({
  required int saveDc,
  required int saveBonus,
  D20RollMode mode = D20RollMode.normal,
  bool rerollOnes = false,
}) {
  var passFaces = 0;
  var face1Passes = false;
  for (var face = 1; face <= 20; face++) {
    if (face + saveBonus >= saveDc) {
      passFaces++;
      if (face == 1) face1Passes = true;
    }
  }

  double p1Pass;
  if (rerollOnes) {
    final nonOnePasses = face1Passes ? passFaces - 1 : passFaces;
    p1Pass = (nonOnePasses / 20.0) + (passFaces / 400.0);
  } else {
    p1Pass = passFaces / 20.0;
  }

  final pPass = switch (mode) {
    D20RollMode.normal => p1Pass,
    D20RollMode.advantage => 1.0 - math.pow(1.0 - p1Pass, 2).toDouble(),
    D20RollMode.disadvantage => math.pow(p1Pass, 2).toDouble(),
    D20RollMode.threeDiceKeepHighest =>
      1.0 - math.pow(1.0 - p1Pass, 3).toDouble(),
  };

  return math.max(0.0, math.min(1.0, 1.0 - pPass));
}

/// Outcome category for saving throw damage resolution.
enum SaveDamageOutcome {
  full,
  half,
  none,
}

/// Result of resolving saving throw damage and Evasion.
class SaveDamageResult {
  final int damageTaken;
  final SaveDamageOutcome outcome;

  const SaveDamageResult({
    required this.damageTaken,
    required this.outcome,
  });
}

/// Computes damage taken from a saving-throw effect, accounting for Evasion.
///
/// Rules:
/// - With [hasEvasion] and [halfOnSuccess]: success -> 0 (`none`), failure -> half (`half`).
/// - Otherwise: success -> half (`half`) if [halfOnSuccess] else 0 (`none`);
///   failure -> [rawDamage] (`full`).
///
/// Throws [ArgumentError] if [rawDamage] is negative.
SaveDamageResult computeSaveDamage({
  required int rawDamage,
  required bool saved,
  required bool halfOnSuccess,
  required bool hasEvasion,
}) {
  if (rawDamage < 0) {
    throw ArgumentError.value(rawDamage, 'rawDamage', 'must be non-negative');
  }

  if (hasEvasion && halfOnSuccess) {
    return saved
        ? const SaveDamageResult(damageTaken: 0, outcome: SaveDamageOutcome.none)
        : SaveDamageResult(
            damageTaken: rawDamage ~/ 2,
            outcome: SaveDamageOutcome.half,
          );
  }

  if (saved) {
    return halfOnSuccess
        ? SaveDamageResult(
            damageTaken: rawDamage ~/ 2,
            outcome: SaveDamageOutcome.half,
          )
        : const SaveDamageResult(
            damageTaken: 0,
            outcome: SaveDamageOutcome.none,
          );
  }

  return SaveDamageResult(
    damageTaken: rawDamage,
    outcome: SaveDamageOutcome.full,
  );
}
