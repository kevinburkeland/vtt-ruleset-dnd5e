import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
void main() {
  group('Dnd5eScoreMath Extension Tests', () {
    test('Ability Modifier calculation matches 5e RAW floor((score-10)/2)', () {
      expect(1.dndModifier, -5);
      expect(3.dndModifier, -4);
      expect(8.dndModifier, -1);
      expect(9.dndModifier, -1);
      expect(10.dndModifier, 0);
      expect(11.dndModifier, 0);
      expect(12.dndModifier, 1);
      expect(13.dndModifier, 1);
      expect(14.dndModifier, 2);
      expect(18.dndModifier, 4);
      expect(20.dndModifier, 5);
      expect(24.dndModifier, 7);
      expect(30.dndModifier, 10);
    });

    test('Formatted modifier strings include explicit sign', () {
      expect(1.dndModifierString, '-5');
      expect(10.dndModifierString, '+0');
      expect(14.dndModifierString, '+2');
      expect(20.dndModifierString, '+5');
    });

    test('Proficiency Bonus scales correctly from Level 1 to 20', () {
      // Level 1-4: +2
      expect(1.dndProficiencyBonus, 2);
      expect(4.dndProficiencyBonus, 2);

      // Level 5-8: +3
      expect(5.dndProficiencyBonus, 3);
      expect(8.dndProficiencyBonus, 3);

      // Level 9-12: +4
      expect(9.dndProficiencyBonus, 4);
      expect(12.dndProficiencyBonus, 4);

      // Level 13-16: +5
      expect(13.dndProficiencyBonus, 5);
      expect(16.dndProficiencyBonus, 5);

      // Level 17-20: +6
      expect(17.dndProficiencyBonus, 6);
      expect(20.dndProficiencyBonus, 6);
    });
  });
}