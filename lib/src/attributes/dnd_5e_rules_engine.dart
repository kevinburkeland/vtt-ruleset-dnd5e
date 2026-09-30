/// Standard D&D 5e Ability Score Math & Modifier Helpers.
abstract final class Dnd5eScoreMath {
  /// Calculates the ability modifier for a given ability score (e.g., 10 -> 0, 16 -> +3, 9 -> -1).
  static int scoreToModifier(int score) => ((score - 10) / 2).floor();

  /// Formats an ability score with its modifier (e.g., "16 (+3)" or "9 (-1)").
  static String formatScoreWithModifier(int score) {
    final mod = scoreToModifier(score);
    final sign = mod >= 0 ? '+$mod' : '$mod';
    return '$score ($sign)';
  }

  /// Calculates the standard proficiency bonus by character level (1-20).
  static int levelToProficiencyBonus(int level) =>
      ((level.clamp(1, 20) - 1) ~/ 4) + 2;
}

/// Pure 5e math engine and score extensions for ability modifier and proficiency bonus calculations.
extension Dnd5eScoreMathExtension on int {
  /// Standard 5e Ability Score to Modifier conversion: floor((score - 10) / 2)
  int get dndModifier => Dnd5eScoreMath.scoreToModifier(this);

  /// Formatted modifier with explicit sign (e.g., "+3", "-1", "+0")
  String get dndModifierString {
    final mod = dndModifier;
    return mod >= 0 ? '+$mod' : '$mod';
  }

  /// Standard 5e Level to Proficiency Bonus scaling:
  /// Level 1-4: +2 | 5-8: +3 | 9-12: +4 | 13-16: +5 | 17-20: +6
  int get dndProficiencyBonus => Dnd5eScoreMath.levelToProficiencyBonus(this);

  /// Calculates Spell Save DC: 8 + proficiencyBonus + abilityModifier
  int dndSpellSaveDc({required int abilityScore}) {
    return 8 + dndProficiencyBonus + abilityScore.dndModifier;
  }

  /// Calculates Spell Attack Modifier: proficiencyBonus + abilityModifier
  int dndSpellAttackBonus({required int abilityScore}) {
    return dndProficiencyBonus + abilityScore.dndModifier;
  }
}

/// Zero-guarded numeric ratio calculation for combat and resource meters.
extension DndMathUtils on num {
  /// Computes safe progress fraction [0.0 - 1.0] strictly protected against divide-by-zero
  double ratioOf(num max) =>
      max <= 0 ? 0.0 : (this / max).clamp(0.0, 1.0).toDouble();
}
