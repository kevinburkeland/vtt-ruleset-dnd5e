import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('Damage Adjustment Laws (DA1 - DA4)', () {
    test('DA1: order law: resistant and vulnerable together give 2 * (amount ~/ 2)', () {
      for (var amount = 0; amount <= 500; amount++) {
        final result = adjustDamageForDefenses(
          amount,
          immune: false,
          resistant: true,
          vulnerable: true,
        );
        final expected = 2 * (amount ~/ 2);
        expect(result, equals(expected));
        expect(result, lessThanOrEqualTo(amount));
        if (amount.isOdd) {
          expect(result, equals(amount - 1));
        } else {
          expect(result, equals(amount));
        }
      }
    });

    test('DA2: each defense alone over 0..500', () {
      for (var amount = 0; amount <= 500; amount++) {
        // No defense
        expect(
          adjustDamageForDefenses(
            amount,
            immune: false,
            resistant: false,
            vulnerable: false,
          ),
          equals(amount),
        );

        // Resistance alone
        expect(
          adjustDamageForDefenses(
            amount,
            immune: false,
            resistant: true,
            vulnerable: false,
          ),
          equals(amount ~/ 2),
        );

        // Vulnerability alone
        expect(
          adjustDamageForDefenses(
            amount,
            immune: false,
            resistant: false,
            vulnerable: true,
          ),
          equals(amount * 2),
        );

        // Immunity alone or with any other flags
        for (final r in [false, true]) {
          for (final v in [false, true]) {
            expect(
              adjustDamageForDefenses(
                amount,
                immune: true,
                resistant: r,
                vulnerable: v,
              ),
              equals(0),
            );
          }
        }
      }
    });

    test('DA3: monotone: result never decreases as amount goes up from 0 to 500', () {
      for (final immune in [false, true]) {
        for (final resistant in [false, true]) {
          for (final vulnerable in [false, true]) {
            var prev = adjustDamageForDefenses(
              0,
              immune: immune,
              resistant: resistant,
              vulnerable: vulnerable,
            );
            for (var amount = 1; amount <= 500; amount++) {
              final current = adjustDamageForDefenses(
                amount,
                immune: immune,
                resistant: resistant,
                vulnerable: vulnerable,
              );
              expect(
                current,
                greaterThanOrEqualTo(prev),
                reason:
                    'Failed monotonicity at amount $amount (immune=$immune, res=$resistant, vuln=$vulnerable): $current < $prev',
              );
              prev = current;
            }
          }
        }
      }
    });

    test('DA4: concrete examples from specification', () {
      expect(
        adjustDamageForDefenses(
          25,
          immune: false,
          resistant: true,
          vulnerable: true,
        ),
        equals(24),
      );
      expect(
        adjustDamageForDefenses(
          25,
          immune: false,
          resistant: true,
          vulnerable: false,
        ),
        equals(12),
      );
      expect(
        adjustDamageForDefenses(
          1,
          immune: false,
          resistant: true,
          vulnerable: true,
        ),
        equals(0),
      );
      expect(
        adjustDamageForDefenses(
          -5,
          immune: false,
          resistant: true,
          vulnerable: true,
        ),
        equals(0),
      );
    });
  });
}
