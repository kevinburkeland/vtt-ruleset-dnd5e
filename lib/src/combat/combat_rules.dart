import 'package:vtt_engine_core/rules/i_combat_resolver.dart';

/// Classifies a single d20 attack roll under SRD 5.1 / 5.2.1 rules:
/// - Natural roll >= [critThreshold] (default 20): always hits and crits.
/// - Natural roll == 1: always misses (critical miss).
/// - Otherwise: hits iff [totalToHit] >= [targetAc].
AttackOutcomeType classifyAttackRoll({
  required int naturalRoll,
  required int totalToHit,
  required int targetAc,
  int critThreshold = 20,
}) {
  if (naturalRoll >= critThreshold) {
    return AttackOutcomeType.criticalHit;
  }
  if (naturalRoll == 1) {
    return AttackOutcomeType.criticalMiss;
  }
  if (totalToHit >= targetAc) {
    return AttackOutcomeType.hit;
  }
  return AttackOutcomeType.miss;
}

/// Evaluates whether casting the Shield reaction (+5 AC, including against the
/// triggering attack) turns a hitting attack into a miss.
///
/// Never applies to critical hits or attacks that already missed.
bool doesShieldBlockAttack({
  required int totalToHit,
  required int targetAc,
  required bool isCriticalHit,
}) {
  if (isCriticalHit) return false;
  if (totalToHit < targetAc) return false;
  return totalToHit < targetAc + 5;
}

/// Computes a creature's saving throw DC: `8 + proficiencyBonus + abilityModifier`.
int computeSaveDc({
  required int proficiencyBonus,
  required int abilityModifier,
}) {
  return 8 + proficiencyBonus + abilityModifier;
}

/// Returns the SRD 5.1 / 5.2.1 proficiency bonus for a monster's [challengeRating]:
/// - CR 0–4 (including 1/8, 1/4, 1/2): +2
/// - CR 5–8: +3
/// - CR 9–12: +4
/// - CR 13–16: +5
/// - CR 17–20: +6
/// - CR 21–24: +7
/// - CR 25–28: +8
/// - CR 29–30: +9
///
/// Throws [ArgumentError] for `NaN`, negative CRs, or CRs above 30.
int proficiencyBonusForChallengeRating(double challengeRating) {
  if (challengeRating.isNaN || challengeRating < 0 || challengeRating > 30) {
    throw ArgumentError.value(
      challengeRating,
      'challengeRating',
      'Challenge rating must be between 0 and 30',
    );
  }
  if (challengeRating < 5) return 2;
  return 2 + ((challengeRating - 1).floor() ~/ 4);
}

final _firstChallengeRatingTokenRe = RegExp(r'(\d+)/(\d+)|(\d+(?:\.\d+)?)');

/// Reads the first number or fraction in [text] as a challenge rating value.
///
/// Accepts bare numbers (`"5"`), prefixed forms (`"CR 5"`), fractions
/// (`"1/4"`, `"CR 1/2 (100 XP)"`), and text with trailing XP or proficiency
/// notes (`"30 (155,000 XP)"`, `"CR 5 (XP 1,800; PB +3)"`, `"0 (10 XP)"`).
///
/// A fraction is `<digits>/<digits>` with a non-zero denominator; a zero
/// denominator (such as `"1/0"`) returns `null`. Returns `null` when [text]
/// holds no number. Does not clamp and does not throw.
double? parseChallengeRating(String text) {
  final match = _firstChallengeRatingTokenRe.firstMatch(text);
  if (match == null) return null;

  final numStr = match.group(1);
  final denStr = match.group(2);
  if (numStr != null && denStr != null) {
    final numerator = int.tryParse(numStr);
    final denominator = int.tryParse(denStr);
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return numerator / denominator;
  }

  final scalarStr = match.group(3);
  if (scalarStr == null) return null;
  return double.tryParse(scalarStr);
}
