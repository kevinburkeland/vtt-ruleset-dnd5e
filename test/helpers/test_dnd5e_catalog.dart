import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

/// Test fixture catalog that returns what the old null hooks produced:
/// nothing found, empty lists.
class TestDnd5eCatalog implements Dnd5eCatalog {
  final dynamic Function(String slug)? onFindClass;
  final dynamic Function(String slug)? onFindFeat;
  final dynamic Function(String idOrName)? onFindMagicItem;
  final List<String> Function(String classSlug, String? subclassSlug, int classLevel, RulesetEdition edition)? onGetAlwaysPreparedSpells;
  final int? Function(String slug)? onGetSpellLevel;
  final List<CombatEffectRider> Function(String markdown)? onExtractRiders;
  final Map<String, bool> Function(dynamic addSpellsData)? onExtractSpellDescriptors;
  final Set<String> Function(dynamic addSpellsData)? onExtractSpellNames;
  final List<FeatureGrant> Function(dynamic addSpellsData, String ownerPrefix, String ownerSlug)? onExtractBonusSpells;

  const TestDnd5eCatalog({
    this.onFindClass,
    this.onFindFeat,
    this.onFindMagicItem,
    this.onGetAlwaysPreparedSpells,
    this.onGetSpellLevel,
    this.onExtractRiders,
    this.onExtractSpellDescriptors,
    this.onExtractSpellNames,
    this.onExtractBonusSpells,
  });

  @override
  dynamic findClass(String slug) => onFindClass != null ? onFindClass!(slug) : null;

  @override
  dynamic findFeat(String slug) => onFindFeat != null ? onFindFeat!(slug) : null;

  @override
  dynamic findMagicItem(String idOrName) => onFindMagicItem != null ? onFindMagicItem!(idOrName) : null;

  @override
  List<String> getAlwaysPreparedSpells({
    required String classSlug,
    String? subclassSlug,
    required int classLevel,
    required RulesetEdition edition,
  }) => onGetAlwaysPreparedSpells != null
      ? onGetAlwaysPreparedSpells!(classSlug, subclassSlug, classLevel, edition)
      : const [];

  @override
  int? getSpellLevel(String slug) => onGetSpellLevel != null ? onGetSpellLevel!(slug) : null;

  @override
  List<CombatEffectRider> extractRiders(String markdown) =>
      onExtractRiders != null ? onExtractRiders!(markdown) : const [];

  @override
  Map<String, bool> extractSpellDescriptors(dynamic addSpellsData) =>
      onExtractSpellDescriptors != null ? onExtractSpellDescriptors!(addSpellsData) : const {};

  @override
  Set<String> extractSpellNames(dynamic addSpellsData) =>
      onExtractSpellNames != null ? onExtractSpellNames!(addSpellsData) : const {};

  @override
  List<FeatureGrant> extractBonusSpells(
    dynamic addSpellsData,
    String ownerPrefix,
    String ownerSlug,
  ) => onExtractBonusSpells != null
      ? onExtractBonusSpells!(addSpellsData, ownerPrefix, ownerSlug)
      : const [];
}
