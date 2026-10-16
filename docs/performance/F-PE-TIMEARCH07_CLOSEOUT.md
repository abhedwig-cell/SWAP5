# F-PE-TIMEARCH07 closeout — production timestep decision trace

Date: 2026-09-28

Final status:

`QUALIFIED_PRODUCTION_TIMESTEP_DECISION_TRACE`

## Architectural position

TIMEARCH06 extracted the first timestep decisions into an explicit pure production service.

TIMEARCH07 now makes those decisions observable in worker-local runtime state without changing execution.

For the first time, production code can distinguish:

- the numerical controller's preferred dt;
- the dt actually executed after event clipping;
- accepted-step proposal reason;
- solver-retry reason.

This is the production seam needed to stop treating one mutable `dt` value as both proposal and outcome.

## Preserved behavior

Unchanged:

- timestep sequence;
- DTMIN/DTMAX semantics;
- event scheduler;
- day-start rule;
- solver retry arithmetic;
- process-specific clamps;
- transaction retry;
- temporal acceptance;
- mass accounting;
- physics.

## Why this matters for the larger redesign

TIMEARCH03 showed the current fixed DTMAX is active on nearly half of accepted steps.

TIMEARCH04 showed event clipping and proposal memory are conceptually distinct.

Before TIMEARCH07, production did not retain both values explicitly.

Now it does.

That means the next experiment can finally ask a clean question:

> When an event temporarily clips a step, should the proposal controller retain its pre-event preferred dt rather than treating the clipped dt as new numerical evidence?

That question can now be tested without guessing the original preferred value.

## Recommended successor

`F-PE-TIMEARCH08 — preferred-step memory separation across event clamps`

TIMEARCH08 should remain behavior-preserving in its first phase:

1. accumulate/inspect preferred versus executed dt around hard-event clamps;
2. classify event-clipped accepted steps that are followed by slow regrowth;
3. run a shadow controller whose preferred-dt memory is not reset by event clipping;
4. quantify potential reduction in post-event fragmentation;
5. do not let the shadow controller alter execution until a separate qualification gate is passed.

A later workunit can then address the user's larger input question:

- whether DTMAX should become only a safety ceiling;
- whether ordinary users should need DTMIN/DTMAX at all.

## Production boundary

TIMEARCH07 changes diagnostic ownership only.

No adaptive algorithm change is admitted.
