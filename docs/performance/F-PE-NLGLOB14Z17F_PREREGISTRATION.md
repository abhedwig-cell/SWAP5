# F-PE-NLGLOB14Z17F preregistration — two-recovery fine-RUNOFF continuation to 13:16 -> 14:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Parent authority:

- NLGLOB14Z17 preserves one unmodified accepted control event `13:16 -> 14:16` in coarse HEAD at 514.664625 d;
- NLGLOB14Z17C qualifies repaired event exposure in:
  - HEAD fine at 514.66475 d;
  - RUNOFF coarse at 514.661375 d;
- fine RUNOFF in Z17C is blocked by a second retry at 348.0423125 d before target event;
- NLGLOB14Z17D qualifies that second origin as retry-advised, finite and mass-clean;
- NLGLOB14Z17E qualifies two separate local recoveries for fine RUNOFF through 360.0 d with no third retry.

## Purpose

Continue the fine-RUNOFF trajectory to and beyond exact accepted:

`13:16 -> 14:16`

using exactly the two already-qualified local recovery windows and no additional repair.

## Frozen fixture

Use exactly:

- O05;
- route = RUNOFF;
- nominal dt = 6.25e-5 d;
- horizon = 540.0 d;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged persistent-KLAG control.

## Retry policy

Permit exactly two local recovery windows:

1. first known retry at 71.1821875 d;
2. second known retry at 348.0423125 d.

Each uses:

`dt -> dt/2 + dt/2 -> dt`.

After the second recovery:

- nominal dt must resume;
- no third local repair is permitted;
- any third retry stops the trajectory and is classified.

## Event definition

Require exact accepted transition:

`13:16 -> 14:16`

with contiguous saturated tails defined only by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted threshold, interpolation, extrapolation or event-time forcing.

## Hard gates

Require:

- both known retries reproduced;
- exact rollback at both origins;
- four accepted halfsteps total;
- no half-step retry;
- no third retry before 540 d;
- complete 540.0 d trajectory;
- exact accepted `13:16 -> 14:16`;
- finite accepted state;
- no reverse/skipped/noncontiguous geometry;
- physical mass valid.

## Frozen classifications

If all gates pass:

`QUALIFIED_Z17F_REPAIRED_FINE_RUNOFF_RETREAT_13_TO_14`.

If both recoveries succeed but a third retry occurs before event:

`Z17F_THIRD_RETRY_BEFORE_EVENT`.

If target event is accepted but a third retry occurs before 540 d:

`Z17F_POST_EVENT_THIRD_RETRY`.

If event is not reached despite complete valid 540 d:

`Z17F_EVENT_NOT_REACHED`.

Any transaction/mass inconsistency:

`Z17F_TRANSACTION_INCONSISTENT`.

## Consequence

A positive result, combined with the three preserved accepted control trajectories, restores four-fixture research authority for:

`13:16 -> 14:16`.

That may authorize a separately preregistered split ownership test:

`face 12/13 -> face 13/14`.

## Production boundary

Research only. No production source/default change.
