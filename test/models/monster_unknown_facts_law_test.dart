import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

const _kStatBlockFactKeys = <String>[
  'sizeDisplay',
  'typeDisplay',
  'alignment',
  'ac',
  'maxHp',
  'hitDice',
  'crDisplay',
];

const _kLegacyMonsterFactKeys = <String>[
  'size',
  'monsterType',
  'alignment',
  'armorClass',
  'hitPoints',
  'hitDieFormula',
  'challengeRating',
];

Map<String, Object?> _fullStatBlockMap(int seed) => {
      'id': 'sb-$seed',
      'name': 'Creature $seed',
      'sizeDisplay': 'Large',
      'typeDisplay': 'Dragon',
      'alignment': 'chaotic good',
      'ac': 17,
      'maxHp': 136,
      'hitDice': '16d10 + 48',
      'crDisplay': 'CR 8',
      'attackBonus': 7,
      'damageDiceCount': 2,
      'damageDiceSides': 8,
      'damageBonus': 4,
      'damageType': 'Slashing',
    };

Map<String, Object?> _fullLegacyMonsterMap(int seed) => {
      'id': {'slug': 'mon-$seed', 'ruleset': 'homebrew'},
      'name': 'Legacy Creature $seed',
      'size': 'Huge',
      'monsterType': 'Fiend',
      'alignment': 'lawful evil',
      'armorClass': 18,
      'hitPoints': 152,
      'hitDieFormula': '16d12 + 48',
      'challengeRating': '10',
      'actionsMarkdown': '',
      'innateSpells': const <Object?>[],
      'attackMath': const <Object?>[],
      'customProperties': const <String, Object?>{},
    };

Object? _readStatBlockFact(MonsterStatBlock sb, String key) {
  switch (key) {
    case 'sizeDisplay':
      return sb.sizeDisplay;
    case 'typeDisplay':
      return sb.typeDisplay;
    case 'alignment':
      return sb.alignment;
    case 'ac':
      return sb.ac;
    case 'maxHp':
      return sb.maxHp;
    case 'hitDice':
      return sb.hitDice;
    case 'crDisplay':
      return sb.crDisplay;
    default:
      throw ArgumentError('Unknown stat block fact key: $key');
  }
}

Object? _readMonsterFact(Monster m, String key) {
  switch (key) {
    case 'size':
      return m.size;
    case 'monsterType':
      return m.monsterType;
    case 'alignment':
      return m.alignment;
    case 'armorClass':
      return m.armorClass;
    case 'hitPoints':
      return m.hitPoints;
    case 'hitDieFormula':
      return m.hitDieFormula;
    case 'challengeRating':
      return m.challengeRating;
    default:
      throw ArgumentError('Unknown monster fact key: $key');
  }
}

void main() {
  group('Fix 7.1: Unknown monster facts stay unknown (null, no invented defaults)', () {
    test('MonsterStatBlock.fromMap of minimal {id, name} keeps all 7 F-16 facts null', () {
      final sb = MonsterStatBlock.fromMap(const {
        'id': 'minimal-sb',
        'name': 'Unknown Thing',
      });
      final invented = <String, Object?>{};
      for (final key in _kStatBlockFactKeys) {
        final actual = _readStatBlockFact(sb, key);
        if (actual != null) invented[key] = actual;
      }
      if (invented.isNotEmpty) {
        fail(
          'MonsterStatBlock.fromMap minimal map (removedKeys=$_kStatBlockFactKeys): '
          'expected all null, got invented=$invented',
        );
      }
    });

    test('Monster.fromMap (legacy pre-slice-18) of minimal {id, name} keeps all 7 F-16 facts null', () {
      final m = Monster.fromMap(const {
        'id': {'slug': 'minimal-legacy', 'ruleset': 'homebrew'},
        'name': 'Unknown Legacy Creature',
      });
      final invented = <String, Object?>{};
      for (final key in _kLegacyMonsterFactKeys) {
        final actual = _readMonsterFact(m, key);
        if (actual != null) invented[key] = actual;
      }
      if (invented.isNotEmpty) {
        fail(
          'Monster.fromMap legacy minimal map (removedKeys=$_kLegacyMonsterFactKeys): '
          'expected all null, got invented=$invented',
        );
      }
      for (final key in _kStatBlockFactKeys) {
        final actual = _readStatBlockFact(m.statBlock2024, key);
        if (actual != null) {
          fail(
            'Monster.fromMap legacy minimal map statBlock2024 '
            '(removedKeys=$_kLegacyMonsterFactKeys): expected $key == null, got $actual',
          );
        }
      }
    });

    test('Monster.fromMap (unified embedded stat blocks) of minimal stat blocks keeps all 7 F-16 facts null', () {
      final m = Monster.fromMap(const {
        'id': {'slug': 'minimal-unified', 'ruleset': 'homebrew'},
        'name': 'Unknown Unified Creature',
        'statBlock2014': {'id': 'minimal-unified', 'name': 'Unknown Unified Creature'},
        'statBlock2024': {'id': 'minimal-unified', 'name': 'Unknown Unified Creature'},
      });
      for (final key in _kLegacyMonsterFactKeys) {
        final actual = _readMonsterFact(m, key);
        if (actual != null) {
          fail(
            'Monster.fromMap unified minimal map (removedKeys=$_kStatBlockFactKeys): '
            'expected $key == null, got $actual',
          );
        }
      }
    });

    test('MonsterStatBlock.fromMap subset removal law (200 seeded cases)', () {
      final rng = Random(20260701);
      for (var i = 0; i < 200; i++) {
        final full = _fullStatBlockMap(i);
        final removed = <String>[];
        if (i < _kStatBlockFactKeys.length) {
          removed.add(_kStatBlockFactKeys[i]);
        } else {
          for (final key in _kStatBlockFactKeys) {
            if (rng.nextBool()) removed.add(key);
          }
          if (removed.isEmpty) removed.add(_kStatBlockFactKeys[i % _kStatBlockFactKeys.length]);
        }
        final map = Map<String, dynamic>.from(full);
        for (final key in removed) {
          map.remove(key);
        }
        final sb = MonsterStatBlock.fromMap(map);
        for (final key in _kStatBlockFactKeys) {
          final actual = _readStatBlockFact(sb, key);
          if (removed.contains(key)) {
            if (actual != null) {
              fail(
                'MonsterStatBlock.fromMap case=$i removedKeys=$removed: '
                'expected $key == null, got $actual',
              );
            }
          } else {
            final expected = full[key];
            if (actual != expected) {
              fail(
                'MonsterStatBlock.fromMap case=$i removedKeys=$removed: '
                'expected kept $key == $expected, got $actual',
              );
            }
          }
        }
      }
    });

    test('Monster.fromMap legacy and unified subset removal law (200 seeded cases)', () {
      final rng = Random(20260702);
      for (var i = 0; i < 200; i++) {
        final fullLegacy = _fullLegacyMonsterMap(i);
        final removedLegacy = <String>[];
        if (i < _kLegacyMonsterFactKeys.length) {
          removedLegacy.add(_kLegacyMonsterFactKeys[i]);
        } else {
          for (final key in _kLegacyMonsterFactKeys) {
            if (rng.nextBool()) removedLegacy.add(key);
          }
          if (removedLegacy.isEmpty) {
            removedLegacy.add(_kLegacyMonsterFactKeys[i % _kLegacyMonsterFactKeys.length]);
          }
        }
        final legacyMap = Map<String, dynamic>.from(fullLegacy);
        for (final key in removedLegacy) {
          legacyMap.remove(key);
        }

        final legacyMonster = Monster.fromMap(legacyMap);
        for (final key in _kLegacyMonsterFactKeys) {
          final actual = _readMonsterFact(legacyMonster, key);
          if (removedLegacy.contains(key)) {
            if (actual != null) {
              fail(
                'Monster.fromMap (legacy) case=$i removedKeys=$removedLegacy: '
                'expected $key == null, got $actual',
              );
            }
          } else {
            final expected = fullLegacy[key];
            if (actual != expected) {
              fail(
                'Monster.fromMap (legacy) case=$i removedKeys=$removedLegacy: '
                'expected kept $key == $expected, got $actual',
              );
            }
          }
        }

        // Also test unified embedded statBlock map with the same removed indices
        final fullSb = _fullStatBlockMap(i);
        final removedSb = <String>[];
        for (var idx = 0; idx < _kLegacyMonsterFactKeys.length; idx++) {
          if (removedLegacy.contains(_kLegacyMonsterFactKeys[idx])) {
            removedSb.add(_kStatBlockFactKeys[idx]);
          }
        }
        final sbMap = Map<String, dynamic>.from(fullSb);
        for (final key in removedSb) {
          sbMap.remove(key);
        }
        final unifiedMonster = Monster.fromMap({
          'id': {'slug': 'uni-$i', 'ruleset': 'homebrew'},
          'name': 'Unified Creature $i',
          'statBlock2014': sbMap,
          'statBlock2024': sbMap,
        });
        for (final key in _kStatBlockFactKeys) {
          final actual = _readStatBlockFact(unifiedMonster.statBlock2024, key);
          if (removedSb.contains(key)) {
            if (actual != null) {
              fail(
                'Monster.fromMap (unified) case=$i removedKeys=$removedSb: '
                'expected statBlock2024.$key == null, got $actual',
              );
            }
          } else {
            final expected = fullSb[key];
            if (actual != expected) {
              fail(
                'Monster.fromMap (unified) case=$i removedKeys=$removedSb: '
                'expected kept statBlock2024.$key == $expected, got $actual',
              );
            }
          }
        }
      }
    });
  });
}
