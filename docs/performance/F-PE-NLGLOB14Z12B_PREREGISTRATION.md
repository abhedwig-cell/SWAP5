# F-PE-NLGLOB14Z12B preregistration — local fine-RUNOFF retry recovery

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z12A: `QUALIFIED_FINE_RUNOFF_PRE_EVENT_RETRY_ATTRIBUTION`;
- fine RUNOFF dt = 6.25e-5 d first fails at 71.1821875 d;
- terminal mechanism is `ENDPOINT_SOLVE_FAILURE`, solver status 2, retry advised;
- accepted origin remains finite, mass-clean and at saturated tail `11:16`.

## Purpose

Determine whether the first fine-RUNOFF pre-event retry-advised interval is locally transaction-recoverable using the already qualified one-level bounded subdivision:

`dt -> dt/2 + dt/2 -> dt`.

This workunit does not yet attempt the `11:16 -> 12:16` event.

## Frozen fixture

Use exactly:

- O05;
- route = RUNOFF;
- nominal dt = 6.25e-5 d;
- horizon = 75.0 d;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged persistent-KLAG control.

## Frozen retry semantics

At the first persistent-KLAG nominal interval returning retry advised:

1. reject the nominal candidate;
2. restore accepted physical state, workspace and accepted accounting exactly;
3. set temporary dt = 0.5 * nominal dt;
4. execute first ordinary KLAG half interval;
5. if accepted, execute second ordinary KLAG half interval;
6. restore nominal dt;
7. continue to 75.0 d.

No recursive subdivision.

If either half requests retry, classify it and stop.

## Hard gates

Require:

- nominal retry reproduced;
- exact rollback in h, theta, ponding, ledger and runoff;
- both half intervals accepted;
- no half-step retry;
- exact one-nominal-window time recovery;
- nominal dt restored afterward;
- complete 75.0 d trajectory;
- finite accepted state;
- physical mass valid;
- no recurrent retry before 75.0 d.

## Frozen classification

If all gates pass:

`QUALIFIED_FINE_RUNOFF_LOCAL_RETRY_RECOVERY`.

If the first half still requests retry:

`NLGLOB14Z12B_HALFSTEP_INSUFFICIENT`.

If recovery succeeds but a later nominal retry recurs before 75 d:

`NLGLOB14Z12B_RECOVERY_WITH_RECURRENT_RETRY`.

Any transaction/mass inconsistency:

`NLGLOB14Z12B_RETRY_TRANSACTION_INCONSISTENT`.

Any hard non-retry failure:

`NLGLOB14Z12B_LOCAL_RECOVERY_HARD_FAILURE`.

## Consequence

Only a positive result authorizes Z12C continuation of the repaired fine-RUNOFF trajectory to the physical `11:16 -> 12:16` event.

## Production boundary

Research only. No production source/default change.
