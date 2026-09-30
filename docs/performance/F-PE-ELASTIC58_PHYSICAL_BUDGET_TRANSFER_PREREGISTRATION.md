# F-PE-ELASTIC58 — physical temporal-budget transfer preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Independent physical-error authority:
`F-PE-TEMPORAL04 P1 / F-PE-TEMPORAL05`

Frozen external physical envelope:
- terminal pressure-head error <= `0.01 cm`;
- terminal water-content error <= `1e-5`;
- terminal bottom-flux relative error <= `1%`;
- integrated bottom-exchange relative error <= `0.5%`;
- complete mass accounting.

ELASTIC58 can test only the head/water-content subset with the current
mode-7 full-versus-two-half oracle. Flux/exchange limits remain outside scope.

Frozen ELASTIC54/55 conservative scaling:

`H_INF <= alpha * Binf`

with

`alpha = 0.17320259355765216`.

Therefore the preregistered derived research budget is:

`Binf_budget = 0.01 / alpha = 0.05773585599727987 cm`.

No value from ELASTIC58 may alter alpha, the 0.01-cm head limit, or this
derived Binf budget.

## Question

Does applying the independently derived
`Binf <= 0.05773585599727987 cm`
criterion through the ELASTIC57 C-SAFE refinement pattern preserve the
independent `0.01 cm` head and `1e-5` water-content error envelope over the
multi-profile ELASTIC55 bank?

## Frozen replay bank

Reuse the four ELASTIC55 holdout profiles:
- 11060;
- 10260;
- 8016;
- 3030.

Preserve:
- profile geometry;
- Staringreeks retention materialization;
- generated Ss;
- bottom mode 7;
- swkimpl=0;
- fixed-flux top boundary;
- states `-75,-20,+2,+10 cm`;
- perturbations `-0.05,-0.035,+0.035,+0.05 cm/day`;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- hard mass gate;
- research-only mode-7 defect indicator.

## C-SAFE budget application

For each sequence ordered from largest to smallest dt:

1. unavailable full solve/indicator -> continue refining;
2. if `Binf <= 0.05773585599727987 cm`, accept the first such point;
3. otherwise continue refining;
4. if no point passes, return EXHAUSTED.

No monotonicity assumption is used.

## Verification subset

For every accepted point where full, half1 and half2 all converge, require:

- realized `H_INF <= 0.01 cm`;
- realized `DTHETA_INF <= 1e-5`;
- frozen global envelope `H_INF <= alpha * Binf`.

Accepted points without a paired full/half oracle are counted separately and
are not used to claim direct physical-error verification.

## Gates

A1. Exact four-profile selection reproduces ELASTIC55.

A2. O0/O2 semantic identity.

A3. Derived Binf budget is exactly
`0.05773585599727987 cm`.

A4. C-SAFE accepts only full-converged, indicator-available points satisfying
the frozen Binf budget.

A5. Every paired accepted point satisfies head <= 0.01 cm.

A6. Every paired accepted point satisfies dtheta <= 1e-5.

A7. Frozen ELASTIC54/55 global envelope remains satisfied.

A8. Accepted-but-unpaired points are reported explicitly.

A9. Zero `src/**` production changes.

## Non-claims

ELASTIC58 does not qualify:
- the other six F-CI14 endpoint limits;
- bottom-flux or integrated-exchange limits;
- a production temporal budget;
- production mode-7 indicator admission;
- controller integration into production;
- optional process-state coverage.

## Decision

A green result qualifies only a research bridge between:
- the independent 0.01-cm head-error envelope;
- the frozen global mode-7 defect scaling;
- the C-SAFE refinement pattern.

Production admission remains blocked until the remaining F-CI14 metric limits,
flux/exchange behavior, and independent transaction integration are qualified.
