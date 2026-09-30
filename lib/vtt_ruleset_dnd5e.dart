/// Standalone, pure Dart D&D 5e dual-ruleset module (2014 RAW & 2024 Revised)
/// implementing the public contracts of `vtt_engine_core`.
library vtt_ruleset_dnd5e;

// Ruleset Modules & Core SPI Implementations
export 'src/modules/dnd5e_ruleset_module.dart';
export 'src/modules/dnd_5e_modules.dart';

// Ruleset Edition & Context
export 'src/rules/ruleset_edition.dart';
export 'src/rules/ruleset_context.dart' hide RulesetVersion;
export 'src/rules/dnd_ruleset_strategy.dart';

// Combat & Resolution
export 'src/combat/dnd_5e_combat_resolver.dart';

// Currency
export 'src/currency/dnd_5e_currency_system.dart';

// Attributes & Math
export 'src/attributes/dnd_5e_attribute_system.dart';
export 'src/attributes/dnd5e_attributes.dart';
export 'src/attributes/dnd_5e_rules_engine.dart';

// Mechanics (Mastery & Exhaustion)
export 'src/mechanics/weapon_mastery.dart';
export 'src/mechanics/exhaustion_state.dart';

// Simulation Strategies & Adapters
export 'src/simulation/dnd_5e_dpr_simulation_strategy.dart';
export 'src/simulation/dnd_5e_animated_object_adapter.dart';

// Progression & Leveling
export 'src/progression/character_progression_engine.dart';

// Evaluation & Statistics
export 'src/evaluation/character_evaluation_engine.dart';
export 'src/evaluation/character_stat_calculator.dart';

// Spellcasting
export 'src/spellcasting/spellcasting_rules_engine.dart';
export 'src/spellcasting/spell_allocation_validator.dart';

// Domain Models & Resolvers
export 'src/models/core_types.dart';
export 'src/models/feature_grant.dart';
export 'src/models/spell_monster_equipment.dart';
export 'src/models/character_models.dart';
export 'src/models/i_entity_resolver.dart';
export 'package:vtt_engine_core/models/entity_reference.dart';
