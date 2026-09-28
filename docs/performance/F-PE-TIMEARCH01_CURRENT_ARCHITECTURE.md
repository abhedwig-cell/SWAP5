# F-PE-TIMEARCH01 current timestep architecture audit

Date: 2026-09-28

Authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

## Current ownership map

The current SWAP timestep path uses a single mutable `dt` as the meeting point for several independent concerns.

### 1. Numerical growth after a successful Richards step

Legacy `TimeControl(3)`:

`if numbit <= numbit_crit: dt = min(dt*fact_dt_increase, dtMax)`

`if numbit >= MaxIt: dt = max(dt*fact_dt_decrease, dtMin)`

This is accepted-step numerical policy.

### 2. Numerical recovery after nonlinear failure

Legacy `TimeControl(5)`:

`dt = dt / fact_dt_fldect`

bounded by `dtmin`.

This is failed-trial recovery.

It is semantically different from accepted-step growth, but both mutate the same `dt`.

### 3. Event alignment

`get_dtevent()` clips `dt` to:

- end of calendar day;
- output/print times;
- generic F-CI11 interval end;
- detailed meteo boundaries;
- rainfall-event boundaries;
- subsurface-irrigation boundaries;
- runon-event boundaries.

This is not numerical accuracy policy. It is time-axis scheduling.

### 4. Process-specific clamps

Additional timestep mutation exists for:

- interception events;
- macropore reduction;
- irrigation start/end behavior;
- day-start restart behavior.

These are process-control or discontinuity handling.

### 5. Day-oriented restart policy

At start of day:

`dt = max(dt, sqrt(dtmin*dtmax))`.

This can enlarge a numerically conservative timestep solely because a calendar-day boundary was crossed.

That is a legacy control-flow policy, not a general time-integration principle.

### 6. User bounds are mutated internally

At initialization:

- `dtmax` is reduced by output frequency;
- `dtmax` is reduced by detailed meteo interval;
- `dtmin = min(dtmin, 0.1*dtmax)`.

Therefore the runtime quantities named `dtmin` and `dtmax` are not simply the user's numerical bounds after initialization.

They already contain scheduler policy.

### 7. Maximum steps per day

`msteps` is checked per calendar day.

This is a protection against pathological stepping, but is coupled to the day-oriented loop rather than to a generic interval or work budget.

### 8. Transaction retry exists above legacy retry

SWAP5 transaction authority now supports:

- immutable committed origin;
- retry from the same origin;
- rollback;
- configurable retry scale;
- maximum retries;
- temporal rejection separately from solver rejection.

Thus SWAP5 has an outer retry layer while legacy SWAP still owns an inner `fldecdt -> TimeControl(5)` retry mechanism.

The two layers serve related but not identical purposes, and ownership is currently split.

### 9. Temporal acceptance exists above nonlinear convergence

F-CI14 and TEMPORAL authority explicitly separate:

- nonlinear solver convergence;
- mass acceptance;
- temporal error/certificate acceptance.

This is architecturally correct, but the accepted physical trajectory still runs through legacy `TimeControl` inside the model.

### 10. Coupling-window boundaries are already independent events

F-CI11 added a generic physical interval seam. `get_dtevent()` clips to the interval end.

This demonstrates that calendar-day ownership is no longer necessary for defining the externally requested physical integration interval.

## Architectural problems

### A. One variable carries multiple semantics

`dt` simultaneously means:

- solver trial duration;
- accepted-step proposal;
- event-clipped duration;
- retry duration;
- day-restart duration.

A later clamp loses the reason why the value changed.

### B. Requested bounds and effective bounds are conflated

`DTMAX` can be reduced because of printing or meteo cadence.

A user asking for a numerical maximum timestep is therefore also indirectly configuring scheduling behavior.

### C. Failure recovery and future-step adaptation are coupled

A failed nonlinear solve changes the same state that controls later accepted-step growth.

Modern solver architecture normally treats:

- trial rejection/recovery;
- next accepted-step proposal

as separate decisions.

### D. Calendar control leaks into numerical policy

Day start can enlarge dt to `sqrt(dtmin*dtmax)`.

Output timing can reduce `dtmax`.

These behaviors are historical implementation choices, not intrinsic Richards-equation requirements.

### E. Nested retry ownership is difficult to reason about

Current canonical architecture can contain:

- legacy internal Richards retries;
- transaction-level solver retries;
- temporal acceptance retries;
- coupling-level corrector retries.

Each is individually justified in some scope, but no single timestep authority owns the complete retry hierarchy.

### F. Static user DTMIN/DTMAX cannot express the actual accuracy problem

Recent BOFEK evidence shows safe timestep size depends strongly on:

- evolving hydraulic state;
- dynamic-top regime transitions;
- accepted history;
- process composition.

A single global `DTMAX` is therefore mostly a safety ceiling, not an accurate local timestep choice.

### G. Very small dt is not monotonically safer numerically

SHORTSTEP/TEMPORAL oracle work showed reduced timestep duration can make the current nonlinear path fail.

Therefore `DTMIN` is not simply an accuracy lower bound. It also interacts with nonlinear conditioning and balance floors.

## What is genuinely required

The following responsibilities must remain in any redesign:

1. exact alignment with discontinuous forcing/process events;
2. exact alignment with requested external interval end;
3. recoverable nonlinear failure;
4. bounded retry count / runaway protection;
5. hard mass-accounting preservation;
6. optional temporal-accuracy acceptance;
7. process-specific restrictions where physically justified;
8. deterministic accepted-state commit/rollback semantics.

None of these requires one global mutable `dt` variable or user-owned `DTMIN/DTMAX` as the central policy mechanism.

## Audit conclusion

The current timestep architecture demonstrably mixes more than three independently owned concerns.

The separation condition for redesign is satisfied.

This audit therefore advances to a target architecture rather than another parameter-tuning study.
