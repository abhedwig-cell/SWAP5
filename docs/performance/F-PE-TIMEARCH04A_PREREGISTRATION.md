# F-PE-TIMEARCH04A preregistration — event-clamp proposal-memory separation

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent:

F-PE-TIMEARCH04.

## Question

Can a separated scheduler retain the controller's preferred dt across a non-numerical event clamp and thereby avoid the fragmentation seen when executed dt is fed back as numerical-history evidence?

## Same scheduler grid

Reuse the frozen TIMEARCH04 grid:

- DTMIN user = 0.001 d;
- user DTMAX = 0.02, 0.05, 0.10, 0.25, 1.00 d;
- output cadence = 1, 1/24, 1/48, 1/96 d;
- 7-day horizon;
- daily hard event;
- easy low-iteration accepted-step behavior.

This is controller/scheduler mechanics only.

## Frozen new scenario D — MEMORY_SEPARATED

- numerical min/max remain user values;
- output remains an exact hard event;
- scheduler clips executable dt;
- controller stores a separate preferred dt.

Update rule:

1. before event clipping, controller has `preferred_dt`;
2. executable dt = min(preferred_dt, event remaining);
3. if executable dt was not event-clipped:
   - low-iteration success may grow preferred dt by factor 2, capped by numerical max;
4. if executable dt was event-clipped:
   - do not reduce preferred dt to executed dt;
   - do not use the short event-limited interval as evidence for further growth;
   - retain the prior preferred dt for the next interval.

Legacy-compatible day-start numerical floor is disabled in D because it is itself calendar-to-controller coupling.

Daily process event remains hard.

## Comparator

Compare D against:

- A CURRENT_COUPLED;
- B SCHEDULER_ONLY_OUTPUT.

## Metrics

- accepted steps;
- event clips;
- step-count ratio D/A;
- step-count ratio D/B;
- mean/median executed dt.

## Interpretation

A material architecture gain requires:

- D step count <= B for every grid point;
- D improves step count by >=10% versus B on at least one grid point where B showed fragmentation;
- exact output and daily event times remain hit.

This remains a scheduler-only mechanism study.

No physical accuracy claim is permitted.

## Production boundary

No production source change.
