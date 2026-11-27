import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'core_types.dart';
import 'feature_grant.dart';

/// Canonical item category enumeration (pure Dart, presentation-free).
enum ItemCategory {
  weapon,
  armor,
  potion,
  ring,
  rod,
  scroll,
  staff,
  wand,
  wondrousItem,
  adventuringGear,
  gemstone,
  artObject,
  trinket,
}

/// Canonical item rarity tier enumeration (pure Dart, presentation-free).
enum ItemRarity {
  nonmagical(0),
  common(0),
  uncommon(1),
  rare(2),
  veryRare(3),
  legendary(4),
  artifact(5);

  final int tierLevel;
  const ItemRarity(this.tierLevel);
}

/// Edition-specific rules details for an [EquipmentItem] (2014 RAW or 2024 Revised).
@immutable
class ItemEditionDetails {
  final String summary;
  final String description;
  final String? activation;
  final String? charges;
  final String? masteryProperties;
  final String? savingThrowDc;
  final List<String> properties;

  const ItemEditionDetails({
    required this.summary,
    required this.description,
    this.activation,
    this.charges,
    this.masteryProperties,
    this.savingThrowDc,
    this.properties = const [],
  });

  const ItemEditionDetails.empty()
      : summary = '',
        description = '',
        activation = null,
        charges = null,
        masteryProperties = null,
        savingThrowDc = null,
        properties = const [];

  Map<String, dynamic> toMap() => {
        'summary': summary,
        'description': description,
        'activation': activation,
        'charges': charges,
        'masteryProperties': masteryProperties,
        'savingThrowDc': savingThrowDc,
        'properties': properties,
      };

  factory ItemEditionDetails.fromMap(Map<String, dynamic> map) {
    return ItemEditionDetails(
      summary: map['summary']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      activation: map['activation']?.toString(),
      charges: map['charges']?.toString(),
      masteryProperties: map['masteryProperties']?.toString(),
      savingThrowDc: map['savingThrowDc']?.toString(),
      properties: (map['properties'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  ItemEditionDetails copyWith({
    String? summary,
    String? description,
    String? activation,
    String? charges,
    String? masteryProperties,
    String? savingThrowDc,
    List<String>? properties,
  }) {
    return ItemEditionDetails(
      summary: summary ?? this.summary,
      description: description ?? this.description,
      activation: activation ?? this.activation,
      charges: charges ?? this.charges,
      masteryProperties: masteryProperties ?? this.masteryProperties,
      savingThrowDc: savingThrowDc ?? this.savingThrowDc,
      properties: properties ?? this.properties,
    );
  }

  static const _listEq = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemEditionDetails &&
          runtimeType == other.runtimeType &&
          summary == other.summary &&
          description == other.description &&
          activation == other.activation &&
          charges == other.charges &&
          masteryProperties == other.masteryProperties &&
          savingThrowDc == other.savingThrowDc &&
          _listEq.equals(properties, other.properties);

  @override
  int get hashCode => Object.hash(
        summary,
        description,
        activation,
        charges,
        masteryProperties,
        savingThrowDc,
        _listEq.hash(properties),
      );
}

/// Single-edition & legacy compatibility helper for [EquipmentItem] records.
///
/// Serves both pre-Cleanup slice 17 stored records decoded via
/// [EquipmentItem.fromMap] and new single-edition records built via
/// [EquipmentItem.singleEdition].
/// Maps free-text `itemType` strings using the single-edition substring rules.
ItemCategory _singleEditionCategoryFromItemType(String itemType) {
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

/// Single-edition & legacy compatibility helper for [EquipmentItem] records.
///
/// Serves both pre-Cleanup slice 17 stored records and new single-edition records.
/// Maps free-text `rarity` strings using the single-edition substring rules.
ItemRarity _singleEditionRarityFromString(String rarity) {
  final rarityStr = rarity.toLowerCase();
  if (rarityStr.contains('artifact')) return ItemRarity.artifact;
  if (rarityStr.contains('legendary')) return ItemRarity.legendary;
  if (rarityStr.contains('very rare') || rarityStr.contains('very_rare')) {
    return ItemRarity.veryRare;
  }
  if (rarityStr.contains('rare')) return ItemRarity.rare;
  if (rarityStr.contains('uncommon')) return ItemRarity.uncommon;
  if (rarityStr.contains('common')) return ItemRarity.common;
  return ItemRarity.nonmagical;
}

/// Single-edition & legacy compatibility helper for [EquipmentItem] records.
///
/// Serves both pre-Cleanup slice 17 stored records and new single-edition records.
String _singleEditionFirstContentLine(String descriptionMarkdown, String name) {
  final descLines = descriptionMarkdown
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#') && !l.startsWith('|'))
      .toList();
  if (descLines.isNotEmpty) return descLines.first;
  return descriptionMarkdown.isNotEmpty
      ? descriptionMarkdown.split('\n').first
      : name;
}

/// Shared single-edition hydration path for [EquipmentItem].
///
/// Serves both pre-Cleanup slice 17 stored records decoded via
/// [EquipmentItem.fromMap] and new single-edition records constructed via
/// [EquipmentItem.singleEdition].
EquipmentItem _hydrateSingleEditionItem({
  required EntityId id,
  required String name,
  String? name2014,
  String? name2024,
  required String itemType,
  ItemCategory? category,
  required String rarity,
  ItemRarity? rarityTier,
  String? cost,
  String? cost2014,
  String? cost2024,
  required bool requiresAttunement,
  String? attunementRequirement,
  required String descriptionMarkdown,
  String? summary,
  String? activation,
  String? charges,
  String? masteryProperties,
  String? savingThrowDc,
  List<String>? properties,
  bool isChangedIn2024 = false,
  String? diffSummary,
  List<String> diffHighlights = const [],
  List<String>? tags,
  List<FeatureGrant> grants = const [],
  Map<String, dynamic> customProperties = const {},
}) {
  final resolvedCategory =
      category ?? _singleEditionCategoryFromItemType(itemType);
  final resolvedRarityTier =
      rarityTier ?? _singleEditionRarityFromString(rarity);
  final rawJson = customProperties['rawJson'] as Map?;
  final resolvedCost =
      cost ?? rawJson?['value']?.toString() ?? customProperties['cost']?.toString();
  final resolvedAttunementReq = attunementRequirement ??
      (requiresAttunement
          ? (rawJson?['reqAttune']?.toString() ?? 'Requires Attunement')
          : null);
  final resolvedSummary =
      summary ?? _singleEditionFirstContentLine(descriptionMarkdown, name);
  final editionDetails = ItemEditionDetails(
    summary: resolvedSummary,
    description: descriptionMarkdown,
    activation: activation,
    charges: charges,
    masteryProperties: masteryProperties,
    savingThrowDc: savingThrowDc,
    properties: properties ?? const [],
  );
  return EquipmentItem(
    id: id,
    name: name,
    name2014: name2014,
    name2024: name2024,
    itemType: itemType,
    category: resolvedCategory,
    rarity: rarity,
    rarityTier: resolvedRarityTier,
    cost: resolvedCost,
    cost2014: cost2014,
    cost2024: cost2024,
    requiresAttunement: requiresAttunement,
    attunementRequirement: resolvedAttunementReq,
    descriptionMarkdown: descriptionMarkdown,
    rules2014: editionDetails,
    rules2024: editionDetails,
    isChangedIn2024: isChangedIn2024,
    diffSummary: diffSummary,
    diffHighlights: diffHighlights,
    tags: tags ??
        [
          itemType,
          rarity,
          if (requiresAttunement) 'attunement',
        ],
    grants: grants,
    customProperties: customProperties,
  );
}

/// Unified Equipment & Magic Item Domain Model (both 2014 RAW and 2024 Revised).
@immutable
class EquipmentItem extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  final String? name2014;
  final String? name2024;
  final String itemType;
  final ItemCategory category;
  final String rarity;
  final ItemRarity rarityTier;
  final String? cost;
  final String? cost2014;
  final String? cost2024;
  final bool requiresAttunement;
  final String? attunementRequirement;
  final String descriptionMarkdown;
  final ItemEditionDetails rules2014;
  final ItemEditionDetails rules2024;
  final bool isChangedIn2024;
  final String? diffSummary;
  final List<String> diffHighlights;
  final List<String> tags;

  /// Declarative mechanic grants emitted when this item is equipped (e.g., AC bonus, speed bonus).
  final List<FeatureGrant> grants;
  @override
  final Map<String, dynamic> customProperties;

  const EquipmentItem({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required this.itemType,
    required this.category,
    required this.rarity,
    required this.rarityTier,
    this.cost,
    this.cost2014,
    this.cost2024,
    required this.requiresAttunement,
    this.attunementRequirement,
    required this.descriptionMarkdown,
    required this.rules2014,
    required this.rules2024,
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.tags = const [],
    this.grants = const [],
    this.customProperties = const {},
  });

  /// Builds a single-edition [EquipmentItem] and hydrates `category`,
  /// `rarityTier`, `cost`, `attunementRequirement`, `rules2014`/`rules2024`,
  /// and `tags` via [_hydrateSingleEditionItem], shared with
  /// [EquipmentItem.fromMap] for pre-Cleanup slice 17 stored records.
  factory EquipmentItem.singleEdition({
    required EntityId id,
    required String name,
    String? name2014,
    String? name2024,
    required String itemType,
    ItemCategory? category,
    required String rarity,
    ItemRarity? rarityTier,
    String? cost,
    String? cost2014,
    String? cost2024,
    required bool requiresAttunement,
    String? attunementRequirement,
    required String descriptionMarkdown,
    String? summary,
    String? activation,
    String? charges,
    String? masteryProperties,
    String? savingThrowDc,
    List<String>? properties,
    bool isChangedIn2024 = false,
    String? diffSummary,
    List<String> diffHighlights = const [],
    List<String>? tags,
    List<FeatureGrant> grants = const [],
    Map<String, dynamic> customProperties = const {},
  }) =>
      _hydrateSingleEditionItem(
        id: id,
        name: name,
        name2014: name2014,
        name2024: name2024,
        itemType: itemType,
        category: ItemCategory.wondrousItem,
        rarity: rarity,
        rarityTier: rarityTier,
        cost: cost,
        cost2014: cost2014,
        cost2024: cost2024,
        requiresAttunement: requiresAttunement,
        attunementRequirement: attunementRequirement,
        descriptionMarkdown: descriptionMarkdown,
        summary: summary,
        activation: activation,
        charges: charges,
        masteryProperties: masteryProperties,
        savingThrowDc: savingThrowDc,
        properties: properties,
        isChangedIn2024: isChangedIn2024,
        diffSummary: diffSummary,
        diffHighlights: diffHighlights,
        tags: tags,
        grants: grants,
        customProperties: customProperties,
      );

  @override
  EntityType get entityType => EntityType.equipment;

  @override
  Map<String, dynamic> toMap() => {
        'id': id.toMap(),
        'name': name,
        'name2014': name2014,
        'name2024': name2024,
        'itemType': itemType,
        'category': category.name,
        'rarity': rarity,
        'rarityTier': rarityTier.name,
        'cost': cost,
        'cost2014': cost2014,
        'cost2024': cost2024,
        'requiresAttunement': requiresAttunement,
        'attunementRequirement': attunementRequirement,
        'descriptionMarkdown': descriptionMarkdown,
        'rules2014': rules2014.toMap(),
        'rules2024': rules2024.toMap(),
        'isChangedIn2024': isChangedIn2024,
        'diffSummary': diffSummary,
        'diffHighlights': diffHighlights,
        'tags': tags,
        'grants': grants.map((g) => g.toMap()).toList(),
        'customProperties': customProperties,
      };

  /// Decodes an [EquipmentItem] from a serialized map.
  ///
  /// Supports both unified Cleanup slice 17 maps and legacy pre-Cleanup slice 17
  /// records (which lack `category`, `rarityTier`, and `rules2014`/`rules2024`
  /// and are hydrated using the legacy substring rules).
  factory EquipmentItem.fromMap(Map<String, dynamic> map) {
    final id = EntityId.fromMap(Map<String, dynamic>.from(map['id'] as Map? ?? {}));
    final name = map['name']?.toString() ?? '';
    final itemType = map['itemType']?.toString() ?? 'Wondrous Item';
    final rarity = map['rarity']?.toString() ?? 'Common';
    final requiresAttunement = map['requiresAttunement'] == true;
    final descriptionMarkdown = map['descriptionMarkdown']?.toString() ?? '';
    final grants = (map['grants'] as List? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((g) => FeatureGrant.fromMap(Map<String, dynamic>.from(g)))
        .toList();
    final customProperties =
        Map<String, dynamic>.from(map['customProperties'] as Map? ?? {});

    final isUnified = map.containsKey('category') ||
        map.containsKey('rarityTier') ||
        map.containsKey('rules2014');

    if (isUnified) {
      final catName = map['category']?.toString();
      final category = ItemCategory.values.firstWhere(
        (c) => c.name == catName,
        orElse: () => _singleEditionCategoryFromItemType(itemType),
      );
      final rarName = map['rarityTier']?.toString();
      final rarityTier = ItemRarity.values.firstWhere(
        (r) => r.name == rarName,
        orElse: () => _singleEditionRarityFromString(rarity),
      );
      final r14 = map['rules2014'] is Map
          ? ItemEditionDetails.fromMap(
              Map<String, dynamic>.from(map['rules2014'] as Map))
          : const ItemEditionDetails.empty();
      final r24 = map['rules2024'] is Map
          ? ItemEditionDetails.fromMap(
              Map<String, dynamic>.from(map['rules2024'] as Map))
          : r14;
      return EquipmentItem(
        id: id,
        name: name,
        name2014: map['name2014']?.toString(),
        name2024: map['name2024']?.toString(),
        itemType: itemType,
        category: category,
        rarity: rarity,
        rarityTier: rarityTier,
        cost: map['cost']?.toString(),
        cost2014: map['cost2014']?.toString(),
        cost2024: map['cost2024']?.toString(),
        requiresAttunement: requiresAttunement,
        attunementRequirement: map['attunementRequirement']?.toString(),
        descriptionMarkdown: descriptionMarkdown,
        rules2014: r14,
        rules2024: r24,
        isChangedIn2024: map['isChangedIn2024'] == true,
        diffSummary: map['diffSummary']?.toString(),
        diffHighlights: (map['diffHighlights'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        tags: (map['tags'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        grants: grants,
        customProperties: customProperties,
      );
    }

    // Legacy pre-Cleanup slice 17 record hydration (shared with singleEdition).
    return _hydrateSingleEditionItem(
      id: id,
      name: name,
      itemType: itemType,
      rarity: rarity,
      requiresAttunement: requiresAttunement,
      descriptionMarkdown: descriptionMarkdown,
      grants: grants,
      customProperties: customProperties,
    );
  }

  EquipmentItem copyWith({
    EntityId? id,
    String? name,
    String? name2014,
    String? name2024,
    String? itemType,
    ItemCategory? category,
    String? rarity,
    ItemRarity? rarityTier,
    String? cost,
    String? cost2014,
    String? cost2024,
    bool? requiresAttunement,
    String? attunementRequirement,
    String? descriptionMarkdown,
    ItemEditionDetails? rules2014,
    ItemEditionDetails? rules2024,
    bool? isChangedIn2024,
    String? diffSummary,
    List<String>? diffHighlights,
    List<String>? tags,
    List<FeatureGrant>? grants,
    Map<String, dynamic>? customProperties,
  }) {
    return EquipmentItem(
      id: id ?? this.id,
      name: name ?? this.name,
      name2014: name2014 ?? this.name2014,
      name2024: name2024 ?? this.name2024,
      itemType: itemType ?? this.itemType,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      rarityTier: rarityTier ?? this.rarityTier,
      cost: cost ?? this.cost,
      cost2014: cost2014 ?? this.cost2014,
      cost2024: cost2024 ?? this.cost2024,
      requiresAttunement: requiresAttunement ?? this.requiresAttunement,
      attunementRequirement:
          attunementRequirement ?? this.attunementRequirement,
      descriptionMarkdown: descriptionMarkdown ?? this.descriptionMarkdown,
      rules2014: rules2014 ?? this.rules2014,
      rules2024: rules2024 ?? this.rules2024,
      isChangedIn2024: isChangedIn2024 ?? this.isChangedIn2024,
      diffSummary: diffSummary ?? this.diffSummary,
      diffHighlights: diffHighlights ?? this.diffHighlights,
      tags: tags ?? this.tags,
      grants: grants ?? this.grants,
      customProperties: customProperties ?? this.customProperties,
    );
  }

  static const _deepEq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          name2014 == other.name2014 &&
          name2024 == other.name2024 &&
          itemType == other.itemType &&
          category == other.category &&
          rarity == other.rarity &&
          rarityTier == other.rarityTier &&
          cost == other.cost &&
          cost2014 == other.cost2014 &&
          cost2024 == other.cost2024 &&
          requiresAttunement == other.requiresAttunement &&
          attunementRequirement == other.attunementRequirement &&
          descriptionMarkdown == other.descriptionMarkdown &&
          rules2014 == other.rules2014 &&
          rules2024 == other.rules2024 &&
          isChangedIn2024 == other.isChangedIn2024 &&
          diffSummary == other.diffSummary &&
          _deepEq.equals(diffHighlights, other.diffHighlights) &&
          _deepEq.equals(tags, other.tags) &&
          _deepEq.equals(grants, other.grants) &&
          _deepEq.equals(customProperties, other.customProperties);

  @override
  int get hashCode => Object.hashAll([
        id,
        name,
        name2014,
        name2024,
        itemType,
        category,
        rarity,
        rarityTier,
        cost,
        cost2014,
        cost2024,
        requiresAttunement,
        attunementRequirement,
        descriptionMarkdown,
        rules2014,
        rules2024,
        isChangedIn2024,
        diffSummary,
        _deepEq.hash(diffHighlights),
        _deepEq.hash(tags),
        _deepEq.hash(grants),
        _deepEq.hash(customProperties),
      ]);
}
