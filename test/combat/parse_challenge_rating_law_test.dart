import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('Fix 2.1: parseChallengeRating laws', () {
    test('fixed cases: standard forms, XP tails, invalid and empty strings', () {
      expect(parseChallengeRating('5'), 5.0);
      expect(parseChallengeRating('CR 5'), 5.0);
      expect(parseChallengeRating('1/4'), 0.25);
      expect(parseChallengeRating('CR 1/2 (100 XP)'), 0.5);
      expect(parseChallengeRating('30 (155,000 XP)'), 30.0);
      expect(parseChallengeRating('CR 5 (XP 1,800; PB +3)'), 5.0);
      expect(parseChallengeRating('0 (10 XP)'), 0.0);

      // Empty or unreadable texts return null.
      expect(parseChallengeRating(''), isNull);
      expect(parseChallengeRating('—'), isNull);
      expect(parseChallengeRating('unknown'), isNull);

      // Zero-denominator fraction returns null (not 1, does not throw).
      expect(parseChallengeRating('1/0'), isNull);
      expect(parseChallengeRating('CR 1/0 (0 XP)'), isNull);

      // Does not clamp and does not throw for out-of-range CRs.
      expect(parseChallengeRating('CR 31'), 31.0);
      expect(parseChallengeRating('99 (999,999 XP)'), 99.0);
    });

    test('seeded law: 600 generated SRD CR texts with prefixes and tails parse exactly', () {
      final rng = Random(20261125);
      final srdCrs = <(String, double)>[
        ('0', 0.0),
        ('1/8', 0.125),
        ('1/4', 0.25),
        ('1/2', 0.5),
        for (var i = 1; i <= 30; i++) ('$i', i.toDouble()),
      ];
      const prefixes = ['', 'CR ', 'cr ', 'Cr ', '  CR   ', 'Challenge ', '  '];
      const tails = [
        '',
        ' (10 XP)',
        ' (1,800 XP)',
        ' (155,000 XP)',
        ' (XP 1,800; PB +3)',
        ' (XP 155,000; PB +9)',
        ' — Boss',
        ' [variant 2]',
        '  ',
      ];

      for (var i = 0; i < 600; i++) {
        final (crText, expected) = srdCrs[rng.nextInt(srdCrs.length)];
        final prefix = prefixes[rng.nextInt(prefixes.length)];
        final tail = tails[rng.nextInt(tails.length)];
        final input = '$prefix$crText$tail';
        final actual = parseChallengeRating(input);
        expect(
          actual,
          expected,
          reason: 'Seeded case #$i failed for input "$input"',
        );
      }
    });
  });
}
