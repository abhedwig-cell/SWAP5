# F-PE-NLGLOB14Z14A result — three-fixture pre-event failure attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z14A_THREE_FIXTURE_RETRY_ATTRIBUTION`

Qualification authority:

- workflow run: `36680488191`;
- job: `109774637097`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

What is the first terminal mechanism in the three Z14 controls that fail before aggregate qualification of:

`12:16 -> 13:16`?

## Aggregate result

All three classify:

`QUALIFIED_Z14A_PRE_EVENT_RETRY_ATTRIBUTION`.

Aggregate classification:

`QUALIFIED_Z14A_THREE_FIXTURE_RETRY_ATTRIBUTION`.

## Failure attribution

### HEAD, dt = 6.25e-5 d

- failure step: 2,649,048;
- failure time: 165.565500 d;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated count at failure origin: 5;
- accepted tail: 12:16;
- last accepted tail-change event: 11:16 -> 12:16 at 123.587875 d;
- target 12:16 -> 13:16 not yet exposed.

### RUNOFF, dt = 1.25e-4 d

- failure step: 1,659,714;
- failure time: 207.464250 d;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated count at failure origin: 5;
- accepted tail: 12:16;
- last accepted tail-change event: 11:16 -> 12:16 at 123.584500 d;
- target 12:16 -> 13:16 not yet exposed.

### RUNOFF, dt = 6.25e-5 d

- failure step: 1,138,915;
- failure time: 71.1821875 d;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated count at failure origin: 6;
- accepted tail: 11:16;
- last accepted tail-change event: 10:16 -> 11:16 at 53.9913125 d;
- target 12:16 -> 13:16 not yet exposed.

## State and mass

All three accepted origins remain:

- finite;
- geometrically consistent;
- mass-clean.

Observed maxima:

- interval physical mass ledger: about `2.36e-14 cm`;
- cumulative accepted ledger: about `4.09e-12 cm`.

## Scientific interpretation

None of the three Z14 blockers is a hard physical-state failure.

Each is a local nonlinear interval-resolution event for which the solver explicitly requests temporal subdivision.

The failures occur at different physical phases and times, so they must not be collapsed into a fitted global event threshold.

## Consequence

A separately preregistered Z14B may test the already qualified one-level bounded transaction recovery:

`dt -> dt/2 + dt/2 -> dt`

at the first retry-advised interval of each blocked fixture.

No tolerance tuning, forcing change or recursive subdivision is authorized.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
