# F-PE-NLGLOB10 preregistration — post-replay residual-failure decomposition

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@3fe1e5e6f908f819509f8c1b5ab7438b40267a37`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB08: `NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT`;
- NLGLOB09: `CLOSED_S0_REPLAY_INSUFFICIENT_RECOVERY`.

## Purpose

NLGLOB09 recovered 75/96 frozen dynamic-top trajectories with roundoff-scale physical mass closure.

The remaining 21 failures form two distinct populations:

- 14 later `ENDPOINT_SOLVE_FAILURE` cases after one or more successful S0 replay acceptances;
- 7 TG-only `PREDICTED_RETENTION_DOMAIN_FAILED` cases.

NLGLOB10 is observational only. It asks why these two populations remain and whether they share a mechanism.

No new solver behavior is introduced.

## Frozen bank and replay

Reuse the exact NLGLOB09 test-only S0 replay and 96-case bank unchanged.

No S0 threshold, mass threshold, timestep, K staging, MAXIT, backtracking or route rule is changed.

## Arm A — residual endpoint failures

For each of the 14 final endpoint failures, instrument the final failed HeadCalc solve and evaluate the NLGLOB07 ingredients at each post-backtracking iteration.

At the terminal iteration classify which S0 class prevents replay:

1. `A_GUARD_BALANCE`: balance/storage-floor guard not satisfied;
2. `A_GUARD_HEAD_POND`: head or ponding guard not satisfied;
3. `A_STATE_MOTION`: two-transition 32-ULP stationarity not satisfied;
4. `A_RENEWED_MOTION`: renewed-motion guard fails;
5. `A_ROUTE_STATE`: route/nonfinite continuity fails;
6. `A_OTHER`: none of the above.

Record route, material, mode, dt and terminal iteration.

Also report whether the failing terminal candidate is still within the physical mass-safe regime of the already completed preceding intervals.

## Arm B — TG predictor-domain failures

For each of the 7 `PREDICTED_RETENTION_DOMAIN_FAILED` trajectories record at the failing step:

- minimum and maximum predicted `theta_tilde`;
- material `theta_r` and `theta_s`;
- maximum normalized overshoot beyond either retention bound;
- accepted current-state min/max theta before prediction;
- accepted current state finite and in-domain;
- target route and dt.

Define normalized overshoot:

`O = max((theta_r-min(theta_tilde))/(theta_s-theta_r), (max(theta_tilde)-theta_s)/(theta_s-theta_r), 0)`.

No clipping or projection is allowed.

## Frozen interpretation

If Arm A terminal failures are predominantly (>75%) blocked by `A_STATE_MOTION` or `A_RENEWED_MOTION`, classify:

`NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_STATE_EVOLVING`.

If predominantly (>75%) blocked by balance/storage guard:

`NLGLOB10_POST_REPLAY_ENDPOINT_REMAINS_ABOVE_FLOOR`.

Otherwise:

`NLGLOB10_MIXED_POST_REPLAY_ENDPOINT_BLOCKER`.

For Arm B, if all accepted current states are finite/in-domain and all predictor failures arise only because `theta_tilde` crosses a retention bound, classify:

`NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT`.

If accepted current states are already invalid:

`NLGLOB10_TG_ACCEPTED_STATE_DOMAIN_DEFECT`.

If diagnostics/coverage fail:

`BLOCKED_NLGLOB10_DECOMPOSITION_COVERAGE`.

## Consequence

A result may open separate successors for Arm A and Arm B.

Do not combine a nonlinear endpoint repair with a TG predictor-domain repair unless the evidence shows a shared cause.

## Stop rules

No threshold tuning, clipping, timestep change, historical-K fallback, MAXIT increase, tolerance relaxation or production-source change in NLGLOB10.

## Production boundary

Research diagnostics only.

`LEGACY_NUMERICS` remains production default.
