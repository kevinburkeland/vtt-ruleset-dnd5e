import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../helpers/test_dnd5e_catalog.dart';

// Independent SRD 5.1 (2014) and SRD 5.2.1 (2024) class table copies
// (typed directly from the SRD class tables, never read from code under test).

const _cantrips2014 = <String, List<int>>{
  'bard': [2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  'cleric': [3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  'druid': [2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  'paladin': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'ranger': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'sorcerer': [4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6],
  'warlock': [2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  'wizard': [3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  'eldritch_knight': [0, 0, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
  'arcane_trickster': [0, 0, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
};

const _cantrips2024 = <String, List<int>>{
  'bard': [2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  'cleric': [3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  'druid': [2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  'paladin': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'ranger': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'sorcerer': [4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6],
  'warlock': [2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
  'wizard': [3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  'eldritch_knight': [0, 0, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
  'arcane_trickster': [0, 0, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
};

const _spellsKnown2014 = <String, List<int>>{
  'bard': [4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 15, 16, 18, 19, 19, 20, 22, 22, 22],
  'ranger': [0, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11],
  'sorcerer': [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 13, 14, 14, 15, 15, 15, 15],
  'warlock': [2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15],
  'eldritch_knight': [0, 0, 3, 4, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11, 11, 12, 13],
  'arcane_trickster': [0, 0, 3, 4, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11, 11, 12, 13],
};

const _preparedSpells2024 = <String, List<int>>{
  'bard': [4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22],
  'cleric': [4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22],
  'druid': [4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22],
  'paladin': [2, 3, 4, 5, 6, 6, 7, 7, 9, 9, 10, 10, 11, 11, 12, 12, 14, 14, 15, 15],
  'ranger': [2, 3, 4, 5, 6, 6, 7, 7, 9, 9, 10, 10, 11, 11, 12, 12, 14, 14, 15, 15],
  'sorcerer': [2, 4, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22],
  'warlock': [2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15],
  'wizard': [4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 16, 17, 18, 19, 21, 22, 23, 24, 25],
  'eldritch_knight': [0, 0, 3, 4, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11, 11, 12, 13],
  'arcane_trickster': [0, 0, 3, 4, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 11, 11, 12, 13],
};

const _casterEntries = <({String key, String classSlug, String? subclassSlug})>[
  (key: 'bard', classSlug: 'bard', subclassSlug: null),
  (key: 'cleric', classSlug: 'cleric', subclassSlug: null),
  (key: 'druid', classSlug: 'druid', subclassSlug: null),
  (key: 'paladin', classSlug: 'paladin', subclassSlug: null),
  (key: 'ranger', classSlug: 'ranger', subclassSlug: null),
  (key: 'sorcerer', classSlug: 'sorcerer', subclassSlug: null),
  (key: 'warlock', classSlug: 'warlock', subclassSlug: null),
  (key: 'wizard', classSlug: 'wizard', subclassSlug: null),
  (key: 'eldritch_knight', classSlug: 'fighter', subclassSlug: 'eldritch_knight'),
  (key: 'arcane_trickster', classSlug: 'rogue', subclassSlug: 'arcane_trickster'),
];

void main() {
  setUp(() {
    Dnd5eRuleset.install(const TestDnd5eCatalog());
  });

  group('Fix 3.1 law: SRD class table spell counts in both editions', () {
    test('2024 Paladin at level 1 with +3 modifier has 2 prepared spells and 0 cantrips', () {
      final limits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'paladin',
        classLevel: 1,
        abilityModifier: 3,
        edition: RulesetEdition.v2024,
      );
      expect(limits.maxCantrips, equals(0),
          reason: '2024 paladin level 1 cantrips: expected 0, got ${limits.maxCantrips}');
      expect(limits.maxSpellsPrepared, equals(2),
          reason: '2024 paladin level 1 prepared: expected 2, got ${limits.maxSpellsPrepared}');
    });

    test('exhaustive 2014 and 2024 class table cantrip and prepared/known counts for levels 1-20 and modifiers -1..+5', () {
      final failures = <String>[];

      for (final edition in const [RulesetEdition.v2014, RulesetEdition.v2024]) {
        final edLabel = edition == RulesetEdition.v2014 ? '2014' : '2024';
        for (final entry in _casterEntries) {
          for (var level = 1; level <= 20; level++) {
            for (var mod = -1; mod <= 5; mod++) {
              final limits = SpellAllocationValidator.getLimitsForClass(
                classSlug: entry.classSlug,
                subclassSlug: entry.subclassSlug,
                classLevel: level,
                abilityModifier: mod,
                edition: edition,
              );

              final expCantrips = edition == RulesetEdition.v2014
                  ? _cantrips2014[entry.key]![level - 1]
                  : _cantrips2024[entry.key]![level - 1];
              if (limits.maxCantrips != expCantrips) {
                failures.add(
                  '$edLabel ${entry.key} L$level mod=$mod cantrips: expected $expCantrips, got ${limits.maxCantrips}',
                );
              }

              if (edition == RulesetEdition.v2024) {
                final expCount = _preparedSpells2024[entry.key]![level - 1];
                final usesKnownBucket = entry.key == 'bard' ||
                    entry.key == 'sorcerer' ||
                    entry.key == 'warlock' ||
                    entry.key == 'eldritch_knight' ||
                    entry.key == 'arcane_trickster';
                final expPrepared = usesKnownBucket ? 0 : expCount;
                final expKnown = usesKnownBucket ? expCount : 0;
                if (limits.maxSpellsPrepared != expPrepared ||
                    limits.maxSpellsKnown != expKnown) {
                  failures.add(
                    '$edLabel ${entry.key} L$level mod=$mod prepared/known: expected ($expPrepared, $expKnown), got (${limits.maxSpellsPrepared}, ${limits.maxSpellsKnown})',
                  );
                }
              } else {
                // 2014 edition
                final knownTable = _spellsKnown2014[entry.key];
                if (knownTable != null) {
                  final expKnown = knownTable[level - 1];
                  if (limits.maxSpellsKnown != expKnown || limits.maxSpellsPrepared != 0) {
                    failures.add(
                      '$edLabel ${entry.key} L$level mod=$mod known/prepared: expected ($expKnown, 0), got (${limits.maxSpellsKnown}, ${limits.maxSpellsPrepared})',
                    );
                  }
                } else if (entry.key == 'paladin') {
                  final expPrepared = level < 2 ? 0 : math.max(1, (level ~/ 2) + mod);
                  if (limits.maxSpellsPrepared != expPrepared || limits.maxSpellsKnown != 0) {
                    failures.add(
                      '$edLabel ${entry.key} L$level mod=$mod prepared/known: expected ($expPrepared, 0), got (${limits.maxSpellsPrepared}, ${limits.maxSpellsKnown})',
                    );
                  }
                } else {
                  // 2014 Cleric, Druid, Wizard: max(1, level + mod)
                  final expPrepared = math.max(1, level + mod);
                  if (limits.maxSpellsPrepared != expPrepared || limits.maxSpellsKnown != 0) {
                    failures.add(
                      '$edLabel ${entry.key} L$level mod=$mod prepared/known: expected ($expPrepared, 0), got (${limits.maxSpellsPrepared}, ${limits.maxSpellsKnown})',
                    );
                  }
                }
              }
            }
          }
        }
      }

      if (failures.isNotEmpty) {
        final preview = failures.take(40).join('\n');
        fail('SRD spell count law failed (${failures.length} cell mismatch(es)):\n$preview');
      }
    });

    test('2024 validateSpellSelection prepared limit message cites 2024 class table', () {
      final result = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'paladin',
        targetClassLevel: 1,
        castingAbilityModifier: 3,
        edition: RulesetEdition.v2024,
        cantrips: const [],
        spellsKnown: const [],
        spellsPrepared: const [
          EntityReference.empty(slug: 'bless', refType: EntityType.spell, displayName: 'Bless'),
          EntityReference.empty(slug: 'command', refType: EntityType.spell, displayName: 'Command'),
          EntityReference.empty(slug: 'shield-of-faith', refType: EntityType.spell, displayName: 'Shield of Faith'),
        ],
      );
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('2024 class table'));
    });
  });
}
