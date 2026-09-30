import '../mechanics/weapon_mastery.dart';
import '../spellcasting/spellcasting_rules_engine.dart';
import 'dart:math' as math;
import 'package:meta/meta.dart';
import '../rules/ruleset_edition.dart';
import '../models/core_types.dart';
import '../models/character_models.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import '../models/spell_monster_equipment.dart';
import '../models/i_entity_resolver.dart';
import '../attributes/dnd_5e_rules_engine.dart';
import '../rules/dnd_ruleset_strategy.dart';

import '../modules/dnd5e_ruleset_module.dart';

/// Computed Attack Profile for equipped weapons and unarmed strikes
@immutable
class ComputedAttackProfile {
  final String weaponName;
  final int attackBonus;
  final String attackBonusString;
  final String damageFormula; // e.g. "1d8 + 3"
  final DamageType damageType;
  final String range;
  final bool isOffhand;
  final String? notes;
  final WeaponMasteryProperty? activeMastery;

  const ComputedAttackProfile({
    required this.weaponName,
    required this.attackBonus,
    required this.attackBonusString,
    required this.damageFormula,
    required this.damageType,
    this.range = '5 ft',
    this.isOffhand = false,
    this.notes,
    this.activeMastery,
  });

  Map<String, dynamic> toMap() => {
        'weaponName': weaponName,
        'attackBonus': attackBonus,
        'attackBonusString': attackBonusString,
        'damageFormula': damageFormula,
        'damageType': damageType.name,
        'range': range,
        'isOffhand': isOffhand,
        'notes': notes,
        'activeMastery': activeMastery?.name,
      };
}

/// Fully Evaluated, Reactive Stat Projection for a Character
@immutable
class ComputedCharacterStats {
  final AbilityScores effectiveScores;
  final Map<AbilityType, int> abilityModifiers;
  final int proficiencyBonus;
  final int armorClass;
  final String armorClassBreakdown;
  final int maxHp;
  final int speedFeet;
  final int initiativeBonus;
  final Map<AbilityType, int> savingThrowModifiers;
  final Map<SkillType, int> skillModifiers;
  final int passivePerception;
  final int passiveInsight;
  final int passiveInvestigation;
  final Map<String, int> spellSaveDcs;
  final Map<String, int> spellAttackBonuses;
  final SpellSlotPool computedSpellSlots;
  final List<ComputedAttackProfile> attackProfiles;
  final List<UnresolvedReference> unresolvedReferences;
  final List<String> activeBuffNotes;
  final EncumbranceStatus encumbrance;
  final ExhaustionEffects exhaustion;
  final int? grappleShoveSaveDc;
  final String grappleShoveSummary;
  final List<WeaponMasteryProperty> activeWeaponMasteries;
  final RulesetEdition rulesEdition;

  const ComputedCharacterStats({
    required this.effectiveScores,
    required this.abilityModifiers,
    required this.proficiencyBonus,
    required this.armorClass,
    required this.armorClassBreakdown,
    required this.maxHp,
    required this.speedFeet,
    required this.initiativeBonus,
    required this.savingThrowModifiers,
    required this.skillModifiers,
    required this.passivePerception,
    required this.passiveInsight,
    required this.passiveInvestigation,
    required this.spellSaveDcs,
    required this.spellAttackBonuses,
    required this.computedSpellSlots,
    required this.attackProfiles,
    required this.unresolvedReferences,
    required this.activeBuffNotes,
    required this.encumbrance,
    required this.exhaustion,
    required this.grappleShoveSaveDc,
    required this.grappleShoveSummary,
    required this.activeWeaponMasteries,
    required this.rulesEdition,
  });
}

// ---------------------------------------------------------------------------
// Internal pipeline data models
// ---------------------------------------------------------------------------

class _PhaseABaseResult {
  final int totalLevel;
  final int proficiencyBonus;
  final AbilityScores boundedBaseScores;
  final int baseSpeedFeet;

  const _PhaseABaseResult({
    required this.totalLevel,
    required this.proficiencyBonus,
    required this.boundedBaseScores,
    required this.baseSpeedFeet,
  });
}

class _PhaseBEmbeddedResult {
  final AbilityScores scoresWithEmbeddedBonuses;
  final bool hasDefenseFightingStyle;
  final bool hasDraconicResilience;
  final bool isPowerfulBuild;
  final int racialHpPerLevelBonus;

  const _PhaseBEmbeddedResult({
    required this.scoresWithEmbeddedBonuses,
    required this.hasDefenseFightingStyle,
    required this.hasDraconicResilience,
    required this.isPowerfulBuild,
    required this.racialHpPerLevelBonus,
  });
}

class _PhaseCActiveEffectsResult {
  final AbilityScores effectiveScores;
  final Map<AbilityType, int> abilityModifiers;
  final List<EquipmentItem> resolvedEquippedItems;
  final List<UnresolvedReference> unresolvedReferences;
  final List<String> buffNotes;
  final ExhaustionEffects exhaustion;
  final EncumbranceStatus encumbrance;
  final int magicAcBonus;
  final int itemSpeedBonus;

  const _PhaseCActiveEffectsResult({
    required this.effectiveScores,
    required this.abilityModifiers,
    required this.resolvedEquippedItems,
    required this.unresolvedReferences,
    required this.buffNotes,
    required this.exhaustion,
    required this.encumbrance,
    required this.magicAcBonus,
    required this.itemSpeedBonus,
  });
}

/// Pure 4-Phase Derivation Pipeline for Character Stats adhering to 5e rules.
class CharacterStatCalculator {
  /// Pluggable hook for looking up class definitions when computing caster levels
  static dynamic Function(String slug)? classLookupHook;
  /// Evaluates a Character and its equipped items against the reference resolver
  /// across 4 deterministic derivation phases:
  ///
  /// - Phase A (Base Data): Proficiency bonus, total level, and raw score bounds.
  /// - Phase B (Embedded Grants): Species, background, and class traits.
  /// - Phase C (Active Effects Matrix): Attuned equipment additions, overrides, and conditions.
  /// - Phase D (Derived Data): AC, attack profiles, spell save DCs, skills, and vitals.
  static ComputedCharacterStats compute(
    Character character,
    IEntityResolver resolver,
  ) {
    final strategy = RulesetStrategy.forEdition(character.rulesEdition);

    // Phase A: Base Data
    final phaseA = _phaseABaseData(character);

    // Phase B: Embedded Grants
    final phaseB = _phaseBEmbeddedGrants(character, phaseA);

    // Phase C: Active Effects Matrix
    final phaseC = _phaseCActiveEffectsMatrix(
      character: character,
      phaseA: phaseA,
      phaseB: phaseB,
      resolver: resolver,
      strategy: strategy,
    );

    // Phase D: Derived Data
    return _phaseDDerivedData(
      character: character,
      phaseA: phaseA,
      phaseB: phaseB,
      phaseC: phaseC,
      resolver: resolver,
      strategy: strategy,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase A: Base Data
  // ---------------------------------------------------------------------------

  static _PhaseABaseResult _phaseABaseData(Character character) {
    final totalLevel = math.max(1, character.totalLevel);
    final profBonus = character.proficiencyBonus;

    // Bound raw base ability scores to [1, 30]
    final boundedScores = AbilityScores(
      strength: character.baseScores.strength.clamp(1, 30),
      dexterity: character.baseScores.dexterity.clamp(1, 30),
      constitution: character.baseScores.constitution.clamp(1, 30),
      intelligence: character.baseScores.intelligence.clamp(1, 30),
      wisdom: character.baseScores.wisdom.clamp(1, 30),
      charisma: character.baseScores.charisma.clamp(1, 30),
    );

    return _PhaseABaseResult(
      totalLevel: totalLevel,
      proficiencyBonus: profBonus,
      boundedBaseScores: boundedScores,
      baseSpeedFeet: character.baseSpeedFeet,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase B: Embedded Grants
  // ---------------------------------------------------------------------------

  static _PhaseBEmbeddedResult _phaseBEmbeddedGrants(
    Character character,
    _PhaseABaseResult phaseA,
  ) {
    // 1. Ingest permanent bonus scores from background/species/origin ASI
    final scoresWithBonuses = AbilityScores(
      strength:
          phaseA.boundedBaseScores.strength + character.bonusScores.strength,
      dexterity:
          phaseA.boundedBaseScores.dexterity + character.bonusScores.dexterity,
      constitution: phaseA.boundedBaseScores.constitution +
          character.bonusScores.constitution,
      intelligence: phaseA.boundedBaseScores.intelligence +
          character.bonusScores.intelligence,
      wisdom: phaseA.boundedBaseScores.wisdom + character.bonusScores.wisdom,
      charisma:
          phaseA.boundedBaseScores.charisma + character.bonusScores.charisma,
    );

    // 2. Class trait selections (e.g. Defense fighting style, Draconic Resilience)
    bool hasDefenseStyle = false;
    for (final cls in character.progression.classes) {
      for (final optList in cls.selectedFeatureOptions.values) {
        if (optList.contains('defense')) {
          hasDefenseStyle = true;
        }
      }
    }

    final hasDraconic = character.progression.classes.any((c) =>
        c.subclassRef?.slug.toLowerCase() == 'draconic-sorcery' ||
        c.subclassRef?.slug.toLowerCase() == 'draconic_bloodline');

    // 3. Species physical traits
    final isPowerfulBuild =
        character.customProperties['powerfulBuild'] == true ||
            character.speciesRef.slug.toLowerCase().contains('goliath') ||
            character.speciesRef.slug.toLowerCase().contains('firbolg');

    int racialHpBonus = 0;
    if (character.speciesRef.slug.toLowerCase().contains('dwarf') &&
        (character.rulesEdition == RulesetEdition.v2024 ||
            character.speciesRef.slug.toLowerCase().contains('hill'))) {
      racialHpBonus = 1;
    }

    return _PhaseBEmbeddedResult(
      scoresWithEmbeddedBonuses: scoresWithBonuses,
      hasDefenseFightingStyle: hasDefenseStyle,
      hasDraconicResilience: hasDraconic,
      isPowerfulBuild: isPowerfulBuild,
      racialHpPerLevelBonus: racialHpBonus,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase C: Active Effects Matrix
  // ---------------------------------------------------------------------------

  static _PhaseCActiveEffectsResult _phaseCActiveEffectsMatrix({
    required Character character,
    required _PhaseABaseResult phaseA,
    required _PhaseBEmbeddedResult phaseB,
    required IEntityResolver resolver,
    required RulesetStrategy strategy,
  }) {
    final unresolved = <UnresolvedReference>[];
    final buffNotes = <String>[];
    final resolvedItems = <EquipmentItem>[];

    // C.0 Exhaustion Evaluation
    int exhaustionLevel = 0;
    for (final cond in character.conditions) {
      if (cond.conditionName.toLowerCase() == 'exhaustion') {
        final lvl = (cond.parameters['level'] as num?)?.toInt() ?? 1;
        exhaustionLevel = math.max(exhaustionLevel, lvl);
      }
    }
    final exhaustion = strategy.evaluateExhaustion(exhaustionLevel);
    if (exhaustion.level > 0) {
      if (character.rulesEdition == RulesetEdition.v2024) {
        buffNotes.add(
            'Exhaustion (Level ${exhaustion.level}): ${exhaustion.d20TestPenalty} to d20 tests, -${exhaustion.speedReductionFeet} ft Speed');
      } else {
        buffNotes.add('Exhaustion (Tier ${exhaustion.level}) Active');
      }
    }

    // C.1 Ingest Base + Embedded Scores
    var str = phaseB.scoresWithEmbeddedBonuses.strength;
    var dex = phaseB.scoresWithEmbeddedBonuses.dexterity;
    var con = phaseB.scoresWithEmbeddedBonuses.constitution;
    var intl = phaseB.scoresWithEmbeddedBonuses.intelligence;
    var wis = phaseB.scoresWithEmbeddedBonuses.wisdom;
    var cha = phaseB.scoresWithEmbeddedBonuses.charisma;

    int magicAcBonus = 0;
    int itemSpeedBonus = 0;

    // C.2 Apply Item Additions (checking attunement)
    for (final instance in character.equippedItems) {
      final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
      if (res.isResolved) {
        final item = res.entity!;
        resolvedItems.add(item);

        if (instance.requiresAttunement && !instance.isAttuned) continue;

        final props = item.customProperties;
        if (props['abilityBonuses'] is Map) {
          final bonuses = props['abilityBonuses'] as Map;
          str += (bonuses['strength'] as num?)?.toInt() ?? 0;
          dex += (bonuses['dexterity'] as num?)?.toInt() ?? 0;
          con += (bonuses['constitution'] as num?)?.toInt() ?? 0;
          intl += (bonuses['intelligence'] as num?)?.toInt() ?? 0;
          wis += (bonuses['wisdom'] as num?)?.toInt() ?? 0;
          cha += (bonuses['charisma'] as num?)?.toInt() ?? 0;
        }

        if (instance.equippedSlot != EquipmentSlot.armor &&
            instance.equippedSlot != EquipmentSlot.shield &&
            props['isShield'] != true &&
            props['acBonus'] is num) {
          magicAcBonus += (props['acBonus'] as num).toInt();
        }

        if (props['speedBonus'] is num) {
          itemSpeedBonus += (props['speedBonus'] as num).toInt();
        }
      } else {
        unresolved.add(res.unresolved!);
      }
    }

    // C.3 Apply Ability Overrides (e.g. Gauntlets of Ogre Power)
    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
      if (!res.isResolved) continue;
      final item = res.entity!;
      final props = item.customProperties;

      if (props['abilityOverrides'] is Map) {
        final overrides = props['abilityOverrides'] as Map;
        if (overrides['strength'] is num) {
          str = math.max(str, (overrides['strength'] as num).toInt());
        }
        if (overrides['dexterity'] is num) {
          dex = math.max(dex, (overrides['dexterity'] as num).toInt());
        }
        if (overrides['constitution'] is num) {
          con = math.max(con, (overrides['constitution'] as num).toInt());
        }
        if (overrides['intelligence'] is num) {
          intl = math.max(intl, (overrides['intelligence'] as num).toInt());
        }
        if (overrides['wisdom'] is num) {
          wis = math.max(wis, (overrides['wisdom'] as num).toInt());
        }
        if (overrides['charisma'] is num) {
          cha = math.max(cha, (overrides['charisma'] as num).toInt());
        }
      }
    }

    // Final ceiling clamp [1, 30]
    final effectiveScores = AbilityScores(
      strength: str.clamp(1, 30),
      dexterity: dex.clamp(1, 30),
      constitution: con.clamp(1, 30),
      intelligence: intl.clamp(1, 30),
      wisdom: wis.clamp(1, 30),
      charisma: cha.clamp(1, 30),
    );

    final abilityMods = <AbilityType, int>{
      AbilityType.strength: effectiveScores.strength.dndModifier,
      AbilityType.dexterity: effectiveScores.dexterity.dndModifier,
      AbilityType.constitution: effectiveScores.constitution.dndModifier,
      AbilityType.intelligence: effectiveScores.intelligence.dndModifier,
      AbilityType.wisdom: effectiveScores.wisdom.dndModifier,
      AbilityType.charisma: effectiveScores.charisma.dndModifier,
    };

    // C.4 Encumbrance Matrix
    final encumbrance = strategy.calculateEncumbrance(
      strengthScore: effectiveScores.strength,
      inventory: character.inventory,
      totalCoinCount: character.purse.totalCoins,
      isPowerfulBuildOrLarge: phaseB.isPowerfulBuild,
    );
    if (encumbrance.variantTier != EncumbranceTier.unencumbered) {
      buffNotes.add(
          'Encumbrance (${encumbrance.variantTier.displayName}): -${encumbrance.speedPenaltyFeet} ft Speed');
    }

    return _PhaseCActiveEffectsResult(
      effectiveScores: effectiveScores,
      abilityModifiers: abilityMods,
      resolvedEquippedItems: resolvedItems,
      unresolvedReferences: unresolved,
      buffNotes: buffNotes,
      exhaustion: exhaustion,
      encumbrance: encumbrance,
      magicAcBonus: magicAcBonus,
      itemSpeedBonus: itemSpeedBonus,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase D: Derived Data
  // ---------------------------------------------------------------------------

  static ComputedCharacterStats _phaseDDerivedData({
    required Character character,
    required _PhaseABaseResult phaseA,
    required _PhaseBEmbeddedResult phaseB,
    required _PhaseCActiveEffectsResult phaseC,
    required IEntityResolver resolver,
    required RulesetStrategy strategy,
  }) {
    final abilityMods = phaseC.abilityModifiers;
    final profBonus = phaseA.proficiencyBonus;
    final buffNotes = List<String>.from(phaseC.buffNotes);

    // D.1 Armor Class Precedence Matrix
    int baseAc = 10;
    String acFormula = '10 (Base)';
    int dexContribution = abilityMods[AbilityType.dexterity]!;
    int shieldBonus = 0;
    int magicAcBonus = phaseC.magicAcBonus;
    bool hasEquippedArmor = false;
    bool isHeavyArmor = false;

    // Detect equipped armor and shield
    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
      if (!res.isResolved) continue;
      final item = res.entity!;
      final props = item.customProperties;

      if (instance.equippedSlot == EquipmentSlot.armor) {
        hasEquippedArmor = true;
        int itemBaseAc = (props['baseAc'] as num?)?.toInt() ??
            (props['ac'] as num?)?.toInt() ??
            0;
        String armorType = (props['armorType']?.toString() ?? '').toLowerCase();
        int? maxDex = (props['maxDexBonus'] as num?)?.toInt();

        if (itemBaseAc == 0 || armorType.isEmpty) {
          final standard =
              Dnd5eRulesetModule.resolveStandardArmor(item.name, item.id.slug);
          if (itemBaseAc == 0) itemBaseAc = standard.baseAc;
          if (armorType.isEmpty) armorType = standard.armorType;
          maxDex ??= standard.maxDex;
        }

        baseAc = itemBaseAc;
        if (armorType == 'heavy') {
          isHeavyArmor = true;
          dexContribution = 0;
          acFormula = '$itemBaseAc (${item.name})';
        } else if (armorType == 'medium') {
          final cap = maxDex ?? 2;
          dexContribution = math.min(abilityMods[AbilityType.dexterity]!, cap);
          acFormula =
              '$itemBaseAc (${item.name}) + $dexContribution (DEX capped at $cap)';
        } else {
          // Light armor
          dexContribution = abilityMods[AbilityType.dexterity]!;
          acFormula = '$itemBaseAc (${item.name}) + $dexContribution (DEX)';
        }

        int armorMagic = (props['acBonus'] as num?)?.toInt() ??
            (props['bonusAc'] as num?)?.toInt() ??
            (props['magicBonus'] as num?)?.toInt() ??
            0;
        if (armorMagic == 0) {
          final plusMatch = RegExp(r'\+(\d+)').firstMatch(item.name);
          if (plusMatch != null) {
            armorMagic = int.tryParse(plusMatch.group(1)!) ?? 0;
          }
        }
        if (armorMagic > 0) {
          magicAcBonus += armorMagic;
        }
      } else if (instance.equippedSlot == EquipmentSlot.shield ||
          props['isShield'] == true) {
        final sBonus = (props['acBonus'] as num?)?.toInt() ?? 2;
        shieldBonus += sBonus;
      }
    }

    // Apply Defense Fighting Style (+1 AC while wearing armor)
    if (phaseB.hasDefenseFightingStyle && hasEquippedArmor) {
      magicAcBonus += 1;
      buffNotes.add('Defense Fighting Style: +1 AC');
    }

    // Unarmored hierarchy
    if (!hasEquippedArmor) {
      // Determine which unarmored defense feature was gained first (Barbarian vs Monk)
      String? firstUnarmoredClass;
      for (final c in character.progression.classes) {
        final slug = c.classRef.slug.toLowerCase();
        if (slug == 'barbarian' || slug == 'monk') {
          firstUnarmoredClass ??= slug;
        }
      }

      if (phaseB.hasDraconicResilience) {
        baseAc = 13;
        dexContribution = abilityMods[AbilityType.dexterity]!;
        acFormula = '13 (Draconic Resilience) + $dexContribution (DEX)';
      } else if (firstUnarmoredClass == 'barbarian') {
        baseAc = 10;
        final conBonus = abilityMods[AbilityType.constitution]!;
        dexContribution = abilityMods[AbilityType.dexterity]!;
        acFormula =
            '10 (Unarmored) + $dexContribution (DEX) + $conBonus (CON Barbarian)';
        baseAc += conBonus;
      } else if (firstUnarmoredClass == 'monk' && shieldBonus == 0) {
        baseAc = 10;
        final wisBonus = abilityMods[AbilityType.wisdom]!;
        dexContribution = abilityMods[AbilityType.dexterity]!;
        acFormula =
            '10 (Unarmored) + $dexContribution (DEX) + $wisBonus (WIS Monk)';
        baseAc += wisBonus;
      } else {
        acFormula = '10 (Unarmored) + $dexContribution (DEX)';
      }
    }

    if (shieldBonus > 0) {
      acFormula += ' + $shieldBonus (Shield)';
    }
    if (magicAcBonus > 0) {
      acFormula += ' + $magicAcBonus (Bonus)';
    }

    final totalAc = baseAc +
        (isHeavyArmor ? 0 : dexContribution) +
        shieldBonus +
        magicAcBonus;

    // D.2 Max HP Computation (Retroactive CON Scaling)
    int computedMaxHp = 0;
    final conMod = abilityMods[AbilityType.constitution]!;
    int currentLevelCounter = 1;
    for (int i = 0; i < character.progression.classes.length; i++) {
      final cls = character.progression.classes[i];
      if (cls.isStartingClass || i == 0) {
        // Level 1 max hit die
        final level1Hp =
            character.progression.manualHpRolls[1] ?? cls.hitDieSides;
        computedMaxHp += level1Hp + conMod + phaseB.racialHpPerLevelBonus;
        currentLevelCounter++;
        // Remaining levels
        for (int l = 1; l < cls.level; l++) {
          final rolledIndex = l - 1;
          final recordedRoll =
              character.progression.manualHpRolls[currentLevelCounter];
          final rolled = recordedRoll ??
              ((rolledIndex < cls.hitPointsRolled.length)
                  ? cls.hitPointsRolled[rolledIndex]
                  : cls.averageHpPerLevel);
          computedMaxHp +=
              math.max(1, rolled + conMod + phaseB.racialHpPerLevelBonus);
          currentLevelCounter++;
        }
      } else {
        // Multiclass levels
        for (int l = 0; l < cls.level; l++) {
          final recordedRoll =
              character.progression.manualHpRolls[currentLevelCounter];
          final rolled = recordedRoll ??
              ((l < cls.hitPointsRolled.length)
                  ? cls.hitPointsRolled[l]
                  : cls.averageHpPerLevel);
          computedMaxHp +=
              math.max(1, rolled + conMod + phaseB.racialHpPerLevelBonus);
          currentLevelCounter++;
        }
      }
    }

    // Feat adjustments (e.g. Tough: +2 HP per level)
    for (final featRef in character.feats) {
      if (featRef.slug == 'tough' || featRef.slug == 'toughness') {
        computedMaxHp += character.totalLevel * 2;
        buffNotes.add('Tough Feat: +${character.totalLevel * 2} HP');
      }
    }

    // Draconic Bloodline Sorcerer (+1 HP per Sorcerer level)
    if (phaseB.hasDraconicResilience) {
      int draconicHpBonus = 0;
      for (final cls in character.progression.classes) {
        if (cls.subclassRef?.slug.toLowerCase() == 'draconic-sorcery' ||
            cls.subclassRef?.slug.toLowerCase() == 'draconic_bloodline') {
          draconicHpBonus += cls.level;
        }
      }
      if (draconicHpBonus > 0) {
        computedMaxHp += draconicHpBonus;
        buffNotes.add('Draconic Resilience: +$draconicHpBonus HP');
      }
    }

    // Apply Exhaustion Tier 4 (halve max HP)
    if (phaseC.exhaustion.maxHpMultiplier < 1.0) {
      computedMaxHp =
          (computedMaxHp * phaseC.exhaustion.maxHpMultiplier).floor();
    }
    if (computedMaxHp < 1) computedMaxHp = 1;

    // D.3 Speed & Initiative
    var speed = phaseA.baseSpeedFeet + phaseC.itemSpeedBonus;
    speed = math.max(0, speed - phaseC.encumbrance.speedPenaltyFeet);
    if (phaseC.exhaustion.speedMultiplier < 1.0) {
      speed = (speed * phaseC.exhaustion.speedMultiplier).floor();
    }
    speed = math.max(0, speed - phaseC.exhaustion.speedReductionFeet);

    final initiativeBonus =
        abilityMods[AbilityType.dexterity]! + phaseC.exhaustion.d20TestPenalty;

    // D.4 Saving Throws
    final savingThrows = <AbilityType, int>{};
    for (final ability in AbilityType.values) {
      var save = abilityMods[ability]!;
      if (character.savingThrowProficiencies.contains(ability)) {
        save += profBonus;
      }
      save += phaseC.exhaustion.d20TestPenalty;
      savingThrows[ability] = save;
    }

    // D.5 Skills & Passives
    final skills = <SkillType, int>{};
    for (final skill in SkillType.values) {
      final ability = skill.defaultAbility;
      final baseMod = abilityMods[ability]!;
      final profLevel =
          character.skillProficiencies[skill] ?? SkillProficiencyLevel.none;
      final skillMod = baseMod +
          (profLevel.multiplier * profBonus).floor() +
          phaseC.exhaustion.d20TestPenalty;
      skills[skill] = skillMod;
    }

    final passivePerception = 10 + (skills[SkillType.perception] ?? 0);
    final passiveInsight = 10 + (skills[SkillType.insight] ?? 0);
    final passiveInvestigation = 10 + (skills[SkillType.investigation] ?? 0);

    // D.6 Spellcasting Metrics
    final spellSaveDcs = <String, int>{};
    final spellAttackBonuses = <String, int>{};

    for (final cls in character.progression.classes) {
      final classSlug = cls.classRef.slug.toLowerCase();
      final castingAbility = _inferCastingAbility(classSlug);
      if (castingAbility != null) {
        final mod = abilityMods[castingAbility]!;

        var itemSpellAtkBonus = 0;
        var itemSpellDcBonus = 0;
        for (final instance in character.equippedItems) {
          if (instance.requiresAttunement && !instance.isAttuned) continue;
          final merged = Map<String, dynamic>.from(instance.customProperties);
          final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
          if (res.isResolved && res.entity != null) {
            for (final entry in res.entity!.customProperties.entries) {
              merged.putIfAbsent(entry.key, () => entry.value);
            }
          }
          final rawName = instance.displayName.toLowerCase();
          final pactKeeperMatch = RegExp(
                  r'rod\s+of\s+the\s+pact\s+keeper(?:,\s*|\s*)\+(\d+)',
                  caseSensitive: false)
              .firstMatch(rawName);
          if (pactKeeperMatch != null) {
            final b = int.tryParse(pactKeeperMatch.group(1)!) ?? 0;
            merged.putIfAbsent('bonusSpellAttack', () => b);
            merged.putIfAbsent('bonusSpellSaveDc', () => b);
            merged.putIfAbsent('spellClass', () => 'warlock');
          }

          final itemClass = (merged['spellClass'] ?? merged['class'])
              ?.toString()
              .toLowerCase();
          if (itemClass != null &&
              itemClass.isNotEmpty &&
              !classSlug.contains(itemClass)) {
            continue;
          }

          final rawAtk = merged['bonusSpellAttack'] ??
              merged['spellAttackBonus'] ??
              merged['spellBonus'];
          if (rawAtk != null) {
            final val = rawAtk is num
                ? rawAtk.toInt()
                : int.tryParse(rawAtk.toString().replaceAll('+', '').trim());
            if (val != null) itemSpellAtkBonus += val;
          }

          final rawDc = merged['bonusSpellSaveDc'] ??
              merged['spellDcBonus'] ??
              merged['spellBonus'];
          if (rawDc != null) {
            final val = rawDc is num
                ? rawDc.toInt()
                : int.tryParse(rawDc.toString().replaceAll('+', '').trim());
            if (val != null) itemSpellDcBonus += val;
          }
        }

        spellSaveDcs[classSlug] = 8 + profBonus + mod + itemSpellDcBonus;
        spellAttackBonuses[classSlug] = profBonus +
            mod +
            itemSpellAtkBonus +
            phaseC.exhaustion.d20TestPenalty;
      }
    }

    final computedSpellSlots = _computeMulticlassSpellSlots(
      character.progression.classes,
      character.rulesEdition,
    );

    // D.7 Attack Profiles & Weapon Masteries
    final attackProfiles = <ComputedAttackProfile>[];
    final activeMasteries = <WeaponMasteryProperty>[];
    bool hasEquippedWeapon = false;

    for (final instance in character.equippedItems) {
      if (instance.equippedSlot == EquipmentSlot.mainHand ||
          instance.equippedSlot == EquipmentSlot.offHand ||
          instance.equippedSlot == EquipmentSlot.twoHand) {
        final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
        if (res.isResolved) {
          final item = res.entity!;
          final props = item.customProperties;
          final isArmorOrShield =
              item.itemType.toLowerCase().contains('armor') ||
                  item.itemType.toLowerCase().contains('shield') ||
                  props['armorType'] != null ||
                  props['baseAc'] != null ||
                  props['isShield'] == true ||
                  item.name.toLowerCase().contains('armor') ||
                  item.name.toLowerCase().contains('plate');
          final isWeapon = !isArmorOrShield &&
              (props['isWeapon'] == true ||
                  item.itemType.toLowerCase().contains('weapon'));
          if (isWeapon) {
            hasEquippedWeapon = true;
            final isRanged = props['isRanged'] == true;
            final baseDamageFormula =
                props['damageFormula']?.toString() ?? '1d6';
            final dmgTypeStr = props['damageType']?.toString() ?? 'slashing';
            final dmgType = DamageType.values.firstWhere(
              (d) => d.name == dmgTypeStr,
              orElse: () => DamageType.slashing,
            );
            final magicBonus = (props['attackBonus'] as num?)?.toInt() ?? 0;

            final effectiveAbility = character.getEffectiveAttackAbility(
              instance,
              scores: phaseB.scoresWithEmbeddedBonuses,
            );
            final chosenAbilityMod = abilityMods[effectiveAbility]!;

            final toHit = profBonus +
                chosenAbilityMod +
                magicBonus +
                phaseC.exhaustion.d20TestPenalty;
            final damageBonus = (instance.equippedSlot == EquipmentSlot.offHand)
                ? magicBonus
                : chosenAbilityMod + magicBonus;

            final damageString = damageBonus == 0
                ? baseDamageFormula
                : (damageBonus > 0
                    ? '$baseDamageFormula + $damageBonus'
                    : '$baseDamageFormula - ${damageBonus.abs()}');

            // Weapon mastery check
            WeaponMasteryProperty? activeMastery;
            final masteryKey = props['mastery']?.toString() ??
                props['weaponMastery']?.toString();
            final masteryProp = WeaponMasteryProperty.tryParse(masteryKey);
            if (masteryProp != null &&
                strategy.canUseWeaponMastery(
                    character: character, weapon: item, mastery: masteryProp)) {
              activeMastery = masteryProp;
              if (!activeMasteries.contains(masteryProp)) {
                activeMasteries.add(masteryProp);
              }
            }

            final noteStr = activeMastery != null
                ? '[Mastery: ${activeMastery.displayName}] ${props['propertiesMarkdown']?.toString() ?? ""}'
                : props['propertiesMarkdown']?.toString();

            attackProfiles.add(ComputedAttackProfile(
              weaponName: instance.displayName,
              attackBonus: toHit,
              attackBonusString: toHit >= 0 ? '+$toHit' : '$toHit',
              damageFormula: damageString,
              damageType: dmgType,
              range: props['range']?.toString() ??
                  (isRanged ? '80/320 ft' : '5 ft'),
              isOffhand: instance.equippedSlot == EquipmentSlot.offHand,
              notes: noteStr?.trim(),
              activeMastery: activeMastery,
            ));
          }
        }
      }
    }

    if (!hasEquippedWeapon) {
      final strMod = abilityMods[AbilityType.strength]!;
      final toHit = profBonus + strMod + phaseC.exhaustion.d20TestPenalty;
      final dmg = math.max(1, 1 + strMod);
      attackProfiles.add(ComputedAttackProfile(
        weaponName: 'Unarmed Strike',
        attackBonus: toHit,
        attackBonusString: toHit >= 0 ? '+$toHit' : '$toHit',
        damageFormula: '$dmg',
        damageType: DamageType.bludgeoning,
      ));
    }

    // D.8 Grapple / Shove DC
    final grappleShove = strategy.calculateGrappleShoveDc(
      strengthModifier: abilityMods[AbilityType.strength]!,
      dexterityModifier: abilityMods[AbilityType.dexterity]!,
      proficiencyBonus: profBonus,
    );

    return ComputedCharacterStats(
      effectiveScores: phaseC.effectiveScores,
      abilityModifiers: abilityMods,
      proficiencyBonus: profBonus,
      armorClass: totalAc,
      armorClassBreakdown: acFormula,
      maxHp: computedMaxHp,
      speedFeet: speed,
      initiativeBonus: initiativeBonus,
      savingThrowModifiers: savingThrows,
      skillModifiers: skills,
      passivePerception: passivePerception,
      passiveInsight: passiveInsight,
      passiveInvestigation: passiveInvestigation,
      spellSaveDcs: spellSaveDcs,
      spellAttackBonuses: spellAttackBonuses,
      computedSpellSlots: computedSpellSlots,
      attackProfiles: attackProfiles,
      unresolvedReferences: phaseC.unresolvedReferences,
      activeBuffNotes: buffNotes,
      encumbrance: phaseC.encumbrance,
      exhaustion: phaseC.exhaustion,
      grappleShoveSaveDc: grappleShove.dc,
      grappleShoveSummary: grappleShove.formulaDescription,
      activeWeaponMasteries: activeMasteries,
      rulesEdition: character.rulesEdition,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static bool propsArmorHeavy(Character character, IEntityResolver resolver) {
    for (final instance in character.equippedItems) {
      if (instance.equippedSlot == EquipmentSlot.armor) {
        final res = resolver.resolveTyped<EquipmentItem>(instance.itemRef.cast<EquipmentItem>());
        if (res.isResolved &&
            res.entity!.customProperties['armorType']
                    ?.toString()
                    .toLowerCase() ==
                'heavy') {
          return true;
        }
      }
    }
    return false;
  }

  static AbilityType? _inferCastingAbility(String classSlug) =>
      switch (classSlug.toLowerCase()) {
        'wizard' => AbilityType.intelligence,
        'cleric' || 'druid' || 'ranger' => AbilityType.wisdom,
        'bard' || 'paladin' || 'sorcerer' || 'warlock' => AbilityType.charisma,
        _ => null,
      };

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
          final customCls = CharacterStatCalculator.classLookupHook?.call(slug);
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
