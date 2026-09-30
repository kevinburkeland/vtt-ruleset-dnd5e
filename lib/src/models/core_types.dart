import 'package:vtt_engine_core/models/core_types.dart' as core;
export 'package:vtt_engine_core/models/core_types.dart' hide EntityType;

/// 5E Domain Entity Classification extending core EntityType for type compatibility.
class EntityType extends core.EntityType {
  const EntityType(super.key);

  static const EntityType spell = EntityType('spell');
  static const EntityType monster = EntityType('monster');
  static const EntityType equipment = EntityType('equipment');
  static const EntityType feat = EntityType('feat');
  static const EntityType classFeature = EntityType('classFeature');
  static const EntityType character = EntityType('character');
  static const EntityType species = EntityType('species');
  static const EntityType classDefinition = EntityType('classDefinition');
  static const EntityType subclass = EntityType('subclass');
  static const EntityType background = EntityType('background');
  static const EntityType item = EntityType('item');
  static const EntityType custom = EntityType('custom');

  static const List<EntityType> values = [
    spell,
    monster,
    equipment,
    feat,
    classFeature,
    character,
    species,
    classDefinition,
    subclass,
    background,
    item,
    custom,
  ];

  @override
  String get name => key;
  int get index => values.indexOf(this);

  static EntityType fromString(String? key) {
    if (key == null) return EntityType.custom;
    final clean = key.trim().toLowerCase();
    for (final v in values) {
      if (v.key.toLowerCase() == clean) return v;
    }
    return EntityType(key);
  }

  /// Bridge to generic core [core.EntityType].
  core.EntityType toCore() => this;
}

/// Standardized Action Types for 5e activation economy
enum ActionType {
  action,
  bonusAction,
  reaction,
  minute,
  hour,
  special;

  static ActionType fromString(String? key) {
    if (key == null) return ActionType.action;
    final clean = key.trim().toLowerCase();
    return switch (clean) {
      'bonus action' || 'bonusaction' || 'bonus' => ActionType.bonusAction,
      'reaction' => ActionType.reaction,
      'minute' => ActionType.minute,
      'hour' => ActionType.hour,
      'special' => ActionType.special,
      _ => ActionType.action,
    };
  }
}

/// Standardized 5e Damage Types
enum DamageType {
  acid,
  bludgeoning,
  cold,
  fire,
  force,
  lightning,
  necrotic,
  piercing,
  poison,
  psychic,
  radiant,
  slashing,
  thunder,
  untyped,
  variable;

  /// Safely resolves a loose or unstructured string into a canonical [DamageType].
  static DamageType fromString(String? key) => fromLooseString(key);
  static DamageType fromLooseString(String? key) {
    if (key == null) return DamageType.untyped;
    final clean = key.trim().toLowerCase();
    if (clean == 'choose' || clean == 'variable') return DamageType.variable;
    for (final val in DamageType.values) {
      if (val.name.toLowerCase() == clean) return val;
    }
    return DamageType.untyped;
  }
}


/// Standardized 5e Spell Schools
enum SpellSchool {
  abjuration('Abjuration'),
  conjuration('Conjuration'),
  divination('Divination'),
  enchantment('Enchantment'),
  evocation('Evocation'),
  illusion('Illusion'),
  necromancy('Necromancy'),
  transmutation('Transmutation');

  final String displayName;
  const SpellSchool(this.displayName);

  static SpellSchool fromString(String? key) {
    if (key == null) return SpellSchool.evocation;
    final clean = key.trim().toLowerCase();
    for (final school in SpellSchool.values) {
      if (school.name.toLowerCase() == clean ||
          school.displayName.toLowerCase() == clean) {
        return school;
      }
    }
    return SpellSchool.evocation;
  }
}
