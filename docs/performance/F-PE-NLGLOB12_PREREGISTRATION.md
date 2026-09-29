# F-PE-NLGLOB12 preregistration — above-floor endpoint robustness attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB09: S0 replay physically clean but incomplete;
- NLGLOB10 Arm A: `NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_ABOVE_FLOOR`.

## Purpose

NLGLOB12 isolates the 14 post-replay endpoint failures that remain above the balance/storage-floor guard.

These states are not authorized for S0 acceptance.

The first phase is observational only and asks what prevents these endpoint solves from descending into the already qualified floor neighborhood.

No solver behavior is changed.

## Frozen bank

Reuse exactly the 14 NLGLOB10 Arm-A trajectories under the NLGLOB09 S0 replay.

No case selection is changed after result exposure.

## Frozen diagnostics

For each failed endpoint solve record, by Newton iteration:

1. `r_bal`, `r_cp`, `r_tot`;
2. `r_storage_ulp`;
3. normalized head update;
4. selected and full-step rho;
5. selected backtracking factor;
6. composite merit;
7. maximum raw and normalized head correction;
8. maximum residual node and correction node;
9. route and material;
10. iteration-to-iteration ratios in `r_bal` and correction magnitude.

At the terminal iteration classify the trajectory into one of these mutually exclusive mechanism classes.

### A — monotone descent, iteration budget exhausted

Require:
- terminal `r_bal > 10`;
- at least 5 of the last 7 available iteration transitions reduce `r_bal`;
- geometric mean reduction ratio over those transitions < 0.8;
- no nonfinite or route change.

Classification:

`ABOVE_FLOOR_STILL_DESCENDING`.

### B — above-floor stagnation

Require:
- terminal `r_bal > 10`;
- final three `r_bal` values vary by less than factor 2;
- final three normalized head corrections are each <=1e-8;
- no nonfinite or route change.

Classification:

`ABOVE_FLOOR_STAGNATION`.

### C — oscillatory / poor-model endpoint

Require:
- terminal `r_bal > 10`;
- at least 2 of the final 4 full-step rho values are negative, or `r_bal` alternates increase/decrease at least twice in the final four transitions.

Classification:

`ABOVE_FLOOR_POOR_MODEL_OSCILLATION`.

### D — other

`ABOVE_FLOOR_OTHER`.

Precedence is A, then B, then C, then D.

## Frozen interpretation

If >=75% classify A:

`NLGLOB12_ITERATION_BUDGET_LIMITED_DESCENT`.

If >=75% classify B:

`NLGLOB12_ABOVE_FLOOR_STAGNATION`.

If >=75% classify C:

`NLGLOB12_ABOVE_FLOOR_POOR_MODEL_OSCILLATION`.

Otherwise:

`NLGLOB12_MIXED_ABOVE_FLOOR_ENDPOINT`.

## Consequence

This attribution may justify a separately preregistered repair, but NLGLOB12 itself does not authorize:

- increasing MAXIT;
- changing tolerances;
- accepting above-floor states;
- changing line search/trust-region behavior;
- changing timestep or K staging.

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
