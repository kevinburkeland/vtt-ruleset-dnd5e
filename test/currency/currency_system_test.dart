import 'package:vtt_engine_core/models/party_purse.dart';
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

  group('Dnd5ePurseExtension Replica Identity Hardening Tests', () {
    test('modifyCoin, setCoins, depositCoins, withdrawCoins, and deductGpEquivalent reject "local"', () {
      const purse = PartyPurse.empty();

      expect(
        () => purse.modifyCoin('gp', 10, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.setCoins(gp: 50, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.depositCoins(gp: 20, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.withdrawCoins(gp: 5, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.deductGpEquivalent(1.0, nodeId: 'local'),
        throwsArgumentError,
      );
    });

    test('performs mutations successfully when valid replica nodeId is provided', () {
      const purse = PartyPurse.empty();
      final set = purse.setCoins(gp: 50, sp: 20, nodeId: 'replica-1');
      expect(set.gp, equals(50));
      expect(set.sp, equals(20));

      final deposited = set.depositCoins(gp: 10, nodeId: 'replica-1');
      expect(deposited.gp, equals(60));

      final withdrawn = deposited.withdrawCoins(gp: 5, nodeId: 'replica-1');
      expect(withdrawn.gp, equals(55));

      final modified = withdrawn.modifyCoin('gp', -5, nodeId: 'replica-1');
      expect(modified.gp, equals(50));

      final deducted = modified.deductGpEquivalent(10.0, nodeId: 'replica-1');
      expect(deducted.totalGpEquivalent, closeTo(42.0, 0.001));
    });
  });
}
