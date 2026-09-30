# F-PE-NLGLOB14Z14A result — three-fixture pre-event failure attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z14_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`

Qualification authority:

- workflow run: `36680589640`;
- jobs:
  - HEAD dt=6.25e-5: `109774942467`;
  - RUNOFF dt=1.25e-4: `109774942046`;
  - RUNOFF dt=6.25e-5: `109774942262`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

What is the first pre-event endpoint-solve boundary in the three Z14 controls that failed before accepted `12:16 -> 13:16`?

## Aggregate result

All three fixtures classify:

`Z14A_PRE_EVENT_RETRY_ATTRIBUTED`.

Aggregate qualification:

`QUALIFIED_Z14_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`.

No fixture exposes a hard non-retry failure, state inconsistency or mass inconsistency.

## Fine RUNOFF — dt=6.25e-5 d

First failure:

- time: `71.1821875 d`;
- step: `1138915`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated tail at failure origin: `11:16` (6 saturated nodes);
- last accepted tail-change event: `10:16 -> 11:16` at 53.9913125 d;
- target `12:16 -> 13:16`: not yet reached.

State is finite and mass-clean.

This reproduces the already qualified Z12A retry origin.

## Fine HEAD — dt=6.25e-5 d

First failure:

- time: `165.5655 d`;
- step: `2649048`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated tail at failure origin: `12:16` (5 saturated nodes);
- last accepted tail-change event: `11:16 -> 12:16` at 123.587875 d;
- target `12:16 -> 13:16`: not yet reached.

State is finite and mass-clean.

## Coarse RUNOFF — dt=1.25e-4 d

First failure:

- time: `207.46425 d`;
- step: `1659714`;
- terminal reason: `ENDPOINT_SOLVE_FAILURE`;
- solver status: 2;
- retry advised: true;
- accepted saturated tail at failure origin: `12:16` (5 saturated nodes);
- last accepted tail-change event: `11:16 -> 12:16` at 123.5845 d;
- target `12:16 -> 13:16`: not yet reached.

State is finite and mass-clean.

## Physical mass

All three failures occur from accepted origins with physical mass near roundoff.

Observed interval-ledger maxima remain approximately:

- fine HEAD: `1.83e-14 cm`;
- coarse RUNOFF: `1.57e-14 cm`;
- fine RUNOFF: `2.36e-14 cm`.

## Scientific interpretation

The three Z14 blockers are local nonlinear temporal-resolution requests, not hard physical-state failures.

The solver explicitly requests retry in every blocked fixture.

Therefore bounded transaction-safe subdivision is scientifically admissible as the next research question.

Fine RUNOFF's first retry already has independent local-recovery qualification from Z12B. The newly exposed recovery questions are fine HEAD at 165.5655 d and coarse RUNOFF at 207.46425 d.

## Consequence

Open a separately preregistered local recovery workunit for:

- fine HEAD at its first retry origin;
- coarse RUNOFF at its first retry origin.

Use exactly:

`dt -> dt/2 + dt/2 -> dt`

with exact rollback and no recursive subdivision.

Do not tune solver tolerances, forcing or physical thresholds.

## Production boundary

Research only. No production source/default change.
