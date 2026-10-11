# F-PE-TIMEARCH04A result — event-clamp proposal-memory separation

Date: 2026-09-28

Status: `CHARACTERIZED_NOT_QUALIFIED`

Authority:

- canonical base: `integration/f-ci-canonical@b0269f6fe7e7cbfcf47095cd6d471eb2fb180036`;
- Actions run: `36421428498`;
- conclusion: SUCCESS.

## Frozen question

Can the scheduler clip an interval at an exact event while the numerical controller retains its pre-event preferred dt, avoiding fragmentation caused by feeding the shortened executed dt back into controller history?

## Result

Across the frozen 20-point scheduler grid:

- memory-separated D was non-inferior to scheduler-only B in 16/20 points;
- it improved B by >=10% in 6/20 points;
- best D/B step-count ratio: 0.667, about 33% fewer steps;
- median D/B ratio: about 0.992;
- worst D/B ratio: about 1.006, roughly 0.6% more steps.

The preregistered advancement rule required D <= B at every grid point.

That rule is not met.

## Interpretation

Proposal-memory separation is a real mechanism: periodic event clipping can fragment subsequent stepping when the shortened executed interval overwrites numerical proposal memory.

However, the simple frozen D rule is not uniformly better.

The small regressions show that event-clipped history cannot simply be ignored unconditionally. A future controller needs an explicit policy for whether an event-limited accepted interval contains useful numerical evidence.

## Decision

TIMEARCH04A does not qualify a replacement controller rule.

It does support the architectural separation already qualified in TIMEARCH01:

- preferred numerical interval;
- executed event-limited interval;
- typed clamp provenance

must remain separately observable.

No production source change.
