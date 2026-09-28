# F-PE-TIMEARCH03 preregistration — timestep attribution and shadow observation

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e78e9094d3c6bb1bbb0816487289299e84b7e7a9`

Parents:

- TIMEARCH01 — `QUALIFIED_TIMESTEP_ARCHITECTURE_REDESIGN`;
- TIMEARCH02 — `QUALIFIED_EXECUTABLE_TIMESTEP_DECISION_CONTRACTS`.

## Purpose

Quantify why the current controller selects its timestep and how often alternative shadow proposals would request a different interval, without changing accepted execution.

TIMEARCH03 is observation-only.

## P0 — dynamic numerical attribution

Use the 16 exposed BOFEK01 screening cases on the corrected fixed-K dynamic-top SWKIMPL=0 route.

Execute the current Reference adaptive policy unchanged.

For every attempted interval record:

- current accepted time;
- controller dt before event clipping;
- executed dt after interval-end clipping;
- whether interval-end clipping occurred;
- converged/rejected;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- current proposal reason;
- next Reference dt;
- shadow uncapped-legacy proposal;
- shadow normalized-state proposal.

### Current proposal reason

Typed as:

- KEEP;
- GROW_LOW_ITER;
- SHRINK_MAX_ITER;
- GROW_THEN_SHRINK;
- SOLVER_RETRY;
- SOLVER_RETRY_FLOOR.

The Reference execution itself remains unchanged.

## Shadow A — uncapped legacy proposal

Use the exact same accepted-step iteration rule as current TimeControl, but replace the normal numerical ceiling with:

`shadow ceiling = 4 * current Reference DTMAX`.

This isolates how often the current DTMAX ceiling is active.

It does not execute.

Metrics:

- number/fraction of accepted decisions for which shadow A > Reference next dt;
- median and max ratio shadowA/reference;
- deterministic solver work occurring after DTMAX-limited decisions.

No speedup is inferred from these values.

## Shadow B — normalized accepted-state proposal

Observation-only reuse of the STATESTEP normalized signal:

`r_h = max_i(|dh_i| / max(10 cm, |h_i(t0)|))`

with frozen `R=0.40`.

`factor = clamp(sqrt(R/max(r_h,1e-12)),0.5,2.0)`

`shadowB = clamp(dt*factor,DTMIN,4*DTMAX_reference)`.

This shadow has no timestep authority.

Metrics:

- fraction shadowB > Reference next dt;
- fraction shadowB < Reference next dt;
- disagreement by dry/moist/wet/ponding case labels.

## P1 — source-bound event ownership registry

Inventory every current non-solver TimeControl limiter from canonical source.

Required registry classes:

- CALENDAR_DAY_END;
- OUTPUT_TIME;
- EXTERNAL_INTERVAL_END;
- DETAILED_METEO;
- RAIN_EVENT;
- SSDI_EVENT;
- RUNON_EVENT;
- INTERCEPTION_EVENT;
- IRRIGATION_EVENT;
- MACROPORE_RECOVERY;
- DAYSTART_COMPATIBILITY;
- INITIAL_OUTPUT_DTMAX_MUTATION;
- INITIAL_METEO_DTMAX_MUTATION;
- INITIAL_DTMIN_MUTATION.

Each entry records:

- source file/part;
- ownership class;
- whether it is a hard event, retry rule, compatibility rule or mutable numerical bound;
- redesign disposition candidate.

The source guard fails if a registered controlling source pattern disappears.

## Important inference boundary

The BOFEK P0 bank has no representative daily/output/meteo/irrigation event density.

Therefore P0 may quantify numerical proposal/retry attribution only.

P1 classifies full legacy event ownership statically but does not claim event-frequency runtime shares.

A later real-workload event trace is required before removing or relaxing event boundaries.

## Advancement

TIMEARCH03 succeeds if:

1. all 16 P0 Reference cases complete;
2. every attempted interval receives deterministic typed attribution;
3. trace counts reconcile exactly with case accepted/rejected totals;
4. shadow proposals do not affect physical outputs;
5. P1 registry source guard passes and covers all known TimeControl dt mutation/clamp surfaces;
6. a quantitative attribution report is produced.

Possible outcome:

`QUALIFIED_TIMESTEP_ATTRIBUTION_AND_SHADOW_OBSERVATION`.

## Production boundary

No production `src/**` changes.
