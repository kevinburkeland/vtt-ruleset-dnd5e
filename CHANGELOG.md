# Changelog

One line per slice, newest first. Each line: date, slice name, what changed for a user or a developer.
Work before Map slice 1.1 (hardening passes 0 to 12) is in the git history.

## 2026-11-11
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
