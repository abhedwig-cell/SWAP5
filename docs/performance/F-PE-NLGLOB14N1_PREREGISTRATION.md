# F-PE-NLGLOB14N1 preregistration — fine-dt saturation-entry root-trial failure attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a6e4579a98b127eb95f271e855aafe9d1e394c80`

Parent authority:

- NLGLOB14M: `NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`;
- NLGLOB14N: `BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`.

## Purpose

NLGLOB14N showed positive refined retreat-event convergence for RUNOFF but could not evaluate the finest HEAD fixture because that trajectory terminated much earlier at saturation entry with:

`SATURATION_ROOT_TRIAL_OTHER_FAILED`.

NLGLOB14N1 attributes that single fine-dt saturation-entry failure.

This workunit is diagnostic only.

It does not change the saturation root, event bracket, timestep ladder, release event, solver policy or physical acceptance gates.

## Frozen target fixture

Use exactly:

- material: O05;
- mode: TG;
- wet-entry route: HEAD;
- dt: `7.8125e-6 d`;
- total horizon: `0.05 d`;
- unchanged forcing and complete dynamic-top research policy.

The expected failure location from NLGLOB14N is around step 82, before persistent saturated-mode entry.

## Frozen diagnostic question

Inside the existing NLGLOB14A saturation-root bisection, when a trial returns `trial_fail=.false.` but `eligible=.false.`, identify the exact underlying `terminal_reason` produced by `advance_tg_core` before NLGLOB14A replaces it by `SATURATION_ROOT_TRIAL_OTHER_FAILED`.

For that first failing root trial record:

- step;
- bisection iteration;
- phi_lo;
- phi_hi;
- phi_mid;
- trial_dt;
- underlying terminal_reason;
- last origin route;
- last predictor route;
- last endpoint route;
- last accepted route;
- solver status;
- state finiteness;
- physical mass diagnostics accumulated before the failed trial.

No classifier may depend on a post hoc numerical threshold.

## Frozen classifications

If the first failing trial is caused by an existing route-consistency terminal reason:

`NLGLOB14N1_ROOT_TRIAL_ROUTE_CONSISTENCY_FAILURE`.

If caused by an endpoint or nonlinear solve failure:

`NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE`.

If caused by predictor/ponding/constitutive admissibility:

`NLGLOB14N1_ROOT_TRIAL_PREDICTOR_OR_STATE_FAILURE`.

If the underlying reason cannot be recovered or diagnostics are inconsistent:

`NLGLOB14N1_ROOT_TRIAL_FAILURE_UNATTRIBUTED`.

If the target fixture no longer reproduces the blocker on the pinned postimage:

`NLGLOB14N1_BLOCKER_NOT_REPRODUCED`.

## Consequence

This workunit does not repair the blocker.

A follow-up repair is authorized only after the cause is attributed and separately preregistered.

The frozen NLGLOB14N convergence gate remains unchanged.

## Stop rules

Do not:

- modify root bisection behavior;
- alter route checks;
- change MAXIT, BALTOL, timestep or forcing;
- change the NLGLOB14N convergence threshold;
- change the retreat-event definition;
- switch temporal mode;
- infer release semantics.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

Expected effect: diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14N1

BASELINE: `a6e4579a98b127eb95f271e855aafe9d1e394c80`

BRANCH: `research/f-pe-nlglob14n1-fine-dt-entry-root-attribution`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: expose the underlying root-trial terminal reason for the single frozen finest HEAD fixture.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
