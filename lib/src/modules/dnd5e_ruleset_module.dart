import 'dart:math' as math;
import 'package:vtt_engine_core/currency/i_currency_system.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_engine_core/rules/i_ruleset_module.dart';
import '../models/character_models.dart';
import '../models/feature_grant.dart';
import '../rules/ruleset_edition.dart';
import '../attributes/dnd_5e_attribute_system.dart';
import '../combat/dnd_5e_combat_resolver.dart';
import '../currency/dnd_5e_currency_system.dart';
import 'dnd_5e_modules.dart';

/// Pluggable D&D 5e Ruleset Module encapsulating 2014 and 2024 tabletop mechanics,
/// derived statistic resolution, resting frameworks, action budgets, and exhaustion.
class Dnd5eRulesetModule implements IRulesetModule {
  final RulesetEdition edition;

  const Dnd5eRulesetModule({this.edition = RulesetEdition.v2024});

  const Dnd5eRulesetModule.v2014() : edition = RulesetEdition.v2014;
  const Dnd5eRulesetModule.v2024() : edition = RulesetEdition.v2024;


  @override
  bool hasCapability<T extends IRulesetCapability>() => getCapability<T>() != null;

  @override
  T? getCapability<T extends IRulesetCapability>() {
    if (this is T) return this as T;
    if (exhaustionMechanic is T) return exhaustionMechanic as T;
    if (restMechanic is T) return restMechanic as T;
    if (actionEconomy is T) return actionEconomy as T;
    return null;
  }

  @override
  String get moduleId =>
      edition == RulesetEdition.v2024 ? 'dnd5e_2024' : 'dnd5e_2014';

  @override
  String get displayName => edition == RulesetEdition.v2024
      ? '5E (2024 Revised / SRD 5.2.1)'
      : '5E (2014 Rules / SRD 5.1)';

  @override
  String get rulesetVersion =>
      edition == RulesetEdition.v2024 ? 'SRD 5.2.1' : 'SRD 5.1';

  @override
  String? get legalCitation => srdCitation;

  String get srdCitation => edition == RulesetEdition.v2024
      ? 'System Reference Document 5.2.1 (CC-BY-4.0)'
      : 'Systems Reference Document 5.1 (OGL 1.0a / CC-BY-4.0)';

  @override
  IAttributeSystem get attributeSystem => const Dnd5eAttributeSystem();

  @override
  ICurrencySystem get currencySystem => const Dnd5eCurrencySystem();

  @override
  IExhaustionMechanic get exhaustionMechanic => edition == RulesetEdition.v2024
      ? const Dnd5e2024ExhaustionMechanic()
      : const Dnd5e2014ExhaustionMechanic();

  @override
  IRestMechanic get restMechanic => const Dnd5eRestMechanic();

  @override
  IActionEconomy get actionEconomy => edition == RulesetEdition.v2024
      ? const Dnd5e2024ActionEconomy()
      : const Dnd5e2014ActionEconomy();

  @override
  ICombatResolver get combatResolver => const Dnd5eCombatResolver();

  @override
  Set<String> get defaultPinnedRules => const {
        'concentration',
        'falling',
        'grapple_shove',
        'cover',
        'resting',
      };

  @override
  bool supportsFeature(String featureKey) {
    return switch (featureKey.toLowerCase().trim()) {
      'weapon_masteries' => edition == RulesetEdition.v2024,
      'bonus_action_potions' => edition == RulesetEdition.v2024,
      'tactical_mind' => edition == RulesetEdition.v2024,
      _ => true,
    };
  }

  @override
  int calculateDerivedStat({
    required dynamic character,
    required String statKey,
    Map<String, dynamic> context = const {},
  }) {
    if (character is! Character) {
      return 10;
    }
    return switch (statKey.toLowerCase().trim()) {
      'ac' ||
      'armor_class' ||
      'armorclass' =>
        calculateCharacterArmorClass(character),
      'initiative' ||
      'initiative_bonus' ||
      'initiativebonus' =>
        calculateCharacterInitiativeBonus(character),
      'passive_perception' ||
      'passiveperception' =>
        calculateCharacterPassivePerception(character),
      'passive_investigation' ||
      'passiveinvestigation' =>
        calculateCharacterPassiveInvestigation(character),
      'passive_insight' ||
      'passiveinsight' =>
        calculateCharacterPassiveInsight(character),
      _ => (character.customProperties[statKey] as num?)?.toInt() ?? 10,
    };
  }

  // ==========================================================================
  // Static Derived Stat Evaluation Engines
  // ==========================================================================

  /// Armor Class calculation: Armor + Shields + DEX cap + Unarmored Defense / Natural Armor.
  static int calculateCharacterArmorClass(Character character) {
    int totalAc = 10;
    final dexMod = character.effectiveAbilityScores.getModifier('dexterity');
    final conMod = character.effectiveAbilityScores.getModifier('constitution');
    final wisMod = character.effectiveAbilityScores.getModifier('wisdom');

    // 1. Check custom AC override
    if (character.customProperties['armorClass'] is num) {
      return (character.customProperties['armorClass'] as num).toInt();
    }

    // 2. Scan equipped inventory for armor and shields
    InventoryItemInstance? equippedArmor;
    int shieldBonus = 0;
    int magicAcBonus = 0;

    for (final item in character.inventory) {
      if (!item.isEquipped) continue;
      final props = item.customProperties;
      final nameLower = item.displayName.toLowerCase();
      final slugLower = item.itemRef.slug.toLowerCase();

      final isShield = props['isShield'] == true ||
          props['type'] == 'shield' ||
          nameLower.contains('shield') ||
          slugLower.contains('shield');

      if (isShield) {
        final acVal = (props['ac'] as num?)?.toInt() ?? 2;
        shieldBonus = math.max(shieldBonus, acVal);
        final bonusVal = (props['magicBonus'] as num?)?.toInt() ??
            (props['bonusAc'] as num?)?.toInt() ??
            0;
        magicAcBonus += bonusVal;
        continue;
      }

      final isArmor = props['isArmor'] == true ||
          props['armor'] == true ||
          props['armorType'] != null ||
          props['type'] == 'armor' ||
          _isStandardArmorName(nameLower, slugLower);

      if (isArmor && equippedArmor == null) {
        equippedArmor = item;
        final bonusVal = (props['magicBonus'] as num?)?.toInt() ??
            (props['bonusAc'] as num?)?.toInt() ??
            0;
        magicAcBonus += bonusVal;
      }
    }

    for (final grant in character.activeGrants) {
      if (grant.type == GrantType.passiveModifier &&
          grant.payload['stat'] == 'ac') {
        magicAcBonus += (grant.payload['flat'] as num?)?.toInt() ?? 0;
      }
    }

    if (equippedArmor != null) {
      final props = equippedArmor.customProperties;
      final nameLower = equippedArmor.displayName.toLowerCase();
      final slugLower = equippedArmor.itemRef.slug.toLowerCase();
      final resolved = resolveStandardArmor(nameLower, slugLower);

      final baseAc = (props['baseAc'] as num?)?.toInt() ??
          (props['ac'] as num?)?.toInt() ??
          resolved.baseAc;
      final armorType =
          (props['armorType']?.toString().toLowerCase()) ?? resolved.armorType;
      final maxDex = (props['maxDex'] as num?)?.toInt() ?? resolved.maxDex;

      int effectiveDex = dexMod;
      if (armorType == 'heavy') {
        effectiveDex = 0;
      } else if (armorType == 'medium' && maxDex != null) {
        final cap = character.hasCapabilityFlag('mediumArmorDexCapBonus')
            ? maxDex + 1
            : maxDex;
        effectiveDex = math.min(effectiveDex, cap);
      }

      totalAc = baseAc + effectiveDex + shieldBonus + magicAcBonus;
      final hasDefenseStyle = character.progression.classes.any((c) =>
              c.selectedFeatureOptions['fighting_style']?.contains('defense') ==
              true) ||
          character.hasCapabilityFlag('defenseFightingStyle');
      if (hasDefenseStyle) {
        totalAc += 1;
      }
    } else {
      int unarmoredAc = 10 + dexMod;

      final isBarbarian = character.progression.classes.any((c) =>
              c.classRef.slug.toLowerCase().contains('barbarian') ||
              c.classRef.displayName.toLowerCase().contains('barbarian')) ||
          character.hasCapabilityFlag('unarmoredDefenseBarbarian');
      if (isBarbarian) {
        final barbarianAc = 10 + dexMod + conMod;
        if (barbarianAc > unarmoredAc) {
          unarmoredAc = barbarianAc;
        }
      }

      final isMonk = character.progression.classes.any((c) =>
              c.classRef.slug.toLowerCase().contains('monk') ||
              c.classRef.displayName.toLowerCase().contains('monk')) ||
          character.hasCapabilityFlag('unarmoredDefenseMonk');
      if (isMonk && shieldBonus == 0) {
        final monkAc = 10 + dexMod + wisMod;
        if (monkAc > unarmoredAc) {
          unarmoredAc = monkAc;
        }
      }

      final isDraconic = character.progression.classes.any((c) =>
              c.subclassRef?.slug.toLowerCase().contains('draconic') == true ||
              c.subclassRef?.displayName.toLowerCase().contains('draconic') ==
                  true) ||
          character.hasCapabilityFlag('draconicResilience');
      if (isDraconic) {
        final draconicAc = 13 + dexMod;
        if (draconicAc > unarmoredAc) {
          unarmoredAc = draconicAc;
        }
      }

      totalAc = unarmoredAc + shieldBonus + magicAcBonus;
    }

    return totalAc;
  }

  static bool _isStandardArmorName(String name, String slug) {
    final combined = '$name $slug'.toLowerCase().replaceAll('-', ' ');
    return combined.contains('padded') ||
        combined.contains('leather') ||
        combined.contains('studded') ||
        combined.contains('hide') ||
        combined.contains('chain shirt') ||
        combined.contains('elven chain') ||
        combined.contains('scale mail') ||
        combined.contains('breastplate') ||
        combined.contains('half plate') ||
        combined.contains('ring mail') ||
        combined.contains('chain mail') ||
        combined.contains('splint') ||
        combined.contains('plate');
  }

  static ({int baseAc, String armorType, int? maxDex}) resolveStandardArmor(
    String name,
    String slug,
  ) {
    final combined = '$name $slug'.toLowerCase().replaceAll('-', ' ');
    if (combined.contains('breastplate'))
      return (baseAc: 14, armorType: 'medium', maxDex: 2);
    if (combined.contains('half plate'))
      return (baseAc: 15, armorType: 'medium', maxDex: 2);
    if (combined.contains('plate'))
      return (baseAc: 18, armorType: 'heavy', maxDex: 0);
    if (combined.contains('splint'))
      return (baseAc: 17, armorType: 'heavy', maxDex: 0);
    if (combined.contains('chain mail'))
      return (baseAc: 16, armorType: 'heavy', maxDex: 0);
    if (combined.contains('ring mail'))
      return (baseAc: 14, armorType: 'heavy', maxDex: 0);
    if (combined.contains('scale mail'))
      return (baseAc: 14, armorType: 'medium', maxDex: 2);
    if (combined.contains('chain shirt') || combined.contains('elven chain')) {
      return (baseAc: 13, armorType: 'medium', maxDex: 2);
    }
    if (combined.contains('hide'))
      return (baseAc: 12, armorType: 'medium', maxDex: 2);
    if (combined.contains('studded leather') || combined.contains('studded')) {
      return (baseAc: 12, armorType: 'light', maxDex: null);
    }
    if (combined.contains('padded') || combined.contains('leather')) {
      return (baseAc: 11, armorType: 'light', maxDex: null);
    }
    return (baseAc: 11, armorType: 'light', maxDex: null);
  }

  /// Dynamic Initiative Bonus: DEX modifier + Alert feat bonus + Jack of All Trades (if untrained).
  static int calculateCharacterInitiativeBonus(Character character) {
    final dexMod = character.effectiveAbilityScores.getModifier('dexterity');
    int bonus = dexMod;

    final hasInitiativeBonus = character
            .hasCapabilityFlag('initiativeBonusMode') ||
        character.activeGrants.any((g) => g.payload['stat'] == 'initiative');
    if (hasInitiativeBonus) {
      if (character.rulesEdition == RulesetEdition.v2024) {
        bonus += character.proficiencyBonus;
      } else {
        bonus += 5;
      }
    } else if (character.hasCapabilityFlag('jackOfAllTrades')) {
      bonus += (character.proficiencyBonus * 0.5).floor();
    }

    if (character.customProperties['initiativeBonus'] is num) {
      bonus += (character.customProperties['initiativeBonus'] as num).toInt();
    }

    return bonus;
  }

  /// Passive Perception (10 + Perception skill modifier + passive bonus if present).
  static int calculateCharacterPassivePerception(Character character) {
    int bonus = character.hasCapabilityFlag('passivePerceptionBonus') ? 5 : 0;
    for (final g in character.activeGrants) {
      if (g.type == GrantType.passiveModifier &&
          g.payload['stat'] == 'passivePerception') {
        bonus += (g.payload['flat'] as num?)?.toInt() ?? 0;
      }
    }
    final perceptionMod =
        calculateSkillModifier(character, SkillType.perception);
    return 10 + perceptionMod + bonus;
  }

  /// Passive Investigation (10 + Investigation skill modifier + passive bonus if present).
  static int calculateCharacterPassiveInvestigation(Character character) {
    int bonus =
        character.hasCapabilityFlag('passiveInvestigationBonus') ? 5 : 0;
    for (final g in character.activeGrants) {
      if (g.type == GrantType.passiveModifier &&
          g.payload['stat'] == 'passiveInvestigation') {
        bonus += (g.payload['flat'] as num?)?.toInt() ?? 0;
      }
    }
    final invMod = calculateSkillModifier(character, SkillType.investigation);
    return 10 + invMod + bonus;
  }

  /// Passive Insight (10 + Insight skill modifier + passive bonus if present).
  static int calculateCharacterPassiveInsight(Character character) {
    int bonus = character.hasCapabilityFlag('passiveInsightBonus') ? 5 : 0;
    for (final g in character.activeGrants) {
      if (g.type == GrantType.passiveModifier &&
          g.payload['stat'] == 'passiveInsight') {
        bonus += (g.payload['flat'] as num?)?.toInt() ?? 0;
      }
    }
    final insMod = calculateSkillModifier(character, SkillType.insight);
    return 10 + insMod + bonus;
  }

  /// Calculates skill modifier for a specific 5e [SkillType].
  static int calculateSkillModifier(Character character, SkillType skill) {
    final abilityKey = skill.defaultAbility.name;
    final baseMod = character.effectiveAbilityScores.getModifier(abilityKey);
    final profMultiplier = character.getTraitProficiency(skill.name);

    int bonus = 0;
    if (profMultiplier > 0) {
      bonus = (character.proficiencyBonus * profMultiplier).floor();
    } else if (character.hasCapabilityFlag('jackOfAllTrades')) {
      bonus = (character.proficiencyBonus * 0.5).floor();
    }

    return baseMod + bonus;
  }

  /// Resolves the optimal attack ability for [weapon] considering weapon properties and feature grants.
  static AbilityType resolveCharacterAttackAbility({
    required Character character,
    required InventoryItemInstance weapon,
    AttributePool? scores,
    List<FeatureGrant>? additionalGrants,
  }) {
    final effectiveScores = scores ?? character.effectiveAbilityScores;
    final props = weapon.customProperties;
    final nameLower = weapon.displayName.toLowerCase();

    final isFinesse = props['isFinesse'] == true ||
        props['finesse'] == true ||
        (props['property'] != null &&
            props['property'].toString().toLowerCase().contains('finesse')) ||
        (props['properties'] != null &&
            props['properties'].toString().toLowerCase().contains('finesse')) ||
        nameLower.contains('shortsword') ||
        nameLower.contains('rapier') ||
        nameLower.contains('scimitar') ||
        nameLower.contains('dagger') ||
        nameLower.contains('whip');

    final isRanged = props['isRanged'] == true ||
        props['ranged'] == true ||
        nameLower.contains('longbow') ||
        nameLower.contains('shortbow') ||
        nameLower.contains('crossbow') ||
        nameLower.contains('blowgun') ||
        nameLower.contains('sling');

    // Check attack ability substitution grants
    final allGrants = [
      ...character.activeGrants,
      if (additionalGrants != null) ...additionalGrants
    ];
    for (final grant in allGrants) {
      if (grant.type == GrantType.attackAbilitySubstitution) {
        final substitute = grant.payload['ability']?.toString();
        if (substitute != null) {
          final parsed = AbilityType.fromLooseString(substitute);
          final substituteMod = effectiveScores.getModifier(parsed.name);
          final baseMod = isRanged
              ? effectiveScores.getModifier('dexterity')
              : effectiveScores.getModifier('strength');
          if (substituteMod > baseMod) {
            return parsed;
          }
        }
      }
    }

    if (isFinesse) {
      final strMod = effectiveScores.getModifier('strength');
      final dexMod = effectiveScores.getModifier('dexterity');
      return dexMod >= strMod ? AbilityType.dexterity : AbilityType.strength;
    }

    if (isRanged) {
      return AbilityType.dexterity;
    }

    return AbilityType.strength;
  }

  static int calculatePassivePerception(Character character) =>
      calculateCharacterPassivePerception(character);

  static int calculatePassiveInsight(Character character) =>
      calculateCharacterPassiveInsight(character);

  static int calculatePassiveInvestigation(Character character) =>
      calculateCharacterPassiveInvestigation(character);

  static AbilityType resolveEffectiveAttackAbility({
    required AttributePool scores,
    required InventoryItemInstance weapon,
    Character? character,
    List<FeatureGrant>? additionalGrants,
  }) {
    if (character != null) {
      return resolveCharacterAttackAbility(
        character: character,
        weapon: weapon,
        scores: scores,
        additionalGrants: additionalGrants,
      );
    }

    final props = weapon.customProperties;
    final nameLower = weapon.displayName.toLowerCase();

    final isFinesse = props['isFinesse'] == true ||
        props['finesse'] == true ||
        (props['property'] != null &&
            props['property'].toString().toLowerCase().contains('finesse')) ||
        (props['properties'] != null &&
            props['properties'].toString().toLowerCase().contains('finesse')) ||
        nameLower.contains('shortsword') ||
        nameLower.contains('rapier') ||
        nameLower.contains('scimitar') ||
        nameLower.contains('dagger') ||
        nameLower.contains('whip');

    final isRanged = props['isRanged'] == true ||
        props['ranged'] == true ||
        nameLower.contains('longbow') ||
        nameLower.contains('shortbow') ||
        nameLower.contains('crossbow') ||
        nameLower.contains('blowgun') ||
        nameLower.contains('sling');

    final isThrown = props['isThrown'] == true ||
        props['thrown'] == true ||
        (props['property'] != null &&
            props['property'].toString().toLowerCase().contains('thrown')) ||
        (props['properties'] != null &&
            props['properties'].toString().toLowerCase().contains('thrown'));

    if (additionalGrants != null) {
      for (final grant in additionalGrants) {
        if (grant.type == GrantType.attackAbilitySubstitution) {
          final substitute = grant.payload['ability']?.toString();
          if (substitute != null) {
            final parsed = AbilityType.fromLooseString(substitute);
            final substituteMod = scores.getModifier(parsed.name);
            final baseMod = isRanged
                ? scores.getModifier('dexterity')
                : scores.getModifier('strength');
            if (substituteMod > baseMod) {
              return parsed;
            }
          }
        }
      }
    }

    if (isFinesse) {
      final strMod = scores.getModifier('strength');
      final dexMod = scores.getModifier('dexterity');
      return dexMod >= strMod ? AbilityType.dexterity : AbilityType.strength;
    }

    if (isRanged && !isThrown) {
      return AbilityType.dexterity;
    }

    return AbilityType.strength;
  }
}
