# F-PE-TIMEARCH06 preregistration — production decision-service extraction

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b372305b21012318175b973680f1204e7c5e8dd0`

Parents:

- TIMEARCH01 — timestep architecture redesign qualified;
- TIMEARCH02 — executable legacy-compatible decision contracts qualified;
- TIMEARCH03 — timestep attribution qualified;
- TIMEARCH04 — scheduler separation target qualified;
- TIMEARCH05 — retry ownership hierarchy qualified.

## Purpose

Perform the first production-shaped structural extraction of timestep decision ownership without changing timestep semantics.

This workunit does not introduce a new adaptive controller.

It extracts only formulas that are already qualified as exact legacy compatibility rules.

## Candidate production service

Introduce an explicit pure decision service owning:

1. accepted-step proposal;
2. solver-failure retry.

The service must not own:

- hard event clipping;
- calendar/day flags;
- output scheduling;
- meteo/rain/runon events;
- irrigation/interception events;
- transaction retry;
- temporal acceptance;
- process-state mutation.

## Exact accepted-step semantics

For `swsolve=1`:

Starting from input dt:

1. if `numbit <= NUMBIT_CRIT`:
   `dt = min(dt * FACT_DT_INCREASE, DTMAX)`;
2. if `numbit >= MAXIT`:
   `dt = max(dt * FACT_DT_DECREASE, DTMIN)`;
3. if the result is below DTMIN:
   - set dt=DTMIN;
   - report floor reached.

Ordering must remain exactly as current TimeControl.

For `swsolve != 1`, TimeControl retains its existing fixed one-day behavior and does not use the service.

## Exact solver-retry semantics

When `fldecdt` is true:

- if `dt > FACT_DT_FLDECT * DTMIN`:
  `dt = dt / FACT_DT_FLDECT`;
- else:
  `dt = DTMIN`;
  floor reached = true.

The service does not clear `fldecdt`; TimeControl remains owner of legacy mutable flags during this migration step.

## Provenance

The service returns typed reason codes:

- KEEP;
- GROW_LOW_ITER;
- SHRINK_MAX_ITER;
- GROW_THEN_SHRINK;
- SOLVER_RETRY;
- SOLVER_RETRY_FLOOR.

TIMEARCH06 does not yet publish those reasons from production runtime. They are available for later decision tracing.

## Source-scope rule

Permitted production changes:

- one new timestep decision-service module;
- minimal `use` binding in TimeControl;
- replacement of only the accepted-step proposal arithmetic and solver-retry arithmetic by service calls.

No other production source change is allowed.

## Exactness gates

### Gate A — direct decision identity

The new production service must reproduce the already qualified TIMEARCH02 matrix exactly at O0 and O2.

### Gate B — source scope

A source guard must prove:

- legacy event scheduler code is unchanged;
- day-start compatibility floor is unchanged;
- initialization DTMIN/DTMAX mutation is unchanged;
- process-specific clamps are unchanged;
- only the two preregistered arithmetic blocks are replaced.

### Gate C — BOFEK Reference preservation

Run the existing 20-case Reference/trace authority or an equivalent current canonical preservation harness.

Require exact integer identity for:

- accepted steps;
- rejected attempts;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves.

Require scale-aware 1e-12 preservation for:

- runoff;
- terminal top/mid/bottom head;
- ponding;
- storage;
- ledger residual.

### Gate D — relevant existing CI

Run at minimum the current TIMEARCH02 compatibility contract and BOFEK00 wet-regime preservation path.

## Decision

If all gates pass, candidate status:

`QUALIFIED_PRODUCTION_DECISION_SERVICE_EXTRACTION`.

Production admission may occur in this same workunit only if:

- branch is current with canonical before final write;
- no unrelated production source changed;
- all required preservation CI is green.

No new timestep algorithm or user-input change is permitted here.
