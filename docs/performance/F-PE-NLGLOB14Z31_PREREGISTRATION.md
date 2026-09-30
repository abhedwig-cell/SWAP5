# F-PE-NLGLOB14Z31 preregistration — adaptive cumulative-drift attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@38b78b3415cee0563eb19efa68b73a6082b3c899`

Parent authority:

- Z30: `DRIVING_ADAPTIVE_DIVERGENCE`;
- independent adaptive/full trajectories remain locally equivalent for >2.1 million intervals;
- only the preregistered cumulative adaptive/full mass-difference gate `5e-7 cm` is exceeded first;
- deterministic adaptive/full work ratio is about 0.76.

## Purpose

Determine whether the Z30 cumulative mass-difference growth is a systematic physical bias in the reduced moving-interface representation or accumulation of numerically tiny interval differences.

Z31 is attribution only. It does not alter Z30 tolerances and does not authorize production admission.

## Frozen fixtures

Reuse exactly the Z30 fine O05 fixtures:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

Use the exact 140 d checkpoint origin and unchanged full/adaptive solver semantics.

## Frozen execution horizon

Run both independent trajectories from 140 d through 540 d unless one of these hard physical blockers occurs:

- non-finite state;
- reduced reconstruction failure;
- nonlinear solve failure;
- noncontiguous saturated tail;
- ownership jump > 1 face;
- per-interval physical ledger > 5e-8 cm.

The Z30 cumulative-difference threshold `5e-7 cm` is **not** a Z31 stop condition; instead record every threshold crossing and continue for attribution.

This does not retroactively reclassify Z30.

## Frozen attribution diagnostics

For every accepted interval derive:

- signed interval mass difference:
  `delta_m = adaptive_ledger - full_ledger`;
- cumulative signed mass difference;
- absolute cumulative mass difference;
- adaptive active dimension;
- current saturated-tail identity;
- whether ownership changed;
- event direction if changed;
- h/theta/top-flux differences.

Aggregate by:

1. active dimension;
2. ownership regime / tail identity;
3. event versus stable intervals;
4. time bins:
   - 140–200 d;
   - 200–260 d;
   - 260–320 d;
   - 320–400 d;
   - 400–480 d;
   - 480–540 d.

For each group report:

- interval count;
- sum(delta_m);
- mean(delta_m);
- min/max(delta_m);
- positive/negative/zero counts;
- RMS(delta_m);
- start/end cumulative mass difference.

## Frozen drift indicators

### SYSTEMATIC_SIGNED_BIAS

Require both fixtures to show:

- same dominant sign in stable intervals;
- absolute mean signed `delta_m` >= 25% of RMS `delta_m`;
- cumulative signed difference grows predominantly in that same sign across >=4/6 time bins.

### ZERO_MEAN_NUMERICAL_ACCUMULATION

Require both fixtures to show:

- positive and negative interval differences both materially present;
- absolute mean signed `delta_m` < 10% of RMS;
- no same-sign growth across >=4/6 time bins.

### REGIME_LOCALIZED_BIAS

Require >=80% of total signed drift to be attributable to one active dimension, tail regime, or event class while that class occupies <80% of intervals.

### MIXED_DRIFT_MECHANISM

Use if no frozen class above applies.

## Event attribution

For the first chatter family and later 13:16 -> 14:16 transition family, report:

- cumulative mass difference immediately before event family;
- cumulative mass difference immediately after settlement;
- net event-family contribution;
- subsequent stable-regime contribution.

Do not modify event semantics.

## Frozen classifications

Positive attribution classifications are descriptive, not admission:

- `QUALIFIED_Z31_SYSTEMATIC_SIGNED_BIAS`;
- `QUALIFIED_Z31_ZERO_MEAN_NUMERICAL_ACCUMULATION`;
- `QUALIFIED_Z31_REGIME_LOCALIZED_BIAS`;
- `QUALIFIED_Z31_MIXED_DRIFT_MECHANISM`.

Any physical blocker becomes:

- `Z31_RECONSTRUCTION_FAILURE`;
- `Z31_SOLVE_FAILURE`;
- `Z31_PHYSICAL_GATE_FAILURE`.

## Consequence rules

If systematic signed bias:

- localize the reduced-tail equation responsible before any production benchmark continuation.

If zero-mean accumulation:

- preserve Z30 negative classification;
- next test should quantify physically meaningful long-horizon state/mass envelopes without tuning against one fixture.

If regime-localized bias:

- target only the implicated regime.

If mixed:

- keep research-only and isolate the largest contributor.

## Stop rules

Do not:

- relax or reinterpret the Z30 `5e-7 cm` gate;
- repair adaptive state from full;
- add mass redistribution;
- add hysteresis/dwell;
- fit a correction coefficient;
- alter dt or forcing.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z31

BASELINE: `f3e597e50f5a1e2a158d98f4edbc071f64aa1e99`

BRANCH: `research/f-pe-nlglob14z31-drift-attribution`

NEXT SAFE STEP: execute unchanged dual trajectories to 540 d with signed drift attribution.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
