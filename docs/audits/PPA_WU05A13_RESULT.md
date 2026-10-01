# PPA-WU05-A13 result — RFM surface-event age service

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@ae4eede414692fb0071ea093050f5accd36dd48d

Qualified postimage:

    9ab2f5996c6698916c5febe1ddb8a2685ee8d56c

Qualification run:

    36861648257 — SUCCESS

Focused gate output:

    PPA_WU05A13_RFM_SURFACE_EVENT_AGE=PASS

## Qualified semantics

A13 promotes only deterministic surface-event age evolution.

For an already segmented active interval:

    evaluation_age = accepted_age + 0.5 * dt
    candidate_age  = accepted_age + dt

For an inactive interval:

    evaluation_age = 0
    candidate_age  = 0

The midpoint convention matches the qualified ALT23 standalone event integration.

## Transaction semantics

The service is pure candidate construction.

It does not mutate accepted age.

The focused gate proves bit-identical replay from the same accepted age and
therefore supports reject/discard/retry composition by an owning transaction
layer.

## Event-boundary ownership

A13 does not infer event activity from rainfall or flux values.

The caller remains responsible for:

- event-active identity;
- splitting intervals when event identity changes;
- committing or discarding candidate age;
- defining the effective infiltrating source.

This prevents A13 from silently becoming a surface-boundary owner.

## Qualified gates

- first active interval: midpoint/candidate age pass;
- continuous second interval: continuation pass;
- inactive accepted interval: reset pass;
- new event after reset: restart pass;
- retry/replay identity: pass;
- negative accepted age: fail closed;
- zero step duration: fail closed.

## Architecture boundary

A13 does not change:

- A8/A9/A10 source ownership;
- restart layouts;
- existing committed state;
- sigma_B ownership;
- preferential routing;
- f_MB or p.

It establishes only a production-grade event-age state transition primitive.

## Lifecycle

    implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this result.
