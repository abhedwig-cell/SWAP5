# F-PE-TIMEARCH02 preregistration — executable timestep decision contracts

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@79dde9d93fe17dd686ba9902eca2bd0ab0d2f26b`

Parent:

F-PE-TIMEARCH01 — `QUALIFIED_TIMESTEP_ARCHITECTURE_REDESIGN`.

## Purpose

Materialize the first executable proof of the redesigned ownership model without changing production TimeControl semantics.

TIMEARCH02 does not select a new adaptive algorithm.

It proves that the current legacy behavior can be decomposed into typed decisions while preserving the existing formulas.

## Test-only contracts

Define test-only pure contracts for:

1. accepted-step proposal;
2. hard event clipping;
3. solver retry;
4. day-start compatibility floor;
5. final executable interval composition;
6. typed provenance/reason codes.

## Legacy compatibility formulas

### Accepted-step proposal

For `swsolve=1`:

- if `numbit <= NUMBIT_CRIT`:
  - preferred dt = min(dt * FACT_DT_INCREASE, DTMAX);
- if `numbit >= MAXIT`:
  - preferred dt = max(current preferred dt * FACT_DT_DECREASE, DTMIN);
- otherwise dt is unchanged.

The ordering follows current TimeControl source.

### Solver failure retry

If retry requested:

- if `dt > FACT_DT_FLDECT * DTMIN`:
  - retry dt = dt / FACT_DT_FLDECT;
- otherwise:
  - retry dt = DTMIN;
  - floor reached = true.

### Event clipping

Executable dt:

`min(preferred_dt, hard_event_remaining, external_interval_remaining when active)`.

The event layer may only reduce the proposed interval.

### Day-start compatibility

Legacy-compatible day-start floor:

`dt = max(dt, sqrt(DTMIN*DTMAX))`

before hard-event clipping.

This is represented as a compatibility profile decision, not as a universal numerical rule.

## Reason codes

At minimum:

- `KEEP`;
- `GROW_LOW_ITER`;
- `SHRINK_MAX_ITER`;
- `GROW_THEN_SHRINK`;
- `SOLVER_RETRY`;
- `SOLVER_RETRY_FLOOR`;
- `DAYSTART_COMPAT_FLOOR`;
- `HARD_EVENT_CLAMP`;
- `EXTERNAL_INTERVAL_CLAMP`;
- `SAFETY_FLOOR`;
- `SAFETY_CEILING`.

## Source binding

A Python source guard must verify that canonical TimeControl still contains the exact controlling source patterns used by the compatibility contract:

- accepted-step growth/shrink conditions;
- failure reduction formula;
- day-start floor;
- event min-clipping;
- initialization mutation of dtmax/dtmin.

If any guarded source changes, TIMEARCH02 must fail rather than silently claim compatibility.

## Executable decision matrix

Test at least:

- low-iteration growth;
- neutral accepted step;
- MAXIT shrink;
- simultaneous low-iteration/MAXIT edge configuration;
- dtmax ceiling;
- dtmin floor;
- solver retry above floor;
- solver retry at floor;
- day-start floor below geometric mean;
- no day-start change above geometric mean;
- hard-event clamp;
- external interval clamp;
- event clamp after growth;
- retry reason does not mutate accepted-step proposal history.

## Shadow-controller seam

The contract must expose a separate `preferred_dt` and `executed_dt`.

This is required so a future shadow controller can propose an interval while the current compatibility controller still determines actual execution.

No shadow proposal may affect the accepted trajectory in TIMEARCH02.

## Advancement

TIMEARCH02 advances only if:

1. source guard passes against current canonical;
2. O0 and O2 test builds pass;
3. all legacy-compatibility decision matrix cases pass exactly;
4. reason provenance is deterministic;
5. proposal and event/retry ownership remain structurally separate.

## Production boundary

No production `src/**` changes in TIMEARCH02.

Possible outcomes:

- `QUALIFIED_EXECUTABLE_TIMESTEP_DECISION_CONTRACTS`;
- `BLOCKED_LEGACY_COMPATIBILITY_NOT_REPRODUCED`.
