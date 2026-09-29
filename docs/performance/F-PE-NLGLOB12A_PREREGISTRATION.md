# F-PE-NLGLOB12A preregistration — aggregate storage-representation floor attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Parent authority:

- NLGLOB12: `NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`;
- stagnation subset: 8 trajectories classified `ABOVE_FLOOR_STAGNATION`;
- NLGLOB04: storage-representation floor identified at node level;
- BALTOL02 authority remains unchanged.

## Purpose

NLGLOB12A asks whether the eight above-floor stagnation cases are globally blocked only because the total balance residual is being compared with a fixed scalar tolerance that lies below the aggregate representational resolution of the compartment storage differences.

This is observational only.

No convergence decision is changed.

## Frozen subset

Use exactly the 8 NLGLOB12 stagnation trajectories.

No case selection changes after result exposure.

## Aggregate storage representation scale

For every Newton iteration and active node i define the existing NLGLOB04 storage representation rate scale:

`U_i = (ulp(theta_i) + ulp(theta_m1_i)) * f_i * dz_i / dt`.

Define:

`U_total = sum_i |U_i|`.

Define the normalized aggregate total-residual ratio:

`R_total_ulp = |sum_i R_i| / max(U_total,tiny)`.

Define the maximum local storage-floor ratio:

`R_local_ulp = max_i |R_i| / max(|U_i|,tiny)`.

These diagnostics are representation bounds, not new physical tolerances.

## Frozen question

At terminal stagnation, are the residuals already bounded by the arithmetic representation scale implied by the stored theta differences?

## Frozen gates

Classify:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`

only if all hold:

1. all 8 stagnation trajectories reproduced;
2. all terminal states finite and route-consistent;
3. terminal `R_total_ulp <= 1` in at least 7/8 cases;
4. terminal `R_local_ulp <= 1` in at least 7/8 cases;
5. existing head and ponding guards pass in those same cases;
6. no physical or solver threshold is changed;
7. no residual is recomputed from storage-derived external flux.

If fewer than 4/8 satisfy both representation bounds:

`NLGLOB12A_AGGREGATE_STORAGE_FLOOR_NOT_SUPPORTED`.

Otherwise:

`NLGLOB12A_MIXED_AGGREGATE_STORAGE_FLOOR`.

## Consequence

A positive result may justify a separately preregistered representation-aware convergence certificate whose bound is derived from the arithmetic state representation rather than an empirically relaxed balance tolerance.

It does not itself authorize acceptance.

## Stop rules

Do not tune the factor 1 representation bound.

Do not change BALTOL02.

Do not introduce a new scalar floor from observed outcomes.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
