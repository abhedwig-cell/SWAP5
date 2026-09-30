# F-PE-ELASTIC60 — direct defect-head candidate preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authorities:
- F-PE-ELASTIC58 — QUALIFIED_SAFE_UNSATURATED_HEAD_BUDGET_WITH_SATURATED_EXHAUSTION;
- F-PE-ELASTIC59 — canonically admitted mode-7 typed mass publication.

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`.

## Problem

ELASTIC58 preserves the independently frozen terminal head limit
`H_limit = 0.01 cm`, but the mass-norm-to-infinity inequality used by
`Binf`

`Binf = bounded_m_norm / sqrt(min_mass_weight)`

is excessively conservative in saturated ELAS states because the smallest
capacity/mass weight is very small.

All saturated ELASTIC58 sequences therefore exhausted.

## Candidate

The existing defect indicator already solves the linear defect system

`A * delta = rhs`.

Define a research-only direct head observable

`D_INF = max_i |delta_i|`.

This quantity:
- is in cm of pressure head;
- comes from the same single tridiagonal defect solve;
- introduces no fitted scale;
- does not divide by a global minimum mass weight;
- is not claimed a priori to be a rigorous upper bound on realized temporal
  error.

## Frozen physical limit

Use the same independently qualified TEMPORAL04/05 terminal head limit:

`D_INF <= 0.01 cm`.

No new physical tolerance is introduced.

For paired-converged selected points also retain:
- `H_INF <= 0.01 cm`;
- `THETA_INF <= 1e-5`.

Hard mass acceptance remains separate and unchanged.

## Bank

Replay the full ELASTIC55 four-profile bank:
- profiles 11060, 10260, 8016, 3030;
- states -75, -20, +2, +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- bottom mode 7, swkimpl=0;
- same solver/tolerances and materialization.

## Controller replay

Use C-SAFE:
1. largest to smallest dt;
2. unavailable solve/indicator -> refine;
3. first point with `D_INF <= 0.01 cm` -> select;
4. otherwise EXHAUSTED.

No monotonicity assumption.

## Comparator

Replay the ELASTIC58 criterion in parallel:

`Binf <= 0.05773585599727987 cm`.

Report selected/exhausted counts and saturated coverage for both criteria.

## Hypotheses

H1. Direct D_INF materially reduces saturated exhaustion relative to the
ELASTIC58 Binf-derived criterion.

H2. Every paired D_INF-selected observation satisfies the frozen physical
`H_INF <= 0.01 cm` limit.

H3. Every paired D_INF-selected observation satisfies
`THETA_INF <= 1e-5`.

H4. D_INF remains finite/nonnegative whenever the research defect solve is
available.

## Gates

A1. Same four profiles and 1728 requested physical cases.

A2. O0/O2 semantic identity.

A3. D_INF is computed from the same defect tridiagonal solution, with no second
nonlinear solve and no fitted scale.

A4. D_INF selection uses exactly 0.01 cm.

A5. Zero paired selected H_INF failures.

A6. Zero paired selected THETA_INF failures.

A7. Hard typed mass publication from canonical ELASTIC59 remains untouched.

A8. Zero production src/** changes.

## Decision

A green result may qualify a tighter research candidate for saturated temporal
control.

It does not authorize:
- production indicator replacement;
- a complete F-CI14 eight-metric numeric profile;
- transaction integration;
- any relaxation of mass acceptance.
