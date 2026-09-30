# F-PE-NLGLOB14Z17A result — three-fixture pre-event failure attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z17_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`

Qualification authority:

- workflow run: `36690908340`;
- jobs:
  - HEAD dt=6.25e-5: `109807648977`;
  - RUNOFF dt=1.25e-4: `109807648583`;
  - RUNOFF dt=6.25e-5: `109807649091`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

What is the first pre-event endpoint-solve boundary in the three Z17 controls that failed before accepted `13:16 -> 14:16`?

## Aggregate result

All three fixtures classify:

`Z17A_PRE_EVENT_RETRY_ATTRIBUTED`.

Aggregate qualification:

`QUALIFIED_Z17_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`.

No hard non-retry failure, state inconsistency or mass inconsistency is exposed.

## Fine RUNOFF — dt=6.25e-5 d

First failure:

- time: `71.1821875 d`;
- step: `1138915`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated tail at failure origin: `11:16`;
- last accepted tail-change event: `10:16 -> 11:16` at 53.9913125 d;
- target `13:16 -> 14:16`: not reached.

State is finite and mass-clean.

## Fine HEAD — dt=6.25e-5 d

First failure:

- time: `165.5655 d`;
- step: `2649048`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated tail at failure origin: `12:16`;
- last accepted tail-change event: `11:16 -> 12:16` at 123.587875 d;
- target event: not reached.

State is finite and mass-clean.

## Coarse RUNOFF — dt=1.25e-4 d

First failure:

- time: `207.46425 d`;
- step: `1659714`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated tail at failure origin: `12:16`;
- last accepted tail-change event: `11:16 -> 12:16` at 123.5845 d;
- target event: not reached.

State is finite and mass-clean.

## Physical mass

Accepted origins remain at roundoff-scale physical mass error.

Observed interval-ledger maxima:

- fine HEAD: about `1.83e-14 cm`;
- coarse RUNOFF: about `1.57e-14 cm`;
- fine RUNOFF: about `2.36e-14 cm`.

## Scientific interpretation

All three Z17 blockers are local nonlinear temporal-resolution requests, not hard physical-state failures.

The solver explicitly requests retry in every blocked fixture.

These origins have already appeared in earlier long-horizon work and are consistent with the qualified local-recovery pattern.

## Consequence

Open a separately preregistered one-level recovery workunit for the three fixtures using exactly:

`dt -> dt/2 + dt/2 -> dt`.

Require exact rollback and no recursive subdivision.

Do not tune tolerances, forcing or physical thresholds.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
