import 'dart:math' as math;

/// SRD 5.1 / 5.2.1: immunity gives 0. Otherwise resistance halves (round down),
/// then vulnerability doubles. Several sources of one defense count once,
/// which is why each defense is a single bool.
int adjustDamageForDefenses(
  int amount, {
  required bool immune,
  required bool resistant,
  required bool vulnerable,
}) {
  if (amount <= 0) return 0;
  if (immune) return 0;

  var adjusted = amount;
  if (resistant) {
    adjusted = adjusted ~/ 2;
  }
  if (vulnerable) {
    adjusted = adjusted * 2;
  }
  return math.max(0, adjusted);
}
