import 'package:meta/meta.dart';
import '../models/character_models.dart';
import '../rules/ruleset_edition.dart';
import 'spell_allocation_validator.dart';
import 'spellcasting_rules_engine.dart' show SpellClass;

/// Spellcasting slot progression tier for a class (used for custom/homebrew
/// classes whose slug is not in the built-in SRD class tables).
enum CasterProgression {
  full,
  half,
  third,
  pact;

  /// Parses a serialized progression key (case-insensitive) or returns `null`
  /// if unrecognized.
  static CasterProgression? tryParse(String? raw) {
    if (raw == null) return null;
    final norm = raw.trim().toLowerCase();
    return switch (norm) {
      'full' => CasterProgression.full,
      'half' || '1/2' => CasterProgression.half,
      'third' || '1/3' => CasterProgression.third,
      'pact' => CasterProgression.pact,
      _ => null,
    };
  }
}

/// Canonical spellcasting profile for a class (and optional subclass) at a
/// specific class level and ruleset edition.
@immutable
class ClassSpellcasterProfile {
  final bool isSpellcaster;
  final AbilityType? castingAbility;
  final int highestSpellLevel;
  final SpellClass? spellList;

  const ClassSpellcasterProfile({
    required this.isSpellcaster,
    required this.castingAbility,
    required this.highestSpellLevel,
    required this.spellList,
  });

  const ClassSpellcasterProfile.nonCaster()
      : isSpellcaster = false,
        castingAbility = null,
        highestSpellLevel = 0,
        spellList = null;
}

AbilityType? _parseAbilityName(String raw) {
  final lower = raw.toLowerCase().trim();
  for (final ab in AbilityType.values) {
    if (ab.name.toLowerCase() == lower || ab.shortName.toLowerCase() == lower) {
      return ab;
    }
  }
  return null;
}

SpellClass? _resolveSpellList(String classSlug, String? subclassSlug) {
  final sub = subclassSlug?.toLowerCase().replaceAll('-', '_') ?? '';
  if (sub.contains('eldritch_knight') || sub.contains('arcane_trickster')) {
    return SpellClass.wizard;
  }
  return switch (classSlug.toLowerCase()) {
    'wizard' => SpellClass.wizard,
    'cleric' => SpellClass.cleric,
    'druid' => SpellClass.druid,
    'bard' => SpellClass.bard,
    'sorcerer' => SpellClass.sorcerer,
    'warlock' => SpellClass.warlock,
    'ranger' => SpellClass.ranger,
    'paladin' => SpellClass.paladin,
    _ => null,
  };
}

/// Resolves whether [classSlug] (with optional [subclassSlug]) casts spells at
/// [classLevel] under [edition], its casting ability, highest accessible spell
/// level, and spell list.
///
/// Delegates to [SpellAllocationValidator.getLimitsForClass] as the single
/// source of truth. [fallbackCastingAbility] is used only when a custom class
/// is not covered by the built-in SRD class tables.
ClassSpellcasterProfile resolveClassSpellcasterProfile({
  required String classSlug,
  required int classLevel,
  required RulesetEdition edition,
  String? subclassSlug,
  AbilityType? fallbackCastingAbility,
  CasterProgression? casterProgression,
}) {
  final limits = SpellAllocationValidator.getLimitsForClass(
    classSlug: classSlug,
    classLevel: classLevel,
    abilityModifier: 0,
    subclassSlug: subclassSlug,
    edition: edition,
  );
  if (!limits.isSpellcaster) {
    if (casterProgression != null && fallbackCastingAbility != null) {
      final highest = switch (casterProgression) {
        CasterProgression.full =>
          SpellAllocationValidator.getMaxSpellTierForClass(
            classSlug: 'wizard',
            classLevel: classLevel,
            edition: edition,
          ),
        CasterProgression.half =>
          SpellAllocationValidator.getMaxSpellTierForClass(
            classSlug: 'paladin',
            classLevel: classLevel,
            edition: edition,
          ),
        CasterProgression.third =>
          SpellAllocationValidator.getMaxSpellTierForClass(
            classSlug: 'fighter',
            subclassSlug: 'eldritch_knight',
            classLevel: classLevel,
            edition: edition,
          ),
        CasterProgression.pact =>
          SpellAllocationValidator.getMaxSpellTierForClass(
            classSlug: 'warlock',
            classLevel: classLevel,
            edition: edition,
          ),
      };
      if (highest > 0) {
        return ClassSpellcasterProfile(
          isSpellcaster: true,
          castingAbility: fallbackCastingAbility,
          highestSpellLevel: highest,
          spellList: null,
        );
      }
    }
    return const ClassSpellcasterProfile.nonCaster();
  }
  final ability =
      _parseAbilityName(limits.castingAbility) ?? fallbackCastingAbility;
  return ClassSpellcasterProfile(
    isSpellcaster: true,
    castingAbility: ability,
    highestSpellLevel: limits.maxSpellSlotLevel,
    spellList: _resolveSpellList(classSlug, subclassSlug),
  );
}
