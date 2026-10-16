# F-PE-NLGLOB12B preregistration — bounded extra-iteration falsification

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Parent authority:

- NLGLOB09: physically clean S0 replay but incomplete recovery;
- NLGLOB10 Arm A: 14 residual endpoint failures remain above the S0 balance/storage guard;
- NLGLOB12: mixed split of those 14 into 8 `ABOVE_FLOOR_STAGNATION` and 6 `ABOVE_FLOOR_STILL_DESCENDING`.

## Purpose

NLGLOB12B tests only the six trajectories already classified, before this experiment, as still descending at the current nonlinear iteration budget.

The question is whether their residual failure is genuinely iteration-budget limited.

This is a falsification experiment, not a production MAXIT change.

## Frozen candidate

For the exact six NLGLOB12 `ABOVE_FLOOR_STILL_DESCENDING` trajectories:

- retain the NLGLOB09 test-only S0 replay unchanged;
- increase nonlinear `max_iterations` from 8 to exactly 16;
- retain `max_backtracking=8`;
- retain all balance, head and ponding tolerances;
- retain timestep, K staging, route physics and transaction semantics;
- introduce no new damping, trust-region, clipping or acceptance rule.

No other bank cases are used to decide the primary mechanism result.

## Frozen endpoints

For each of the six trajectories record:

1. whether the requested horizon completes;
2. whether S0 replay terminates any extended endpoint solve;
3. final terminal reason if incomplete;
4. nonlinear/backtracking work;
5. max accepted-interval physical ledger;
6. max cumulative physical ledger;
7. finite-state and route consistency.

## Frozen interpretation

If at least 5/6 trajectories complete with unchanged mass/state guards:

`NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_SUPPORTED`.

If 3/6 or fewer complete:

`NLGLOB12B_ITERATION_BUDGET_HYPOTHESIS_FALSIFIED`.

Otherwise:

`NLGLOB12B_MIXED_EXTRA_ITERATION_SIGNAL`.

Any physical mass or route/state failure classifies:

`NLGLOB12B_EXTRA_ITERATION_PHYSICAL_ADMISSIBILITY_FAILED`.

## Consequence

A positive result does not authorize a global production MAXIT increase.

It authorizes a separate design step asking whether a bounded-cost continuation policy can be applied only to a diagnosed still-descending endpoint trajectory.

A negative result sends those cases back to nonlinear-method attribution rather than iteration-budget policy.

## Stop rules

Do not test MAXIT 12, 24, 32 or adaptive iteration budgets inside NLGLOB12B.

Do not change tolerances, S0, timestep, K staging or backtracking.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12B

BASELINE: `e59f1b2ffd97fb210c9d682332e740a1552a9f46`

BRANCH: `research/f-pe-nlglob12b-extra-iteration-falsification`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize fixed MAXIT=16 in the six preclassified descending trajectories

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
