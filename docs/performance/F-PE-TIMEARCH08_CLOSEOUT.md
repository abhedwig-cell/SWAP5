# F-PE-TIMEARCH08 closeout — preferred-step memory shadow

Date: 2026-09-28

Final status:

`QUALIFIED_PREFERRED_STEP_MEMORY_SHADOW`

TIMEARCH08 adds production-owned, worker-local shadow preferred-step memory while leaving actual timestep behavior unchanged.

The work confirms that scheduler clipping is not merely a one-step effect. Feeding event-limited dt back into numerical proposal memory can cause persistent post-event fragmentation.

No behavioral timestep change is admitted.

## Required successor

`F-PE-TIMEARCH09 — preferred-memory behavioral qualification and safety-bound semantics`

TIMEARCH09 should:

1. test a conservative retained-memory execution candidate;
2. retain exact hard-event boundaries;
3. preserve current solver retry and temporal-acceptance ownership;
4. use physical P-C1 and strict preservation gates, not scheduler step count alone;
5. evaluate DTMAX as a safety ceiling rather than as controller memory;
6. explicitly assess whether ordinary users still need to provide DTMIN and DTMAX.

The EVIDENCE shadow must not be enabled directly without separate calibration because TIMEARCH08 observed ratios up to about 12 times current post-event proposals.
