import '../spellcasting/spellcasting_rules_engine.dart';
import 'dart:math' as math;
import 'package:meta/meta.dart';
import '../models/core_types.dart';
import '../models/character_models.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';

import '../models/spell_monster_equipment.dart';
import '../models/i_entity_resolver.dart';
import '../rules/ruleset_edition.dart';
import '../evaluation/character_stat_calculator.dart';
import '../attributes/dnd_5e_rules_engine.dart';


/// HP Progression Choice for a level up step (Fixed Average vs Rolled Die).
@immutable
class HpProgressionChoice {
  final bool useFixedAverage;
  final int? rolledValue;

  const HpProgressionChoice.average()
      : useFixedAverage = true,
        rolledValue = null;

  const HpProgressionChoice.rolled(int value)
      : useFixedAverage = false,
        rolledValue = value;
}

/// Ability Score Improvement (+2 / +1+1) or Feat Selection.
@immutable
class AsiOrFeatChoice {
  final Map<AbilityType, int> abilityIncreases;
  final EntityReference<DomainEntity>? featRef;
  final Set<AbilityType> savingThrowGrants;
  final Set<SkillType> skillGrants;
  final Set<SkillType> expertiseGrants;
  final AbilityType? chosenFeatAbility;
  final Map<String, List<String>> featureOptionGrants;

  const AsiOrFeatChoice.asi(this.abilityIncreases)
      : featRef = null,
        savingThrowGrants = const {},
        skillGrants = const {},
        expertiseGrants = const {},
        chosenFeatAbility = null,
        featureOptionGrants = const {};

  const AsiOrFeatChoice.feat(
    EntityReference<DomainEntity> feat, {
    this.abilityIncreases = const {},
    this.savingThrowGrants = const {},
    this.skillGrants = const {},
    this.expertiseGrants = const {},
    this.chosenFeatAbility,
    this.featureOptionGrants = const {},
  }) : featRef = feat;

  bool get isFeat => featRef != null;
}

/// Complete parameter request for advancing a character level.
@immutable
class LevelUpRequest {
  final String targetClassSlug;
  final String? targetClassDisplayName;
  final String? targetClassHitDie; // e.g. "d8", "d10"
  final bool isMulticlass;
  final EntityReference<DomainEntity>? subclassRef;
  final HpProgressionChoice hpChoice;
  final AsiOrFeatChoice? asiOrFeat;
  final List<EntityReference<Spell>> newCantrips;
  final List<EntityReference<Spell>> newSpells;
  final List<String> replacedSpellIds;
  final Map<String, List<String>> selectedFeatureOptions;
  final List<String> newToolProficiencies;
  final List<String> newLanguages;
  final EntityReference<Spell>? mysticArcanumSpell;

  const LevelUpRequest({
    required this.targetClassSlug,
    this.targetClassDisplayName,
    this.targetClassHitDie,
    this.isMulticlass = false,
    this.subclassRef,
    this.hpChoice = const HpProgressionChoice.average(),
    this.asiOrFeat,
    this.newCantrips = const [],
    this.newSpells = const [],
    this.replacedSpellIds = const [],
    this.selectedFeatureOptions = const {},
    this.newToolProficiencies = const [],
    this.newLanguages = const [],
    this.mysticArcanumSpell,
  });
}

/// Validation result with diagnostic reason strings.
class LevelUpValidationResult {
  final bool isValid;
  final List<String> errors;

  const LevelUpValidationResult.valid()
      : isValid = true,
        errors = const [];

  const LevelUpValidationResult.invalid(this.errors) : isValid = false;
}

/// Pure Dart progression service providing 5e RAW / 2024 revised mechanics for leveling up.
class CharacterProgressionEngine {
  /// Pluggable hook for looking up class definitions when computing caster levels
  static dynamic Function(String slug)? classLookupHook;
  CharacterProgressionEngine._();

  /// Standard 5e Multiclass Prerequisites mapping class slug to required attribute threshold options.
  static Map<String, List<Map<AbilityType, int>>> getMulticlassPrerequisites() {
    return {
      'barbarian': [
        {AbilityType.strength: 13}
      ],
      'bard': [
        {AbilityType.charisma: 13}
      ],
      'cleric': [
        {AbilityType.wisdom: 13}
      ],
      'druid': [
        {AbilityType.wisdom: 13}
      ],
      'fighter': [
        {AbilityType.strength: 13},
        {AbilityType.dexterity: 13}, // STR or DEX 13
      ],
      'monk': [
        {
          AbilityType.dexterity: 13,
          AbilityType.wisdom: 13
        } // Both DEX and WIS 13
      ],
      'paladin': [
        {
          AbilityType.strength: 13,
          AbilityType.charisma: 13
        } // Both STR and CHA 13
      ],
      'ranger': [
        {
          AbilityType.dexterity: 13,
          AbilityType.wisdom: 13
        } // Both DEX and WIS 13
      ],
      'rogue': [
        {AbilityType.dexterity: 13}
      ],
      'sorcerer': [
        {AbilityType.charisma: 13}
      ],
      'warlock': [
        {AbilityType.charisma: 13}
      ],
      'wizard': [
        {AbilityType.intelligence: 13}
      ],
    };
  }

  /// Default Hit Die for standard 5e classes.
  static String getDefaultHitDie(String classSlug) {
    switch (classSlug.toLowerCase()) {
      case 'barbarian':
        return 'd12';
      case 'fighter':
      case 'paladin':
      case 'ranger':
        return 'd10';
      case 'bard':
      case 'cleric':
      case 'druid':
      case 'monk':
      case 'rogue':
      case 'warlock':
        return 'd8';
      case 'sorcerer':
      case 'wizard':
        return 'd6';
      default:
        return 'd8';
    }
  }

  /// Calculates average HP gain per level for a hit die (e.g., d6 -> 4, d8 -> 5, d10 -> 6, d12 -> 7).
  static int getAverageHpForHitDie(String hitDie) {
    final clean = hitDie.replaceAll('d', '').trim();
    final sides = int.tryParse(clean) ?? 8;
    return (sides / 2).floor() + 1;
  }

  /// Parses hit die sides integer.
  static int getHitDieSides(String hitDie) {
    final clean = hitDie.replaceAll('d', '').trim();
    return int.tryParse(clean) ?? 8;
  }

  /// Checks if reaching [newClassLevel] in [classSlug] triggers an Ability Score Improvement (ASI) milestone.
  static bool isAsiMilestone(String classSlug, int newClassLevel) {
    final slug = classSlug.toLowerCase();
    if (slug == 'fighter') {
      return [4, 6, 8, 12, 14, 16, 19].contains(newClassLevel);
    } else if (slug == 'rogue') {
      return [4, 8, 10, 12, 16, 19].contains(newClassLevel);
    } else {
      return [4, 8, 12, 16, 19].contains(newClassLevel);
    }
  }

  /// Checks if reaching [newClassLevel] in [classSlug] unlocks subclass selection,
  /// respecting ruleset version (2014 vs 2024) or custom class configuration.
  static bool isSubclassMilestone(
    String classSlug,
    int newClassLevel, {
    RulesetVersion ruleset = RulesetVersion.v2024,
    dynamic characterClass,
  }) {
    if (characterClass != null) {
      try {
        final dynamic res = characterClass.getSubclassLevel(ruleset);
        if (res is num) return newClassLevel == res.toInt();
      } catch (_) {}
      final lvl = (characterClass is num)
          ? characterClass.toInt()
          : ((characterClass.customProperties['subclassLevel'] as num?)?.toInt() ??
              (characterClass.subclassSelectionLevel as num?)?.toInt());
      if (lvl != null) {
        if (ruleset == RulesetVersion.v2014) {
          final slug = classSlug.toLowerCase();
          if (['cleric', 'sorcerer', 'warlock'].contains(slug)) return newClassLevel == 1;
          if (['druid', 'wizard'].contains(slug)) return newClassLevel == 2;
        }
        return newClassLevel == lvl;
      }
    }
    if (ruleset == RulesetVersion.v2014) {
      final slug = classSlug.toLowerCase();
      if (['cleric', 'sorcerer', 'warlock'].contains(slug)) {
        return newClassLevel == 1;
      }
      if (['druid', 'wizard'].contains(slug)) {
        return newClassLevel == 2;
      }
      return newClassLevel == 3;
    }
    // 2024 Revision standardizes all subclass selections to Level 3
    return newClassLevel == 3;
  }

  /// Checks if ability scores satisfy multiclass prerequisite requirement options.
  static bool _meetsPrereq(
      AbilityScores scores, List<Map<AbilityType, int>> prereqOptions) {
    for (final option in prereqOptions) {
      bool allPassed = true;
      option.forEach((ability, requiredScore) {
        if (scores.getScore(ability) < requiredScore) {
          allPassed = false;
        }
      });
      if (allPassed) return true;
    }
    return false;
  }

  /// Validates multiclass prerequisites for both existing classes (multiclassing OUT)
  /// and target class (multiclassing IN).
  static LevelUpValidationResult validateMulticlass(
      Character character, String targetClassSlug) {
    final errors = <String>[];
    final scores = character.rawAbilityScores;
    final prereqs = getMulticlassPrerequisites();

    // 1. Max level ceiling check (20)
    if (character.totalLevel >= 20) {
      errors.add('Character has already reached the maximum total level (20).');
    }

    final isExisting = character.progression.classes.any(
      (c) => c.classRef.slug.toLowerCase() == targetClassSlug.toLowerCase(),
    );

    if (!isExisting) {
      // Multiclassing into a new class requires satisfying:
      // a) Current class prerequisites to multiclass OUT
      for (final existingClass in character.progression.classes) {
        final slug = existingClass.classRef.slug.toLowerCase();
        final currentPrereq = prereqs[slug];
        if (currentPrereq != null && !_meetsPrereq(scores, currentPrereq)) {
          errors.add(
              'Cannot multiclass out of ${existingClass.classRef.displayName}: does not meet attribute prerequisite (13+ in primary stat).');
        }
      }

      // b) Target class prerequisites to multiclass IN
      final targetPrereq = prereqs[targetClassSlug.toLowerCase()];
      if (targetPrereq != null && !_meetsPrereq(scores, targetPrereq)) {
        errors.add(
            'Cannot multiclass into $targetClassSlug: does not meet attribute prerequisite (13+ required).');
      }
    }

    if (errors.isNotEmpty) {
      return LevelUpValidationResult.invalid(errors);
    }
    return const LevelUpValidationResult.valid();
  }

  /// Pure function applying level-up progression to a [Character].
  static Character applyLevelUp(
    Character character,
    LevelUpRequest request, {
    IEntityResolver? resolver,
  }) {
    final validation = validateMulticlass(character, request.targetClassSlug);
    if (!validation.isValid) {
      throw ArgumentError(
          'Level up validation failed: ${validation.errors.join(', ')}');
    }

    final newTotalLevel = character.totalLevel + 1;
    final newManualHpRolls =
        Map<int, int>.from(character.progression.manualHpRolls);

    // 1. Update Class Progression slices
    final updatedClasses = <ClassLevelProgression>[];
    bool classFound = false;
    String gainedHitDie =
        request.targetClassHitDie ?? getDefaultHitDie(request.targetClassSlug);
    int addedHp = 0;

    for (final cls in character.progression.classes) {
      if (cls.classRef.slug.toLowerCase() ==
          request.targetClassSlug.toLowerCase()) {
        classFound = true;
        gainedHitDie = cls.hitDie;
        final newLevel = cls.level + 1;
        final rolledHpList = List<int>.from(cls.hitPointsRolled);

        final avg = cls.averageHpPerLevel;
        addedHp = request.hpChoice.useFixedAverage
            ? avg
            : (request.hpChoice.rolledValue ?? avg);
        rolledHpList.add(addedHp);
        newManualHpRolls[newTotalLevel] = addedHp;

        final mergedOptions =
            Map<String, List<String>>.from(cls.selectedFeatureOptions);
        request.selectedFeatureOptions.forEach((k, v) {
          mergedOptions[k] = List<String>.from(v);
        });
        if (request.asiOrFeat != null &&
            request.asiOrFeat!.featureOptionGrants.isNotEmpty) {
          request.asiOrFeat!.featureOptionGrants.forEach((k, v) {
            mergedOptions[k] = List<String>.from(v);
          });
        }

        updatedClasses.add(cls.copyWith(
          level: newLevel,
          subclassRef: request.subclassRef ?? cls.subclassRef,
          hitPointsRolled: rolledHpList,
          selectedFeatureOptions: mergedOptions,
        ));
      } else {
        updatedClasses.add(cls);
      }
    }

    if (!classFound) {
      // Initiating a new Multiclass slice
      final hitDie = request.targetClassHitDie ??
          getDefaultHitDie(request.targetClassSlug);
      gainedHitDie = hitDie;
      final avg = getAverageHpForHitDie(hitDie);

      addedHp = request.hpChoice.useFixedAverage
          ? avg
          : (request.hpChoice.rolledValue ?? avg);
      newManualHpRolls[newTotalLevel] = addedHp;

      final initialOptions =
          Map<String, List<String>>.from(request.selectedFeatureOptions);
      if (request.asiOrFeat != null &&
          request.asiOrFeat!.featureOptionGrants.isNotEmpty) {
        request.asiOrFeat!.featureOptionGrants.forEach((k, v) {
          initialOptions[k] = List<String>.from(v);
        });
      }

      updatedClasses.add(ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: request.targetClassSlug,
          displayName: request.targetClassDisplayName ??
              request.targetClassSlug.toUpperCase(),
        ),
        subclassRef: request.subclassRef,
        level: 1,
        hitDie: hitDie,
        hitPointsRolled: [addedHp],
        isStartingClass: false,
        selectedFeatureOptions: initialOptions,
      ));
    }

    final newProgression = character.progression.copyWith(
      classes: updatedClasses,
      manualHpRolls: newManualHpRolls,
    );

    // 2. Apply ASI or Feat Choice
    var newBonusScores = character.bonusScores;
    final newFeats = List<EntityReference<DomainEntity>>.from(character.feats);
    final updatedSavingThrows =
        Set<AbilityType>.from(character.savingThrowProficiencies);
    final updatedSkills = Map<SkillType, SkillProficiencyLevel>.from(
        character.skillProficiencies);

    if (request.asiOrFeat != null) {
      final choice = request.asiOrFeat!;
      if (choice.featRef != null) {
        newFeats.add(choice.featRef!);
      }
      choice.abilityIncreases.forEach((ability, bonus) {
        final currentRaw = character.rawAbilityScores.getScore(ability);
        final maxAllowed = character.getAbilityScoreMaximum(ability);
        final effectiveBonus =
            math.max(0, math.min(bonus, maxAllowed - currentRaw));
        switch (ability) {
          case AbilityType.strength:
            newBonusScores = newBonusScores.copyWith(
                strength: newBonusScores.strength + effectiveBonus);
          case AbilityType.dexterity:
            newBonusScores = newBonusScores.copyWith(
                dexterity: newBonusScores.dexterity + effectiveBonus);
          case AbilityType.constitution:
            newBonusScores = newBonusScores.copyWith(
                constitution: newBonusScores.constitution + effectiveBonus);
          case AbilityType.intelligence:
            newBonusScores = newBonusScores.copyWith(
                intelligence: newBonusScores.intelligence + effectiveBonus);
          case AbilityType.wisdom:
            newBonusScores = newBonusScores.copyWith(
                wisdom: newBonusScores.wisdom + effectiveBonus);
          case AbilityType.charisma:
            newBonusScores = newBonusScores.copyWith(
                charisma: newBonusScores.charisma + effectiveBonus);
        }
      });
      if (choice.savingThrowGrants.isNotEmpty) {
        updatedSavingThrows.addAll(choice.savingThrowGrants);
      }
      for (final skill in choice.skillGrants) {
        if (!updatedSkills.containsKey(skill) ||
            updatedSkills[skill] == SkillProficiencyLevel.none) {
          updatedSkills[skill] = SkillProficiencyLevel.proficient;
        }
      }
      for (final skill in choice.expertiseGrants) {
        updatedSkills[skill] = SkillProficiencyLevel.expertise;
      }
    }

    // 3. Update Spells Known, Spells Prepared & Cantrips
    final existingCantripSlugs = character.cantrips.map((c) => c.slug).toSet();
    final updatedCantrips =
        List<EntityReference<Spell>>.from(character.cantrips);
    for (final c in request.newCantrips) {
      if (!existingCantripSlugs.contains(c.slug)) {
        updatedCantrips.add(c);
        existingCantripSlugs.add(c.slug);
      }
    }

    final existingKnownSlugs = character.spellsKnown.map((s) => s.slug).toSet();
    final updatedSpellsKnown =
        List<EntityReference<Spell>>.from(character.spellsKnown);
    for (final s in request.newSpells) {
      if (!existingKnownSlugs.contains(s.slug)) {
        updatedSpellsKnown.add(s);
        existingKnownSlugs.add(s.slug);
      }
    }
    if (request.mysticArcanumSpell != null) {
      final s = request.mysticArcanumSpell!;
      if (!existingKnownSlugs.contains(s.slug)) {
        updatedSpellsKnown.add(s);
        existingKnownSlugs.add(s.slug);
      }
    }

    final updatedSpellsPrepared =
        List<EntityReference<Spell>>.from(character.spellsPrepared);
    final existingPrepSlugs =
        character.spellsPrepared.map((s) => s.slug).toSet();
    for (final s in request.newSpells) {
      if (!existingPrepSlugs.contains(s.slug)) {
        updatedSpellsPrepared.add(s);
        existingPrepSlugs.add(s.slug);
      }
    }

    // Initialize allocatedSpells copy
    final updatedAllocated = Map<String, List<EntityReference<Spell>>>.from(
        character.allocatedSpells);

    // Process Replaced Spells
    if (request.replacedSpellIds.isNotEmpty) {
      final toRemove = request.replacedSpellIds.toSet();
      updatedCantrips.removeWhere((c) => toRemove.contains(c.slug));
      updatedSpellsKnown.removeWhere((s) => toRemove.contains(s.slug));
      updatedSpellsPrepared.removeWhere((s) => toRemove.contains(s.slug));

      final targetSpellsKey = 'class-${request.targetClassSlug}-spells';
      final targetCantripsKey = 'class-${request.targetClassSlug}-cantrips';

      // Strictly remove replaced spells from the target class's allocation
      // to preserve other class allocations in multiclass builds
      for (final entry in updatedAllocated.entries.toList()) {
        if (entry.key == targetSpellsKey ||
            entry.key == targetCantripsKey ||
            !entry.key.startsWith('class-')) {
          final filteredList =
              entry.value.where((s) => !toRemove.contains(s.slug)).toList();
          updatedAllocated[entry.key] = filteredList;
        }
      }
    }

    // Update allocatedSpells with newly acquired spells & cantrips
    if (request.newCantrips.isNotEmpty) {
      final key = 'class-${request.targetClassSlug}-cantrips';
      final curList =
          List<EntityReference<Spell>>.from(updatedAllocated[key] ?? []);
      final curSlugs = curList.map((c) => c.slug).toSet();
      for (final c in request.newCantrips) {
        if (!curSlugs.contains(c.slug)) curList.add(c);
      }
      updatedAllocated[key] = curList;
    }
    if (request.newSpells.isNotEmpty) {
      final key = 'class-${request.targetClassSlug}-spells';
      final curList =
          List<EntityReference<Spell>>.from(updatedAllocated[key] ?? []);
      final curSlugs = curList.map((s) => s.slug).toSet();
      for (final s in request.newSpells) {
        if (!curSlugs.contains(s.slug)) curList.add(s);
      }
      updatedAllocated[key] = curList;
    }
    if (request.mysticArcanumSpell != null) {
      final key = 'class-${request.targetClassSlug}-mystic-arcanum';
      final curList =
          List<EntityReference<Spell>>.from(updatedAllocated[key] ?? []);
      final curSlugs = curList.map((s) => s.slug).toSet();
      if (!curSlugs.contains(request.mysticArcanumSpell!.slug)) {
        curList.add(request.mysticArcanumSpell!);
      }
      updatedAllocated[key] = curList;
    }

    // 4. Update Hit Dice Resource Pool (increment pool for gained hit die)
    final updatedHitDice =
        Map<String, int>.from(character.resources.currentHitDice);
    updatedHitDice[gainedHitDie] = (updatedHitDice[gainedHitDie] ?? 0) + 1;

    // 5. Update Tool Proficiencies and Languages
    final updatedTools = List<String>.from(character.toolProficiencies);
    for (final t in request.newToolProficiencies) {
      if (!updatedTools
          .any((existing) => existing.toLowerCase() == t.toLowerCase())) {
        updatedTools.add(t);
      }
    }
    final updatedLanguages = List<String>.from(character.languages);
    for (final l in request.newLanguages) {
      if (!updatedLanguages
          .any((existing) => existing.toLowerCase() == l.toLowerCase())) {
        updatedLanguages.add(l);
      }
    }

    // 6. Build candidate updated Character
    var candidate = character.copyWith(
      progression: newProgression,
      bonusScores: newBonusScores,
      feats: newFeats,
      savingThrowProficiencies: updatedSavingThrows,
      skillProficiencies: updatedSkills,
      toolProficiencies: updatedTools,
      languages: updatedLanguages,
      allocatedSpells: updatedAllocated,
      cantrips: updatedCantrips,
      spellsKnown: updatedSpellsKnown,
      spellsPrepared: updatedSpellsPrepared,
      resources: character.resources.copyWith(
        currentHitDice: updatedHitDice,
      ),
    );

    // 6. Recalculate derived combat stats (HP, Spell Slots) using RAW calculation
    int newMaxHp = computeMaxHp(candidate);
    final newSlotPool = computeSpellSlots(
      candidate.progression.classes,
      edition: candidate.rulesEdition,
    );

    // Preserve expended slot delta if possible, or initialize up to new max
    final currentSlotMap =
        Map<int, int>.from(character.resources.spellSlots.currentSlots);
    final maxSlotMap = Map<int, int>.from(newSlotPool.maxSlots);
    final mergedCurrentSlots = <int, int>{};

    maxSlotMap.forEach((level, maxCount) {
      final prevCur = currentSlotMap[level] ?? maxCount;
      mergedCurrentSlots[level] = math.min(prevCur, maxCount);
    });

    final updatedSlots = newSlotPool.copyWith(
      currentSlots: mergedCurrentSlots,
      pactMagicCurrent: math.min(
          character.resources.spellSlots.pactMagicCurrent,
          newSlotPool.pactMagicMax),
    );

    // If resolver is provided, use full CharacterStatCalculator
    if (resolver != null) {
      final computed = CharacterStatCalculator.compute(candidate, resolver);
      newMaxHp = computed.maxHp;
    }

    // Calculate HP increase to add to current HP (including retroactive CON scaling)
    final oldMaxHp = resolver != null
        ? CharacterStatCalculator.compute(character, resolver).maxHp
        : computeMaxHp(character);
    final hpDelta = math.max(0, newMaxHp - oldMaxHp);
    final updatedCurrentHp =
        math.min(newMaxHp, character.resources.currentHp + hpDelta);

    return candidate.copyWith(
      resources: candidate.resources.copyWith(
        currentHp: updatedCurrentHp,
        spellSlots: updatedSlots,
      ),
    );
  }

  /// Max HP computation adhering strictly to 5e RAW rules:
  /// - Starting class gets full hit die sides + CON at Level 1 (or manualHpRolls[1] if recorded).
  /// - Subsequent levels (and all multiclass levels) gain recorded manualHpRolls or rolled/average hit die + CON (min 1 per level).
  /// - Retroactive CON modifier adjustments apply automatically across all levels.
  /// - Feats (like Tough) add +2 HP per total character level.
  static int computeMaxHp(Character character) {
    int maxHp = 0;
    final totalCon =
        character.baseScores.constitution + character.bonusScores.constitution;
    final conMod = totalCon.dndModifier;

    int currentLevelCounter = 1;
    for (int i = 0; i < character.progression.classes.length; i++) {
      final cls = character.progression.classes[i];
      if (cls.isStartingClass || i == 0) {
        // Starting class level 1 gets max hit die + CON
        final level1Hp =
            character.progression.manualHpRolls[1] ?? cls.hitDieSides;
        maxHp += level1Hp + conMod;
        currentLevelCounter++;

        // Remaining levels of starting class
        for (int l = 1; l < cls.level; l++) {
          final rolledIndex = l - 1;
          final recordedRoll =
              character.progression.manualHpRolls[currentLevelCounter];
          final rolled = recordedRoll ??
              ((rolledIndex < cls.hitPointsRolled.length)
                  ? cls.hitPointsRolled[rolledIndex]
                  : cls.averageHpPerLevel);
          maxHp += math.max(1, rolled + conMod);
          currentLevelCounter++;
        }
      } else {
        // Multiclass slices: all levels gain rolled/average + CON
        for (int l = 0; l < cls.level; l++) {
          final recordedRoll =
              character.progression.manualHpRolls[currentLevelCounter];
          final rolled = recordedRoll ??
              ((l < cls.hitPointsRolled.length)
                  ? cls.hitPointsRolled[l]
                  : cls.averageHpPerLevel);
          maxHp += math.max(1, rolled + conMod);
          currentLevelCounter++;
        }
      }
    }

    // Tough Feat (+2 HP per level)
    for (final feat in character.feats) {
      if (feat.slug == 'tough' || feat.slug == 'toughness') {
        maxHp += character.totalLevel * 2;
      }
    }

    // Hill Dwarf / Dwarven Toughness (+1 HP per level)
    final isHillDwarf =
        character.speciesRef.slug.toLowerCase().contains('dwarf') &&
            (character.rulesEdition == RulesetEdition.v2024 ||
                character.speciesRef.slug.toLowerCase().contains('hill'));
    if (isHillDwarf) {
      maxHp += character.totalLevel;
    }

    // Draconic Bloodline Sorcerer (+1 HP per sorcerer level)
    for (final cls in character.progression.classes) {
      final isDraconic =
          cls.subclassRef?.slug.toLowerCase() == 'draconic-sorcery' ||
              cls.subclassRef?.slug.toLowerCase() == 'draconic_bloodline';
      if (isDraconic) {
        maxHp += cls.level;
      }
    }

    return math.max(1, maxHp);
  }

  /// Computes composite Multiclass and Pact Magic spell slots adhering to 2014/2024 RAW rules.
  static SpellSlotPool computeSpellSlots(
    List<ClassLevelProgression> classes, {
    RulesetEdition edition = RulesetEdition.v2014,
  }) {
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
          final customCls = CharacterProgressionEngine.classLookupHook?.call(slug);
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

      // Check for third caster subclasses (Eldritch Knight, Arcane Trickster)
      final subSlug = cls.subclassRef?.slug.toLowerCase() ?? '';
      if (subSlug.contains('eldritch_knight') ||
          subSlug.contains('arcane_trickster') ||
          subSlug.contains('eldritch-knight') ||
          subSlug.contains('arcane-trickster')) {
        thirdCasterLevels += cls.level;
      }
    }

    return MulticlassSlotMatrix.calculateSpellSlotsForProgression(
      fullCasterLevels: fullCasterLevels,
      paladinLevels: paladinLevels,
      rangerLevels: rangerLevels,
      roundUpHalfCasterLevels: roundUpHalfCasterLevels,
      thirdCasterLevels: thirdCasterLevels,
      warlockLevels: warlockLevels,
      edition: edition,
    );
  }
}
