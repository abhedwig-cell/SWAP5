# F-PE-KIMPL-DYNTOP01 preregistration — fully implicit dynamic-top nonlinear-path attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_TRACE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@199566655db5b13483194e16bb81a154f6fc2547`

Parent:

F-PE-TIMEINT12A.

## Trigger

TIMEINT12A showed that fully implicit BE with the qualified dynamic-top derivative completes only 6/12 MOIST/WET/POND cases.

This workunit does not change timestep policy, tolerances, MAXIT or physics.

## Primary trace cases

- B01/WET;
- O14/WET.

Comparator:

- same case with SWKIMPL=0 lagged-K at identical fixed dt=0.005 d.

## Trace objective

Identify the earliest KIMPL failing step and compare its nonlinear path against:

1. the previous successful KIMPL step;
2. the corresponding KLAG step.

Record per Newton iteration:

- residual quadratic norm;
- max local residual;
- scalar total-balance residual;
- max Newton update;
- line-search/backtracking factor;
- head extrema;
- capacity extrema;
- conductivity extrema;
- dynamic-top route at the accepted origin/final candidate;
- nonlinear iteration and linear solve counts.

## Frozen attribution classes

Classify the first failure as one of:

- `BALANCE_FLOOR_STALL`:
  physical/Newton residual and updates collapse to representation scale while only total balance remains above tolerance;
- `LINE_SEARCH_FAILURE`:
  repeated factor reduction with no accepted progress;
- `NEWTON_DIVERGENCE`:
  residual/update magnitude grows or fails to contract materially;
- `BOUNDARY_ROUTE_OSCILLATION`:
  dynamic-top route changes repeatedly across Newton candidates;
- `JACOBIAN_INCONSISTENCY_SUSPECTED`:
  updates/residual show systematic noncontraction without line-search or balance-floor explanation;
- `OTHER_<evidence>`.

No repair is allowed until attribution is recorded.

## Production boundary

Observation only. No `src/**` change.
