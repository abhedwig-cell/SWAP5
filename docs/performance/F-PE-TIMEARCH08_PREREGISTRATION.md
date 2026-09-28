# F-PE-TIMEARCH08 preregistration — preferred-step memory separation shadow

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@230f71ee3b2ca991624977fb3b73a2acd5f86f3a`

Parents:

- TIMEARCH01 — architecture redesign qualified;
- TIMEARCH02 — executable timestep contracts;
- TIMEARCH03 — current decision attribution;
- TIMEARCH04A — simple event-memory separation characterized but not qualified;
- TIMEARCH05 — retry ownership hierarchy;
- TIMEARCH06 — production proposal/retry services;
- TIMEARCH07 — production preferred/executed decision trace.

## Purpose

Measure, in production-owned diagnostics and without changing execution, how much numerical proposal memory is lost when a hard event clips an accepted step.

TIMEARCH08 is shadow-only.

No shadow value may be read back by TimeControl to choose `dt`.

## Shadow memories

Maintain two worker-local shadow preferred-dt memories.

### RETAIN

If the previously executed interval was not event-clipped:

- shadow preferred memory becomes the current legacy pre-event preferred dt.

If the previously executed interval was event-clipped:

- retain the pre-event preferred memory;
- do not replace it with the shorter executed dt;
- do not use the short interval's iteration count to change it.

### EVIDENCE

If the previously executed interval was not event-clipped:

- shadow preferred memory becomes the current legacy pre-event preferred dt.

If the previously executed interval was event-clipped:

- apply the exact TIMEARCH06 accepted-step decision formula to the prior shadow preferred memory using the current accepted step's `numbit`;
- keep the existing `dtmin`, `dtmax`, increase/decrease factors and thresholds;
- the event-limited executed duration itself is not used as the proposal base.

This tests whether numerical difficulty observed during the short event-limited step is useful while keeping scheduler duration out of controller memory.

## Trace

TIMEARCH07 trace remains authoritative for actual execution.

TIMEARCH08 adds diagnostic fields:

- shadow memory available;
- retain preferred dt;
- evidence preferred dt;
- previous decision was event-clipped.

No existing trace field changes meaning.

## Preservation gates

1. exact current timestep sequence;
2. exact solver retry sequence;
3. exact 20-case BOFEK preservation;
4. worker-context O0/O2 identity;
5. standalone no-worker path unchanged;
6. shadow fields are write-only with respect to timestep selection.

## Observation metrics

On synthetic event-clamp sequences and available production-shaped traces record:

- number of event-clipped accepted decisions;
- actual next preferred dt;
- RETAIN shadow preferred dt;
- EVIDENCE shadow preferred dt;
- steps needed for actual legacy proposal to return to the shadow level;
- potential post-event fragmentation.

No step-count reduction is claimed from shadow data alone.

## Advancement

TIMEARCH08 advances if:

- all preservation gates pass;
- shadow state is deterministic and worker-local;
- at least one event-clipped sequence shows persistent preferred/executed memory divergence after the clamp;
- RETAIN and/or EVIDENCE provides a well-defined non-mutating counterfactual for a later qualification workunit.

Possible result:

`QUALIFIED_PREFERRED_STEP_MEMORY_SHADOW`

No behavioral timestep change is permitted here.
