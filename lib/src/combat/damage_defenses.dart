import 'package:meta/meta.dart';

/// Parsed damage immunities, resistances, and vulnerabilities from stat-block text.
///
/// Splits stat-block text on commas, semicolons, and `and`, normalizes to
/// lower-case, and preserves qualifiers after a damage type (such as
/// `"from nonmagical attacks"`). An empty or unknown damage type is never
/// matched by a substring; it matches only when present as an exact parsed
/// token (or via `all` for immunity and resistance).
@immutable
class DamageDefenses {
  final Set<String> immunities;
  final Set<String> resistances;
  final Set<String> vulnerabilities;

  const DamageDefenses({
    required this.immunities,
    required this.resistances,
    required this.vulnerabilities,
  });

  static final RegExp _separatorRe = RegExp(r'[,;]|\band\b', caseSensitive: false);
  static final RegExp _parenRe = RegExp(r'\([^)]*\)');
  static final RegExp _qualifierTailRe = RegExp(
    r'\s+(?:from|that|not|unless|while|made|dealt|by|except|in|of|with)\b.*$',
    caseSensitive: false,
  );
  static final RegExp _leadingNoiseRe = RegExp(
    r'^(?:non[\s-]+magical|nonmagical|magical|damage)\s+',
    caseSensitive: false,
  );

  /// Parses stat-block text fields into normalized defense token sets.
  factory DamageDefenses.fromStatBlockText({
    String? immunities,
    String? resistances,
    String? vulnerabilities,
  }) {
    return DamageDefenses(
      immunities: Set<String>.unmodifiable(_parseField(immunities)),
      resistances: Set<String>.unmodifiable(_parseField(resistances)),
      vulnerabilities: Set<String>.unmodifiable(_parseField(vulnerabilities)),
    );
  }

  static Set<String> _parseField(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <String>{};
    final cleaned = raw.toLowerCase().replaceAll(_parenRe, ' ');
    final tokens = <String>{};
    for (final segment in cleaned.split(_separatorRe)) {
      var part = segment.trim();
      if (part.isEmpty) continue;
      part = part.replaceFirst(_qualifierTailRe, '').trim();
      while (part.isNotEmpty) {
        final stripped = part.replaceFirst(_leadingNoiseRe, '').trim();
        if (stripped == part) break;
        part = stripped;
      }
      if (part.isNotEmpty) {
        tokens.add(part);
      }
    }
    return tokens;
  }

  static String _normalize(String damageType) => damageType.trim().toLowerCase();

  /// Returns whether [damageType] is negated by immunity (including `all`).
  /// Empty strings never match.
  bool isImmune(String damageType) {
    final key = _normalize(damageType);
    if (key.isEmpty) return false;
    return immunities.contains(key) || immunities.contains('all');
  }

  /// Returns whether [damageType] is halved by resistance (including `all`).
  /// Empty strings never match.
  bool isResistant(String damageType) {
    final key = _normalize(damageType);
    if (key.isEmpty) return false;
    return resistances.contains(key) || resistances.contains('all');
  }

  /// Returns whether [damageType] is doubled by vulnerability.
  /// Empty strings and `all` never grant vulnerability.
  bool isVulnerable(String damageType) {
    final key = _normalize(damageType);
    if (key.isEmpty) return false;
    return vulnerabilities.contains(key);
  }
}
