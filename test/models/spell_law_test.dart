import 'dart:math';

import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

import '../helpers/map_diff_helper.dart';
import '../helpers/test_dnd5e_catalog.dart';

Map<String, dynamic> _spellFieldSnapshot(Spell s) => {
      'id': s.id.toMap(),
      'name': s.name,
      'name2014': s.name2014,
      'name2024': s.name2024,
      'level': s.level,
      'school': s.school,
      'schoolEnum': s.schoolEnum?.name,
      'castingTime': s.castingTime.toMap(),
      'duration': s.duration.toMap(),
      'range': s.range,
      'rangeDistanceFeet': s.rangeDistanceFeet,
      'rangeType': s.rangeType,
      'damageType': s.damageType,
      'components': s.components.toMap(),
      'descriptionMarkdown': s.descriptionMarkdown,
      'higherLevelsMarkdown': s.higherLevelsMarkdown,
      'damageMath': s.damageMath.map((d) => d.toMap()).toList(),
      'relatedEntityRefs': s.relatedEntityRefs.map((r) => r.toMap()).toList(),
      'rules2014': s.rules2014.toMap(),
      'rules2024': s.rules2024.toMap(),
      'isChangedIn2024': s.isChangedIn2024,
      'diffSummary': s.diffSummary,
      'diffHighlights': s.diffHighlights,
      'tags': s.tags,
      'customProperties': s.customProperties,
    };

void main() {
  setUpAll(() {
    Dnd5eRuleset.install(const TestDnd5eCatalog());
  });

  group('Fix 6.1 & 6.2: Unified Spell round-trip and legacy compatibility laws',
      () {
    test('500-seed round-trip law: Spell -> toMap -> fromMap preserves all fields',
        () {
      for (var seed = 1; seed <= 500; seed++) {
        final rng = Random(seed);
        final schoolEnum =
            rng.nextBool() ? SpellSchool.values[rng.nextInt(SpellSchool.values.length)] : null;
        final schoolStr = schoolEnum?.name ?? 'chronomancy_$seed';
        final level = rng.nextInt(10);
        final classes14 = [
          for (var i = 0; i < 1 + rng.nextInt(3); i++)
            SpellClass.values[(seed + i) % SpellClass.values.length],
        ];
        final classes24 = [
          for (var i = 0; i < 1 + rng.nextInt(3); i++)
            SpellClass.values[(seed + i + 2) % SpellClass.values.length],
        ];

        final r14 = SpellEditionDetails(
          schoolOverride: rng.nextBool()
              ? SpellSchool.values[rng.nextInt(SpellSchool.values.length)]
              : null,
          castingTime: '1 Action',
          range: '${30 + rng.nextInt(4) * 30} feet',
          components: 'V, S',
          materialDetails: rng.nextBool()
              ? SpellMaterialComponent(
                  description: 'dust_$seed',
                  hasCost: rng.nextBool(),
                  costInGp: rng.nextInt(500),
                  isConsumed: rng.nextBool(),
                )
              : null,
          duration: rng.nextBool() ? 'Instantaneous' : 'Concentration, up to 1 minute',
          concentration: rng.nextBool(),
          ritual: rng.nextBool(),
          description: ['Paragraph 1 for spell $seed', 'Paragraph 2'],
          higherLevels: rng.nextBool() ? 'Upcast +1d6 ($seed)' : null,
          classes: classes14,
          rollFormula: rng.nextBool() ? '${1 + rng.nextInt(6)}d6' : null,
          scalingFormula: rng.nextBool()
              ? SpellScalingFormula(
                  baseDiceCount: 1 + rng.nextInt(6),
                  diceSides: 6,
                  dicePerSlotLevel: 1,
                  slotStep: 1 + rng.nextInt(2),
                  addsAbilityMod: rng.nextBool(),
                  staticBonus: rng.nextInt(4),
                )
              : null,
          damageOrHealType: rng.nextBool() ? 'Fire' : null,
          savingThrow: rng.nextBool() ? 'Dexterity' : null,
          reactionTrigger: rng.nextBool() ? 'when hit ($seed)' : null,
        );

        final r24 = SpellEditionDetails(
          castingTime: '1 Bonus Action',
          range: '60 feet',
          components: 'V, S, M',
          duration: 'Instantaneous',
          concentration: false,
          ritual: rng.nextBool(),
          description: ['Revised 2024 paragraph $seed'],
          higherLevels: rng.nextBool() ? '2024 upcast $seed' : null,
          classes: classes24,
        );

        final original = Spell(
          id: EntityId(
            slug: 'spell-seed-$seed',
            ruleset: RulesetVersion.values[seed % RulesetVersion.values.length],
          ),
          name: 'Seed Spell $seed',
          name2014: rng.nextBool() ? 'Old Spell $seed' : null,
          name2024: rng.nextBool() ? 'New Spell $seed' : null,
          level: level,
          school: schoolStr,
          schoolEnum: schoolEnum,
          castingTime: CastingTime(
            cost: 1,
            actionType: ActionType.values[seed % ActionType.values.length],
          ),
          duration: SpellDuration(
            type: DurationType.values[seed % DurationType.values.length],
            durationSeconds: rng.nextInt(600),
            requiresConcentration: rng.nextBool(),
            rawText: rng.nextBool() ? '1 minute' : null,
          ),
          range: '60 feet',
          rangeDistanceFeet: 60,
          rangeType: 'ranged',
          damageType: rng.nextBool() ? 'fire' : null,
          components: SpellComponents(
            v: true,
            s: rng.nextBool(),
            m: rng.nextBool(),
            materialDescription: rng.nextBool() ? 'pinch of ash' : null,
            materialCostGp: rng.nextInt(100),
            consumesMaterial: rng.nextBool(),
          ),
          descriptionMarkdown: 'Markdown description $seed',
          higherLevelsMarkdown: rng.nextBool() ? 'Higher levels $seed' : null,
          rules2014: r14,
          rules2024: r24,
          isChangedIn2024: rng.nextBool(),
          diffSummary: rng.nextBool() ? 'Changed in 2024 ($seed)' : null,
          diffHighlights: rng.nextBool() ? ['Highlight $seed'] : const [],
          tags: ['tag-$seed', 'level-$level'],
          customProperties: {'seed': seed},
        );

        final originalMap = original.toMap();
        final decoded = Spell.fromMap(originalMap);
        expectMapsEqualWithDiff(
          _spellFieldSnapshot(decoded),
          _spellFieldSnapshot(original),
          seed: seed,
          typeName: 'Spell',
        );
        expectMapsEqualWithDiff(
          decoded.toMap(),
          originalMap,
          seed: seed,
          typeName: 'Spell',
        );
        expect(decoded, equals(original), reason: 'Failed on seed $seed');
        expect(decoded.school, equals(schoolStr));
        expect(decoded.schoolEnum, equals(schoolEnum));
        expect(decoded.rules2014, equals(r14));
        expect(decoded.rules2024, equals(r24));
        expect(decoded.tags, equals(original.tags));
      }
    });

    test(
        '200-seed legacy pre-slice-17 map compatibility law: hydrates rules2014/2024 without dropping unknown school',
        () {
      const legacySchools = [
        'abjuration',
        'conjuration',
        'divination',
        'enchantment',
        'evocation',
        'illusion',
        'necromancy',
        'transmutation',
        'chronomancy',
        'dunamancy',
      ];
      for (var seed = 1; seed <= 200; seed++) {
        final rng = Random(seed + 1000);
        final schoolStr = legacySchools[seed % legacySchools.length];
        final level = rng.nextInt(10);
        final ritual = rng.nextBool();
        final conc = rng.nextBool();
        final legacyMap = <String, dynamic>{
          'id': {'slug': 'legacy-spell-$seed', 'ruleset': 'homebrew'},
          'name': 'Legacy Spell $seed',
          'level': level,
          'school': schoolStr,
          'castingTime': {
            'cost': 1,
            'actionType': 'action',
            'triggerCondition': null,
          },
          'duration': {
            'type': conc ? 'timed' : 'instantaneous',
            'durationSeconds': conc ? 60 : 0,
            'requiresConcentration': conc,
            'rawText': conc ? 'Concentration, up to 1 minute' : null,
          },
          'range': '90 feet',
          'rangeDistanceFeet': 90,
          'rangeType': 'ranged',
          'components': {
            'v': true,
            's': true,
            'm': seed.isEven,
            'materialDescription': seed.isEven ? 'a silver thread' : null,
            'materialCostGp': 0,
            'consumesMaterial': false,
          },
          'descriptionMarkdown': 'Legacy spell body $seed',
          'higherLevelsMarkdown': seed.isOdd ? 'Upcast +1d8' : null,
          'damageMath': [
            {
              'diceFormula': '3d8',
              'damageType': 'fire',
              'isAttackRoll': false,
              'requiresSave': true,
            },
          ],
          'relatedEntityRefs': const <Map<String, dynamic>>[],
          'customProperties': {
            'classes': ['Wizard', 'Sorcerer'],
            'ritual': ritual,
            'savingThrow': ['dexterity'],
            'areaTags': ['S'],
            'source': 'HB-LEGACY',
          },
        };

        final decoded = Spell.fromMap(legacyMap);
        expect(decoded.id.slug, equals('legacy-spell-$seed'));
        expect(decoded.name, equals('Legacy Spell $seed'));
        expect(decoded.level, equals(level));
        expect(decoded.school, equals(schoolStr));
        final expectedEnum = SpellSchool.values
            .where((s) => s.name == schoolStr)
            .firstOrNull;
        expect(decoded.schoolEnum, equals(expectedEnum));
        expect(decoded.rules2024.concentration, equals(conc));
        expect(decoded.rules2024.ritual, equals(ritual));
        expect(decoded.rules2024.classes,
            containsAll([SpellClass.wizard, SpellClass.sorcerer]));
        expect(decoded.rules2024.savingThrow, equals('dexterity'));
        expect(decoded.rules2024.rollFormula, equals('3d8'));
        expect(decoded.rules2024.damageOrHealType, equals('fire'));
        expect(decoded.tags, containsAll(['S', 'HB-LEGACY']));
      }
    });

    test(
        '300-seed Spell.singleEdition parity law: matches Spell.fromMap(legacyMap) field by field',
        () {
      const schools = [
        'Abjuration',
        'Conjuration',
        'Divination',
        'Enchantment',
        'Evocation',
        'Illusion',
        'Necromancy',
        'Transmutation',
        'Chronomancy',
      ];
      for (var seed = 1; seed <= 300; seed++) {
        final rng = Random(seed + 7700);
        final schoolStr = schools[seed % schools.length];
        final level = rng.nextInt(10);
        final ritual = rng.nextBool();
        final conc = rng.nextBool();
        final actionType = ActionType.values[seed % ActionType.values.length];
        final hasMat = rng.nextBool();
        final matDesc = hasMat ? 'silver bell #$seed' : null;
        final hasHigher = rng.nextBool();
        final higherText = hasHigher ? 'Upcast +1d8 ($seed)' : null;
        final hasDamage = rng.nextBool();
        final damageMath = hasDamage
            ? [
                EvaluationMath(
                  diceFormula: '${1 + (seed % 5)}d8',
                  damageType:
                      DamageType.values[seed % DamageType.values.length],
                ),
              ]
            : const <EvaluationMath>[];
        final rangeText = switch (seed % 3) {
          0 => 'Self',
          1 => 'Touch',
          _ => '${30 + (seed % 4) * 30} feet',
        };
        final duration = SpellDuration(
          type: conc ? DurationType.timed : DurationType.instantaneous,
          durationSeconds: conc ? 60 : 0,
          requiresConcentration: conc,
          rawText: conc ? 'Concentration, up to 1 minute' : null,
        );
        final components = SpellComponents(
          v: true,
          s: seed.isEven,
          m: hasMat,
          materialDescription: matDesc,
          materialCostGp: hasMat ? 10 : 0,
          consumesMaterial: false,
        );
        final castingTime = CastingTime(cost: 1, actionType: actionType);
        final cp = <String, dynamic>{
          'classes': seed.isEven
              ? <String>['Wizard', 'Cleric']
              : <String>['Bard'],
          if (ritual) 'ritual': true,
          if (seed % 4 == 0) 'savingThrow': <String>['dexterity'],
          if (seed % 5 == 0) 'source': 'HB-$seed',
          if (seed % 3 == 0) 'areaTags': <String>['S'],
        };
        final desc = 'Single edition spell body $seed';
        final id =
            EntityId(slug: 'single-spell-$seed', ruleset: RulesetVersion.homebrew);
        final name = 'Single Spell $seed';

        final single = Spell.singleEdition(
          id: id,
          name: name,
          level: level,
          school: schoolStr,
          castingTime: castingTime,
          duration: duration,
          range: rangeText,
          damageType: hasDamage ? damageMath.first.damageType.name : null,
          components: components,
          descriptionMarkdown: desc,
          higherLevelsMarkdown: higherText,
          damageMath: damageMath,
          customProperties: cp,
        );

        final legacyMap = <String, dynamic>{
          'id': id.toMap(),
          'name': name,
          'level': level,
          'school': schoolStr,
          'castingTime': castingTime.toMap(),
          'duration': duration.toMap(),
          'range': rangeText,
          if (hasDamage) 'damageType': damageMath.first.damageType.name,
          'components': components.toMap(),
          'descriptionMarkdown': desc,
          'higherLevelsMarkdown': higherText,
          'damageMath': damageMath.map((d) => d.toMap()).toList(),
          'relatedEntityRefs': const <Map<String, dynamic>>[],
          'customProperties': cp,
        };
        final fromLegacy = Spell.fromMap(legacyMap);

        expectMapsEqualWithDiff(
          _spellFieldSnapshot(single),
          _spellFieldSnapshot(fromLegacy),
          seed: seed,
          typeName: 'Spell.singleEdition',
        );
      }
    });
  });
}
