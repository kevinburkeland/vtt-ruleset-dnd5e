import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';

/// Concrete D&D 5e Attribute System governing the classic 6 ability scores:
/// Strength, Dexterity, Constitution, Intelligence, Wisdom, Charisma.
class Dnd5eAttributeSystem implements IAttributeSystem {
  const Dnd5eAttributeSystem();

  static const List<String> _keys = [
    'strength',
    'dexterity',
    'constitution',
    'intelligence',
    'wisdom',
    'charisma',
  ];

  @override
  List<String> get attributeKeys => _keys;

  @override
  String getAbbreviation(String key) {
    return switch (key.toLowerCase().trim()) {
      'strength' || 'str' => 'STR',
      'dexterity' || 'dex' => 'DEX',
      'constitution' || 'con' => 'CON',
      'intelligence' || 'int' => 'INT',
      'wisdom' || 'wis' => 'WIS',
      'charisma' || 'cha' => 'CHA',
      _ => key.toUpperCase().substring(0, key.length.clamp(0, 3)),
    };
  }

  @override
  String getDisplayName(String key) {
    return switch (key.toLowerCase().trim()) {
      'strength' || 'str' => 'Strength',
      'dexterity' || 'dex' => 'Dexterity',
      'constitution' || 'con' => 'Constitution',
      'intelligence' || 'int' => 'Intelligence',
      'wisdom' || 'wis' => 'Wisdom',
      'charisma' || 'cha' => 'Charisma',
      _ => key,
    };
  }

  @override
  int calculateModifier(String key, int score) {
    // 5e RAW modifier formula: floor((score - 10) / 2)
    return (score - 10) >= 0 ? (score - 10) ~/ 2 : ((score - 11) ~/ 2);
  }

  @override
  Map<String, int> get standardArray => const {
        'strength': 15,
        'dexterity': 14,
        'constitution': 13,
        'intelligence': 12,
        'wisdom': 10,
        'charisma': 8,
      };
}
