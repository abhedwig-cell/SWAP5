# F-PE-NLGLOB14Z14B preregistration — three-fixture local retry recovery

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z14A: `QUALIFIED_Z14A_THREE_FIXTURE_RETRY_ATTRIBUTION`;
- all three blocked Z14 fixtures terminate at a clean accepted origin with `ENDPOINT_SOLVE_FAILURE`, solver status 2 and retry advised;
- failure times:
  - HEAD dt=6.25e-5: 165.565500 d;
  - RUNOFF dt=1.25e-4: 207.464250 d;
  - RUNOFF dt=6.25e-5: 71.1821875 d.

## Purpose

Determine whether each first retry-advised interval is locally transaction-recoverable using the already qualified one-level bounded subdivision:

`dt -> dt/2 + dt/2 -> dt`.

This workunit does not attempt qualification of the physical `12:16 -> 13:16` event.

## Frozen fixtures and local horizons

Use exactly:

- HEAD, dt=6.25e-5 d, horizon=170.0 d;
- RUNOFF, dt=1.25e-4 d, horizon=212.0 d;
- RUNOFF, dt=6.25e-5 d, horizon=75.0 d.

All use:

- O05;
- unchanged dry forcing;
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
7. continue to the fixture-specific local horizon.

No recursive subdivision.

If either half requests retry, classify it and stop.

## Hard gates

Per fixture require:

- first nominal retry reproduced;
- exact rollback in h, theta, ponding, ledger and runoff;
- both half intervals accepted;
- no half-step retry;
- exact recovery of one nominal time window;
- nominal dt restored afterward;
- complete local horizon;
- finite accepted state;
- physical mass valid;
- no recurrent retry before the local horizon.

## Frozen classifications

If all gates pass:

`QUALIFIED_Z14B_LOCAL_RETRY_RECOVERY`.

If first half still retries:

`NLGLOB14Z14B_HALFSTEP_INSUFFICIENT`.

If recovery succeeds but a later retry recurs before local horizon:

`NLGLOB14Z14B_RECOVERY_WITH_RECURRENT_RETRY`.

Any transaction/mass inconsistency:

`NLGLOB14Z14B_RETRY_TRANSACTION_INCONSISTENT`.

Any hard non-retry failure:

`NLGLOB14Z14B_LOCAL_RECOVERY_HARD_FAILURE`.

## Aggregate interpretation

If all three fixtures qualify:

`QUALIFIED_Z14B_THREE_FIXTURE_LOCAL_RECOVERY`.

Otherwise preserve per-fixture outcomes and do not proceed to event continuation for non-qualified members.

## Consequence

Positive Z14B authorizes a separately preregistered repaired continuation of the three trajectories toward the independently observed coarse-HEAD `12:16 -> 13:16` event.

No tolerance tuning, forcing change or production adaptive stepping is authorized.

## Production boundary

Research only. No production source/default change.
