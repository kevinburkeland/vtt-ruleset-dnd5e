import 'dart:math';
import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/models/value_objects/hit_points.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';

/// Concrete D&D 5e Combat Resolver implementing core SRD combat calculations:
/// - d20 roll + attack bonus vs Target Armor Class
/// - Natural 20 critical hit (doubles damage dice), Natural 1 critical miss
/// - 5e RAW Vitals & Instant Death decoupling:
///   - Temp HP absorbs damage first
///   - Dropping to 0 HP sets isDowned = true
///   - Massive damage where excess damage >= maxHp triggers instant death (isDead = true)
///   - Standard healing revives downed characters at 0 HP
///   - Dead characters cannot be healed unless allowRevive is true
class Dnd5eCombatResolver implements ICombatResolver {
  const Dnd5eCombatResolver();

  @override
  AttackResolution resolveAttack({
    required AttackIntent attack,
    required TargetDefenseProfile defense,
    required Random rng,
  }) {
    final natural = rng.nextInt(20) + 1;
    final totalToHit = natural + attack.attackBonus;
    final isCrit = natural >= attack.critThreshold;
    final isFumble = natural == 1;

    final AttackOutcomeType outcome;
    if (isCrit) {
      outcome = AttackOutcomeType.criticalHit;
    } else if (isFumble) {
      outcome = AttackOutcomeType.criticalMiss;
    } else if (totalToHit >= defense.targetDefenseRating) {
      outcome = AttackOutcomeType.hit;
    } else {
      outcome = AttackOutcomeType.miss;
    }

    final isHit = outcome == AttackOutcomeType.hit ||
        outcome == AttackOutcomeType.criticalHit;
    final damageDealt = isHit
        ? rollDamage(
            damageExpression: attack.damageExpression,
            isCrit: isCrit,
            rng: rng,
          )
        : 0;

    final riderLogs = <String>[];
    if (isHit && attack.riders.isNotEmpty) {
      for (final rider in attack.riders) {
        riderLogs.add('Triggered rider: ${rider.name} (${rider.riderType})');
      }
    }

    return AttackResolution(
      outcome: outcome,
      naturalRoll: natural,
      totalToHit: totalToHit,
      damageDealt: damageDealt,
      triggeredRiderLogs: riderLogs,
    );
  }

  @override
  int rollDamage({
    required String damageExpression,
    required bool isCrit,
    required Random rng,
  }) {
    // Basic parser for NdS+M or flat scalars
    final clean = damageExpression.replaceAll(' ', '').toLowerCase();
    if (clean.isEmpty) return 0;

    var numDice = 1;
    var dieSides = 0;
    var modifier = 0;

    final dIndex = clean.indexOf('d');
    if (dIndex != -1) {
      final diceCountStr = clean.substring(0, dIndex);
      numDice = diceCountStr.isEmpty ? 1 : (int.tryParse(diceCountStr) ?? 1);

      final rest = clean.substring(dIndex + 1);
      final plusIndex = rest.indexOf('+');
      final minusIndex = rest.indexOf('-');

      if (plusIndex != -1) {
        dieSides = int.tryParse(rest.substring(0, plusIndex)) ?? 6;
        modifier = int.tryParse(rest.substring(plusIndex + 1)) ?? 0;
      } else if (minusIndex != -1) {
        dieSides = int.tryParse(rest.substring(0, minusIndex)) ?? 6;
        modifier = -(int.tryParse(rest.substring(minusIndex + 1)) ?? 0);
      } else {
        dieSides = int.tryParse(rest) ?? 6;
      }
    } else {
      return int.tryParse(clean) ?? 0;
    }

    final effectiveDice = isCrit ? numDice * 2 : numDice;
    var total = modifier;
    for (var i = 0; i < effectiveDice; i++) {
      total += (dieSides > 0 ? rng.nextInt(dieSides) + 1 : 0);
    }

    return max(0, total);
  }

  @override
  VitalsModification resolveVitalsChange({
    required EntityVitals currentVitals,
    required int delta,
    bool allowRevive = false,
  }) {
    if (delta == 0) {
      return VitalsModification(
        updatedVitals: currentVitals,
        effectiveDelta: 0,
      );
    }

    if (delta < 0) {
      // Damage resolution
      final damageAmount = delta.abs();
      var remainingDamage = damageAmount;
      var newTempHp = currentVitals.temporaryHp;

      if (newTempHp > 0) {
        if (remainingDamage <= newTempHp) {
          newTempHp -= remainingDamage;
          remainingDamage = 0;
        } else {
          remainingDamage -= newTempHp;
          newTempHp = 0;
        }
      }

      final hpBefore = currentVitals.currentHp;
      final newHp = max(0, hpBefore - remainingDamage);
      final excessDamage = remainingDamage - hpBefore;

      // 5e RAW: Massive damage that exceeds remaining HP plus maxHp causes instant death
      final triggeredDeath =
          (hpBefore > 0 && excessDamage >= currentVitals.maxHp) ||
              currentVitals.isDead;

      final updated = currentVitals.copyWith(
        currentHp: newHp,
        temporaryHp: newTempHp,
        isDowned: newHp <= 0,
        isDead: triggeredDeath,
      );

      return VitalsModification(
        updatedVitals: updated,
        effectiveDelta: delta,
        triggeredDeath: triggeredDeath && !currentVitals.isDead,
      );
    } else {
      // Healing resolution
      if (currentVitals.isDead && !allowRevive) {
        return VitalsModification(
          updatedVitals: currentVitals,
          effectiveDelta: 0,
        );
      }

      final hpBefore = currentVitals.currentHp;
      final newHp = min(currentVitals.maxHp, hpBefore + delta);
      final wasDowned = currentVitals.isDowned && hpBefore <= 0;
      final revived = wasDowned && newHp > 0;

      final updated = currentVitals.copyWith(
        currentHp: newHp,
        isDowned: newHp <= 0,
        isDead: allowRevive ? false : currentVitals.isDead,
        auxiliaryPools: revived
            ? {
                ...currentVitals.auxiliaryPools,
                'deathSaveSuccesses': 0,
                'deathSaveFailures': 0,
              }
            : currentVitals.auxiliaryPools,
      );

      return VitalsModification(
        updatedVitals: updated,
        effectiveDelta: newHp - hpBefore,
        revivedFromDefeat: revived,
      );
    }
  }

  /// Resolves damage against a [HitPoints] value object applying 5e RAW rules
  /// (Temporary HP absorption and Massive Damage instant death).
  HitPoints resolveHitPointsDamage(HitPoints currentHp, int amount) {
    final vitals = EntityVitals(
      currentHp: currentHp.currentHp,
      maxHp: currentHp.maxHp,
      temporaryHp: currentHp.tempHp,
      isDowned: currentHp.isDowned,
      isDead: currentHp.isDead,
    );
    final mod = resolveVitalsChange(currentVitals: vitals, delta: -amount);
    return HitPoints(
      currentHp: mod.updatedVitals.currentHp,
      maxHp: mod.updatedVitals.maxHp,
      tempHp: mod.updatedVitals.temporaryHp,
      isDead: mod.updatedVitals.isDead,
    );
  }
}
