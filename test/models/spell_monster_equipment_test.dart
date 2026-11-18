import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('EvaluationMath Domain Model Tests', () {
    test(
        'copyWith accepts and assigns isAttackRoll, requiresSave, and scalingFormula',
        () {
      const base = EvaluationMath(
        diceFormula: '1d10',
        damageType: DamageType.force,
        scalingFormula: '+1d10 per slot above 1st',
        isAttackRoll: false,
        requiresSave: false,
      );

      // Mutate isAttackRoll
      final withAttack = base.copyWith(isAttackRoll: true);
      expect(withAttack.isAttackRoll, isTrue);
      expect(withAttack.requiresSave, isFalse);
      expect(withAttack.diceFormula, equals('1d10'));
      expect(withAttack.scalingFormula, equals('+1d10 per slot above 1st'));

      // Mutate requiresSave and scalingFormula
      final withSaveAndScale = base.copyWith(
        requiresSave: true,
        scalingFormula: '+2d6 per slot',
      );
      expect(withSaveAndScale.isAttackRoll, isFalse);
      expect(withSaveAndScale.requiresSave, isTrue);
      expect(withSaveAndScale.scalingFormula, equals('+2d6 per slot'));

      // Preserves existing flags if not specified
      final unchanged = withAttack.copyWith(diceFormula: '2d10');
      expect(unchanged.isAttackRoll, isTrue);
      expect(unchanged.diceFormula, equals('2d10'));
      expect(unchanged.scalingFormula, equals('+1d10 per slot above 1st'));
    });

    test('toMap and fromMap serialize and deserialize flags cleanly', () {
      const math = EvaluationMath(
        diceFormula: '8d6',
        damageType: DamageType.fire,
        scalingFormula: '+1d6 per slot above 3rd',
        isAttackRoll: false,
        requiresSave: true,
      );

      final map = math.toMap();
      expect(map['isAttackRoll'], isFalse);
      expect(map['requiresSave'], isTrue);
      expect(map['scalingFormula'], equals('+1d6 per slot above 3rd'));

      final restored = EvaluationMath.fromMap(map);
      expect(restored, equals(math));
      expect(restored.requiresSave, isTrue);
      expect(restored.scalingFormula, equals('+1d6 per slot above 3rd'));
    });
  });
}
