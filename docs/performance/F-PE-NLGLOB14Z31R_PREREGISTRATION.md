# F-PE-NLGLOB14Z31R preregistration — protocol-correct cumulative-drift attribution re-execution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a9bf62afd08b30087c3385709f94e4143d9de006`

Parent authority:

- Z30: `DRIVING_ADAPTIVE_DIVERGENCE`;
- Z31: `BLOCKED_Z31_PROTOCOL_EXECUTION_MISMATCH`;
- Z31 partial evidence is non-qualifying and may not be used to tune thresholds or physics.

## Purpose

Re-execute the frozen Z31 cumulative-drift attribution exactly as originally intended, correcting only the executable stop-contract mismatch discovered after Z31 result exposure.

This is a protocol repair, not a new scientific hypothesis and not a tolerance change.

## Frozen scientific contract

Reuse unchanged from Z31:

- O05 fine HEAD and RUNOFF fixtures;
- dt = 6.25e-5 d;
- exact 140 d checkpoint origin;
- independent full and adaptive trajectories;
- unchanged reduced moving-interface physics;
- unchanged dynamic-top and qbot semantics;
- horizon through 540 d;
- unchanged signed drift diagnostics;
- unchanged grouping by active dimension, tail identity, event/stable class and frozen time bins;
- unchanged drift-indicator thresholds and classifications.

## Corrected execution stop contract

The re-execution must continue through 540 d unless one of the **original Z31 physical blockers** occurs:

1. non-finite state;
2. reduced reconstruction failure;
3. nonlinear solve failure;
4. noncontiguous saturated tail;
5. ownership jump greater than one face;
6. adaptive per-interval physical ledger exceeds 5e-8 cm.

The runner must **not** stop on:

- cumulative adaptive/full mass difference;
- max h difference between trajectories;
- max theta difference between trajectories;
- top-flux difference between trajectories;
- same-nominal-step event-direction mismatch;
- event-time mismatch;
- final tail mismatch.

Those quantities are diagnostics only in Z31R.

## Event handling

Full and adaptive ownership events are recorded independently.

Event families are compared after execution by ordered direction and time.

A one-step or multi-step event-time offset is an attribution result, not an execution blocker, provided both trajectories remain physically valid under the frozen physical blockers.

## Frozen attribution classifications

Apply the original Z31 rules only after protocol-correct execution.

### `QUALIFIED_Z31R_SYSTEMATIC_SIGNED_BIAS`

Both fixtures satisfy the original Z31 SYSTEMATIC_SIGNED_BIAS criteria.

### `QUALIFIED_Z31R_ZERO_MEAN_NUMERICAL_ACCUMULATION`

Both fixtures satisfy the original Z31 ZERO_MEAN_NUMERICAL_ACCUMULATION criteria.

### `QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS`

Both fixtures satisfy the original Z31 REGIME_LOCALIZED_BIAS criterion:

>=80% of total signed drift attributable to one active dimension, tail regime, or event class while that class occupies <80% of intervals.

### `QUALIFIED_Z31R_MIXED_DRIFT_MECHANISM`

Use if the protocol-correct full-horizon evidence does not satisfy one common frozen mechanism class across both fixtures.

Physical execution blockers retain:

- `Z31R_RECONSTRUCTION_FAILURE`;
- `Z31R_SOLVE_FAILURE`;
- `Z31R_PHYSICAL_GATE_FAILURE`.

## Reporting requirements

For each fixture report:

- final time reached;
- full/adaptive final tail;
- event sequences and event-time offsets;
- signed final mass difference;
- threshold crossing times for |cumulative difference| >=5e-7 cm;
- work ratio;
- active-dimension histogram;
- by-dimension drift statistics;
- by-tail drift statistics;
- event versus stable drift;
- all six time-bin statistics;
- contribution of first chatter family;
- contribution around the later 13:16 -> 14:16 family.

## Stop rules

Do not:

- modify physical equations;
- tune the reduced-tail representation;
- alter dt or forcing;
- repair adaptive state from full;
- introduce mass redistribution;
- alter the original Z31 drift thresholds;
- reinterpret Z31 as qualified.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z31R

BASELINE: `3911fdb941d3c9c46673c4a487a82564b14edd40`

BRANCH: `research/f-pe-nlglob14z31r-drift-attribution-reexec`

NEXT SAFE STEP: materialize protocol-only runner correction and execute unchanged full/adaptive trajectories to 540 d.

## Production boundary

Research attribution only.

`LEGACY_NUMERICS` remains production default.
