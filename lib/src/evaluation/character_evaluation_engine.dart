import 'package:vtt_engine_core/models/entity_reference.dart';
import '../rules/ruleset_edition.dart';
import '../mechanics/weapon_mastery.dart';
import '../spellcasting/spellcasting_rules_engine.dart';
import 'dart:math' as math;
import 'package:meta/meta.dart';
import '../models/core_types.dart';
import '../models/character_models.dart';
import '../models/spell_monster_equipment.dart';
import '../models/feature_grant.dart';



import '../models/i_entity_resolver.dart';
import 'character_stat_calculator.dart' show ComputedAttackProfile;
import '../attributes/dnd_5e_rules_engine.dart';
import '../rules/dnd_ruleset_strategy.dart';

export 'character_stat_calculator.dart' show ComputedAttackProfile;
export '../rules/dnd_ruleset_strategy.dart';

/// Fully evaluated and reactive stat calculation result for a Character.
@immutable
class EvaluatedCharacterStats {
  final AbilityScores effectiveScores;
  final Map<AbilityType, int> abilityModifiers;
  final int proficiencyBonus;
  final int effectiveMaxAttunementSlots;
  final int attunedItemCount;
  final int armorClass;
  final String armorClassBreakdown;
  final int maxHp;
  final int speedFeet;
  final int initiativeBonus;
  final String initiativeBonusString;
  final Map<AbilityType, int> savingThrowModifiers;
  final Map<SkillType, int> skillModifiers;
  final int passivePerception;
  final int passiveInsight;
  final int passiveInvestigation;
  final Map<String, int> spellSaveDcs;
  final Map<String, int> spellAttackBonuses;
  final SpellSlotPool computedSpellSlots;
  final List<ComputedAttackProfile> attackProfiles;
  final List<String> activeBuffNotes;
  final EncumbranceStatus? encumbrance;
  final ExhaustionEffects? exhaustion;
  final int? grappleShoveSaveDc;
  final String? grappleShoveSummary;
  final List<WeaponMasteryProperty> activeWeaponMasteries;
  final RulesetEdition rulesEdition;

  const EvaluatedCharacterStats({
    required this.effectiveScores,
    required this.abilityModifiers,
    required this.proficiencyBonus,
    required this.effectiveMaxAttunementSlots,
    required this.attunedItemCount,
    required this.armorClass,
    required this.armorClassBreakdown,
    required this.maxHp,
    required this.speedFeet,
    required this.initiativeBonus,
    required this.initiativeBonusString,
    required this.savingThrowModifiers,
    required this.skillModifiers,
    required this.passivePerception,
    required this.passiveInsight,
    required this.passiveInvestigation,
    required this.spellSaveDcs,
    required this.spellAttackBonuses,
    required this.computedSpellSlots,
    required this.attackProfiles,
    required this.activeBuffNotes,
    this.encumbrance,
    this.exhaustion,
    this.grappleShoveSaveDc,
    this.grappleShoveSummary,
    this.activeWeaponMasteries = const [],
    this.rulesEdition = RulesetEdition.v2014,
  });

  /// Primary spell attack bonus (first class or default proficiency bonus).
  int get spellAttackBonus => spellAttackBonuses.isNotEmpty
      ? spellAttackBonuses.values.first
      : proficiencyBonus;
}

/// Pure Dart derivation engine for computing dynamic stats from base Character models,
/// equipped & attuned inventory items, and class progression.
class CharacterEvaluationEngine {
  /// Pluggable compendium lookup hooks
  static dynamic Function(String idOrName)? magicItemLookupHook;
  static dynamic Function(String slug)? featLookupHook;
  static dynamic Function(String slug)? classLookupHook;
  /// Evaluates a [Character] model into [EvaluatedCharacterStats].
  /// Optionally accepts a [IEntityResolver] if item references need compendium fallback.
  static EvaluatedCharacterStats evaluate(
    Character character, {
    IEntityResolver? resolver,
    RulesetEdition? overrideEdition,
  }) {
    final buffNotes = <String>[];
    final edition = overrideEdition ?? character.rulesEdition;
    final strategy = RulesetStrategy.forEdition(edition);

    // 0. Evaluate Exhaustion Condition
    int exhaustionLevel = 0;
    for (final cond in character.conditions) {
      if (cond.conditionName.toLowerCase() == 'exhaustion') {
        final lvl = (cond.parameters['level'] as num?)?.toInt() ?? 1;
        exhaustionLevel = math.max(exhaustionLevel, lvl);
      }
    }
    final exhaustion = strategy.evaluateExhaustion(exhaustionLevel);
    if (exhaustion.level > 0) {
      if (edition == RulesetEdition.v2024) {
        buffNotes.add(
            'Exhaustion (Level ${exhaustion.level}): ${exhaustion.d20TestPenalty} to d20 tests, -${exhaustion.speedReductionFeet} ft Speed');
      } else {
        buffNotes.add('Exhaustion (Tier ${exhaustion.level}) Active');
      }
    }

    // 1. Calculate Attunement Slot Limits (Standard 3, scaling with custom properties & feature grants)
    int maxAttunement = character.maxAttunementSlots;

    // Check custom properties for attunement overrides
    if (character.customProperties['overrideMaxAttunementSlots'] is num) {
      maxAttunement =
          (character.customProperties['overrideMaxAttunementSlots'] as num)
              .toInt();
    }
    if (character.customProperties['attunementSlotBonus'] is num) {
      maxAttunement +=
          (character.customProperties['attunementSlotBonus'] as num).toInt();
    }
    for (final feat in character.feats) {
      if (feat.customProperties['attunementSlotBonus'] is num) {
        maxAttunement +=
            (feat.customProperties['attunementSlotBonus'] as num).toInt();
      }
    }

    final attunedCount = character.inventory.where((i) => i.isAttuned).length;

    // 2. Helper to get merged custom properties for an inventory item
    Map<String, dynamic> getItemProperties(InventoryItemInstance instance) {
      final merged = Map<String, dynamic>.from(instance.customProperties);
      if (resolver != null) {
        final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
        if (res.isResolved && res.entity != null) {
          for (final entry in res.entity!.customProperties.entries) {
            merged.putIfAbsent(entry.key, () => entry.value);
          }
        }
      }

      // Fallback: Lookup from MagicItemLibrary if customProperties lacks bonus keys
      final rawSlug = instance.itemRef.slug.toLowerCase().replaceAll('-', '_');
      final dynamic magicItem = CharacterEvaluationEngine.magicItemLookupHook?.call(rawSlug) ??
          CharacterEvaluationEngine.magicItemLookupHook?.call('item_$rawSlug') ??
          CharacterEvaluationEngine.magicItemLookupHook?.call(instance.displayName);
      if (magicItem != null) {
        merged.putIfAbsent('category', () => magicItem.category.name);
        merged.putIfAbsent('tags', () => magicItem.tags);
      }

      final nameAndSummary =
          '${instance.displayName} ${magicItem?.rules2024.summary ?? ""} ${magicItem?.rules2014.summary ?? ""}';

      // Check Rod of the Pact Keeper (+1, +2, +3)
      final pactKeeperMatch = RegExp(
              r'rod\s+of\s+the\s+pact\s+keeper(?:,\s*|\s*)\+(\d+)',
              caseSensitive: false)
          .firstMatch(nameAndSummary);
      if (pactKeeperMatch != null) {
        final b = int.tryParse(pactKeeperMatch.group(1)!) ?? 0;
        merged.putIfAbsent('bonusSpellAttack', () => b);
        merged.putIfAbsent('bonusSpellSaveDc', () => b);
        merged.putIfAbsent('spellDcBonus', () => b);
        merged.putIfAbsent('spellClass', () => 'warlock');
      }

      // Check Wand of the War Mage (+1, +2, +3)
      final warMageMatch = RegExp(
              r'wand\s+of\s+the\s+war\s+mage(?:,\s*|\s*)\+(\d+)',
              caseSensitive: false)
          .firstMatch(nameAndSummary);
      if (warMageMatch != null) {
        final b = int.tryParse(warMageMatch.group(1)!) ?? 0;
        merged.putIfAbsent('bonusSpellAttack', () => b);
      }

      // General +N spell bonus regex pattern
      final genSpellMatch = RegExp(
              r'\+(\d+)\s+(?:bonus\s+)?to\s+(?:warlock\s+)?spell\s+attack\s+rolls',
              caseSensitive: false)
          .firstMatch(nameAndSummary);
      if (genSpellMatch != null) {
        final b = int.tryParse(genSpellMatch.group(1)!) ?? 0;
        merged.putIfAbsent('bonusSpellAttack', () => b);
        if (nameAndSummary.toLowerCase().contains('saving throw dc') ||
            nameAndSummary.toLowerCase().contains('spell save dc')) {
          merged.putIfAbsent('bonusSpellSaveDc', () => b);
          merged.putIfAbsent('spellDcBonus', () => b);
        }
      }

      // Check Armor / Shield AC bonuses (+1, +2, +3)
      final acMatch = RegExp(
              r'(?:armor|shield|ring of protection|cloak of protection)(?:,\s*|\s*)\+(\d+)',
              caseSensitive: false)
          .firstMatch(nameAndSummary);
      if (acMatch != null) {
        final b = int.tryParse(acMatch.group(1)!) ?? 0;
        merged.putIfAbsent('bonusAc', () => b);
        merged.putIfAbsent('acBonus', () => b);
      }

      return merged;
    }

    // 3. Ability Score Derivation (Base + Bonus + Item Bonuses / Overrides)
    var str = character.baseScores.strength + character.bonusScores.strength;
    var dex = character.baseScores.dexterity + character.bonusScores.dexterity;
    var con =
        character.baseScores.constitution + character.bonusScores.constitution;
    var intl =
        character.baseScores.intelligence + character.bonusScores.intelligence;
    var wis = character.baseScores.wisdom + character.bonusScores.wisdom;
    var cha = character.baseScores.charisma + character.bonusScores.charisma;

    // Accumulate item bonuses & overrides
    for (final instance in character.equippedItems) {
      // Must be attuned if attunement is required
      if (instance.requiresAttunement && !instance.isAttuned) continue;

      final props = getItemProperties(instance);

      // Direct bonus keys
      str += (props['strengthBonus'] as num?)?.toInt() ??
          (props['bonusStrength'] as num?)?.toInt() ??
          0;
      dex += (props['dexterityBonus'] as num?)?.toInt() ??
          (props['bonusDexterity'] as num?)?.toInt() ??
          0;
      con += (props['constitutionBonus'] as num?)?.toInt() ??
          (props['bonusConstitution'] as num?)?.toInt() ??
          0;
      intl += (props['intelligenceBonus'] as num?)?.toInt() ??
          (props['bonusIntelligence'] as num?)?.toInt() ??
          0;
      wis += (props['wisdomBonus'] as num?)?.toInt() ??
          (props['bonusWisdom'] as num?)?.toInt() ??
          0;
      cha += (props['charismaBonus'] as num?)?.toInt() ??
          (props['bonusCharisma'] as num?)?.toInt() ??
          0;

      // Nested abilityBonuses map
      if (props['abilityBonuses'] is Map) {
        final bonuses = props['abilityBonuses'] as Map;
        str += (bonuses['strength'] as num?)?.toInt() ?? 0;
        dex += (bonuses['dexterity'] as num?)?.toInt() ?? 0;
        con += (bonuses['constitution'] as num?)?.toInt() ?? 0;
        intl += (bonuses['intelligence'] as num?)?.toInt() ?? 0;
        wis += (bonuses['wisdom'] as num?)?.toInt() ?? 0;
        cha += (bonuses['charisma'] as num?)?.toInt() ?? 0;
      }

      // Direct override keys (e.g. overrideStrength: 21, overrideConstitution: 19)
      if (props['overrideStrength'] is num) {
        final overrideVal = (props['overrideStrength'] as num).toInt();
        if (overrideVal > str) {
          str = overrideVal;
          buffNotes.add('${instance.displayName}: STR set to $overrideVal');
        }
      }
      if (props['overrideDexterity'] is num) {
        final overrideVal = (props['overrideDexterity'] as num).toInt();
        if (overrideVal > dex) {
          dex = overrideVal;
          buffNotes.add('${instance.displayName}: DEX set to $overrideVal');
        }
      }
      if (props['overrideConstitution'] is num) {
        final overrideVal = (props['overrideConstitution'] as num).toInt();
        if (overrideVal > con) {
          con = overrideVal;
          buffNotes.add('${instance.displayName}: CON set to $overrideVal');
        }
      }
      if (props['overrideIntelligence'] is num) {
        final overrideVal = (props['overrideIntelligence'] as num).toInt();
        if (overrideVal > intl) {
          intl = overrideVal;
          buffNotes.add('${instance.displayName}: INT set to $overrideVal');
        }
      }
      if (props['overrideWisdom'] is num) {
        final overrideVal = (props['overrideWisdom'] as num).toInt();
        if (overrideVal > wis) {
          wis = overrideVal;
          buffNotes.add('${instance.displayName}: WIS set to $overrideVal');
        }
      }
      if (props['overrideCharisma'] is num) {
        final overrideVal = (props['overrideCharisma'] as num).toInt();
        if (overrideVal > cha) {
          cha = overrideVal;
          buffNotes.add('${instance.displayName}: CHA set to $overrideVal');
        }
      }

      // Nested abilityOverrides map
      if (props['abilityOverrides'] is Map) {
        final overrides = props['abilityOverrides'] as Map;
        if (overrides['strength'] is num) {
          final o = (overrides['strength'] as num).toInt();
          if (o > str) str = o;
        }
        if (overrides['dexterity'] is num) {
          final o = (overrides['dexterity'] as num).toInt();
          if (o > dex) dex = o;
        }
        if (overrides['constitution'] is num) {
          final o = (overrides['constitution'] as num).toInt();
          if (o > con) con = o;
        }
        if (overrides['intelligence'] is num) {
          final o = (overrides['intelligence'] as num).toInt();
          if (o > intl) intl = o;
        }
        if (overrides['wisdom'] is num) {
          final o = (overrides['wisdom'] as num).toInt();
          if (o > wis) wis = o;
        }
        if (overrides['charisma'] is num) {
          final o = (overrides['charisma'] as num).toInt();
          if (o > cha) cha = o;
        }
      }
    }

    final effectiveScores = AbilityScores(
      strength: str,
      dexterity: dex,
      constitution: con,
      intelligence: intl,
      wisdom: wis,
      charisma: cha,
    );

    final abilityMods = <AbilityType, int>{
      AbilityType.strength: effectiveScores.strength.dndModifier,
      AbilityType.dexterity: effectiveScores.dexterity.dndModifier,
      AbilityType.constitution: effectiveScores.constitution.dndModifier,
      AbilityType.intelligence: effectiveScores.intelligence.dndModifier,
      AbilityType.wisdom: effectiveScores.wisdom.dndModifier,
      AbilityType.charisma: effectiveScores.charisma.dndModifier,
    };

    final profBonus = character.proficiencyBonus;

    // Encumbrance
    final isPowerfulBuild =
        character.customProperties['powerfulBuild'] == true ||
            character.speciesRef.slug.toLowerCase().contains('goliath') ||
            character.speciesRef.slug.toLowerCase().contains('firbolg');
    final encumbrance = strategy.calculateEncumbrance(
      strengthScore: effectiveScores.strength,
      inventory: character.inventory,
      totalCoinCount: character.purse.totalCoins,
      isPowerfulBuildOrLarge: isPowerfulBuild,
    );
    if (encumbrance.variantTier != EncumbranceTier.unencumbered) {
      buffNotes.add(
          'Encumbrance (${encumbrance.variantTier.displayName}): -${encumbrance.speedPenaltyFeet} ft Speed');
    }

    // 4. Armor Class Calculation
    int baseAc = 10;
    String armorDesc = '10 (Base Unarmored)';
    int dexAcBonus = abilityMods[AbilityType.dexterity]!;
    int shieldBonus = 0;
    String? shieldDesc;
    int magicAcBonus = 0;
    final List<String> magicAcSources = [];
    bool hasEquippedArmor = false;

    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final props = getItemProperties(instance);

      final nameLower = instance.displayName.toLowerCase();
      final slugLower = instance.itemRef.slug.toLowerCase();
      final isStandardArmor = nameLower.contains('armor') ||
          nameLower.contains('plate') ||
          nameLower.contains('chain mail') ||
          nameLower.contains('ring mail') ||
          nameLower.contains('splint') ||
          nameLower.contains('leather') ||
          nameLower.contains('padded') ||
          nameLower.contains('hide') ||
          nameLower.contains('breastplate') ||
          slugLower.contains('armor') ||
          slugLower.contains('plate') ||
          slugLower.contains('breastplate');

      final isArmorSlot = instance.equippedSlot == EquipmentSlot.armor;
      final isArmorType = props['armorType'] != null ||
          props['baseAc'] != null ||
          (props['category'] == 'armor' && !nameLower.contains('shield')) ||
          isStandardArmor;

      if (isArmorSlot ||
          (isArmorType &&
              instance.equippedSlot != EquipmentSlot.shield &&
              props['isShield'] != true &&
              !nameLower.contains('shield'))) {
        hasEquippedArmor = true;
        int itemBaseAc = (props['baseAc'] as num?)?.toInt() ??
            (props['ac'] as num?)?.toInt() ??
            0;
        String armorType = (props['armorType']?.toString() ?? '').toLowerCase();
        if (armorType.isEmpty) {
          final t = (props['type']?.toString() ?? '').toLowerCase();
          if (t == 'ha' || t.contains('heavy')) {
            armorType = 'heavy';
          } else if (t == 'ma' || t.contains('medium')) {
            armorType = 'medium';
          } else if (t == 'la' || t.contains('light')) {
            armorType = 'light';
          }
        }
        int? maxDex = (props['maxDexBonus'] as num?)?.toInt();

        // Fallback for standard armor names if baseAc or armorType is unspecified
        if (itemBaseAc == 0 || armorType.isEmpty) {
          final normalized = '$nameLower $slugLower'.replaceAll('-', ' ');
          if (normalized.contains('breastplate')) {
            itemBaseAc = 14;
            armorType = 'medium';
            maxDex ??= 2;
          } else if (normalized.contains('half plate')) {
            itemBaseAc = 15;
            armorType = 'medium';
            maxDex ??= 2;
          } else if (normalized.contains('plate')) {
            itemBaseAc = 18;
            armorType = 'heavy';
            maxDex ??= 0;
          } else if (normalized.contains('splint')) {
            itemBaseAc = 17;
            armorType = 'heavy';
            maxDex ??= 0;
          } else if (normalized.contains('chain mail')) {
            itemBaseAc = 16;
            armorType = 'heavy';
            maxDex ??= 0;
          } else if (normalized.contains('ring mail')) {
            itemBaseAc = 14;
            armorType = 'heavy';
            maxDex ??= 0;
          } else if (normalized.contains('scale mail')) {
            itemBaseAc = 14;
            armorType = 'medium';
            maxDex ??= 2;
          } else if (normalized.contains('chain shirt') ||
              normalized.contains('elven chain')) {
            itemBaseAc = 13;
            armorType = 'medium';
            maxDex ??= 2;
          } else if (normalized.contains('hide')) {
            itemBaseAc = 12;
            armorType = 'medium';
            maxDex ??= 2;
          } else if (normalized.contains('studded leather') ||
              normalized.contains('studded')) {
            itemBaseAc = 12;
            armorType = 'light';
          } else if (normalized.contains('leather') ||
              normalized.contains('padded')) {
            itemBaseAc = 11;
            armorType = 'light';
          } else {
            if (itemBaseAc == 0) itemBaseAc = 10;
            if (armorType.isEmpty) armorType = 'light';
          }
        }

        baseAc = itemBaseAc;
        if (armorType == 'heavy') {
          dexAcBonus = 0;
          armorDesc = '$itemBaseAc (${instance.displayName})';
        } else if (armorType == 'medium') {
          final cap = maxDex ?? 2;
          dexAcBonus = math.min(abilityMods[AbilityType.dexterity]!, cap);
          armorDesc =
              '$itemBaseAc (${instance.displayName}) + $dexAcBonus DEX (capped at $cap)';
        } else {
          // Light armor
          dexAcBonus = abilityMods[AbilityType.dexterity]!;
          armorDesc = '$itemBaseAc (${instance.displayName}) + $dexAcBonus DEX';
        }

        int armorMagic = (props['acBonus'] as num?)?.toInt() ??
            (props['bonusAc'] as num?)?.toInt() ??
            (props['magicBonus'] as num?)?.toInt() ??
            0;
        if (armorMagic == 0) {
          final plusMatch = RegExp(r'\+(\d+)').firstMatch(instance.displayName);
          if (plusMatch != null) {
            armorMagic = int.tryParse(plusMatch.group(1)!) ?? 0;
          }
        }
        if (armorMagic > 0) {
          magicAcBonus += armorMagic;
          magicAcSources.add('+$armorMagic (${instance.displayName})');
        }
      } else if (instance.equippedSlot == EquipmentSlot.shield ||
          props['isShield'] == true ||
          nameLower.contains('shield')) {
        final sBonus = (props['acBonus'] as num?)?.toInt() ??
            (props['bonusAc'] as num?)?.toInt() ??
            (props['shieldBonus'] as num?)?.toInt() ??
            2;
        shieldBonus += sBonus;
        shieldDesc = '+$sBonus (${instance.displayName})';
      } else {
        final otherBonus = (props['acBonus'] as num?)?.toInt() ??
            (props['bonusAc'] as num?)?.toInt() ??
            (props['magicBonus'] as num?)?.toInt() ??
            0;
        if (otherBonus != 0) {
          magicAcBonus += otherBonus;
          magicAcSources.add(
              '${otherBonus >= 0 ? "+$otherBonus" : "$otherBonus"} (${instance.displayName})');
        }
      }
    }

    // Unarmored Defense check if no armor is equipped
    if (!hasEquippedArmor) {
      final classSlugs = character.progression.classes
          .map((c) => c.classRef.slug.toLowerCase())
          .toSet();

      if (classSlugs.contains('barbarian')) {
        final conBonus = abilityMods[AbilityType.constitution]!;
        baseAc = 10;
        dexAcBonus = abilityMods[AbilityType.dexterity]!;
        armorDesc =
            '10 (Unarmored) + $dexAcBonus DEX + $conBonus CON (Barbarian)';
        baseAc += conBonus;
      } else if (classSlugs.contains('monk') && shieldBonus == 0) {
        final wisBonus = abilityMods[AbilityType.wisdom]!;
        baseAc = 10;
        dexAcBonus = abilityMods[AbilityType.dexterity]!;
        armorDesc = '10 (Unarmored) + $dexAcBonus DEX + $wisBonus WIS (Monk)';
        baseAc += wisBonus;
      } else {
        armorDesc = '10 (Unarmored) + $dexAcBonus DEX';
      }
    }

    final totalAc = baseAc + dexAcBonus + shieldBonus + magicAcBonus;
    final breakdownParts = <String>[armorDesc];
    if (shieldBonus > 0 && shieldDesc != null) breakdownParts.add(shieldDesc);
    for (final src in magicAcSources) {
      breakdownParts.add(src);
    }
    final breakdownString = '${breakdownParts.join(' + ')} = $totalAc AC';

    // 5. HP, Speed, and Initiative (Retroactive CON Scaling across all Hit Dice)
    var maxHp = 0;
    final conMod = abilityMods[AbilityType.constitution]!;
    for (int i = 0; i < character.progression.classes.length; i++) {
      final c = character.progression.classes[i];
      if (c.isStartingClass || i == 0) {
        // Starting class level 1 gets max hit die + CON
        maxHp += c.hitDieSides + conMod;
        // Remaining levels
        for (int l = 1; l < c.level; l++) {
          final rolledIndex = l - 1;
          final rolled = (rolledIndex < c.hitPointsRolled.length)
              ? c.hitPointsRolled[rolledIndex]
              : c.averageHpPerLevel;
          maxHp += math.max(1, rolled + conMod);
        }
      } else {
        // Multiclass slices: all levels gain rolled/average + CON
        for (int l = 0; l < c.level; l++) {
          final rolled = (l < c.hitPointsRolled.length)
              ? c.hitPointsRolled[l]
              : c.averageHpPerLevel;
          maxHp += math.max(1, rolled + conMod);
        }
      }
    }

    // Tough feat
    for (final feat in character.feats) {
      if (feat.slug == 'tough' || feat.slug == 'toughness') {
        maxHp += character.totalLevel * 2;
        buffNotes.add('Tough Feat: +${character.totalLevel * 2} HP');
      }
    }

    // Dwarven Toughness (Hill Dwarf or 2024 Dwarf)
    final speciesSlug = character.speciesRef.slug.toLowerCase();
    if (character.customProperties['dwarvenToughness'] == true ||
        (speciesSlug.contains('dwarf') &&
            (edition == RulesetEdition.v2024 ||
                speciesSlug.contains('hill')))) {
      maxHp += character.totalLevel;
      buffNotes.add('Dwarven Toughness: +${character.totalLevel} HP');
    }

    // Apply 2014 Exhaustion Tier 4 (halve max HP)
    if (exhaustion.maxHpMultiplier < 1.0) {
      maxHp = (maxHp * exhaustion.maxHpMultiplier).floor();
    }
    if (maxHp <= 0) maxHp = 1;

    var speed = character.baseSpeedFeet;
    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final props = getItemProperties(instance);
      if (props['speedBonus'] is num) {
        speed += (props['speedBonus'] as num).toInt();
      }
    }

    // Subtract encumbrance & exhaustion speed penalties
    speed = math.max(0, speed - encumbrance.speedPenaltyFeet);
    if (exhaustion.speedMultiplier < 1.0) {
      speed = (speed * exhaustion.speedMultiplier).floor();
    }
    speed = math.max(0, speed - exhaustion.speedReductionFeet);

    final initBonus =
        abilityMods[AbilityType.dexterity]! + exhaustion.d20TestPenalty;
    final initBonusString = initBonus >= 0 ? '+$initBonus' : '$initBonus';

    // 6. Saving Throws
    final savingThrows = <AbilityType, int>{};
    for (final ability in AbilityType.values) {
      var saveMod = abilityMods[ability]!;
      if (character.savingThrowProficiencies.contains(ability)) {
        saveMod += profBonus;
      }
      // Check magic item save bonuses
      for (final instance in character.equippedItems) {
        if (instance.requiresAttunement && !instance.isAttuned) continue;
        final props = getItemProperties(instance);
        if (props['savingThrowBonus'] is num) {
          saveMod += (props['savingThrowBonus'] as num).toInt();
        }
      }
      saveMod += exhaustion.d20TestPenalty;
      savingThrows[ability] = saveMod;
    }

    // 7. Skill Modifiers
    final grantedExpertises = <SkillType>{};
    for (final featRef in character.feats) {
      final dynamic feat = CharacterEvaluationEngine.featLookupHook?.call(featRef.slug);
      if (feat != null && feat.grants.isNotEmpty) {
        grantedExpertises.addAll(GrantEvaluator.evaluateExpertiseGrants(feat.grants).map(SkillType.fromLooseString).whereType<SkillType>());
      }
    }

    final skillMods = <SkillType, int>{};
    for (final skill in SkillType.values) {
      final ability = skill.defaultAbility;
      final mod = abilityMods[ability]!;
      var profLevel =
          character.skillProficiencies[skill] ?? SkillProficiencyLevel.none;
      if (grantedExpertises.contains(skill) &&
          profLevel != SkillProficiencyLevel.expertise) {
        profLevel = SkillProficiencyLevel.expertise;
      }
      final skillTotal = mod +
          (profBonus * profLevel.multiplier).floor() +
          exhaustion.d20TestPenalty;
      skillMods[skill] = skillTotal;
    }

    final passivePerc = 10 +
        (skillMods[SkillType.perception] ?? abilityMods[AbilityType.wisdom]!);
    final passiveIns =
        10 + (skillMods[SkillType.insight] ?? abilityMods[AbilityType.wisdom]!);
    final passiveInvest = 10 +
        (skillMods[SkillType.investigation] ??
            abilityMods[AbilityType.intelligence]!);

    // 8. Spell Save DCs & Attack Bonuses
    final spellSaveDcs = <String, int>{};
    final spellAttackBonuses = <String, int>{};

    for (final c in character.progression.classes) {
      final className = c.classRef.displayName;
      final slug = c.classRef.slug.toLowerCase();

      AbilityType castingAbility;
      if (slug.contains('wizard')) {
        castingAbility = AbilityType.intelligence;
      } else if (slug.contains('cleric') ||
          slug.contains('druid') ||
          slug.contains('ranger')) {
        castingAbility = AbilityType.wisdom;
      } else if (slug.contains('bard') ||
          slug.contains('paladin') ||
          slug.contains('sorcerer') ||
          slug.contains('warlock')) {
        castingAbility = AbilityType.charisma;
      } else {
        castingAbility = AbilityType.intelligence;
      }

      var itemSpellAtkBonus = 0;
      var itemSpellDcBonus = 0;
      for (final instance in character.equippedItems) {
        if (instance.requiresAttunement && !instance.isAttuned) continue;
        final props = getItemProperties(instance);

        // Check if restricted to a specific class (e.g. Warlock for Rod of the Pact Keeper)
        final itemClass =
            (props['spellClass'] ?? props['class'])?.toString().toLowerCase();
        if (itemClass != null &&
            itemClass.isNotEmpty &&
            !slug.contains(itemClass)) {
          continue;
        }

        // Spell Attack Bonus
        final rawAtk = props['bonusSpellAttack'] ??
            props['spellAttackBonus'] ??
            props['spellBonus'];
        if (rawAtk != null) {
          final val = rawAtk is num
              ? rawAtk.toInt()
              : int.tryParse(rawAtk.toString().replaceAll('+', '').trim());
          if (val != null) itemSpellAtkBonus += val;
        }

        // Spell Save DC Bonus
        final rawDc = props['bonusSpellSaveDc'] ??
            props['spellDcBonus'] ??
            props['spellBonus'];
        if (rawDc != null) {
          final val = rawDc is num
              ? rawDc.toInt()
              : int.tryParse(rawDc.toString().replaceAll('+', '').trim());
          if (val != null) itemSpellDcBonus += val;
        }
      }

      final castMod = abilityMods[castingAbility]!;
      final dc = 8 + profBonus + castMod + itemSpellDcBonus;
      final atk =
          profBonus + castMod + itemSpellAtkBonus + exhaustion.d20TestPenalty;
      spellSaveDcs[className] = dc;
      spellSaveDcs[slug] = dc;
      spellAttackBonuses[className] = atk;
      spellAttackBonuses[slug] = atk;
    }

    // Compute multiclass spell slots
    final computedSlots =
        _computeMulticlassSpellSlots(character.progression.classes, edition);

    // 9. Attack Profiles & Weapon Masteries
    final attackProfiles = <ComputedAttackProfile>[];
    final activeMasteries = <WeaponMasteryProperty>[];

    for (final instance in character.equippedItems) {
      final props = getItemProperties(instance);
      final nameLower = instance.displayName.toLowerCase();
      final slugLower = instance.itemRef.slug.toLowerCase();

      final isArmorOrShield = instance.equippedSlot == EquipmentSlot.armor ||
          instance.equippedSlot == EquipmentSlot.shield ||
          props['armorType'] != null ||
          props['baseAc'] != null ||
          props['isShield'] == true ||
          props['category'] == 'armor' ||
          props['category'] == 'shield' ||
          nameLower.contains('armor') ||
          nameLower.contains('shield') ||
          nameLower.contains('plate') ||
          slugLower.contains('armor') ||
          slugLower.contains('plate');

      if (isArmorOrShield &&
          props['weaponType'] == null &&
          props['damageDice'] == null) {
        continue;
      }

      final isWeaponSlot = instance.equippedSlot == EquipmentSlot.mainHand ||
          instance.equippedSlot == EquipmentSlot.offHand ||
          instance.equippedSlot == EquipmentSlot.twoHand;
      final isWeapon = isWeaponSlot ||
          props['weaponType'] != null ||
          props['damageDice'] != null;

      if (isWeapon) {
        final weaponName = instance.displayName;
        final isRanged = props['isRanged'] == true || props['ranged'] == true;
        final magicWeaponBonus = (props['attackBonus'] as num?)?.toInt() ??
            (props['magicBonus'] as num?)?.toInt() ??
            0;

        final effectiveAbility = character.getEffectiveAttackAbility(
          instance,
          scores: effectiveScores,
        );
        final abilityMod = abilityMods[effectiveAbility]!;

        final isProficient = props['isProficient'] != false;
        final totalAttackBonus = abilityMod +
            (isProficient ? profBonus : 0) +
            magicWeaponBonus +
            exhaustion.d20TestPenalty;
        final attackBonusStr =
            totalAttackBonus >= 0 ? '+$totalAttackBonus' : '$totalAttackBonus';

        final baseDice = props['damageDice']?.toString() ??
            props['damageFormula']?.toString() ??
            '1d8';
        final isOffhand = instance.equippedSlot == EquipmentSlot.offHand;
        final damageMod =
            isOffhand ? magicWeaponBonus : (abilityMod + magicWeaponBonus);
        final damageModStr = damageMod > 0
            ? ' + $damageMod'
            : (damageMod < 0 ? ' - ${damageMod.abs()}' : '');
        final formula = '$baseDice$damageModStr';

        final dmgTypeStr = props['damageType']?.toString() ?? 'slashing';
        final dmgType = DamageType.values.firstWhere(
          (d) => d.name.toLowerCase() == dmgTypeStr.toLowerCase(),
          orElse: () => DamageType.slashing,
        );

        // Weapon mastery
        WeaponMasteryProperty? activeMastery;
        final masteryKey =
            props['mastery']?.toString() ?? props['weaponMastery']?.toString();
        final masteryProp = WeaponMasteryProperty.tryParse(masteryKey);
        if (masteryProp != null) {
          EquipmentItem? equipEntity;
          if (resolver != null) {
            final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
            if (res.isResolved) equipEntity = res.entity;
          }
          final weaponEntity = equipEntity ??
              EquipmentItem(
                id: EntityId(
                    slug: instance.itemRef.slug, ruleset: RulesetVersion.v2024),
                name: instance.displayName,
                itemType: 'weapon',
                rarity: 'Common',
                requiresAttunement: instance.requiresAttunement,
                descriptionMarkdown: props['notes']?.toString() ??
                    props['propertiesMarkdown']?.toString() ??
                    '',
                customProperties: props,
              );

          if (strategy.canUseWeaponMastery(
              character: character,
              weapon: weaponEntity,
              mastery: masteryProp)) {
            activeMastery = masteryProp;
            if (!activeMasteries.contains(masteryProp)) {
              activeMasteries.add(masteryProp);
            }
          }
        }

        final noteStr = activeMastery != null
            ? '[Mastery: ${activeMastery.displayName}] ${props['notes']?.toString() ?? props['propertiesMarkdown']?.toString() ?? ""}'
            : props['notes']?.toString() ??
                props['propertiesMarkdown']?.toString();

        attackProfiles.add(ComputedAttackProfile(
          weaponName: weaponName,
          attackBonus: totalAttackBonus,
          attackBonusString: attackBonusStr,
          damageFormula: formula,
          damageType: dmgType,
          range:
              props['range']?.toString() ?? (isRanged ? '80/320 ft' : '5 ft'),
          isOffhand: isOffhand,
          notes: noteStr?.trim(),
          activeMastery: activeMastery,
        ));
      }
    }

    // Default Unarmed Strike if no weapons equipped
    if (attackProfiles.isEmpty) {
      final strMod = abilityMods[AbilityType.strength]!;
      final atkBonus = strMod + profBonus + exhaustion.d20TestPenalty;
      final atkBonusStr = atkBonus >= 0 ? '+$atkBonus' : '$atkBonus';
      final dmg = math.max(1, 1 + strMod);
      attackProfiles.add(ComputedAttackProfile(
        weaponName: 'Unarmed Strike',
        attackBonus: atkBonus,
        attackBonusString: atkBonusStr,
        damageFormula: '$dmg',
        damageType: DamageType.bludgeoning,
        range: '5 ft',
      ));
    }

    // 10. Grapple / Shove DC
    final grappleShove = strategy.calculateGrappleShoveDc(
      strengthModifier: abilityMods[AbilityType.strength]!,
      dexterityModifier: abilityMods[AbilityType.dexterity]!,
      proficiencyBonus: profBonus,
    );

    return EvaluatedCharacterStats(
      effectiveScores: effectiveScores,
      abilityModifiers: abilityMods,
      proficiencyBonus: profBonus,
      effectiveMaxAttunementSlots: maxAttunement,
      attunedItemCount: attunedCount,
      armorClass: totalAc,
      armorClassBreakdown: breakdownString,
      maxHp: maxHp,
      speedFeet: speed,
      initiativeBonus: initBonus,
      initiativeBonusString: initBonusString,
      savingThrowModifiers: savingThrows,
      skillModifiers: skillMods,
      passivePerception: passivePerc,
      passiveInsight: passiveIns,
      passiveInvestigation: passiveInvest,
      spellSaveDcs: spellSaveDcs,
      spellAttackBonuses: spellAttackBonuses,
      computedSpellSlots: computedSlots,
      attackProfiles: attackProfiles,
      activeBuffNotes: buffNotes,
      encumbrance: encumbrance,
      exhaustion: exhaustion,
      grappleShoveSaveDc: grappleShove.dc,
      grappleShoveSummary: grappleShove.formulaDescription,
      activeWeaponMasteries: activeMasteries,
      rulesEdition: edition,
    );
  }

  static SpellSlotPool _computeMulticlassSpellSlots(
    List<ClassLevelProgression> classes,
    RulesetEdition edition,
  ) {
    int fullCasterLevels = 0;
    int paladinLevels = 0;
    int rangerLevels = 0;
    int roundUpHalfCasterLevels = 0;
    int thirdCasterLevels = 0;
    int warlockLevels = 0;

    for (final cls in classes) {
      final slug = cls.classRef.slug.toLowerCase();
      switch (slug) {
        case 'wizard':
        case 'cleric':
        case 'druid':
        case 'bard':
        case 'sorcerer':
          fullCasterLevels += cls.level;
        case 'paladin':
          paladinLevels += cls.level;
        case 'ranger':
          rangerLevels += cls.level;
        case 'warlock':
          warlockLevels += cls.level;
        default:
          final customCls = CharacterEvaluationEngine.classLookupHook?.call(slug);
          final prog = customCls?.customProperties['spellcastingProgression']
                  ?.toString()
                  .toLowerCase() ??
              '';
          if (prog == 'half_round_up' || prog == 'halfcasterroundup') {
            roundUpHalfCasterLevels += cls.level;
          } else if (prog == 'full' || prog == 'fullcaster') {
            fullCasterLevels += cls.level;
          }
      }

      final subSlug = cls.subclassRef?.slug.toLowerCase() ?? '';
      if (subSlug.contains('eldritch_knight') ||
          subSlug.contains('arcane_trickster')) {
        thirdCasterLevels += cls.level;
      }
    }

    final ecl = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
      fullCasterLevels: fullCasterLevels,
      paladinLevels: paladinLevels,
      rangerLevels: rangerLevels,
      roundUpHalfCasterLevels: roundUpHalfCasterLevels,
      thirdCasterLevels: thirdCasterLevels,
      edition: edition,
    );

    final Map<int, int> maxSlots = {};
    if (ecl > 0) {
      final slotList = MulticlassSlotMatrix.getSpellSlots(ecl);
      for (int i = 0; i < slotList.length; i++) {
        final slotLevel = i + 1;
        final count = slotList[i];
        if (count > 0) {
          maxSlots[slotLevel] = count;
        }
      }
    }

    // Pact Magic (Separate, unmerged pool)
    int pactSlotLevel = 0;
    int pactCount = 0;
    if (warlockLevels > 0) {
      final pactData = PactMagicPool.fromWarlockLevel(warlockLevels);
      pactSlotLevel = pactData.slotLevel;
      pactCount = pactData.totalSlots;
    }

    return SpellSlotPool(
      currentSlots: Map<int, int>.from(maxSlots),
      maxSlots: maxSlots,
      pactMagicSlotLevel: pactSlotLevel,
      pactMagicMax: pactCount,
      pactMagicCurrent: pactCount,
    );
  }
}
