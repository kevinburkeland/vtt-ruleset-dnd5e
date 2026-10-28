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
│       ├── attributes/               # Dnd5eAttributeSystem, AbilityScores, Dnd5eScoreMath
│       ├── catalog/                  # Dnd5eCatalog
│       ├── combat/                   # Dnd5eCombatResolver, attack declaration & resolution
│       ├── currency/                 # Dnd5eCurrencySystem
│       ├── dice/                     # DiceExpression, tabletop dice notation parser
│       ├── evaluation/               # CharacterEvaluationEngine, CharacterStatCalculator, ComputedAttackProfile
│       ├── mechanics/                # ExhaustionState, WeaponMasteryProperty, WeaponMasteryValidator
│       ├── models/                   # Character, CharacterProgression, FeatureGrant
│       ├── modules/                  # Dnd5eRulesetModule, Dnd5e2014Module, Dnd5e2024Module
│       ├── progression/              # CharacterProgressionEngine, LevelUpRequest, HpProgressionChoice
│       ├── rules/                    # RulesetEdition, RulesetStrategy, Ruleset2014Strategy, Ruleset2024Strategy
│       ├── simulation/               # Dnd5eDprSimulationStrategy (DPR calculation for the app lives in the app)
│       └── spellcasting/             # SpellcastingRulesEngine, SpellAllocationValidator
└── test/                             # Automated test suite
    ├── attributes/                   # Ability score math tests
    ├── boundary/                     # Package boundary integration tests
    ├── catalog/                      # Bundled catalog verification tests
    ├── combat/                       # Combat resolver tests
    ├── compliance/                   # Domain purity, docs truth & SRD legal compliance
    ├── currency/                     # Currency system tests
    ├── dice/                         # Dice expression and parsing law tests
    ├── evaluation/                   # Character stat & evaluation tests
    ├── helpers/                      # Test doubles and fixtures
    ├── mechanics/                    # Weapon mastery & exhaustion state tests
    ├── models/                       # Entity serialization & map flavour tests
    ├── modules/                      # Ruleset module & capability tests
    ├── rules/                        # Ruleset edition reference tests
    └── spellcasting/                 # Spellcasting rules engine tests
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

### Repository Hygiene & Mutation Branches
- `strict-casts`, `strict-raw-types` and `strict-inference` are on. Never turn them off, never add an `errors:` override, never add an `ignore` comment. `scripts/check_strict_analysis.sh` proves the options work. A strict fix must keep runtime behaviour: never narrow a type test, never add a default or a catch.
- Mutation branches are named `mutation/<slice-id>-<id>` and exist only while their slice is under review. Mutation branches are retired with `scripts/retire_mutation_branches.sh` and are never deleted by hand. CI fails above 20 per repo.
- `AGENTS.md` and `.antigravityrules` are checked by `test/compliance/agents_docs_truth_test.dart`: every tree path, every type name and every repo path must exist.
- READMEs and docs never state test counts or hand-typed status; use generated badges.

---

## 🔄 Cross-Boundary Repository Pivot Protocol
When inspecting, editing, refactoring, or running commands inside `../vtt-engine-core` or `../dangerously_nerdy_5e_toolkit`:
1. **Mandatory Ingestion:** Ingest the target repository's `.antigravityrules` and `AGENTS.md` before making changes.
2. **Context Suspension:** Suspend ruleset assumptions when in core (no 5e mechanics or terminology in core); suspend pure-Dart assumptions when in the toolkit (Flutter UI, persistence, DI).
3. **Local Governance:** The target repository's rules take absolute precedence for its files.

---

## 📌 Pinned Git Dependency Synchronization Protocol
1. Core changes produce a concrete commit SHA on `main` in `../vtt-engine-core`.
2. Update `pubspec.yaml` in `vtt-ruleset-dnd5e` with `vtt_engine_core.git.ref: <core-sha>`.
3. Run `dart pub get`, `dart analyze`, and `dart test`.
4. Commit changes with DCO sign-off (`git commit -s`) to produce a concrete ruleset commit SHA.
5. Downstream applications (e.g. `dangerously_nerdy_5e_toolkit`) update their pinned Git dependencies accordingly.

---

## 🧹 Mutation Branch Retirement Protocol
Mutation branches are retired with `scripts/retire_mutation_branches.sh` at the start of the next slice, after the review closes. Never delete them by hand.
