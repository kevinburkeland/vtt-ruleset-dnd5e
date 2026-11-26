# Changelog

One line per slice, newest first. Each line: date, slice name, what changed for a user or a developer.
Work before Map slice 1.1 (hardening passes 0 to 12) is in the git history.

## 2026-11-26
- Cleanup slice 17: Move EquipmentItem into lib/src/models/equipment_item.dart with pure-Dart ItemCategory, ItemRarity, ItemEditionDetails, edition fields, and pre-slice-17 fromMap compatibility, backed by 500-seed round-trip and 200-seed legacy compatibility laws (Fixes 5.1, 5.3).
- Cleanup slice 17: Align 2024 SpellAllocationValidator.getLimitsForClass with SRD 5.2.1 class tables (and 2024 table message), add CasterProgression enum and homebrew caster support to resolveClassSpellcasterProfile with exhaustive laws (Fixes 3.1, 3.2).
- Cleanup slice 17: Retire 7 cs16 mutation branches and confirm 14-day dependency look-ahead passes (Fixes 1.1, 1.4).

## 2026-11-25
- Cleanup slice 16: Fix getMaxSpellTierForClass clamping for full casters (L19-20 -> 9) and half casters (L3-4 -> 1, L7-8 -> 2, L11-12 -> 3, L15-16 -> 4, L19-20 -> 5) caught by Fix 7.1 app law (Fix 7.1).
- Cleanup slice 16: Add ClassSpellcasterProfile/resolveClassSpellcasterProfile, computeEffectiveAsiBonusDelta/applyAbilityScoreIncreases, computeOriginAbilityBonuses, and computeLevelUpHpGain with exhaustive laws and wire into CharacterProgressionEngine (Fixes 7.1-7.3).
- Cleanup slice 16: Replace all dynamic types in Dnd5eCatalog with CatalogFeat, CatalogMagicItem, and Object?, remove dynamic casts in CharacterEvaluationEngine, and add catalog_no_dynamic_bar_test.dart (Fix 5.1).
- Cleanup slice 16: Add computeAttackOddsWithBuffDie, computeVexConditionalOdds, and computeFirstHitSneakAttackExpectedDamage with exact grid laws and 60-turn x 200k-trial Monte Carlo cross-check (Fix 4.3).
- Cleanup slice 16: Add parseChallengeRating(String) with 600-seed laws to vtt_ruleset_dnd5e (Fix 2.1).
- Cleanup slice 16: Retire cs15 mutation branches and run 14-day dependency look-ahead (upgraded local coverage to 1.16.2) (Fixes 1.1, 1.5).

## 2026-11-24
- Cleanup slice 15: Add DamageDefenses stat-block parser, classifyAttackRoll, doesShieldBlockAttack, computeSaveDc, and SRD proficiencyBonusForChallengeRating (CR 0-30, +2 to +9) with exhaustive/seeded laws, and delegate Dnd5eCombatResolver.resolveAttack to classifyAttackRoll (Fixes 5.1-5.4).

## 2026-11-23
- Cleanup slice 15: Retire cs14 mutation branches and sync coverage floor barrel self-test cases 21-24 (Fixes 1.1, 1.2).

## 2026-11-21
- Cleanup slice 14: Re-pin vtt_engine_core to ec9f155cbdce8315b0d84213842ddf8a22e46a66, add 1500-line big-file bar with character_models.dart allowlisted at 1742 lines, sync check_coverage_floor.py, and remove duplicate test files test/attributes/dnd_5e_rules_engine_test.dart and test/combat/dnd_5e_combat_resolver_test.dart (Fixes 7.3, 7.4).

## 2026-11-19
- Cleanup slice 14: Wrap Character.inventory in List.unmodifiable once in the constructor with a 120-seed read-only law, make parse_semver fail closed in check_dependencies.py (DC75-DC76), and upgrade no_super_conversion_bar_test to catch closures and report line numbers (Fixes 4.1-4.3).
- Cleanup slice 14: Add EvaluatedCharacterStats.spellcastingModifiers keyed identically to spellAttackBonuses (empty for non-spellcasters) with a 360-seed law test and updated coverage floors (Fix 3.1).
- Cleanup slice 14: Retire cs13 mutation branches, allow renamed-test reasons in check_srd_terms.py, and enforce append-only history on test/removed_test_names.txt in check_test_names.py (Fixes 1.1-1.3).

## 2026-11-18
- Cleanup slice 13: Re-pin vtt_engine_core to 87011633eb26d170a67b7992132cae9866cd297b, declare moved D&D fields and typed model fields directly on Character/InventoryItemInstance (zero super.* conversions), implement IRulesetModule<Character>, add Dnd5eRulesetModule.forEdition, route Character.queryStat through edition module with ArgumentError on unknown keys, align customProperties['armorClass'/'ac'] override with CharacterEvaluationEngine, and add typed contract laws, no-super-conversion bar, and Step 8 golden diff-guard (Fixes 8.1-8.5).
- Cleanup slice 13: Re-pin vtt_engine_core to db2e90c5e657a6c6ccba631764e999816d2e14fd, extend TabletopCharacter/TabletopResourcePool/TabletopItemInstance/TabletopEntityType, delete RulesetVersion alias, remove all hide combinators on core/ruleset URIs, and add unique-type-names and no-package-hide compliance bars (Fixes 7.1, 7.2).
- Cleanup slice 13: Enforce full schema paths in check_dependencies.py, upgrade check_coverage_floor.py to full git history with fetch-depth: 0 and 0.5 max floor lag, add SpellAllocationValidator tests (97.1% coverage), and raise coverage floors (Fixes 5.1-5.3).
- Cleanup slice 13: Add DiceExpression.singleDieGroup read-only helper and law test (Fix 3.3).
- Cleanup slice 13: Retire cs12 mutation branches and strengthen SRD denylist guard test to plant a real denylist term in a temp directory (Fixes 2.1, 2.2).
- Cleanup slice 13: Expand shared SRD compliance denylist and tighten check_srd_terms.py to scan test/removed_test_names.txt except rows with the slice 13 SRD removal reason (Fix 1.3).
- Cleanup slice 12: Add exact computeAttackOdds, computeSaveFailureProbability, and computeSaveDamage (with Evasion) and oracle law tests (Fixes 7.1, 7.2, 7.3).

## 2026-11-17
- Cleanup slice 12: Move pure ruleset tests home with InMemoryEntityResolver (Fix 6.1), and add monotonic coverage floor script check_coverage_floor.py, coverage_floors.tsv, and CI enforcement (Fix 6.2).
- Cleanup slice 12: Scan lib/ against compliance/srd_denylist.txt in srd_legal_compliance_test and add meta-test guarding against existsSync-only test bodies (Fix 5.2).

## 2026-11-13
- Cleanup slice 11: Add DiceExpression.tryParse, DiceExpression.findAll with DiceMatch, and read-only helpers (Fix 7.1).
- Cleanup slice 11: Add shared SRD denylist and scanner check_srd_terms.py (Fix 5.1), remove non-SRD species check (Fix 5.2), and massive damage at 0 HP kills (Fix 5.4).
- Cleanup slice 11: Enforce fail-closed input validation by schema table in check_dependencies.py (Fix 3.1) and generate dynamic table-driven damage and valid tests in test_check_dependencies.sh (Fix 3.2).
- Cleanup slice 11: Retire bs2 mutation branches, and teach check_test_names to refuse live and invented test names in test/removed_test_names.txt.
- Cleanup slice 11: Update dart-lang/setup-dart workflow action pins to v1.8.2 (2286a0c042b44434fe26d292bbce8d34f7ec662b).

## 2026-11-12
- Bonus slice 2: Move environment SDK to ^3.14.0, pin vtt_engine_core to 0617617e954e0add7898a00cf5f9b4ec3334525e, move workflows setup-dart to 3.14.0, and update DC36 in test_check_dependencies.sh.

## 2026-11-11
- Bonus slice 1.1: Enforce mutation branch commit rules (single commit, Signed-off-by trailer, and MUTATION subject format with matching id), validate remote branch subjects and active branch limit in check_mutation_branches.sh, support dated exact-SHA exceptions in mutation_subject_exceptions.tsv, and add MB1-MB17 and RM1-RM20 self-tests.
- Bonus slice 1.1: Add npm override declaration rule N4, per-advisory vulnerability checking with GHSA verification rule N2, and add DC60-DC69 self-tests.
- Bonus slice 1.1: Calculate wait counts from first newer release date, enforce declared floor currency (rule D6), tighten direct dependency floors, refine D4 exception reasons, pin vtt_engine_core to a570912f39a03889a1c76b03482ed9c680e2df3a, and add DC50-DC59 self-tests.
- Bonus slice 1.1: Enforce fail-closed validation for missing or unreadable inputs, validate pub and npm JSON shapes, fail on npm audit/outdated error objects, and add DC42-DC49 self-tests.
- Bonus slice 1.1: Fix workflow parsing in check_dependencies to follow jobs layout, check exact min-sdk job id, require single min-sdk job with single setup-dart step in pure Dart packages, print setup-dart summary, and add DC36-DC41 self-tests.

## 2026-11-10
- Bonus slice 1: Bring dependencies, Dart SDK, and CI actions up to date, pin vtt_engine_core to a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf, and wire dependency currency checks in CI.

## 2026-11-05
- Cleanup slice 9: Retire script pushes archive tags atomically with leased branch deletions.

## 2026-11-04
- Cleanup slice 8: Enforce single root analysis_options.yaml in check_strict_analysis.sh.

## 2026-11-03
- Cleanup slice 6: Ratchet sees renamed and moved test files with --no-renames and self-tests TN9-TN11.

## 2026-10-28
- Cleanup slice 5: Test-name ratchet script, self-test suite, CI workflow integration, documentation truth compliance test suite, adjustDamageForDefenses, and unified DiceExpression parser with laws and regex source bar.

## 2026-10-27
- Cleanup slice 4.1: Enable strict-casts, strict-raw-types, and strict-inference with canary verification script, map-flavour round-trip law, and pin vtt_engine_core to 59d7178dea6527a18a2cac3b7fe0f110fb93717a.

## 2026-10-26
- Cleanup slice 3: Automated mutation branch retirement script, self-test suite, CI workflow integration, and mutation archive folder.
- Mutation slice-id prefixes: ms111 = Map slice 1.1.1, ms12 = 1.2, ms121 = 1.2.1, ms13 = 1.3, ms14 = 1.4, ms141 = 1.4.1, ms15 = 1.5, ms16 = 1.6, cs1 = Cleanup slice 1, cs2 = Cleanup slice 2, cs3 = Cleanup slice 3, cs41 = Cleanup slice 4.1.
- Cleanup slice 2: Relative documentation link fixes and markdown link compliance test.
- Cleanup slice 1: Add CONTRIBUTING, CODE_OF_CONDUCT, mutation branch CI check, and repository hygiene rules.
- Map slice 1.6: Pin vtt_engine_core to cf0cff8506cc51a9d903c1bca566c059736cd4e7 (pin bump only).

## 2026-10-25
- Map slice 1.5: Pin vtt_engine_core to 1807882 (pin bump only).
- Map slice 1.4.1: Pin vtt_engine_core to 662547d (pin bump only).
- Map slice 1.4: Pin vtt_engine_core to b2a88d6 (pin bump only).

## 2026-10-24
- Map slice 1.1.1: Pin vtt_engine_core to a80ed6a (pin bump only).
- Map slice 1.1: Pin vtt_engine_core to 926e7b2 (pin bump only).
