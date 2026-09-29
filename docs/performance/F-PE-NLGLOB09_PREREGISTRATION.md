# F-PE-NLGLOB09 preregistration — S0 test-only endpoint replay and physical admissibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@64f477f16eef5f87f52cdcc0615b1d0ae7b48375`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB07: `NLGLOB07_STATE_STATIONARITY_NONSPECIFIC`;
- NLGLOB08: `NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT`.

## Purpose

NLGLOB09 performs the first test-only replay authorized by the positive NLGLOB08 tail-inertness result.

The replay asks whether returning the current endpoint candidate once the unchanged NLGLOB07 S0 state-stationarity condition is satisfied can recover the frozen dynamic-top endpoint bank without violating the unchanged physical mass and state contracts.

This is not production admission.

## Replay seam

The replay is injected only into a materialized test-only HeadCalc source.

Production `src/**` remains unchanged.

The replay may return from HeadCalc before the normal nonconvergence reset/retry path only if the preregistered S0 certificate is true.

The adapter then observes:

- no `fldecdt`;
- no `request_dt_reduction`;

and therefore exposes the candidate as `SW_SOLVE_CONVERGED`.

The replay must emit an explicit diagnostic:

`F_PE_NLGLOB09_ACCEPT|REASON=S0_STATE_STATIONARITY`.

## Frozen S0 rule

Reuse NLGLOB07 unchanged.

At current iteration k, S0 requires:

1. current physical/numerical guard:
   - `r_bal <= 10`;
   - `r_storage_ulp <= 10`;
   - existing head-update contract `r_head <= 1`;
   - ponding contract satisfied when applicable;
   - finite diagnostics;
   - provider route equals the frozen fixture route;
2. two consecutive moisture-state transitions k-2 -> k-1 and k-1 -> k satisfy:
   - `D_theta_inf <= 32`;
   - `D_S <= 32`;
3. renewed-motion guard:
   - `D_S(k) <= 2 * max(D_S(k-1),1)`;
4. route/state continuity across the three-state window.

No S0 threshold is changed.

## Frozen bank

Reuse the exact 96-case TIMEINT17 A2 / NLGLOB08 bank:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- TG and matched KLAG;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.001 d;
- unchanged dynamic-top provider;
- unchanged current-step K staging;
- unchanged BALTOL02;
- unchanged head and ponding tolerances;
- unchanged MAXIT and MaxBackTr.

## Frozen replay guards

An S0 replay acceptance is admissible only if:

1. S0 is true;
2. all candidate state values are finite;
3. the intended dynamic-top route remains unchanged;
4. existing head and ponding guards used inside S0 pass;
5. no solver threshold has been relaxed;
6. no extra Newton iteration or backtracking factor is added.

Physical accepted-interval and cumulative mass remain evaluated by the existing TIMEINT17 test driver after replay.

## Frozen qualification gates

Classify:

`QUALIFIED_S0_ENDPOINT_REPLAY_RESEARCH`

only if all hold:

1. complete 96-case bank;
2. at least 80% of previously failing endpoint trajectories complete the requested horizon;
3. recovered trajectories include TG and KLAG;
4. recovered trajectories include FLUX, HEAD and RUNOFF;
5. recovered trajectories include at least 3 materials;
6. max absolute accepted-interval physical ledger <= `5e-8 cm`;
7. max absolute cumulative physical ledger <= `5e-8 cm`;
8. no nonfinite accepted state;
9. no newly accepted route mismatch;
10. all replay acceptances are explicitly diagnosed as S0 state-stationarity;
11. accepted replay states remain within `5e-8 cm` volume-weighted absolute moisture distance of the corresponding later canonical terminal candidate as established by NLGLOB08;
12. replay does not increase deterministic Newton/backtracking work relative to the unreplayed failing trajectory.

If physical mass fails:

`CLOSED_S0_REPLAY_PHYSICAL_MASS_FAILED`.

If any route/nonfinite unsafe state is accepted:

`CLOSED_S0_REPLAY_STATE_UNSAFE`.

If recovery fraction is below 80% while safety gates pass:

`CLOSED_S0_REPLAY_INSUFFICIENT_RECOVERY`.

If instrumentation cannot implement the unchanged S0 semantics faithfully:

`BLOCKED_S0_REPLAY_IMPLEMENTATION`.

## Positive consequence

A positive NLGLOB09 result removes the endpoint-globalization blocker for the frozen same-route dynamic-top bank at research level.

It authorizes returning to TIMEINT17 same-route dynamic-top mechanism qualification using the qualified replay rule as research numerical policy.

It does not yet authorize production convergence changes.

## Stop rules

Do not:

- alter S0;
- loosen mass, head or ponding gates;
- increase MAXIT or backtracking;
- add new damping/trust-region logic;
- change dt or K staging;
- accept a state from storage-derived external flux reconstruction.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

Expected effect: test-only numerical-policy replay with unchanged physics and mass authority.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB09

BASELINE: `64f477f16eef5f87f52cdcc0615b1d0ae7b48375`

BRANCH: `research/f-pe-nlglob09-s0-replay`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize test-only S0 terminal-return seam and execute frozen replay bank

RECOVERY POINT: this preregistration commit

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
