/// Canonical 5e Ruleset Edition domain enum and parsing logic.
enum RulesetEdition {
  v2014,
  v2024;

  /// Static aliases for seamless backward-compatibility across legacy call sites.
  static const RulesetEdition dnd2014 = RulesetEdition.v2014;
  static const RulesetEdition dnd2024 = RulesetEdition.v2024;
  static const RulesetEdition srd2014 = RulesetEdition.v2014;
  static const RulesetEdition srd2024 = RulesetEdition.v2024;
  static const RulesetEdition comparative = RulesetEdition.v2014;

  /// Identity helper for code transitioning from legacy conversion methods.
  RulesetEdition toEdition() => this;

  /// Identity parser for code transitioning from legacy conversion methods.
  static RulesetEdition fromEdition(RulesetEdition edition) => edition;

  /// Instance getter for edition name supporting dynamic call sites.
  String get name => switch (this) {
        RulesetEdition.v2014 => 'v2014',
        RulesetEdition.v2024 => 'v2024',
      };

  /// Concise label for badges, chips, and tabs.
  String get shortLabel => switch (this) {
        RulesetEdition.v2014 => '2014',
        RulesetEdition.v2024 => '2024',
      };

  /// Legacy label alias for UI components expecting [label].
  String get label => shortLabel;

  /// Whether this edition represents the revised 2024 ruleset baseline.
  bool get is2024 => this == RulesetEdition.v2024;

  /// Whether this edition represents the legacy 2014 ruleset baseline.
  bool get is2014 => this == RulesetEdition.v2014;

  /// Robust string parser handling compendium and schema identifiers ('5e-2014', 'v2014', 'srd2024', etc.).
  static RulesetEdition fromString(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.contains('2024') ||
        clean == 'srd5.2.1' ||
        clean == 'srd5.2' ||
        clean == 'srd2024' ||
        clean == 'srd521' ||
        clean == 'srd52' ||
        clean == '5e-2024' ||
        clean == 'v2024' ||
        clean.contains('5.2')) {
      return RulesetEdition.v2024;
    }
    return RulesetEdition.v2014;
  }
}

/// 5e-specific extensions on [RulesetEdition] providing SRD citations, display names, and bundle IDs.
extension RulesetEdition5eExtension on RulesetEdition {
  /// Human-readable display title.
  String get displayName => switch (this) {
        RulesetEdition.v2014 => '2014 Rules (SRD 5.1)',
        RulesetEdition.v2024 => '2024 Revised Rules (SRD 5.2.1)',
      };

  /// Machine edition identifier for bundles and wire payloads.
  String get editionId => switch (this) {
        RulesetEdition.v2014 => '5e-2014',
        RulesetEdition.v2024 => '5e-2024',
      };

  /// Systems Reference Document citation.
  String get srdCitation => switch (this) {
        RulesetEdition.v2014 =>
          'Systems Reference Document 5.1 (OGL 1.0a / CC-BY-4.0)',
        RulesetEdition.v2024 => 'System Reference Document 5.2.1 (CC-BY-4.0)',
      };
}
