# F-PE-NLGLOB13D preregistration — same-origin h/8 falsification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@dc12c52ea71e136cd9ea0573980915b8618ca7d6`

Parent authority:

- NLGLOB13C1: exact rollback/pre-state identity confirmed;
- NLGLOB13C2: `NLGLOB13C2_SAME_ORIGIN_H4_CONTRACTION_CONFIRMED`.

## Purpose

NLGLOB13D tests exactly one additional temporal refinement on only the five same-origin h/4 children that remain retention-inadmissible after C2.

No adaptive recursion is opened.

## Frozen target set

Exactly these five O05/TG trajectories:

- HEAD, dt = 0.00025 d;
- HEAD, dt = 0.000125 d;
- HEAD, dt = 0.0000625 d;
- RUNOFF, dt = 0.00025 d;
- RUNOFF, dt = 0.000125 d.

For each target, use the same failing parent origin already qualified by C2.

## Frozen candidate

For the same-origin inadmissible h/4 child only:

- rollback exactly to that child's origin;
- replace the failing h/4 interval by two h/8 intervals;
- do not subdivide further;
- retain endpoint/provider-consistent coefficient staging;
- retain unchanged TG accepted update;
- retain S0/R0 research endpoint certificates;
- retain unchanged route semantics and physical mass contract.

No accepted-theta clipping or constitutive extrapolation is allowed.

## Frozen gates

Classify:

`NLGLOB13D_H8_ADMISSIBILITY_CONFIRMED`

only if all hold:

1. all five targets execute without process failure;
2. exact origin identity is preserved;
3. every first same-origin h/8 child becomes retention-admissible;
4. no route, ponding or nonfinite-state failure occurs before that decision;
5. physical mass remains within the unchanged 5e-8 cm authority;
6. smooth TIMEINT16C second-order authority remains unchanged when subdivision is inactive.

If at least 3/5 first h/8 children remain inadmissible:

`NLGLOB13D_H8_ADMISSIBILITY_NOT_CONFIRMED`.

If coverage/origin identity fails:

`BLOCKED_NLGLOB13D_COVERAGE`.

Otherwise:

`NLGLOB13D_MIXED_H8_SIGNAL`.

## Consequence

A positive result supports bounded event-local temporal subdivision through h/8 as a research robustness mechanism.

It does not authorize deeper recursion.

A negative result closes simple subdivision-depth rescue for this line and requires a different temporal construction.

## Stop rules

Do not:

- execute h/16;
- add adaptive recursive subdivision;
- clip accepted moisture;
- relax physical or numerical tolerances;
- alter S0/R0;
- change route physics.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
