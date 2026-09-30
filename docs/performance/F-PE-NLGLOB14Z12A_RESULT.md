# F-PE-NLGLOB14Z12A result — fine-RUNOFF pre-event failure attribution

Date: 2026-09-30

Status:

`QUALIFIED_FINE_RUNOFF_PRE_EVENT_RETRY_ATTRIBUTION`

Qualification authority:

- workflow run: `36675726320`;
- job: `109760143791`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Attribution

Fine RUNOFF at dt = 6.25e-5 d terminates at:

- step: `1138915`;
- time: `71.1821875 d`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: `2`;
- retry advised: true.

The accepted saturated tail at failure origin is exactly:

`11:16`.

The most recent accepted physical retreat remains the already qualified:

`10:16 -> 11:16`

at 53.9913125 d.

The target `11:16 -> 12:16` has not yet occurred.

## State and mass

At failure attribution:

- state is finite;
- accepted geometry remains contiguous;
- mass remains clean;
- max interval ledger about `2.36e-14 cm`;
- cumulative accepted ledger about `1.38e-13 cm`.

## Scientific interpretation

The Z12 fine-RUNOFF blocker is a local nonlinear retry-advised interval, not a hard physical-state failure.

The accepted origin remains valid and the solver explicitly requests temporal subdivision.

## Consequence

A separately preregistered Z12B may test exact rollback followed by one bounded recovery:

`dt -> dt/2 + dt/2 -> dt`

at the first failure origin.

No tolerance tuning or forcing change is authorized.

## Production boundary

Research only. No production source/default change.
