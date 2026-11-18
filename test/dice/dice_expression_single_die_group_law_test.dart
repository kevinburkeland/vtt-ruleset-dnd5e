import 'dart:math';
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('DiceExpression.singleDieGroup law', () {
    test('returns the sole non-negative die term across >= 500 seeded expressions, else null', () {
      final rng = Random(130301);
      const sidesPool = [4, 6, 8, 10, 12, 20, 100];

      for (var i = 0; i < 600; i++) {
        final groupCount = rng.nextInt(4); // 0, 1, 2, 3
        final terms = <DiceExpressionTerm>[];
        for (var g = 0; g < groupCount; g++) {
          final count = 1 + rng.nextInt(8);
          final sides = sidesPool[rng.nextInt(sidesPool.length)];
          final isNeg = rng.nextBool();
          terms.add(DiceRollTerm(count: count, sides: sides, isNegative: isNeg));
        }
        if (rng.nextBool()) {
          terms.add(DiceConstantTerm(
            value: 1 + rng.nextInt(10),
            isNegative: rng.nextBool(),
          ));
        }
        if (rng.nextBool()) {
          terms.add(DiceModTerm(isNegative: rng.nextBool()));
        }

        final expr = DiceExpression(terms);
        final dice = terms.whereType<DiceRollTerm>().toList();
        final expected =
            (dice.length == 1 && !dice.first.isNegative) ? dice.first : null;

        expect(
          expr.singleDieGroup,
          equals(expected),
          reason: 'seed=$i expr=${expr.format()}',
        );
      }
    });

    test('handles canonical boundary examples', () {
      expect(DiceExpression.parse('1d8').singleDieGroup,
          equals(const DiceRollTerm(count: 1, sides: 8)));
      expect(DiceExpression.parse('2d6 + 3').singleDieGroup,
          equals(const DiceRollTerm(count: 2, sides: 6)));
      expect(DiceExpression.parse('1d8 + 1d6').singleDieGroup, isNull);
      expect(DiceExpression.parse('1d8 - 1d4').singleDieGroup, isNull);
      expect(DiceExpression.parse('-1d8').singleDieGroup, isNull);
      expect(DiceExpression.parse('5').singleDieGroup, isNull);
    });
  });
}
