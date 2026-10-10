import 'dart:convert';
import 'package:test/test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('InventoryItemInstance Canonical Serialization & Compatibility', () {
    final itemRef = EntityReference<DomainEntity>(
      refType: EntityType.item,
      slug: 'breastplate',
      displayName: 'Breastplate',
    );

    test('Canonicalizes known slot strings into EquipmentSlot', () {
      final cases = {
        'armor': EquipmentSlot.armor,
        'shield': EquipmentSlot.shield,
        'boots': EquipmentSlot.boots,
        'wondrous': EquipmentSlot.wondrous,
        'mainHand': EquipmentSlot.mainHand,
        'main_hand': EquipmentSlot.mainHand,
        'Main Hand': EquipmentSlot.mainHand,
        'EquipmentSlot.armor': EquipmentSlot.armor,
      };

      for (final entry in cases.entries) {
        final item = InventoryItemInstance.fromMap({
          'itemRef': itemRef.toMap(),
          'instanceId': 'i-1',
          'isEquipped': true,
          'equippedSlot': entry.key,
        });

        expect(item.equippedSlot, isA<EquipmentSlot>());
        expect(item.equippedSlot, equals(entry.value));
      }
    });

    test('Serializes equippedSlot canonically as String .name for JSON safety', () {
      final item = InventoryItemInstance(
        itemRef: itemRef,
        instanceId: 'i-1',
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
      );

      final map = item.toMap();
      expect(map['equippedSlot'], isA<String>());
      expect(map['equippedSlot'], equals('armor'));

      // jsonEncode must succeed without throwing
      final encoded = jsonEncode(map);
      expect(encoded, contains('"equippedSlot":"armor"'));

      // Round trip
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = InventoryItemInstance.fromMap(decoded);
      expect(restored.equippedSlot, equals(EquipmentSlot.armor));
    });

    test('Unknown historical slot policy (Option A): sets null and preserves legacy string', () {
      final item = InventoryItemInstance.fromMap({
        'itemRef': itemRef.toMap(),
        'instanceId': 'i-1',
        'isEquipped': true,
        'equippedSlot': 'third_arm_mount',
      });

      expect(item.equippedSlot, isNull);
      expect(item.customProperties['legacyEquippedSlot'], equals('third_arm_mount'));
    });
  });
}
