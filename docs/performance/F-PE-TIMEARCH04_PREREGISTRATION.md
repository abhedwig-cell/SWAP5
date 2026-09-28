# F-PE-TIMEARCH04 preregistration — hard-event density and scheduler ownership

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b0269f6fe7e7cbfcf47095cd6d471eb2fb180036`

Parents:

- TIMEARCH01 — timestep architecture redesign qualified;
- TIMEARCH02 — executable compatibility contracts qualified;
- TIMEARCH03 — timestep attribution seam qualified; fixed DTMAX materially active on the 20-case bank.

## Purpose

Separate unavoidable hard time-axis events from legacy control artifacts before designing a replacement timestep controller.

This workunit does not alter physical execution.

## Source-bound event inventory

Audit current TimeControl ownership for:

- end-of-day;
- output/print times;
- detailed meteorological records;
- precipitation events;
- SSDI/irrigation events;
- runon events;
- interception events;
- generic external interval end.

For each event classify:

1. physical/forcing discontinuity;
2. external contract boundary;
3. output/reporting boundary;
4. legacy calendar/control boundary.

## Double-binding question

Current initialization contains:

- `DTMAX = min(DTMAX, 1/NPRINTDAY)`;
- when detailed meteo is active, `DTMAX = min(DTMAX, DT_METEO)`;
- `DTMIN = min(DTMIN, 0.1*DTMAX)`.

Current `get_dtevent()` also clips executable dt to:

- output times;
- detailed meteo boundaries.

TIMEARCH04 tests whether permanently mutating the numerical bounds adds timestep pressure beyond exact event clipping.

## Scheduler-only decision simulation

Test-only, no Richards solve.

Assume an easy accepted-step sequence where every accepted step satisfies the low-iteration growth rule.

Frozen controller values:

- user DTMIN = 0.001 d;
- growth factor = 2;
- simulation horizon = 7 d.

User DTMAX grid:

- 0.02 d;
- 0.05 d;
- 0.10 d;
- 0.25 d;
- 1.00 d.

Output cadence grid:

- 1 d;
- 1/24 d;
- 1/48 d;
- 1/96 d.

A daily physical hard event remains in every scenario.

## Scenarios

### A. CURRENT_COUPLED

Emulate current initialization/control semantics:

- effective DTMAX = min(user DTMAX, output cadence);
- effective DTMIN = min(user DTMIN, 0.1*effective DTMAX);
- initial dt = sqrt(effective DTMIN*effective DTMAX);
- output cadence is also a hard event;
- daily boundary is a hard event;
- accepted low-iteration steps grow by factor 2 to effective DTMAX;
- legacy day-start floor is active.

### B. SCHEDULER_ONLY_OUTPUT

Separate numerical bounds from output scheduling:

- numerical max remains user DTMAX;
- numerical min remains user DTMIN;
- initial dt = sqrt(user DTMIN*user DTMAX);
- output cadence remains an exact hard event;
- daily boundary remains a hard event;
- event scheduler clips executable intervals;
- accepted next proposal grows from accepted executable dt;
- legacy-compatible day-start floor uses user numerical bounds.

This tests whether initialization mutation is redundant once exact output events remain.

### C. OUTPUT_DECOUPLED_SHADOW

Counterfactual architecture upper bound only:

- numerical bounds remain user bounds;
- output cadence does not constrain physical stepping;
- daily physical hard event remains;
- output is treated as an observation/reporting service.

This does not claim output semantics can already be preserved this way.

It only estimates the maximum scheduling opportunity if output can later be decoupled safely.

## Metrics

Per grid point record:

- total accepted steps;
- event-clipped steps;
- day-start resets;
- mean and median executable dt;
- step-count ratio B/A;
- step-count ratio C/A.

## Source guard

A source guard must verify current canonical still contains:

- output-frequency DTMAX mutation;
- detailed-meteo DTMAX mutation;
- DTMIN mutation;
- output event clipping;
- detailed-meteo event clipping;
- day-start geometric floor;
- generic interval clipping.

## Interpretation rules

1. If B materially reduces steps versus A while exact output events remain, bound mutation itself is a distinct inefficiency.
2. If B is close to A, output/meteo bound mutation is mainly architectural duplication rather than a large steady-state runtime cost.
3. If C is materially lower than B for fine output cadences, output scheduling is a potentially large future performance lever, but only after separate output-semantics qualification.
4. No result may generalize from this easy-solver decision simulation to physical accuracy.

A material step-count change is defined as >=10%.

## Production boundary

No production `src/**` change.

Possible outcome:

- `QUALIFIED_EVENT_SCHEDULER_SEPARATION_TARGET`;
- `CLOSED_EVENT_SCHEDULER_NOT_MATERIAL`;
- `BLOCKED_SOURCE_DRIFT`.
