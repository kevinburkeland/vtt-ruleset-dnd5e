import 'dart:math' as math;
import 'package:meta/meta.dart';

import '../rules/ruleset_edition.dart';
import '../models/character_models.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import '../models/feature_grant.dart';
import '../models/spell_monster_equipment.dart';
import 'spellcasting_rules_engine.dart' show SpellClass;
import '../models/i_entity_resolver.dart';

/// Specification of spell quota limits for a given class slice at a specific level.
@immutable
class SpellAllocationLimits {
  final int maxCantrips;
  final int
      maxSpellsKnown; // Non-zero for spontaneous/known casters (Sorcerer, Bard, Warlock, Ranger 2014)
  final int
      maxSpellsPrepared; // Non-zero for prepared casters (Wizard, Cleric, Druid, Paladin)
  final int maxSpellbookInitialScribe; // 6 for Level 1 Wizard
  final int maxSpellbookLevelUpScribe; // 2 per level-up for Wizard
  final int
      maxSpellSlotLevel; // Highest spell slot tier available for this class slice
  final bool isSpellcaster;
  final String castingAbility;
  final int magicalSecretsCount; // Number of cross-list magical secret picks
  final Set<SpellClass>
      allowedMagicalSecretClasses; // Eligible classes for Magical Secrets
  final int mysticArcanumLevel; // 6, 7, 8, or 9 for high-level Warlocks
  final int
      mysticArcanumCount; // Total number of Mystic Arcanum picks gained (1 at 11, 2 at 13, 3 at 15, 4 at 17)
  final int
      alwaysPreparedSubclassCount; // Number of domain/oath spells auto-prepared

  const SpellAllocationLimits({
    required this.maxCantrips,
    required this.maxSpellsKnown,
    required this.maxSpellsPrepared,
    this.maxSpellbookInitialScribe = 0,
    this.maxSpellbookLevelUpScribe = 0,
    required this.maxSpellSlotLevel,
    required this.isSpellcaster,
    required this.castingAbility,
    this.magicalSecretsCount = 0,
    this.allowedMagicalSecretClasses = const {},
    this.mysticArcanumLevel = 0,
    this.mysticArcanumCount = 0,
    this.alwaysPreparedSubclassCount = 0,
  });

  const SpellAllocationLimits.nonCaster()
      : maxCantrips = 0,
        maxSpellsKnown = 0,
        maxSpellsPrepared = 0,
        maxSpellbookInitialScribe = 0,
        maxSpellbookLevelUpScribe = 0,
        maxSpellSlotLevel = 0,
        isSpellcaster = false,
        castingAbility = 'Intelligence',
        magicalSecretsCount = 0,
        allowedMagicalSecretClasses = const {},
        mysticArcanumLevel = 0,
        mysticArcanumCount = 0,
        alwaysPreparedSubclassCount = 0;
}

/// Validation result container for spell selection.
@immutable
class SpellValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const SpellValidationResult.valid()
      : isValid = true,
        errors = const [],
        warnings = const [];

  const SpellValidationResult.invalid(this.errors, [this.warnings = const []])
      : isValid = false;
}

/// Pure Dart rules validator enforcing SRD 5.1 (2014) and SRD 5.2.1 (2024) RAW spell invariants.
class SpellAllocationValidator {
  /// Pluggable hook for looking up always prepared subclass spells
  static List<String> Function({required String classSlug, String? subclassSlug, required int classLevel, required RulesetEdition edition})? alwaysPreparedSpellsHook;
  SpellAllocationValidator._();

  /// Known spells progression table for Bard (levels 1-20)
  static const Map<int, int> _bardSpellsKnown = {
    1: 4,
    2: 5,
    3: 6,
    4: 7,
    5: 8,
    6: 9,
    7: 10,
    8: 11,
    9: 12,
    10: 14,
    11: 15,
    12: 15,
    13: 16,
    14: 18,
    15: 19,
    16: 19,
    17: 20,
    18: 22,
    19: 22,
    20: 22,
  };

  /// Known spells progression table for Sorcerer (levels 1-20)
  static const Map<int, int> _sorcererSpellsKnown = {
    1: 2,
    2: 3,
    3: 4,
    4: 5,
    5: 6,
    6: 7,
    7: 8,
    8: 9,
    9: 10,
    10: 11,
    11: 12,
    12: 12,
    13: 13,
    14: 13,
    15: 14,
    16: 14,
    17: 15,
    18: 15,
    19: 15,
    20: 15,
  };

  /// Known spells progression table for Warlock (levels 1-20)
  static const Map<int, int> _warlockSpellsKnown = {
    1: 2,
    2: 3,
    3: 4,
    4: 5,
    5: 6,
    6: 7,
    7: 8,
    8: 9,
    9: 10,
    10: 10,
    11: 11,
    12: 11,
    13: 12,
    14: 12,
    15: 13,
    16: 13,
    17: 14,
    18: 14,
    19: 15,
    20: 15,
  };

  /// Known spells progression table for 1/3 Casters (Eldritch Knight, Arcane Trickster, levels 1-20)
  static const Map<int, int> _thirdCasterSpellsKnown = {
    1: 0,
    2: 0,
    3: 3,
    4: 4,
    5: 4,
    6: 4,
    7: 5,
    8: 6,
    9: 6,
    10: 7,
    11: 8,
    12: 8,
    13: 9,
    14: 10,
    15: 10,
    16: 11,
    17: 11,
    18: 11,
    19: 12,
    20: 13,
  };

  /// Known spells progression table for Ranger (2014, levels 1-20)
  static const Map<int, int> _rangerSpellsKnown2014 = {
    1: 0,
    2: 2,
    3: 3,
    4: 3,
    5: 4,
    6: 4,
    7: 5,
    8: 5,
    9: 6,
    10: 6,
    11: 7,
    12: 7,
    13: 8,
    14: 8,
    15: 9,
    16: 9,
    17: 10,
    18: 10,
    19: 11,
    20: 11,
  };

  /// Calculates max spell slot tier available for a single class slice
  static int getMaxSpellTierForClass({
    required String classSlug,
    required int classLevel,
    String? subclassSlug,
    RulesetEdition edition = RulesetEdition.v2014,
  }) {
    final slug = classSlug.toLowerCase();
    final sub = subclassSlug?.toLowerCase().replaceAll('-', '_') ?? '';
    final lvl = classLevel.clamp(1, 20);

    if (slug == 'wizard' ||
        slug == 'sorcerer' ||
        slug == 'cleric' ||
        slug == 'druid' ||
        slug == 'bard') {
      return (lvl + 1) ~/
          2; // Full casters: 1-2: 1st, 3-4: 2nd, 5-6: 3rd, ..., 17-20: 9th
    } else if (slug == 'warlock') {
      if (lvl >= 9) return 5;
      return (lvl + 1) ~/ 2;
    } else if (slug == 'paladin' || slug == 'ranger') {
      if (edition == RulesetEdition.v2024) {
        return ((lvl + 1) ~/ 4) +
            1; // 2024 half casters gain 1st level spells at level 1
      }
      if (lvl < 2) return 0;
      return ((lvl + 1) ~/ 4) +
          1; // 2014: lvl 2-4: 1st, 5-8: 2nd, 9-12: 3rd, 13-16: 4th, 17-20: 5th
    } else if (slug.contains('eldritch_knight') ||
        slug.contains('arcane_trickster') ||
        sub.contains('eldritch_knight') ||
        sub.contains('arcane_trickster')) {
      if (lvl < 3) return 0;
      if (lvl >= 19) return 4;
      if (lvl >= 13) return 3;
      if (lvl >= 7) return 2;
      return 1;
    }
    return 0;
  }

  /// Returns RAW allocation limits for a class slice at a specific class level.
  static SpellAllocationLimits getLimitsForClass({
    required String classSlug,
    required int classLevel,
    required int abilityModifier,
    String? subclassSlug,
    RulesetEdition edition = RulesetEdition.v2014,
  }) {
    final slug = classSlug.toLowerCase();
    final sub = subclassSlug?.toLowerCase().replaceAll('-', '_') ?? '';
    final lvl = classLevel.clamp(1, 20);
    final maxTier = getMaxSpellTierForClass(
        classSlug: slug,
        classLevel: lvl,
        subclassSlug: subclassSlug,
        edition: edition);

    switch (slug) {
      case 'wizard':
        final cantrips = (lvl >= 10) ? 5 : ((lvl >= 4) ? 4 : 3);
        final maxPrepared = math.max(1, lvl + abilityModifier);
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellbookInitialScribe: 6,
          maxSpellbookLevelUpScribe: 2,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Intelligence',
        );

      case 'sorcerer':
        final cantrips = (lvl >= 10) ? 6 : ((lvl >= 4) ? 5 : 4);
        final known = _sorcererSpellsKnown[lvl] ?? 2;
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: known,
          maxSpellsPrepared: 0,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Charisma',
        );

      case 'bard':
        final cantrips = (lvl >= 10) ? 4 : ((lvl >= 4) ? 3 : 2);
        final known = _bardSpellsKnown[lvl] ?? 4;

        var secretsCount = 0;
        var allowedSecretClasses = <SpellClass>{};

        if (edition == RulesetEdition.v2024) {
          if (lvl >= 10) {
            allowedSecretClasses = {
              SpellClass.bard,
              SpellClass.cleric,
              SpellClass.druid,
              SpellClass.wizard,
            };
          }
          if (sub.contains('lore') && lvl >= 6 && lvl < 10) {
            secretsCount = 2;
            allowedSecretClasses = {
              SpellClass.cleric,
              SpellClass.druid,
              SpellClass.wizard,
            };
          }
        } else {
          // 2014 Magical Secrets
          if (lvl >= 18) {
            secretsCount = 6;
          } else if (lvl >= 14) {
            secretsCount = 4;
          } else if (lvl >= 10) {
            secretsCount = 2;
          }
          if (sub.contains('lore') && lvl >= 6) {
            secretsCount += 2;
          }
          if (secretsCount > 0) {
            allowedSecretClasses = SpellClass.values.toSet();
          }
        }

        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: known + (sub.contains('lore') && lvl >= 6 ? 2 : 0),
          maxSpellsPrepared: 0,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Charisma',
          magicalSecretsCount: secretsCount,
          allowedMagicalSecretClasses: allowedSecretClasses,
        );

      case 'cleric':
        final cantrips = (lvl >= 10) ? 5 : ((lvl >= 4) ? 4 : 3);
        final maxPrepared = math.max(1, lvl + abilityModifier);
        final alwaysPreparedCount = SpellAllocationValidator.alwaysPreparedSpellsHook != null
            ? SpellAllocationValidator.alwaysPreparedSpellsHook!(
                classSlug: 'cleric',
                subclassSlug: subclassSlug,
                classLevel: lvl,
                edition: edition,
              ).length
            : ((subclassSlug != null && subclassSlug.isNotEmpty) ? math.min(5, maxTier) * 2 : 0);

        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Wisdom',
          alwaysPreparedSubclassCount: alwaysPreparedCount,
        );

      case 'druid':
        final cantrips = (lvl >= 10) ? 4 : ((lvl >= 4) ? 3 : 2);
        final maxPrepared = math.max(1, lvl + abilityModifier);
        final alwaysPreparedCount = SpellAllocationValidator.alwaysPreparedSpellsHook != null
            ? SpellAllocationValidator.alwaysPreparedSpellsHook!(
                classSlug: 'druid',
                subclassSlug: subclassSlug,
                classLevel: lvl,
                edition: edition,
              ).length
            : ((subclassSlug != null && subclassSlug.isNotEmpty) ? math.min(5, maxTier) * 2 : 0);

        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Wisdom',
          alwaysPreparedSubclassCount: alwaysPreparedCount,
        );

      case 'warlock':
        final cantrips = (lvl >= 10) ? 4 : ((lvl >= 4) ? 3 : 2);
        final known = _warlockSpellsKnown[lvl] ?? 2;
        final mysticTier = (lvl >= 17)
            ? 9
            : ((lvl >= 15) ? 8 : ((lvl >= 13) ? 7 : ((lvl >= 11) ? 6 : 0)));
        final mysticCount = (lvl >= 17)
            ? 4
            : ((lvl >= 15) ? 3 : ((lvl >= 13) ? 2 : ((lvl >= 11) ? 1 : 0)));

        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: known,
          maxSpellsPrepared: 0,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Charisma',
          mysticArcanumLevel: mysticTier,
          mysticArcanumCount: mysticCount,
        );

      case 'paladin':
        final maxPrepared = (edition == RulesetEdition.v2024)
            ? math.max(1, ((lvl + 1) ~/ 2) + abilityModifier)
            : (lvl < 2 ? 0 : math.max(1, (lvl ~/ 2) + abilityModifier));
        final alwaysPreparedCount = SpellAllocationValidator.alwaysPreparedSpellsHook != null
            ? SpellAllocationValidator.alwaysPreparedSpellsHook!(
                classSlug: 'paladin',
                subclassSlug: subclassSlug,
                classLevel: lvl,
                edition: edition,
              ).length
            : ((subclassSlug != null && subclassSlug.isNotEmpty) ? math.min(5, maxTier) * 2 : 0);

        return SpellAllocationLimits(
          maxCantrips: 0,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: lvl >= (edition == RulesetEdition.v2024 ? 1 : 2),
          castingAbility: 'Charisma',
          alwaysPreparedSubclassCount: alwaysPreparedCount,
        );

      case 'ranger':
        if (edition == RulesetEdition.v2024) {
          const cantrips = 2;
          final maxPrepared = math.max(1, ((lvl + 1) ~/ 2) + abilityModifier);
          return SpellAllocationLimits(
            maxCantrips: cantrips,
            maxSpellsKnown: 0,
            maxSpellsPrepared: maxPrepared,
            maxSpellSlotLevel: maxTier,
            isSpellcaster: true,
            castingAbility: 'Wisdom',
          );
        } else {
          final known = _rangerSpellsKnown2014[lvl] ?? 0;
          return SpellAllocationLimits(
            maxCantrips: 0,
            maxSpellsKnown: known,
            maxSpellsPrepared: 0,
            maxSpellSlotLevel: maxTier,
            isSpellcaster: lvl >= 2,
            castingAbility: 'Wisdom',
          );
        }

      case 'fighter':
        if (sub.contains('eldritch_knight')) {
          final cantrips = lvl < 3 ? 0 : ((lvl >= 10) ? 3 : 2);
          final known = _thirdCasterSpellsKnown[lvl] ?? 0;
          return SpellAllocationLimits(
            maxCantrips: cantrips,
            maxSpellsKnown: known,
            maxSpellsPrepared: 0,
            maxSpellSlotLevel: maxTier,
            isSpellcaster: lvl >= 3,
            castingAbility: 'Intelligence',
          );
        }
        return const SpellAllocationLimits.nonCaster();

      case 'rogue':
        if (sub.contains('arcane_trickster')) {
          final cantrips = lvl < 3 ? 0 : ((lvl >= 10) ? 3 : 2);
          final known = _thirdCasterSpellsKnown[lvl] ?? 0;
          return SpellAllocationLimits(
            maxCantrips: cantrips,
            maxSpellsKnown: known,
            maxSpellsPrepared: 0,
            maxSpellSlotLevel: maxTier,
            isSpellcaster: lvl >= 3,
            castingAbility: 'Intelligence',
          );
        }
        return const SpellAllocationLimits.nonCaster();

      default:
        return const SpellAllocationLimits.nonCaster();
    }
  }

  /// Audits and validates a character creation or level-up spell payload against RAW restrictions.
  static SpellValidationResult validateSpellSelection({
    required String targetClassSlug,
    required int targetClassLevel,
    required int castingAbilityModifier,
    String? subclassSlug,
    required List<EntityReference<Spell>> cantrips,
    required List<EntityReference<Spell>> spellsKnown,
    required List<EntityReference<Spell>> spellsPrepared,
    List<EntityReference<Spell>> spellbookSpells = const [],
    List<String> alwaysPreparedSpellIds = const [],
    required RulesetEdition edition,
    IEntityResolver? resolver,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    final limits = getLimitsForClass(
      classSlug: targetClassSlug,
      classLevel: targetClassLevel,
      abilityModifier: castingAbilityModifier,
      subclassSlug: subclassSlug,
      edition: edition,
    );

    if (!limits.isSpellcaster) {
      if (cantrips.isNotEmpty ||
          spellsKnown.isNotEmpty ||
          spellsPrepared.isNotEmpty) {
        errors.add(
            'Class $targetClassSlug is not a spellcasting class at level $targetClassLevel.');
      }
      return SpellValidationResult.invalid(errors);
    }

    // 1. Cantrip Count Check
    if (cantrips.length > limits.maxCantrips) {
      errors.add(
        'Selected ${cantrips.length} cantrips, but $targetClassSlug at level $targetClassLevel allows a maximum of ${limits.maxCantrips}.',
      );
    }

    // 2. Wizard Spellbook Initial Scribing Check
    if (targetClassSlug.toLowerCase() == 'wizard' && targetClassLevel == 1) {
      final effectiveScribeCount = spellbookSpells.isNotEmpty
          ? spellbookSpells.length
          : spellsKnown.length;
      if (effectiveScribeCount != 6) {
        errors.add(
          'A Level 1 Wizard must start with exactly 6 1st-level spells in their spellbook (selected $effectiveScribeCount).',
        );
      }
    }

    // 3. Spontaneous Spells Known Count Check
    if (limits.maxSpellsKnown > 0) {
      // In 5e RAW, Mystic Arcanum spells (levels 6-9 for high-level Warlocks) are cast 1/long rest
      // without expending a spell slot, and do NOT count against the Pact Magic Spells Known limit.
      final int effectiveKnownCount;
      if (targetClassSlug.toLowerCase() == 'warlock' &&
          limits.mysticArcanumLevel > 0 &&
          resolver != null) {
        effectiveKnownCount = spellsKnown.where((ref) {
          final res = resolver.resolveTyped<Spell>(ref);
          if (res.isResolved && res.entity != null) {
            final spell = res.entity!;
            return !(spell.level >= 6 &&
                spell.level <= limits.mysticArcanumLevel);
          }
          return true;
        }).length;
      } else {
        effectiveKnownCount = spellsKnown.length;
      }

      if (effectiveKnownCount > limits.maxSpellsKnown) {
        errors.add(
          'Selected $effectiveKnownCount spells known, exceeding the maximum allowed limit of ${limits.maxSpellsKnown} for $targetClassSlug level $targetClassLevel.',
        );
      }
    }

    // 4. Prepared Spells Limit Check (Exempting domain/oath always-prepared spells)
    if (limits.maxSpellsPrepared > 0) {
      final effectivePreparedCount = spellsPrepared.where((ref) {
        return !alwaysPreparedSpellIds.contains(ref.slug) &&
            !alwaysPreparedSpellIds.contains(ref.displayName.toLowerCase());
      }).length;

      if (effectivePreparedCount > limits.maxSpellsPrepared) {
        errors.add(
          'Prepared $effectivePreparedCount spells, exceeding the prepared limit of ${limits.maxSpellsPrepared} (Level $targetClassLevel + Ability Mod $castingAbilityModifier).',
        );
      }
    }

    // 5. Spell Tier & Class Gating Check
    if (resolver != null) {
      final allSelectedSpells = {
        ...cantrips,
        ...spellsKnown,
        ...spellsPrepared,
        ...spellbookSpells
      };
      for (final ref in allSelectedSpells) {
        final res = resolver.resolveTyped<Spell>(ref);
        if (res.isResolved && res.entity != null) {
          final spell = res.entity!;
          final isCantrip = cantrips.any((c) => c.slug == ref.slug);

          if (isCantrip && spell.level != 0) {
            errors.add(
                'Spell "${spell.name}" is Level ${spell.level} but was assigned as a cantrip.');
          } else if (!isCantrip) {
            // Check Mystic Arcanum exception for Warlock
            final isMysticArcanum =
                targetClassSlug.toLowerCase() == 'warlock' &&
                    limits.mysticArcanumLevel > 0 &&
                    spell.level >= 6 &&
                    spell.level <= limits.mysticArcanumLevel;

            if (!isMysticArcanum && spell.level > limits.maxSpellSlotLevel) {
              errors.add(
                'Spell "${spell.name}" is Level ${spell.level}, but $targetClassSlug at level $targetClassLevel can only cast up to Level ${limits.maxSpellSlotLevel} spells.',
              );
            }
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      return SpellValidationResult.invalid(errors, warnings);
    }
    return const SpellValidationResult.valid();
  }

  /// Validates origin-keyed spell allocations against active feature grants and class progressions.
  static SpellValidationResult validateSpellAllocations(
    Character character,
    List<FeatureGrant> activeGrants,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    // Extract all valid grantIds
    final validGrantIds =
        activeGrants.map((g) => g.grantId).whereType<String>().toSet();

    // Add standard class-specific grant ids
    for (final c in character.progression.classes) {
      validGrantIds.add('class-${c.classRef.slug}-cantrips');
      validGrantIds.add('class-${c.classRef.slug}-spells');
      validGrantIds.add('class-${c.classRef.slug}-mystic-arcanum');
      validGrantIds.add('class-${c.classRef.slug}');
      validGrantIds.add(c.classRef.slug);
    }

    // Check character.allocatedSpells.keys
    for (final entry in character.allocatedSpells.entries) {
      final grantKey = entry.key;
      final spells = entry.value;

      // Check if it's an orphan grant
      final matchingGrant =
          activeGrants.where((g) => g.grantId == grantKey).firstOrNull;
      final isClassKey = character.progression.classes.any((c) =>
          grantKey.contains(c.classRef.slug) ||
          grantKey == 'cantrips' ||
          grantKey == 'spellsKnown');

      if (!validGrantIds.contains(grantKey) &&
          !isClassKey &&
          matchingGrant == null) {
        errors.add(
            'Orphan spell allocation key "$grantKey" is not associated with any active grant or class.');
      }

      // If matching grant found, check counts
      if (matchingGrant != null) {
        if (matchingGrant.type == GrantType.bonusCantrip) {
          final maxCount =
              (matchingGrant.payload['count'] as num?)?.toInt() ?? 1;
          if (spells.length > maxCount) {
            errors.add(
                'Grant "$grantKey" allows at most $maxCount cantrips, but allocated ${spells.length}.');
          }
        } else if (matchingGrant.type == GrantType.bonusSpell) {
          const maxCount = 1;
          if (spells.length > maxCount) {
            errors.add(
                'Grant "$grantKey" allows at most $maxCount spells, but allocated ${spells.length}.');
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      return SpellValidationResult.invalid(errors, warnings);
    }
    return const SpellValidationResult.valid();
  }
}
