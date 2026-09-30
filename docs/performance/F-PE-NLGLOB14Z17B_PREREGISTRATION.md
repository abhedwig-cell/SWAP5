# F-PE-NLGLOB14Z17B preregistration — three-fixture local retry recovery

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z17A: `QUALIFIED_Z17_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`;
- blocked fixtures and first retry origins:
  - HEAD dt=6.25e-5 d at 165.5655 d;
  - RUNOFF dt=1.25e-4 d at 207.46425 d;
  - RUNOFF dt=6.25e-5 d at 71.1821875 d;
- all three failures are `ENDPOINT_SOLVE_FAILURE`, solver status 2, retry advised, with finite mass-clean accepted state.

## Purpose

Determine whether each first pre-event retry-advised interval is locally transaction-recoverable using the already qualified one-level subdivision:

`dt -> dt/2 + dt/2 -> dt`.

This workunit does not yet attempt `13:16 -> 14:16`.

## Frozen fixtures and local horizons

Use exactly:

- HEAD dt=6.25e-5 d, horizon = 170.0 d;
- RUNOFF dt=1.25e-4 d, horizon = 212.0 d;
- RUNOFF dt=6.25e-5 d, horizon = 75.0 d;
- O05;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged persistent-KLAG control.

## Frozen retry semantics

At the first persistent-KLAG nominal interval returning retry advised:

1. reject the nominal candidate;
2. restore accepted physical state, workspace and accepted accounting exactly;
3. set temporary dt = 0.5 * nominal dt;
4. execute one ordinary KLAG half interval;
5. if accepted, execute the second half;
6. restore nominal dt;
7. continue to the fixture's frozen local horizon.

No recursive subdivision.

## Hard gates

Per fixture require:

- nominal retry reproduced;
- exact rollback in h, theta, ponding, ledger and runoff;
- both half intervals accepted;
- no half-step retry;
- exact one-nominal-window time recovery;
- nominal dt restored;
- complete local horizon;
- finite accepted state;
- physical mass valid;
- no recurrent retry before local horizon.

## Frozen classifications

If all gates pass for a fixture:

`QUALIFIED_Z17B_LOCAL_RETRY_RECOVERY`.

If first half still requests retry:

`Z17B_HALFSTEP_INSUFFICIENT`.

If recovery succeeds but later nominal retry recurs before local horizon:

`Z17B_RECOVERY_WITH_RECURRENT_RETRY`.

Any transaction/mass inconsistency:

`Z17B_RETRY_TRANSACTION_INCONSISTENT`.

Any hard non-retry failure:

`Z17B_LOCAL_RECOVERY_HARD_FAILURE`.

Aggregate positive classification if all three qualify:

`QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY`.

## Consequence

Only a positive result authorizes repaired continuation of the three trajectories toward independently exposed `13:16 -> 14:16`.

No tolerance tuning, forcing change or recursive subdivision is authorized.

## Production boundary

Research only. No production source/default change.
