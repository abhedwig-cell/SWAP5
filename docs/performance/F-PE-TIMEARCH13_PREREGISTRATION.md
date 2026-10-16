# F-PE-TIMEARCH13 preregistration — look-ahead boundary-risk AUTO_REFERENCE controller

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@3faa901ff99880d3c1b3f8747646e471e18644e4`

Parent authority:

- TIMEARCH01-11: timestep architecture and AUTO_REFERENCE interface qualified;
- TIMEARCH12: effort-only automatic controller rejected;
- STATESTEP02: normalized accepted-state head movement showed large performance signal but insufficient wet-transition prediction;
- DYNERR01: dynamic-top temporal defect indicator failed across regime-path transitions.

## Purpose

Test whether a cheap look-ahead boundary-risk predictor can make the promising state-change controller robust without reintroducing soil/regime lookup tables or a normal operating DTMAX.

Research-only. No production activation.

## Base state-change proposal

After accepted step k compute:

`r_h = max_i(|h_i(k)-h_i(k-1)| / max(10 cm, |h_i(k-1)|))`

with frozen target:

`R = 0.40`.

Base proposal:

`f = clamp(sqrt(R/max(r_h,1e-12)),0.5,2.0)`

`dt_raw = preferred_dt_previous * f`

No normal operating maximum timestep is applied.

The simulation horizon / hard event boundary may clip execution.

Internal retry floor remains 0.001 d in the discovery harness.

Rejected attempts do not update accepted controller history.

## Cheap boundary-risk predictor

Use the already corrected dynamic-top boundary provider with SWKIMPL=0 fixed top conductivity.

Two predictor states are frozen:

### ORIGIN

Evaluate the next proposed interval at the accepted current top pressure head.

### LINEAR_LOOKAHEAD

Estimate next-step top head from accepted history:

`h_top_pred = h_top(k) + (h_top(k)-h_top(k-1))/dt_k * dt_raw`.

Evaluate the dynamic-top boundary provider for `dt_raw` using:

- predicted top pressure head;
- current accepted top water content;
- current accepted ponding depth;
- current forcing;
- current fixed top-node conductivity.

If the provider is unavailable/nonfinite, classify as RISK.

Boundary is classified RISK when the predicted result:

- is head-regime; or
- has runoff_potential=true.

Otherwise it is SAFE.

No material/regime identifiers are used.

## Risk response

Two responses are frozen:

### HOLD

If RISK:

`dt_next = min(dt_raw, dt_k)`.

Thus a risky prediction may prevent growth but does not force shrinkage.

### HALF

If RISK:

`dt_next = min(dt_raw, max(retry_floor,0.5*dt_k))`.

Thus a risky prediction forces one conservative shrink.

Candidate matrix:

- ORIGIN_HOLD
- ORIGIN_HALF
- LINEAR_HOLD
- LINEAR_HALF

## Bootstrap

Internal initial preferred dt:

0.005 d.

Not user input.

## Failure recovery

On nonlinear failure:

- rollback;
- retry duration = max(retry_floor, attempted_dt/2);
- accepted controller history remains unchanged;
- fail if retry at floor still does not converge.

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

Comparator:

LEGACY_NUMERICS on current corrected Reference route.

P-C1 gates remain unchanged.

## Advancement

Candidate advances only if:

1. >=15/16 P-C1 pass;
2. all WET/POND cases pass;
3. median deterministic work reduction >=15%;
4. no hydrologic regime has median work regression >5%;
5. retry-work fraction is no more than 5 percentage points above LEGACY_NUMERICS;
6. no material/regime identifiers enter the controller.

Selection:
- highest median deterministic work reduction;
- tie-break LINEAR over ORIGIN;
- tie-break HOLD over HALF.

If no candidate advances, close this risk-predictor family.

If one advances, freeze it before any unexposed validation bank is created.

## Production boundary

No production controller activation or parser change.
