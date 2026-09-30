# vtt_ruleset_dnd5e

Standalone, pure Dart D&D 5e dual-ruleset module (2014 RAW & 2024 Revised) implementing the public contracts of `vtt_engine_core`.

## Architectural Role

```text
vtt-engine-core (Ruleset-Agnostic Core Engine & CRDT Primitives)
      ↑
      │
vtt-ruleset-dnd5e (D&D 5e Ruleset Module, Mechanics, & Domain Models)
      ↑
      │
dangerously_nerdy_5e_toolkit (Flutter Tabletop Companion & Presentation Host)
```

## Features

- **Dual-Ruleset Architecture:** Full support for both 2014 RAW (SRD 5.1) and 2024 Revised (SRD 5.2.1) rulesets.
- **Contract Conformance:** Implements `IRulesetModule`, `ICombatResolver`, `ICurrencySystem`, `IAttributeSystem`, and `ISimulationStrategy` from `vtt_engine_core`.
- **Character Progression & Evaluation:** Multiclass spellcasting progressions, hit dice scaling, attack profiles, derived AC, and passive senses.
- **Exhaustion & Rest Frameworks:** Dual-ruleset exhaustion tracking and resting mechanics.
- **2024 Weapon Mastery:** Native evaluation of weapon mastery properties (Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex).
- **Pure Dart & Zero Flutter:** Fully decoupled from UI frameworks, presentation widgets, and platform-specific databases.

## License

GNU AGPLv3. Copyright (C) 2026 Kevin Burkeland.
