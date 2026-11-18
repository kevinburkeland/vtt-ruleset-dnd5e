import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'in_memory_entity_resolver.dart';

void main() {
  group('InMemoryEntityResolver', () {
    const chainMail = EquipmentItem(
      id: EntityId(slug: 'chain-mail', ruleset: RulesetVersion.v2024),
      name: 'Chain Mail',
      itemType: 'Heavy Armor',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy armor AC 16.',
      customProperties: {'baseAc': 16, 'armorType': 'heavy'},
    );

    test('resolves registered entity by slug and typed result', () {
      final resolver = InMemoryEntityResolver([chainMail]);
      const ref = EntityReference<EquipmentItem>.empty(
        refType: EntityType.equipment,
        slug: 'chain-mail',
        displayName: 'Chain Mail',
      );

      final resolved = resolver.resolve(ref);
      expect(resolved, same(chainMail));

      final typed = resolver.resolveTyped<EquipmentItem>(ref);
      expect(typed.isResolved, isTrue);
      expect(typed.entity, same(chainMail));
    });

    test('returns UnresolvedReference for missing slug', () {
      final resolver = InMemoryEntityResolver();
      const ref = EntityReference<EquipmentItem>.empty(
        refType: EntityType.equipment,
        slug: 'missing-item',
        displayName: 'Missing Item',
      );

      final resolved = resolver.resolve(ref);
      expect(resolved, isA<UnresolvedReference>());
      expect(resolved.slug, equals('missing-item'));
      expect(resolved.entityType, equals(EntityType.equipment));

      final typed = resolver.resolveTyped<EquipmentItem>(ref);
      expect(typed.isResolved, isFalse);
      expect(typed.entity, isNull);
      expect(typed.unresolved?.slug, equals('missing-item'));
      expect(typed.unresolved?.entityType, equals(EntityType.equipment));
    });
  });
}
