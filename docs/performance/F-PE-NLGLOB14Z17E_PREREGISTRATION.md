# F-PE-NLGLOB14Z17E preregistration — second local retry recovery

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Parent authority:

- NLGLOB14Z17D: `QUALIFIED_Z17D_SECOND_RETRY_ATTRIBUTION`;
- fine RUNOFF dt=6.25e-5 d has:
  - first retry at 71.1821875 d, already qualified and locally recoverable;
  - second retry at 348.0423125 d;
- second retry is `ENDPOINT_SOLVE_FAILURE`, solver status 2, retry advised;
- accepted origin tail is `13:16`;
- state, geometry and mass remain clean;
- target `13:16 -> 14:16` has not yet occurred.

## Purpose

Determine whether the second fine-RUNOFF retry-advised interval is locally transaction-recoverable using one additional already-qualified one-level subdivision.

## Frozen fixture

Use exactly:

- O05;
- route = RUNOFF;
- nominal dt = 6.25e-5 d;
- horizon = 360.0 d;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged persistent-KLAG control.

## Frozen retry policy

Permit exactly two local recoveries total:

1. first known retry near 71.1821875 d:
   `dt -> dt/2 + dt/2 -> dt`;
2. second known retry near 348.0423125 d:
   `dt -> dt/2 + dt/2 -> dt`.

For each recovery:

- reject the nominal retry candidate;
- restore accepted state, workspace and accepted accounting exactly;
- execute two half-dt KLAG intervals;
- restore nominal dt;
- continue.

No recursive subdivision.

A third retry before 360 d stops the trajectory and is classified.

## Hard gates

Require:

- both nominal retries reproduced;
- exact rollback at both retry origins;
- both half intervals accepted for both recoveries;
- no half-step retry;
- both nominal windows recovered exactly;
- nominal dt restored after each;
- complete 360.0 d trajectory;
- no third retry before 360 d;
- finite accepted state;
- physical mass valid;
- accepted geometry consistent.

## Frozen classifications

If all gates pass:

`QUALIFIED_Z17E_SECOND_LOCAL_RETRY_RECOVERY`.

If second recovery halfstep still retries:

`Z17E_SECOND_HALFSTEP_INSUFFICIENT`.

If both recoveries succeed but a third retry occurs before 360 d:

`Z17E_THIRD_RETRY_BEFORE_360D`.

Any transaction/mass inconsistency:

`Z17E_RETRY_TRANSACTION_INCONSISTENT`.

Any hard non-retry failure:

`Z17E_SECOND_RECOVERY_HARD_FAILURE`.

## Consequence

Only a positive Z17E result authorizes a separately preregistered fine-RUNOFF continuation toward exact accepted:

`13:16 -> 14:16`.

No production adaptive stepping, recursive subdivision, tolerance tuning or forcing change is authorized.

## Production boundary

Research only. No production source/default change.
