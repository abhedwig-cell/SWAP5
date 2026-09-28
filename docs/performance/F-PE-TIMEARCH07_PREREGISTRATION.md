# F-PE-TIMEARCH07 preregistration — production timestep decision trace

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@70be0aeca1485dd626749d34e5c46aba166e2eb5`

Parents:

- TIMEARCH01 — architecture redesign qualified;
- TIMEARCH02 — executable legacy-compatible decision contracts;
- TIMEARCH03 — non-invasive attribution seam;
- TIMEARCH04 — event-scheduler separation target;
- TIMEARCH05 — retry ownership hierarchy;
- TIMEARCH06 — production decision-service extraction.

## Purpose

Add production-owned timestep provenance without changing timestep behavior.

The trace must make visible, for the latest timestep decision in a worker-local execution context:

- input dt;
- preferred dt before event clipping;
- executed/event-limited dt;
- accepted-step proposal reason;
- whether hard-event clipping changed the preferred dt;
- solver-retry decision reason and retry dt where applicable.

TIMEARCH07 does not introduce a new adaptive controller and does not preserve preferred dt across event clamps yet.

## Ownership

Trace state must be worker-local.

No new module-global mutable timestep trace is permitted.

The existing `a23bu_worker_context_t` is the owner.

Standalone execution without a worker must preserve historical behavior and incur no required trace dependency.

## Candidate production changes

Allowed:

1. add a compact timestep-trace carrier to `mod_a23bu_worker_execution_context`;
2. extend `TimeControl` with an optional worker argument;
3. pass the existing optional worker through the local `call_timecontrol` wrapper;
4. populate trace fields around the already extracted TIMEARCH06 decision-service calls and existing event clamp;
5. add typed generic limiting provenance:
   - NONE;
   - HARD_EVENT_CLAMP;
   - SOLVER_RETRY;
   - SOLVER_RETRY_FLOOR.

TIMEARCH07 deliberately does not yet split HARD_EVENT_CLAMP into day/output/meteo/rain/runon subtypes.

Not allowed:

- any change to dt arithmetic;
- event-scheduler reordering;
- preservation of pre-event proposal memory;
- day-start behavior change;
- DTMIN/DTMAX semantics change;
- transaction/temporal retry change;
- physics changes.

## Trace semantics

After accepted-step proposal in `TimeControl(3)`:

- `input_dt` = dt entering TIMEARCH06 accepted-step service;
- `preferred_dt` = service result before event clipping;
- `proposal_reason` = TIMEARCH06 reason code;
- `executed_dt` = dt after existing `get_dtevent()` clamp;
- `limit_reason` = HARD_EVENT_CLAMP only when event clipping reduced the preferred dt, otherwise NONE.

After solver retry in `TimeControl(5)`:

- `input_dt` = retry input dt;
- `preferred_dt = executed_dt` = TIMEARCH06 retry result;
- `proposal_reason` = SOLVER_RETRY or SOLVER_RETRY_FLOOR;
- `limit_reason` = corresponding retry reason.

Trace publication is diagnostic only and never read by TimeControl to choose dt.

## Preservation gates

### A. Worker-context lifecycle

Initialization, reset and release must produce deterministic empty trace state.

Existing worker scratch/diagnostic semantics must remain intact.

### B. Direct trace contract

Test at minimum:

- accepted grow without event clamp;
- accepted grow with event clamp;
- keep;
- MAXIT shrink;
- solver retry;
- solver retry floor;
- no-worker path.

### C. Exact timestep preservation

For every direct TimeControl test case, traced and untraced execution must return identical dt and flags.

### D. BOFEK preservation

Run the current 20-case Reference preservation/trace authority and require exact step/work identity plus current physical tolerance preservation.

### E. Canonical preservation

Run the current relevant F-CI and performance preservation suites.

## Decision

If all gates pass:

`QUALIFIED_PRODUCTION_TIMESTEP_DECISION_TRACE`

No algorithmic timestep change is admitted.

## Successor boundary

After TIMEARCH07, the next architecture workunit may separate controller preferred-step memory from event-limited executed dt, because both quantities will finally exist explicitly in production diagnostics.
