# F-PE-TIMEARCH13 preregistration — state-and-boundary-risk AUTO_REFERENCE discovery

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@3faa901ff99880d3c1b3f8747646e471e18644e4`

Parent authority:

- TIMEARCH09: DTMAX demoted to optional expert safety ceiling; DTMIN to internal retry floor;
- TIMEARCH10: LEGACY_NUMERICS/AUTO_REFERENCE configuration seam;
- TIMEARCH11: AUTO_REFERENCE controller interface;
- TIMEARCH12: effort-only controller rejected.

## Purpose

Discover an AUTO_REFERENCE controller that uses accepted-state evolution and cheap dynamic-top risk signals, without relying on soil/material/regime identifiers or a normal operating DTMAX.

Research-only. No parser or production activation.

## Accepted-state signal

After each committed accepted step compute:

`r_h = max_i ( |h_i(t1)-h_i(t0)| / max(10 cm, |h_i(t0)|) )`.

This is dimensionless and already showed useful performance signal in STATESTEP02.

Two frozen state targets:

- R20 = 0.20;
- R40 = 0.40.

Accepted-step preferred proposal:

`factor = clamp(sqrt(R / max(r_h,1e-12)),0.5,2.0)`

`dt_candidate = previous_preferred_dt * factor`.

If no previous preferred value is available, use executed accepted dt as the proposal base.

No normal operating maximum timestep is applied.

Initial internal preferred dt:

0.005 d.

## Boundary-risk signal

Maintain the accepted top-head rate from the most recent committed step:

`v_top = (h_top(t1)-h_top(t0))/dt_accepted`.

For the next candidate interval:

`h_top_linear = h_top(t1) + v_top * dt_candidate`.

Also evaluate the existing corrected dynamic-top provider cheaply at the accepted origin and candidate dt using fixed-K SWKIMPL=0 semantics.

Risk is TRUE when either:

1. origin-frozen dynamic-top prediction reports runoff potential; or
2. `h_top_linear` exceeds a frozen threshold.

Frozen linear-risk thresholds:

- H20 = -20 cm;
- H10 = -10 cm;
- H05 = -5 cm.

If risk is TRUE:

`dt_preferred = min(dt_candidate, dt_accepted)`.

That is, the controller may maintain or shrink but may not grow through a predicted surface-risk transition.

If risk is FALSE:

`dt_preferred = dt_candidate`.

## Candidate matrix

Six candidates:

- R20_H20
- R20_H10
- R20_H05
- R40_H20
- R40_H10
- R40_H05

No threshold or target is changed after exposure.

## Solver retry

On nonlinear failure:

- rollback to accepted origin;
- retry dt = max(internal_floor, attempted_dt/2);
- rejected trial does not update accepted-state history or preferred memory;
- internal floor = 0.001 d for this discovery harness.

No user DTMIN is required by the candidate.

## Hard events

The horizon end is the only hard event in the BOFEK calibration harness.

Candidate preferred dt is clipped only to remaining horizon.

No user DTMAX is applied.

## Comparator

Current corrected LEGACY_NUMERICS trajectory.

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

P-C1 gates remain unchanged:

- runoff difference <=0.01 cm when baseline runoff <1 cm, otherwise <=1%;
- terminal storage difference <=max(0.01 cm,0.5% baseline storage);
- terminal ponding difference <=0.02 cm;
- top/mid/bottom head difference <=2 cm;
- max ledger <=5e-8 cm;
- no terminal failure;
- retry pathology forbidden.

## Advancement

A candidate advances only if all are true:

1. >=15/16 P-C1 pass;
2. every WET/POND case passes;
3. median deterministic work reduction >=15%;
4. no hydrologic regime has median work regression >5%;
5. retry work fraction does not exceed LEGACY_NUMERICS by more than 5 percentage points.

Select highest median deterministic work reduction. Tie-break tighter boundary threshold, then lower R.

If none advances, close this candidate family and do not rescue it post hoc.

If one advances, freeze it before constructing a new validation bank.

## Production boundary

No production timestep behavior change.
