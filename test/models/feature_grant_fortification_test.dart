import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('FeatureGrant Fortification & Strict Required grantId Tests', () {
    test('All factory constructors enforce deterministic grantId', () {
      final hp = FeatureGrant.hpBonus(grantId: 'tough_hp_grant', perLevel: 2);
      expect(hp.grantId, 'tough_hp_grant');
      expect(hp.type, GrantType.hpModifier);

      final unarmored = FeatureGrant.unarmoredDefense(
        grantId: 'barbarian_unarmored_defense',
        primaryAbility: 'constitution',
      );
      expect(unarmored.grantId, 'barbarian_unarmored_defense');
      expect(unarmored.type, GrantType.acFormula);

      final draconic = FeatureGrant.draconicResilience(
        grantId: 'draconic_resilience_grant',
      );
      expect(draconic.grantId, 'draconic_resilience_grant');

      final acBonus = FeatureGrant.acBonus(
        grantId: 'defense_fighting_style',
        amount: 1,
        requiresArmor: true,
      );
      expect(acBonus.grantId, 'defense_fighting_style');

      final passive = FeatureGrant.passiveBonus(
        grantId: 'alert_initiative',
        stat: 'initiative',
        formula: 'profBonus',
      );
      expect(passive.grantId, 'alert_initiative');

      final skill = FeatureGrant.skillProficiency(
        'athletics',
        grantId: 'fighter_skill_athletics',
      );
      expect(skill.grantId, 'fighter_skill_athletics');

      final skillChoice = FeatureGrant.skillChoice(
        grantId: 'bard_bonus_skills',
        count: 3,
      );
      expect(skillChoice.grantId, 'bard_bonus_skills');

      final expertise = FeatureGrant.expertise(
        'stealth',
        grantId: 'rogue_expertise_stealth',
      );
      expect(expertise.grantId, 'rogue_expertise_stealth');

      final prof = FeatureGrant.weaponArmorProficiency(
        'martialWeapons',
        grantId: 'martial_weapon_prof',
      );
      expect(prof.grantId, 'martial_weapon_prof');

      final cantrips = FeatureGrant.bonusCantrips(
        grantId: 'high_elf_cantrip_grant',
        count: 1,
        castingAbility: 'intelligence',
      );
      expect(cantrips.grantId, 'high_elf_cantrip_grant');

      final spell = FeatureGrant.bonusSpell(
        grantId: 'homebrew_fey_step_grant',
        slug: 'misty-step',
        displayName: 'Misty Step',
      );
      expect(spell.grantId, 'homebrew_fey_step_grant');

      final darkvision = FeatureGrant.darkvisionRange(
        60,
        grantId: 'elf_darkvision',
      );
      expect(darkvision.grantId, 'elf_darkvision');

      final asi = FeatureGrant.abilityBoost(
        grantId: 'mountain_dwarf_str',
        ability: 'strength',
        amount: 2,
      );
      expect(asi.grantId, 'mountain_dwarf_str');

      final resist = FeatureGrant.resistance(
        'fire',
        grantId: 'tiefling_hellish_resistance',
      );
      expect(resist.grantId, 'tiefling_hellish_resistance');

      final speed = FeatureGrant.speedBonus(
        10,
        grantId: 'wood_elf_fleet_of_foot',
      );
      expect(speed.grantId, 'wood_elf_fleet_of_foot');
    });

    test(
        'Serialization toMap preserves grantId and fromMap handles legacy unkeyed maps safely',
        () {
      final grant = FeatureGrant.bonusCantrips(
        grantId: 'tiefling_thaumaturgy',
        count: 1,
        castingAbility: 'charisma',
        label: 'Infernal Legacy: Thaumaturgy',
      );

      final map = grant.toMap();
      expect(map['grantId'], 'tiefling_thaumaturgy');
      expect(map['type'], 'bonusCantrip');

      final reconstituted = FeatureGrant.fromMap(map);
      expect(reconstituted, equals(grant));
      expect(reconstituted.grantId, 'tiefling_thaumaturgy');

      // Legacy map without grantId
      final legacyMap = {
        'type': 'bonusCantrip',
        'payload': {'count': 1},
        'label': 'Legacy Grant',
      };
      final legacyReconstituted = FeatureGrant.fromMap(legacyMap);
      expect(legacyReconstituted.grantId, 'grant_bonusCantrip_legacy');
    });
  });
}
