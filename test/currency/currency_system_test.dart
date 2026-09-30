import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('D&D 5e Currency System Tests', () {
    const currency = Dnd5eCurrencySystem();

    test('exposes all 5 canonical coin denominations', () {
      final ids = currency.denominations.map((d) => d.id).toList();
      expect(ids, equals(['cp', 'sp', 'ep', 'gp', 'pp']));
    });

    test('converts coin denominations accurately against gold standard', () {
      expect(
        currency.convert(
            amount: 100, fromDenominationId: 'cp', toDenominationId: 'gp'),
        closeTo(1.0, 0.001),
      );

      expect(
        currency.convert(
            amount: 10, fromDenominationId: 'sp', toDenominationId: 'gp'),
        closeTo(1.0, 0.001),
      );

      expect(
        currency.convert(
            amount: 1, fromDenominationId: 'pp', toDenominationId: 'gp'),
        closeTo(10.0, 0.001),
      );

      expect(
        currency.convert(
            amount: 50, fromDenominationId: 'gp', toDenominationId: 'pp'),
        closeTo(5.0, 0.001),
      );
    });

    test('formats balances cleanly', () {
      final formatted = currency.formatBalances({
        'gp': 45,
        'sp': 8,
        'cp': 12,
      });

      expect(formatted, equals('45 gp, 8 sp, 12 cp'));
    });
  });
}
