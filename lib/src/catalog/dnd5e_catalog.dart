import 'package:meta/meta.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../models/feature_grant.dart';
import '../rules/ruleset_edition.dart';

/// Abstract collaborator contract supplying external entity lookups, spell information,
/// and compendium token parsing required by the D&D 5e rules engine.
abstract interface class Dnd5eCatalog {
  /// Looks up a class definition by its slug.
  DomainEntity? findClass(String slug);

  /// Looks up a feat definition by its slug.
  dynamic findFeat(String slug);

  /// Looks up a magic item by its ID or name.
  dynamic findMagicItem(String idOrName);

  /// Retrieves always-prepared spell names for a class/subclass at the given level and edition.
  List<String> getAlwaysPreparedSpells({
    required String classSlug,
    String? subclassSlug,
    required int classLevel,
    required RulesetEdition edition,
  });

  /// Resolves the spell level (0 for cantrips, 1-9 for leveled spells) for the given spell slug.
  int? getSpellLevel(String slug);

  /// Extracts combat effect riders from a spell or ability markdown description.
  List<CombatEffectRider> extractRiders(String markdown);

  /// Extracts spell names and cantrip flags from compendium additionalSpells / subclassSpells structures.
  Map<String, bool> extractSpellDescriptors(dynamic addSpellsData);

  /// Extracts clean spell names from compendium additionalSpells / subclassSpells structures.
  Set<String> extractSpellNames(dynamic addSpellsData);

  /// Extracts bonus spell feature grants from compendium additionalSpells / subclassSpells structures.
  List<FeatureGrant> extractBonusSpells(
    dynamic addSpellsData,
    String ownerPrefix,
    String ownerSlug,
  );
}

/// Singleton gateway managing the installation and retrieval of the active [Dnd5eCatalog].
/// Error thrown when [Dnd5eRuleset.catalog] is accessed before any catalog has been installed.
class CatalogNotInstalledError extends StateError {
  CatalogNotInstalledError([
    super.message = 'Dnd5eCatalog has not been installed. Call Dnd5eRuleset.install(catalog) '
        'during application or test startup before accessing ruleset capabilities.',
  ]);
}

/// Singleton gateway managing the installation and retrieval of the active [Dnd5eCatalog].
class Dnd5eRuleset {
  Dnd5eRuleset._();

  static Dnd5eCatalog? _catalog;

  /// Retrieves the installed [Dnd5eCatalog].
  ///
  /// Throws [CatalogNotInstalledError] if no catalog has been installed yet.
  static Dnd5eCatalog get catalog {
    final cat = _catalog;
    if (cat == null) {
      throw CatalogNotInstalledError();
    }
    return cat;
  }

  /// Installs the active [Dnd5eCatalog].
  ///
  /// Throws [StateError] if a different catalog is already installed unless
  /// [resetForTesting] is called first.
  static void install(Dnd5eCatalog catalog) {
    if (_catalog != null && !identical(_catalog, catalog)) {
      throw StateError(
        'A Dnd5eCatalog is already installed. Call Dnd5eRuleset.resetForTesting() '
        'before installing a new catalog.',
      );
    }
    _catalog = catalog;
  }

  /// Clears the installed catalog. For use in test tearDown / setup only.
  @visibleForTesting
  static void resetForTesting() {
    _catalog = null;
  }
}
