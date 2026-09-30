# F-PE-NLGLOB14Z30 preregistration — trajectory-driving adaptive manager A/B benchmark

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a3af828f442da7665615b222a0d3a7e5e614ac53`

Parent authority:

- Z29: `QUALIFIED_Z29_REDUCED_PHYSICAL_BINDING`;
- all 70 frozen event/control intervals physically equivalent under observer-only reduced candidates;
- reduced dimensions n=12..14 versus full n=16;
- normalized deterministic probe work about 0.82–0.83 on average.

## Purpose

Let the reduced variable-dimension moving-interface solver become the trajectory-driving candidate for the first time, while running a full-column reference trajectory independently from the same accepted origin.

This is the decisive research A/B benchmark toward a working SWAP Heritage timestep manager.

## Frozen fixtures

Use exactly the fine O05 fixtures:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

Use the same constitutive, forcing, dynamic-top and qbot=0 semantics as Z22/Z29.

## Frozen origin and horizon

Use the exact Z22/Z29 segment-A checkpoint at 140 d.

From that checkpoint, run two independent trajectories to 540 d:

### A — full reference

Use unchanged Z29/Z22 full-column solve semantics.

### B — adaptive manager

At every accepted interval:

1. derive the contiguous lower saturated tail from the adaptive accepted state;
2. if a valid tail exists, use the Z29 reduced guard-node solve;
3. if no valid contiguous tail exists, fail closed in Z30 rather than silently falling back;
4. publish the reduced candidate as the adaptive accepted state;
5. derive next ownership from that accepted state only.

No full-reference state may overwrite or repair the adaptive trajectory.

## Parallel-reference rule

The full trajectory and adaptive trajectory start from byte-identical h/theta state and evolve independently.

The full trajectory is observational authority only.

No per-step nudging, synchronization, clipping or state replacement is allowed.

## Frozen comparison diagnostics

At every nominal interval record or accumulate:

- max absolute h difference;
- max absolute theta difference;
- ponding difference;
- top-flux difference;
- physical ledger difference;
- full and adaptive saturated-tail identity;
- ownership direction changes;
- provider route;
- full and reduced nonlinear iterations;
- full and reduced algebra dimension;
- normalized probe work;
- cumulative normalized probe work.

At every ownership event retain exact event time and direction for both trajectories.

## Frozen hard gates

Adaptive trajectory qualifies only if through 540 d:

- both trajectories complete;
- all states finite;
- adaptive physical ledger remains <= 5e-8 cm per interval;
- rollback leakage remains zero;
- provider route remains valid;
- saturated tail remains contiguous;
- adaptive ownership changes remain one-face;
- max theta divergence <= 5e-8;
- max pressure-head divergence <= 5e-5 cm;
- max ponding divergence <= 5e-8 cm;
- max top-flux divergence <= 5e-8 cm/day;
- cumulative mass difference <= 5e-7 cm;
- final saturated-tail identity matches;
- no event-direction contradiction occurs.

These are A/B comparison gates, not new production acceptance tolerances.

## Event timing comparison

Do not force exact event-time equality.

Record matched event-time differences for the established:

- first reverse / local chatter family;
- later 13:16 -> 14:16 retreat family.

The adaptive event sequence must have the same ordered physical directions and one-face geometry.

## Frozen performance diagnostics

Primary work metric:

`sum(iterations * algebra_dimension)`

for each trajectory.

Report:

- cumulative adaptive/full work ratio;
- work ratio by ownership regime;
- fraction of intervals by active dimension;
- count of reduced dimensions;
- mean active dimension.

Secondary timing:

wall-clock duration of the Python research trajectories may be recorded, but it is secondary because this is not production Fortran execution.

## Frozen classifications

### DRIVING_ADAPTIVE_TRAJECTORY_QUALIFIED

Require every hard gate above.

### DRIVING_ADAPTIVE_DIVERGENCE

Both routes solve, but A/B physical divergence exceeds one or more frozen gates.

### DRIVING_ADAPTIVE_EVENT_SEQUENCE_DIVERGENCE

Ordered ownership directions or one-face event geometry differ.

### DRIVING_ADAPTIVE_RECONSTRUCTION_FAILURE

Reduced tail reconstruction becomes unavailable/inconsistent while the full reference remains valid.

### DRIVING_ADAPTIVE_SOLVE_FAILURE

Reduced nonlinear solve fails while full reference remains valid.

### REFERENCE_FAILURE

Full reference itself fails a frozen physical gate.

Frozen positive aggregate:

`QUALIFIED_Z30_DRIVING_ADAPTIVE_MANAGER_AB`.

## Positive consequence

A positive Z30 result authorizes:

1. production-shaped Fortran manager integration;
2. broader fixture/profile qualification;
3. end-to-end runtime benchmarking versus legacy;
4. eventual production-admission candidate workunit.

## Stop rules

Do not:

- repair adaptive state from the full trajectory;
- add hysteresis/dwell;
- relax comparison gates after exposure;
- fall back silently to full dimension;
- alter dt or forcing;
- reinterpret full reference as adaptive accepted state;
- change production defaults.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z30

BASELINE: `48cb028e0f1295e43b8b59cd3214bf5e7abe788d`

BRANCH: `research/f-pe-nlglob14z30-driving-manager-ab`

NEXT SAFE STEP: materialize independent full and adaptive trajectories from the 140 d checkpoint and run the fine HEAD/RUNOFF A/B qualification to 540 d.

## Production boundary

Research A/B only.

`LEGACY_NUMERICS` remains production default.
