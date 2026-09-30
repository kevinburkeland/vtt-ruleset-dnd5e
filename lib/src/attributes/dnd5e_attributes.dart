import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/models/character_models.dart' as core;

/// 5e Core Ability Score Keys
enum AbilityType {
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma;

  String get shortName => switch (this) {
        AbilityType.strength => 'STR',
        AbilityType.dexterity => 'DEX',
        AbilityType.constitution => 'CON',
        AbilityType.intelligence => 'INT',
        AbilityType.wisdom => 'WIS',
        AbilityType.charisma => 'CHA',
      };

  String get attributeKey => name;

  /// Safely resolves a loose or unstructured string into a canonical [AbilityType].
  static AbilityType fromString(String? key) => fromLooseString(key);
  static AbilityType fromLooseString(
    String? key, [
    AbilityType fallback = AbilityType.strength,
  ]) {
    if (key == null) return fallback;
    final clean = key.trim().toLowerCase();
    return switch (clean) {
      'str' || 'strength' => AbilityType.strength,
      'dex' || 'dexterity' => AbilityType.dexterity,
      'con' || 'constitution' => AbilityType.constitution,
      'int' || 'intelligence' => AbilityType.intelligence,
      'wis' || 'wisdom' => AbilityType.wisdom,
      'cha' || 'charisma' => AbilityType.charisma,
      _ => AbilityType.values.firstWhere(
          (a) => a.name.toLowerCase() == clean,
          orElse: () => fallback,
        ),
    };
  }
}

/// Standard 5e Skills
enum SkillType {
  acrobatics,
  animalHandling,
  arcana,
  athletics,
  deception,
  history,
  insight,
  intimidation,
  investigation,
  medicine,
  nature,
  perception,
  performance,
  persuasion,
  religion,
  sleightOfHand,
  stealth,
  survival;

  AbilityType get defaultAbility => switch (this) {
        SkillType.athletics => AbilityType.strength,
        SkillType.acrobatics ||
        SkillType.sleightOfHand ||
        SkillType.stealth =>
          AbilityType.dexterity,
        SkillType.arcana ||
        SkillType.history ||
        SkillType.investigation ||
        SkillType.nature ||
        SkillType.religion =>
          AbilityType.intelligence,
        SkillType.animalHandling ||
        SkillType.insight ||
        SkillType.medicine ||
        SkillType.perception ||
        SkillType.survival =>
          AbilityType.wisdom,
        SkillType.deception ||
        SkillType.intimidation ||
        SkillType.performance ||
        SkillType.persuasion =>
          AbilityType.charisma,
      };

  String get displayName => switch (this) {
        SkillType.acrobatics => 'Acrobatics',
        SkillType.animalHandling => 'Animal Handling',
        SkillType.arcana => 'Arcana',
        SkillType.athletics => 'Athletics',
        SkillType.deception => 'Deception',
        SkillType.history => 'History',
        SkillType.insight => 'Insight',
        SkillType.intimidation => 'Intimidation',
        SkillType.investigation => 'Investigation',
        SkillType.medicine => 'Medicine',
        SkillType.nature => 'Nature',
        SkillType.perception => 'Perception',
        SkillType.performance => 'Performance',
        SkillType.persuasion => 'Persuasion',
        SkillType.religion => 'Religion',
        SkillType.sleightOfHand => 'Sleight of Hand',
        SkillType.stealth => 'Stealth',
        SkillType.survival => 'Survival',
      };

  /// Converts this [SkillType] to the generic tabletop [ITraitDefinition] primitive.
  ITraitDefinition toTraitDefinition() => ITraitDefinition(
        id: name,
        name: displayName,
        category: 'skill',
        governedAttribute: defaultAbility.name,
      );

  /// Resolves an [ITraitDefinition] to a canonical [SkillType] if recognized.
  static SkillType? fromTraitDefinition(ITraitDefinition trait) {
    return tryParse(trait.id) ?? tryParse(trait.name);
  }

  static final Map<String, SkillType> _lookupMap = () {
    final map = <String, SkillType>{};
    for (final s in SkillType.values) {
      final nameClean = _sanitize(s.name);
      final dispClean = _sanitize(s.displayName);
      map[nameClean] = s;
      map[dispClean] = s;
      map[s.name.toLowerCase()] = s;
      map[s.displayName.toLowerCase()] = s;
    }
    return map;
  }();

  static String _sanitize(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (c != ' ' && c != '_' && c != '-') {
        buffer.write(c.toLowerCase());
      }
    }
    return buffer.toString();
  }

  static SkillType? tryParse(String? value) {
    if (value == null) return null;
    final trimmed = value.trim().toLowerCase();
    final direct = _lookupMap[trimmed];
    if (direct != null) return direct;
    return _lookupMap[_sanitize(value)];
  }

  static SkillType fromString(String? key) => fromLooseString(key);
  static SkillType fromLooseString(String? value,
      {SkillType fallback = SkillType.athletics}) {
    return tryParse(value) ?? fallback;
  }
}

/// Skill Proficiency Levels
enum SkillProficiencyLevel {
  none(0.0),
  jackOfAllTrades(0.5),
  proficient(1.0),
  expertise(2.0);

  final double multiplier;
  const SkillProficiencyLevel(this.multiplier);

  static SkillProficiencyLevel fromLooseString(String? key) {
    if (key == null) return SkillProficiencyLevel.none;
    final clean = key.trim().toLowerCase();
    if (clean.contains('expert')) return SkillProficiencyLevel.expertise;
    if (clean.contains('proficient')) return SkillProficiencyLevel.proficient;
    if (clean.contains('jack')) return SkillProficiencyLevel.jackOfAllTrades;
    return SkillProficiencyLevel.none;
  }

  static SkillProficiencyLevel fromMultiplier(num? multiplier) {
    if (multiplier == null) return SkillProficiencyLevel.none;
    final val = multiplier.toDouble();
    if (val >= 2.0) return SkillProficiencyLevel.expertise;
    if (val >= 1.0) return SkillProficiencyLevel.proficient;
    if (val >= 0.5) return SkillProficiencyLevel.jackOfAllTrades;
    return SkillProficiencyLevel.none;
  }
}

/// 5e Equipment and Wearable Slots
enum EquipmentSlot {
  head,
  cloak,
  armor,
  shield,
  mainHand,
  offHand,
  twoHand,
  ring1,
  ring2,
  boots,
  wondrous;

  String get displayName => switch (this) {
        EquipmentSlot.head => 'Head',
        EquipmentSlot.cloak => 'Cloak',
        EquipmentSlot.armor => 'Armor',
        EquipmentSlot.shield => 'Shield',
        EquipmentSlot.mainHand => 'Main Hand',
        EquipmentSlot.offHand => 'Off Hand',
        EquipmentSlot.twoHand => 'Two-Handed',
        EquipmentSlot.ring1 => 'Ring 1',
        EquipmentSlot.ring2 => 'Ring 2',
        EquipmentSlot.boots => 'Boots',
        EquipmentSlot.wondrous => 'Wondrous',
      };
}

/// 5e Ability Scores container extending generic [core.AttributePool].
@immutable
class AbilityScores extends core.AttributePool {
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  const AbilityScores({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
    Map<String, int> customAttributes = const <String, int>{},
  }) : super(customAttributes);

  const AbilityScores.standardArray()
      : strength = 15,
        dexterity = 14,
        constitution = 13,
        intelligence = 12,
        wisdom = 10,
        charisma = 8,
        super(const <String, int>{});

  const AbilityScores.zero()
      : strength = 0,
        dexterity = 0,
        constitution = 0,
        intelligence = 0,
        wisdom = 0,
        charisma = 0,
        super(const <String, int>{});

  @override
  int getScore(dynamic key) {
    if (key == null) return 0;
    final clean =
        (key is Enum ? key.name : key.toString()).trim().toLowerCase();
    return switch (clean) {
      'str' || 'strength' => strength,
      'dex' || 'dexterity' => dexterity,
      'con' || 'constitution' => constitution,
      'int' || 'intelligence' => intelligence,
      'wis' || 'wisdom' => wisdom,
      'cha' || 'charisma' => charisma,
      _ => super.getScore(key),
    };
  }

  @override
  Map<String, int> toMap() => {
        'strength': strength,
        'dexterity': dexterity,
        'constitution': constitution,
        'intelligence': intelligence,
        'wisdom': wisdom,
        'charisma': charisma,
        ...scores,
      };

  @override
  Map<String, int> get attributes => toMap();

  factory AbilityScores.fromMap(Map<String, dynamic> map) {
    final custom = <String, int>{};
    int str = 10, dex = 10, con = 10, intl = 10, wis = 10, cha = 10;

    map.forEach((k, v) {
      if (v is num) {
        final key = k.toString().trim().toLowerCase();
        switch (key) {
          case 'strength' || 'str':
            str = v.toInt();
          case 'dexterity' || 'dex':
            dex = v.toInt();
          case 'constitution' || 'con':
            con = v.toInt();
          case 'intelligence' || 'int':
            intl = v.toInt();
          case 'wisdom' || 'wis':
            wis = v.toInt();
          case 'charisma' || 'cha':
            cha = v.toInt();
          default:
            custom[key] = v.toInt();
        }
      }
    });

    return AbilityScores(
      strength: str,
      dexterity: dex,
      constitution: con,
      intelligence: intl,
      wisdom: wis,
      charisma: cha,
      customAttributes: Map.unmodifiable(custom),
    );
  }

  @override
  int getModifier(dynamic key, [IAttributeSystem? system]) {
    final clean =
        (key is String ? key : (key is Enum ? key.name : key.toString()))
            .trim()
            .toLowerCase();
    final score = getScore(clean);
    if (system != null) {
      return system.calculateModifier(clean, score);
    }
    return ((score - 10) / 2).floor();
  }

  @override
  AbilityScores copyWith({
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
    Map<String, int>? customAttributes,
    Map<String, int>? scores,
  }) {
    final custom = scores ?? customAttributes;
    return AbilityScores(
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      constitution: constitution ?? this.constitution,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
      customAttributes: custom != null
          ? Map.unmodifiable(custom)
          : this.scores,
    );
  }

  @override
  AbilityScores operator +(core.AttributePool other) => withBonus(other);

  @override
  AbilityScores withBonus(core.AttributePool bonus) {
    return AbilityScores(
      strength: strength + (bonus is AbilityScores ? bonus.strength : bonus.getScore('strength')),
      dexterity: dexterity + (bonus is AbilityScores ? bonus.dexterity : bonus.getScore('dexterity')),
      constitution: constitution + (bonus is AbilityScores ? bonus.constitution : bonus.getScore('constitution')),
      intelligence: intelligence + (bonus is AbilityScores ? bonus.intelligence : bonus.getScore('intelligence')),
      wisdom: wisdom + (bonus is AbilityScores ? bonus.wisdom : bonus.getScore('wisdom')),
      charisma: charisma + (bonus is AbilityScores ? bonus.charisma : bonus.getScore('charisma')),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbilityScores &&
          strength == other.strength &&
          dexterity == other.dexterity &&
          constitution == other.constitution &&
          intelligence == other.intelligence &&
          wisdom == other.wisdom &&
          charisma == other.charisma &&
          const MapEquality().equals(scores, other.scores);

  @override
  int get hashCode => Object.hash(
        strength,
        dexterity,
        constitution,
        intelligence,
        wisdom,
        charisma,
        const MapEquality().hash(scores),
      );
}

/// 5e Extension on [core.AttributePool] providing named getters for the 6 canonical abilities.
extension Dnd5eAttributePoolExtension on core.AttributePool {
  int get strength => getScore('strength');
  int get dexterity => getScore('dexterity');
  int get constitution => getScore('constitution');
  int get intelligence => getScore('intelligence');
  int get wisdom => getScore('wisdom');
  int get charisma => getScore('charisma');

  int getScoreByAbility(AbilityType ability) => getScore(ability.name);
  int getModifierByAbility(AbilityType ability, [IAttributeSystem? system]) =>
      getModifier(ability.name, system);
}
