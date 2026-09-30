/// Standard 5e entity sizes for Animated Objects
enum DndObjectSize {
  tiny,
  small,
  medium,
  large,
  huge,
}

typedef ObjectSize = DndObjectSize;

/// Baseline combat metrics for Animate Objects spell
class AnimatedObjectStats {
  final int pointCost;
  final int maxHp;
  final int ac;
  final int attackBonus;
  final int damageDiceCount;
  final int damageDiceSides;
  final int damageBonus;
  final int strScore;
  final int dexScore;
  final String defaultExample;

  const AnimatedObjectStats({
    required this.pointCost,
    required this.maxHp,
    required this.ac,
    required this.attackBonus,
    required this.damageDiceCount,
    required this.damageDiceSides,
    required this.damageBonus,
    required this.strScore,
    required this.dexScore,
    required this.defaultExample,
  });

  String get damageFormula {
    final bonusStr = damageBonus == 0
        ? ''
        : (damageBonus > 0 ? '+$damageBonus' : '$damageBonus');
    return '${damageDiceCount}d$damageDiceSides$bonusStr';
  }
}

/// Concrete D&D 5e Ruleset Adapter supplying standard Animate Objects baseline metrics.
class Dnd5eAnimatedObjectAdapter {
  const Dnd5eAnimatedObjectAdapter();

  static const Map<DndObjectSize, AnimatedObjectStats> baselines = {
    DndObjectSize.tiny: AnimatedObjectStats(
      pointCost: 1,
      maxHp: 20,
      ac: 18,
      attackBonus: 8,
      damageDiceCount: 1,
      damageDiceSides: 4,
      damageBonus: 4,
      strScore: 4,
      dexScore: 18,
      defaultExample: 'Silver Coin / Needle',
    ),
    DndObjectSize.small: AnimatedObjectStats(
      pointCost: 1,
      maxHp: 25,
      ac: 16,
      attackBonus: 6,
      damageDiceCount: 1,
      damageDiceSides: 8,
      damageBonus: 2,
      strScore: 6,
      dexScore: 14,
      defaultExample: 'Dagger / Chair',
    ),
    DndObjectSize.medium: AnimatedObjectStats(
      pointCost: 2,
      maxHp: 40,
      ac: 13,
      attackBonus: 5,
      damageDiceCount: 2,
      damageDiceSides: 6,
      damageBonus: 1,
      strScore: 10,
      dexScore: 12,
      defaultExample: 'Sword / Table',
    ),
    DndObjectSize.large: AnimatedObjectStats(
      pointCost: 4,
      maxHp: 50,
      ac: 10,
      attackBonus: 6,
      damageDiceCount: 2,
      damageDiceSides: 10,
      damageBonus: 2,
      strScore: 14,
      dexScore: 10,
      defaultExample: 'Cart / Statue',
    ),
    DndObjectSize.huge: AnimatedObjectStats(
      pointCost: 8,
      maxHp: 80,
      ac: 10,
      attackBonus: 8,
      damageDiceCount: 2,
      damageDiceSides: 12,
      damageBonus: 4,
      strScore: 18,
      dexScore: 6,
      defaultExample: 'Bouldering Pillar / Wagon',
    ),
  };

  static AnimatedObjectStats getStats(dynamic size) {
    if (size is DndObjectSize) {
      return baselines[size] ?? baselines[DndObjectSize.medium]!;
    }
    final sizeName = size.toString().split('.').last.toLowerCase();
    for (final entry in baselines.entries) {
      if (entry.key.name.toLowerCase() == sizeName) {
        return entry.value;
      }
    }
    return baselines[DndObjectSize.medium]!;
  }
}
