# vtt_ruleset_dnd5e: Architecture & Navigation Operating Manual

Welcome, AI Agent / Software Architect. This document serves as the primary operating manual and navigation index for the `vtt_ruleset_dnd5e` codebase.

This repository is:
- An upstream provider of concrete D&D 5e dual-ruleset mechanics (2014 RAW & 2024 Revised)
- An implementation of public contracts from `vtt_engine_core` (`IRulesetModule`, `ICombatResolver`, `ICurrencySystem`, `IAttributeSystem`, `ISimulationStrategy`)
- 100% pure Dart with ZERO Flutter dependencies

---

## 🧭 Codebase Structure

```text
vtt_ruleset_dnd5e/
├── lib/
│   ├── vtt_ruleset_dnd5e.dart        # Primary public library entry point & barrel
│   └── src/
│       ├── modules/                  # Dnd5eRulesetModule, Dnd5e2014Module, Dnd5e2024Module
│       ├── combat/                   # Dnd5eCombatResolver, attack declaration & resolution
│       ├── currency/                 # Dnd5eCurrencySystem, Dnd5eCurrency
│       ├── attributes/               # Dnd5eAttributeSystem, AbilityScores, Dnd5eScoreMath
│       ├── mechanics/                # ExhaustionState, WeaponMastery, RestMechanic, ActionEconomy
│       ├── progression/              # CharacterProgressionEngine, LevelUpRequest, HpProgressionChoice
│       ├── evaluation/               # CharacterEvaluationEngine, CharacterStatCalculator, ComputedAttackProfile
│       ├── spellcasting/             # SpellcastingRulesEngine, SpellAllocationValidator
│       ├── simulation/               # Dnd5eDprSimulationStrategy, DprCalculatorEngine, AoeResolver
│       ├── models/                   # Character, CharacterProgression, FeatureGrant, CoreTypes
│       └── rules/                    # RulesetEdition, RulesetContext, DndRulesetStrategy
└── test/                             # Automated test suite
    ├── compliance/                   # Domain purity & SRD legal compliance
    ├── modules/                      # Ruleset module & capability tests
    ├── progression/                  # Progression & level up tests
    ├── evaluation/                   # Character stat & evaluation tests
    └── boundary/                     # Package boundary integration tests
```

---

## 🛡️ Core Engineering Invariants

1. **Zero Flutter:** No `package:flutter/...` imports in `lib/`. Verified by `test/compliance/domain_purity_test.dart`.
2. **Upstream Isolation:** Depends only on `vtt_engine_core` via pinned Git dependency. Never depend on downstream applications (`dangerously_nerdy_5e_toolkit`).
3. **Decoupled Reference Resolution:** Domain entity references resolve through `IEntityResolver`, not application databases.
4. **Clean-Room SRD:** Zero Wizards of the Coast Product Identity terms. Only SRD 5.1 / 5.2.1 content.
5. **Pinned Dependency Synchronization:** Upstream updates must be pinned to exact commit SHAs.

---

## ⚡ Fast Development & Test Workflows

```bash
dart analyze
dart test
```
