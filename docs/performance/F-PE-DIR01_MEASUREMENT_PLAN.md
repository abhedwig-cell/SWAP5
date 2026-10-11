# F-PE-DIR01 measurement plan

Date: 2026-09-26

Status: `OBSERVATION_ONLY_ATTRIBUTION`

Parent evidence:
`F-PE-PROFILE04`

Stacking base:
`work/f-pe-profile04-end-to-end-rebaseline@697686153a15ea3a6b121cea8b286139efe29891`

Canonical production authority underneath the stack:
`integration/f-ci-canonical@c52454b31d6f5d6ae6ed6af56460f158ddb45008`

## Immediate objective

Explain the approximately 86-88% incremental runtime of the production-required bottom-head accepted-trajectory directional route without changing production behavior.

No `src/**` optimization is permitted during this attribution phase.

## Attribution hierarchy

Measure, in order:

1. non-directional Reference solve;
2. factorization-capture preparation and release;
3. total accepted-step directional evaluation;
4. within that evaluation:
   - constitutive base-state directional work;
   - top/bottom route preparation and tangent RHS construction;
   - tridiagonal backsolve;
   - accepted-state water-content directional evaluation;
   - allocation/publication/result materialization;
5. accepted-trajectory accumulation across full + half + half transaction structure.

## Method

Use test-local source instrumentation only.

A copied build-time version of the directional service may contain timers/counters, but the repository production source must remain unchanged until attribution identifies a concrete target.

Use the same bottom-head fixture that PROFILE04 qualified.

Primary timing rule:
- paired same-run measurement;
- repeated calls;
- median across multiple independent CI jobs where needed.

## Preservation gates

Instrumentation runs must retain:
- identical Reference physical checksum;
- same nonlinear-iteration count;
- same constitutive evaluation count;
- same accepted-step count;
- same tangent availability;
- no additional full nonlinear solves;
- same bottom-head control coordinate;
- same accepted bottom-exchange derivative within bit identity where the existing fixture supports it.

## Decision rule

Do not optimize the largest-looking code block by inspection.

A production repair may start only when timing attribution demonstrates which component owns a material fraction of the directional increment.

If no removable exact overhead is found, close DIR01 without a repair and hand off to practical/approximate performance.
