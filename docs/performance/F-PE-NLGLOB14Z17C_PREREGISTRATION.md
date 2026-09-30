# F-PE-NLGLOB14Z17C preregistration — repaired continuation to 13:16 -> 14:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Parent authority:

- NLGLOB14Z17 preserves one unmodified accepted `13:16 -> 14:16` control event:
  - HEAD dt=1.25e-4 d at 514.664625 d;
- NLGLOB14Z17A: `QUALIFIED_Z17_THREE_FIXTURE_PRE_EVENT_RETRY_ATTRIBUTION`;
- NLGLOB14Z17B: `QUALIFIED_Z17B_THREE_FIXTURE_LOCAL_RECOVERY`;
- the three blocked controls each recover their first retry-advised interval by exact rollback + `dt/2 + dt/2`;
- no recurrent retry occurs over their local recovery horizons.

## Purpose

Continue the three repaired control trajectories to and beyond the physical:

`13:16 -> 14:16`

event and determine whether the missing three event trajectories can be restored without a second repair.

## Frozen fixtures

Use exactly:

- HEAD dt=6.25e-5 d;
- RUNOFF dt=1.25e-4 d;
- RUNOFF dt=6.25e-5 d;
- O05;
- horizon = 540.0 d;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged accepted-state event definition.

The 540 d horizon is beyond the independently exposed 514.664625 d event and is fixed before result exposure.

## Retry policy

For each fixture permit exactly one local recovery, at its already attributed first retry-advised persistent-KLAG interval:

`dt -> dt/2 + dt/2 -> dt`.

After that recovery:

- nominal dt resumes;
- no second local repair is permitted;
- any recurrent retry stops the trajectory and is classified.

## Event definition

Require exact accepted transition:

`13:16 -> 14:16`

with contiguous saturated tails defined only by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted threshold, interpolation, extrapolation or control event time may define the event.

## Hard gates

Per fixture require:

- known first nominal retry reproduced;
- rollback exact;
- both halfsteps accepted;
- no recurrent retry before 540 d;
- complete 540 d trajectory;
- exact accepted `13:16 -> 14:16`;
- finite accepted state;
- no reverse/skipped/noncontiguous geometry;
- physical mass valid.

## Frozen classifications

If all gates pass:

`QUALIFIED_Z17C_REPAIRED_RETREAT_13_TO_14`.

If local recovery succeeds but a recurrent retry occurs before the event:

`Z17C_RECURRENT_RETRY_BEFORE_EVENT`.

If local recovery succeeds and event is reached but a later retry occurs before 540 d:

`Z17C_POST_EVENT_RECURRENT_RETRY`.

If event is not reached despite complete valid 540 d trajectory:

`Z17C_EVENT_NOT_REACHED`.

Any transaction/mass inconsistency:

`Z17C_TRANSACTION_INCONSISTENT`.

Aggregate positive classification if all three qualify:

`QUALIFIED_Z17C_THREE_REPAIRED_RETREAT_13_TO_14`.

## Consequence

A positive result, combined with the preserved unmodified coarse-HEAD Z17 event, restores four-fixture control authority for:

`13:16 -> 14:16`.

That authorizes a separately preregistered split ownership test:

`face 12/13 -> face 13/14`.

It does not qualify later retreats, disappearance or whole-column TG re-entry.

## Production boundary

Research only. No production source/default change.
