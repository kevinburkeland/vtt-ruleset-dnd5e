import 'dart:math';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_engine_core/simulation/i_simulation_strategy.dart';
import '../combat/dnd_5e_combat_resolver.dart';

/// Concrete 5e DPR Monte Carlo Simulation Strategy.
/// Evaluates attack intents against defense profiles using standard 5e mechanics.
class Dnd5eDprSimulationStrategy
    implements ISimulationStrategy<AttackIntent, TargetDefenseProfile> {
  final ICombatResolver resolver;

  const Dnd5eDprSimulationStrategy({
    this.resolver = const Dnd5eCombatResolver(),
  });

  @override
  String get strategyId => 'dnd5e_dpr_standard';

  @override
  SimulationStepOutcome simulateStep({
    required AttackIntent action,
    required TargetDefenseProfile target,
    required Random rng,
  }) {
    final resolution = resolver.resolveAttack(
      attack: action,
      defense: target,
      rng: rng,
    );

    return SimulationStepOutcome(
      isSuccess: resolution.isHit,
      isCritical: resolution.isCrit,
      magnitude: resolution.damageDealt.toDouble(),
      logs: resolution.triggeredRiderLogs,
    );
  }
}
