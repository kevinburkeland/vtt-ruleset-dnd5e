import 'dart:math';
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

class MaxRandom implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => 0.999999;
}

class ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.0;
}

const sideOptions = [1, 2, 3, 4, 6, 8, 10, 12, 20, 100];

DiceExpression generateRandomExpression(Random rng, {bool allowMod = true}) {
  final termCount = rng.nextInt(5) + 1; // 1 to 5 terms
  final terms = <DiceExpressionTerm>[];

  for (var i = 0; i < termCount; i++) {
    final isNegative = rng.nextBool();
    final termKind = rng.nextInt(allowMod ? 3 : 2);

    if (termKind == 0) {
      final count = rng.nextInt(20) + 1;
      final sides = sideOptions[rng.nextInt(sideOptions.length)];
      terms.add(DiceRollTerm(count: count, sides: sides, isNegative: isNegative));
    } else if (termKind == 1) {
      final val = rng.nextInt(51); // 0 to 50
      terms.add(DiceConstantTerm(value: val, isNegative: isNegative));
    } else {
      terms.add(DiceModTerm(isNegative: isNegative));
    }
  }
  return DiceExpression(terms);
}

void main() {
  group('Dice Expression Laws (DX1 - DX7)', () {
    test('DX1 (round-trip law)', () {
      for (var seed = 0; seed < 500; seed++) {
        final rng = Random(seed);
        final e = generateRandomExpression(rng, allowMod: true);
        final canonical = e.format();

        final parsed = DiceExpression.parse(canonical);
        expect(parsed, equals(e),
            reason: 'Seed $seed failed on canonical "$canonical"');

        // Formatted with random extra spaces between tokens and random D/d case
        final buffer = StringBuffer();
        buffer.write(' ' * rng.nextInt(3));
        for (var i = 0; i < e.terms.length; i++) {
          final term = e.terms[i];
          if (i == 0) {
            if (term.isNegative) {
              buffer.write('-');
              buffer.write(' ' * rng.nextInt(3));
            }
          } else {
            buffer.write(term.isNegative ? '-' : '+');
            buffer.write(' ' * rng.nextInt(3));
          }

          if (term is DiceRollTerm) {
            final dChar = rng.nextBool() ? 'D' : 'd';
            buffer.write('${term.count}$dChar${term.sides}');
          } else if (term is DiceConstantTerm) {
            buffer.write('${term.value}');
          } else if (term is DiceModTerm) {
            final modForm = rng.nextInt(3);
            buffer.write(modForm == 0
                ? 'mod'
                : (modForm == 1 ? 'MOD' : 'Mod'));
          }
          buffer.write(' ' * rng.nextInt(3));
        }

        final spacedText = buffer.toString();
        final parsedSpaced = DiceExpression.parse(spacedText);
        expect(parsedSpaced, equals(e),
            reason: 'Seed $seed failed on spaced text "$spacedText"');
      }
    });

    test('DX2 (garbage law)', () {
      final badChars = ['x', '(', '.', '*', '/', ',', 'a', 'b', 'c', 'e', 'f', 'g', 'h', 'z'];
      for (var seed = 0; seed < 500; seed++) {
        final rng = Random(seed);
        final e = generateRandomExpression(rng, allowMod: true);
        final canonical = e.format();
        final badChar = badChars[rng.nextInt(badChars.length)];
        final insertPos = rng.nextInt(canonical.length + 1);
        final corrupted = canonical.substring(0, insertPos) +
            badChar +
            canonical.substring(insertPos);

        expect(() => DiceExpression.parse(corrupted), throwsA(isA<FormatException>()),
            reason: 'Seed $seed should throw on corrupted "$corrupted"');
      }

      const fixedGarbageList = [
        '',
        '   ',
        'd',
        '1d',
        '0d6',
        '1d0',
        '2d6+',
        '2d6++3',
        '+2d6',
        '1d10 (fire)',
        '2d6 fire',
        '1.5d6',
        '1d6*2',
        'abc',
        '2d6x',
        '1000d6',
        '1d1001',
      ];

      for (final garbage in fixedGarbageList) {
        expect(() => DiceExpression.parse(garbage), throwsA(isA<FormatException>()),
            reason: 'Should throw FormatException on "$garbage"');
      }
    });

    test('DX3 (sum law)', () {
      final maxRng = MaxRandom();
      final zeroRng = ZeroRandom();
      const resolver = Dnd5eCombatResolver();

      for (var seed = 0; seed < 500; seed++) {
        final rng = Random(seed);
        final e = generateRandomExpression(rng, allowMod: false);
        final formula = e.format();

        var diceMaxSum = 0;
        var diceMinSum = 0;
        var constantSum = 0;

        for (final term in e.terms) {
          if (term is DiceRollTerm) {
            final termMax = term.count * term.sides;
            final termMin = term.count;
            diceMaxSum += term.isNegative ? -termMax : termMax;
            diceMinSum += term.isNegative ? -termMin : termMin;
          } else if (term is DiceConstantTerm) {
            constantSum += term.isNegative ? -term.value : term.value;
          }
        }

        final expectedMaxNonCrit = max(0, diceMaxSum + constantSum);
        final actualMaxNonCrit = resolver.rollDamage(
          damageExpression: formula,
          isCrit: false,
          rng: maxRng,
        );
        expect(actualMaxNonCrit, equals(expectedMaxNonCrit),
            reason: 'Seed $seed failed on max non-crit for "$formula"');

        final expectedMinNonCrit = max(0, diceMinSum + constantSum);
        final actualMinNonCrit = resolver.rollDamage(
          damageExpression: formula,
          isCrit: false,
          rng: zeroRng,
        );
        expect(actualMinNonCrit, equals(expectedMinNonCrit),
            reason: 'Seed $seed failed on min non-crit for "$formula"');

        final expectedMaxCrit = max(0, 2 * diceMaxSum + constantSum);
        final actualMaxCrit = resolver.rollDamage(
          damageExpression: formula,
          isCrit: true,
          rng: maxRng,
        );
        expect(actualMaxCrit, equals(expectedMaxCrit),
            reason: 'Seed $seed failed on max crit for "$formula"');

        final expectedMinCrit = max(0, 2 * diceMinSum + constantSum);
        final actualMinCrit = resolver.rollDamage(
          damageExpression: formula,
          isCrit: true,
          rng: zeroRng,
        );
        expect(actualMinCrit, equals(expectedMinCrit),
            reason: 'Seed $seed failed on min crit for "$formula"');
      }
    });

    test('DX4 (spell roll law)', () {
      final maxRng = MaxRandom();

      for (var seed = 0; seed < 500; seed++) {
        final rng = Random(seed);
        final e = generateRandomExpression(rng, allowMod: true);
        final formula = e.format();

        var totalDiceCount = 0;
        var signedDiceSidesSum = 0;
        var constantsSum = 0;
        var modMultiplier = 0;

        for (final term in e.terms) {
          if (term is DiceRollTerm) {
            totalDiceCount += term.count;
            final sidesSum = term.count * term.sides;
            signedDiceSidesSum += term.isNegative ? -sidesSum : sidesSum;
          } else if (term is DiceConstantTerm) {
            constantsSum += term.isNegative ? -term.value : term.value;
          } else if (term is DiceModTerm) {
            modMultiplier += term.isNegative ? -1 : 1;
          }
        }

        for (var m = -3; m <= 5; m++) {
          final res = SpellRollEngine.roll(
            formula: formula,
            abilityModifier: m,
            rng: maxRng,
          );
          expect(res, isNotNull,
              reason: 'Seed $seed formula "$formula" should parse and roll');

          expect(res!.individualDice.length, equals(totalDiceCount),
              reason: 'Seed $seed individualDice.length mismatch on "$formula"');

          final expectedModifier = constantsSum + (modMultiplier * m);
          expect(res.modifier, equals(expectedModifier),
              reason: 'Seed $seed modifier mismatch on "$formula" with m=$m');

          final expectedTotal = signedDiceSidesSum + expectedModifier;
          expect(res.total, equals(expectedTotal),
              reason: 'Seed $seed total mismatch on "$formula" with m=$m');
        }
      }
    });

    test('DX5 (examples, rollDamage with max rolls)', () {
      final rng = MaxRandom();
      const resolver = Dnd5eCombatResolver();

      // Controls
      expect(
        resolver.rollDamage(damageExpression: '2d6+3', isCrit: false, rng: rng),
        equals(15),
      );
      expect(
        resolver.rollDamage(damageExpression: '1d8-1', isCrit: false, rng: rng),
        equals(7),
      );

      // Dropped terms / errors
      expect(
        resolver.rollDamage(damageExpression: '2d6+1d4+3', isCrit: false, rng: rng),
        equals(19),
      );
      expect(
        resolver.rollDamage(damageExpression: '1d6+2+2', isCrit: false, rng: rng),
        equals(10),
      );
      expect(
        resolver.rollDamage(damageExpression: '4d6 + 4d6', isCrit: false, rng: rng),
        equals(48),
      );
      expect(
        () => resolver.rollDamage(damageExpression: '1d', isCrit: false, rng: rng),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => resolver.rollDamage(damageExpression: 'd', isCrit: false, rng: rng),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => resolver.rollDamage(damageExpression: '1d10 (fire)', isCrit: false, rng: rng),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => resolver.rollDamage(damageExpression: '2d6x', isCrit: false, rng: rng),
        throwsA(isA<FormatException>()),
      );
    });

    test('DX6 (examples, SpellRollEngine)', () {
      // Control
      expect(SpellRollEngine.roll(formula: '8d6')!.individualDice.length, equals(8));

      // Dropped terms in formula
      expect(SpellRollEngine.roll(formula: '4d6 + 4d6')!.individualDice.length, equals(8));
      expect(SpellRollEngine.roll(formula: '20d6 + 20d6')!.individualDice.length, equals(40));
      expect(SpellRollEngine.roll(formula: '2d8 + 4d6')!.individualDice.length, equals(6));

      // Mod description
      expect(
        SpellRollEngine.roll(formula: '2d8 + mod', abilityModifier: 4)!.formulaDescription,
        equals('2d8 + 4'),
      );

      // Non-dice formulas
      expect(SpellRollEngine.roll(formula: '1d10 (fire)'), isNull);
      expect(SpellRollEngine.roll(formula: '2d6 fire'), isNull);
    });

    test('DX7 (cantrip)', () {
      expect(CantripScalingEngine.scaleCantripFormula('1d10', 5), equals('2d10'));
      expect(CantripScalingEngine.scaleCantripFormula('1d8 + mod', 11), equals('3d8 + mod'));
      expect(CantripScalingEngine.scaleCantripFormula('2d6 + 1d4', 17), equals('8d6 + 4d4'));
      expect(CantripScalingEngine.scaleCantripFormula('not dice', 5), equals('not dice'));
    });
  });
}
