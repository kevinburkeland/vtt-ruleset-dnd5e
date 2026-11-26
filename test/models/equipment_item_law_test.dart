import 'dart:math';
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

// Independent copy of pre-Cleanup slice 17 equipmentItemToMagicItem rules
// for Fix 5.3 old-format compatibility law.
ItemCategory _legacyCategory(String itemType) {
  final typeStr = itemType.toLowerCase();
  if (typeStr.contains('weapon')) return ItemCategory.weapon;
  if (typeStr.contains('armor') || typeStr.contains('shield')) {
    return ItemCategory.armor;
  }
  if (typeStr.contains('potion') ||
      typeStr.contains('elixir') ||
      typeStr.contains('oil')) {
    return ItemCategory.potion;
  }
  if (typeStr.contains('ring')) return ItemCategory.ring;
  if (typeStr.contains('rod')) return ItemCategory.rod;
  if (typeStr.contains('scroll')) return ItemCategory.scroll;
  if (typeStr.contains('staff') || typeStr.contains('stave')) {
    return ItemCategory.staff;
  }
  if (typeStr.contains('wand')) return ItemCategory.wand;
  if (typeStr.contains('gem')) return ItemCategory.gemstone;
  if (typeStr.contains('art')) return ItemCategory.artObject;
  if (typeStr.contains('trinket')) return ItemCategory.trinket;
  if (typeStr.contains('gear') ||
      typeStr.contains('tool') ||
      typeStr.contains('adventuring')) {
    return ItemCategory.adventuringGear;
  }
  return ItemCategory.wondrousItem;
}

ItemRarity _legacyRarity(String rarity) {
  final r = rarity.toLowerCase();
  if (r.contains('artifact')) return ItemRarity.artifact;
  if (r.contains('legendary')) return ItemRarity.legendary;
  if (r.contains('very rare') || r.contains('very_rare')) {
    return ItemRarity.veryRare;
  }
  if (r.contains('rare')) return ItemRarity.rare;
  if (r.contains('uncommon')) return ItemRarity.uncommon;
  if (r.contains('common')) return ItemRarity.common;
  return ItemRarity.nonmagical;
}

String _legacySummary(String desc, String name) {
  final descLines = desc
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#') && !l.startsWith('|'))
      .toList();
  if (descLines.isNotEmpty) return descLines.first;
  return desc.isNotEmpty ? desc.split('\n').first : name;
}

void main() {
  group('Fix 5.1 law: EquipmentItem map round-trip and equality (500 seeds)', () {
    test('500 seeded generated EquipmentItems round-trip through toMap/fromMap with equal hashCode', () {
      for (var seed = 0; seed < 500; seed++) {
        final rng = Random(20261126 + seed);
        final cat = ItemCategory.values[rng.nextInt(ItemCategory.values.length)];
        final rar = ItemRarity.values[rng.nextInt(ItemRarity.values.length)];
        final full = seed.isEven;

        final r14 = ItemEditionDetails(
          summary: full ? 'Summary 2014 #$seed' : '',
          description: full ? 'Detailed 2014 description #$seed' : '',
          activation: full ? '1 Action' : null,
          charges: full ? '7 charges' : null,
          masteryProperties: full ? 'Vex' : null,
          savingThrowDc: full ? 'DC 15' : null,
          properties: full ? ['Prop A $seed', 'Prop B'] : const [],
        );
        final r24 = ItemEditionDetails(
          summary: full ? 'Summary 2024 #$seed' : '',
          description: full ? 'Detailed 2024 description #$seed' : '',
          activation: full ? '1 Bonus Action' : null,
          charges: full ? '10 charges' : null,
          masteryProperties: full ? 'Topple' : null,
          savingThrowDc: full ? 'DC 16' : null,
          properties: full ? ['Prop C $seed'] : const [],
        );

        final item = EquipmentItem(
          id: EntityId(
            slug: 'seed-item-$seed',
            ruleset: RulesetVersion.values[rng.nextInt(RulesetVersion.values.length)],
          ),
          name: 'Seed Item $seed',
          name2014: full ? 'Old Seed Item $seed' : null,
          name2024: full ? 'New Seed Item $seed' : null,
          itemType: cat.name,
          category: cat,
          rarity: rar.name,
          rarityTier: rar,
          cost: full ? '${(seed + 1) * 10} gp' : null,
          cost2014: full ? '${(seed + 1) * 8} gp' : null,
          cost2024: full ? '${(seed + 1) * 12} gp' : null,
          requiresAttunement: rng.nextBool(),
          attunementRequirement: full ? 'by a spellcaster' : null,
          descriptionMarkdown: full ? 'Markdown body #$seed' : '',
          rules2014: r14,
          rules2024: r24,
          isChangedIn2024: full && rng.nextBool(),
          diffSummary: full ? 'Changed in 2024 #$seed' : null,
          diffHighlights: full ? ['Highlight 1', 'Highlight $seed'] : const [],
          tags: full ? ['tag-$seed', cat.name] : const [],
          customProperties: full ? {'bonusAc': seed % 4, 'label': 'v$seed'} : const {},
        );

        final map = item.toMap();
        final decoded = EquipmentItem.fromMap(map);

        expect(
          decoded,
          equals(item),
          reason: 'Round-trip mismatch at seed=$seed',
        );
        expect(
          decoded.hashCode,
          equals(item.hashCode),
          reason: 'hashCode mismatch at seed=$seed',
        );
      }
    });
  });

  group('Fix 5.3 law: Old-format EquipmentItem maps load with legacy converter parity (200 seeds)', () {
    test('200 seeded old-format maps decode to exact legacy category, rarityTier, summary, cost, attunement, and tags', () {
      const itemTypes = [
        'Weapon (longsword)',
        'Armor (heavy)',
        'Shield',
        'Potion',
        'Elixir of Health',
        'Oil of Sharpness',
        'Ring',
        'Rod',
        'Scroll',
        'Staff',
        'Stave of Power',
        'Wand',
        'Gemstone',
        'Art Object',
        "Cartographer's Tools",
        'Martial Artefact',
        'Trinket',
        'Adventuring Gear',
        'Thieves Tool',
        'Wondrous Item',
        'Unknown Oddity',
      ];
      const rarities = [
        'artifact',
        'legendary',
        'very rare',
        'very_rare',
        'rare',
        'uncommon',
        'common',
        'none',
        '',
      ];

      for (var seed = 0; seed < 200; seed++) {
        final rng = Random(53000 + seed);
        final itemType = itemTypes[seed % itemTypes.length];
        final rarity = rarities[rng.nextInt(rarities.length)];
        final attune = rng.nextBool();
        final hasRawVal = rng.nextBool();
        final hasCost = rng.nextBool();
        final desc = seed % 3 == 0
            ? '# Heading\n| col |\nActual summary line $seed.\nMore text.'
            : (seed % 3 == 1 ? '' : 'Plain summary $seed.');
        final custom = <String, dynamic>{
          if (hasCost) 'cost': '${seed + 5} gp',
          if (hasRawVal)
            'rawJson': {
              'value': '${seed + 10} gp',
              if (attune) 'reqAttune': 'by a cleric',
            },
        };

        final oldMap = <String, dynamic>{
          'id': {'slug': 'old-item-$seed', 'ruleset': 'homebrew'},
          'name': 'Old Item $seed',
          'itemType': itemType,
          'rarity': rarity,
          'requiresAttunement': attune,
          'descriptionMarkdown': desc,
          'grants': const <Map<String, dynamic>>[],
          'customProperties': custom,
        };

        final decoded = EquipmentItem.fromMap(oldMap);
        final expCat = _legacyCategory(itemType);
        final expRar = _legacyRarity(rarity);
        final expSummary = _legacySummary(desc, 'Old Item $seed');
        final expCost = hasRawVal
            ? '${seed + 10} gp'
            : (hasCost ? '${seed + 5} gp' : null);
        final expAttuneReq = attune
            ? (hasRawVal ? 'by a cleric' : 'Requires Attunement')
            : null;
        final expTags = [itemType, rarity, if (attune) 'attunement'];

        expect(
          decoded.category,
          equals(expCat),
          reason:
              'seed=$seed itemType="$itemType": expected category=$expCat, got ${decoded.category}',
        );
        expect(
          decoded.rarityTier,
          equals(expRar),
          reason:
              'seed=$seed rarity="$rarity": expected rarityTier=$expRar, got ${decoded.rarityTier}',
        );
        expect(decoded.cost, equals(expCost), reason: 'seed=$seed cost mismatch');
        expect(decoded.attunementRequirement, equals(expAttuneReq),
            reason: 'seed=$seed attunementRequirement mismatch');
        expect(decoded.rules2014.summary, equals(expSummary),
            reason: 'seed=$seed rules2014.summary mismatch');
        expect(decoded.rules2024.summary, equals(expSummary),
            reason: 'seed=$seed rules2024.summary mismatch');
        expect(decoded.rules2014.description, equals(desc),
            reason: 'seed=$seed description mismatch');
        expect(decoded.tags, equals(expTags), reason: 'seed=$seed tags mismatch');
      }
    });
  });
}
