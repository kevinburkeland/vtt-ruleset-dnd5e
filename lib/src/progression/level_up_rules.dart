import 'dart:math' as math;
import '../models/character_models.dart';
import '../rules/ruleset_edition.dart';

/// Computes the capped per-ability bonus deltas to add for a pending Ability
/// Score Improvement ([increases]), enforcing each ability's maximum
/// (default SRD maximum 20, or per-ability override in [maximumScoreOverrides]).
///
/// Existing scores already above the maximum are left unchanged (delta 0).
/// Throws [ArgumentError] if any increase in [increases] is negative.
AbilityScores computeEffectiveAsiBonusDelta({
  required AbilityScores currentScores,
  required Map<AbilityType, int> increases,
  int maximumScore = 20,
  Map<AbilityType, int>? maximumScoreOverrides,
}) {
  var dStr = 0;
  var dDex = 0;
  var dCon = 0;
  var dInt = 0;
  var dWis = 0;
  var dCha = 0;

  for (final entry in increases.entries) {
    final ability = entry.key;
    final bonus = entry.value;
    if (bonus < 0) {
      throw ArgumentError.value(
        bonus,
        'increases[$ability]',
        'must be non-negative',
      );
    }
    final current = currentScores.getScore(ability);
    final maxAllowed = maximumScoreOverrides?[ability] ?? maximumScore;
    final effective = math.max(0, math.min(bonus, maxAllowed - current));
    switch (ability) {
      case AbilityType.strength:
        dStr += effective;
      case AbilityType.dexterity:
        dDex += effective;
      case AbilityType.constitution:
        dCon += effective;
      case AbilityType.intelligence:
        dInt += effective;
      case AbilityType.wisdom:
        dWis += effective;
      case AbilityType.charisma:
        dCha += effective;
    }
  }

  return AbilityScores(
    strength: dStr,
    dexterity: dDex,
    constitution: dCon,
    intelligence: dInt,
    wisdom: dWis,
    charisma: dCha,
  );
}

/// Returns the resulting [AbilityScores] after applying [increases] to
/// [currentScores], capped at [maximumScore] (default 20) or any per-ability
/// entry in [maximumScoreOverrides].
AbilityScores applyAbilityScoreIncreases({
  required AbilityScores currentScores,
  required Map<AbilityType, int> increases,
  int maximumScore = 20,
  Map<AbilityType, int>? maximumScoreOverrides,
}) {
  return AbilityScores(
    strength: currentScores.strength + (increases[AbilityType.strength] ?? 0),
    dexterity:
        currentScores.dexterity + (increases[AbilityType.dexterity] ?? 0),
    constitution: currentScores.constitution +
        (increases[AbilityType.constitution] ?? 0),
    intelligence: currentScores.intelligence +
        (increases[AbilityType.intelligence] ?? 0),
    wisdom: currentScores.wisdom + (increases[AbilityType.wisdom] ?? 0),
    charisma: currentScores.charisma + (increases[AbilityType.charisma] ?? 0),
  );
}

int _lookupFixedBonus(Map<String, int> fixed, AbilityType ab) {
  final full = ab.name.toLowerCase();
  final short = ab.shortName.toLowerCase();
  return fixed[full] ?? fixed[short] ?? 0;
}

/// Computes character-creation origin ability score bonuses for [edition]:
/// - 2014: fixed species/subrace bonuses ([fixedBonuses2014]) plus
///   [flexibleBonusValue2014] to up to [flexibleChoiceCount2014] distinct
///   abilities from [flexibleChoices2014].
/// - 2024: background `+1/+1/+1` when [backgroundTriplePlusOne2024] is
///   non-empty (up to 3 distinct abilities), otherwise `+2` to
///   [backgroundPrimary2024] and `+1` to [backgroundSecondary2024].
AbilityScores computeOriginAbilityBonuses({
  required RulesetEdition edition,
  Map<String, int> fixedBonuses2014 = const {},
  int flexibleChoiceCount2014 = 0,
  int flexibleBonusValue2014 = 0,
  Iterable<AbilityType> flexibleChoices2014 = const [],
  AbilityType? backgroundPrimary2024,
  AbilityType? backgroundSecondary2024,
  Iterable<AbilityType> backgroundTriplePlusOne2024 = const [],
}) {
  if (edition == RulesetEdition.v2014) {
    final activeFlex = flexibleChoiceCount2014 > 0
        ? flexibleChoices2014.toSet().take(flexibleChoiceCount2014).toSet()
        : const <AbilityType>{};
    int forAb(AbilityType ab) =>
        _lookupFixedBonus(fixedBonuses2014, ab) +
        (activeFlex.contains(ab) ? flexibleBonusValue2014 : 0);
    return AbilityScores(
      strength: forAb(AbilityType.strength),
      dexterity: forAb(AbilityType.dexterity),
      constitution: forAb(AbilityType.constitution),
      intelligence: forAb(AbilityType.intelligence),
      wisdom: forAb(AbilityType.wisdom),
      charisma: forAb(AbilityType.charisma),
    );
  }

  final triple = backgroundTriplePlusOne2024.toSet().take(3).toSet();
  if (triple.isNotEmpty) {
    int forAb(AbilityType ab) => triple.contains(ab) ? 1 : 0;
    return AbilityScores(
      strength: forAb(AbilityType.strength),
      dexterity: forAb(AbilityType.dexterity),
      constitution: forAb(AbilityType.constitution),
      intelligence: forAb(AbilityType.intelligence),
      wisdom: forAb(AbilityType.wisdom),
      charisma: forAb(AbilityType.charisma),
    );
  }

  int forAb(AbilityType ab) =>
      (backgroundPrimary2024 == ab ? 2 : 0) +
      (backgroundSecondary2024 == ab ? 1 : 0);
  return AbilityScores(
    strength: forAb(AbilityType.strength),
    dexterity: forAb(AbilityType.dexterity),
    constitution: forAb(AbilityType.constitution),
    intelligence: forAb(AbilityType.intelligence),
    wisdom: forAb(AbilityType.wisdom),
    charisma: forAb(AbilityType.charisma),
  );
}

/// Computes hit points gained on a level-up from [hitDie] (e.g. `'d8'`, `'d10'`),
/// either fixed average (`sides ~/ 2 + 1`) or [rolledValue], plus
/// [constitutionModifier], with a minimum gain of 1 HP.
///
/// Throws [ArgumentError] if [hitDie] is not a positive `d<N>` die or if
/// [useFixedAverage] is `false` and [rolledValue] is missing or outside `1..N`.
int computeLevelUpHpGain({
  required String hitDie,
  required int constitutionModifier,
  bool useFixedAverage = true,
  int? rolledValue,
}) {
  final clean = hitDie.trim().toLowerCase();
  final sides = clean.startsWith('d') ? int.tryParse(clean.substring(1)) : null;
  if (sides == null || sides < 1) {
    throw ArgumentError.value(hitDie, 'hitDie', 'must be a valid hit die like d8');
  }
  final int base;
  if (useFixedAverage) {
    base = (sides ~/ 2) + 1;
  } else {
    if (rolledValue == null || rolledValue < 1 || rolledValue > sides) {
      throw ArgumentError.value(
        rolledValue,
        'rolledValue',
        'must be between 1 and $sides for $hitDie',
      );
    }
    base = rolledValue;
  }
  return math.max(1, base + constitutionModifier);
}
