# F-PE-NLGLOB14Z14C preregistration — repaired continuation to 12:16 -> 13:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z14: one unmodified control accepts exact `12:16 -> 13:16` at 260.961125 d;
- NLGLOB14Z14A: all three blocked controls are clean `SW_SOLVE_RETRY_ADVISED` pre-event failures;
- NLGLOB14Z14B: all three first retry windows are locally recovered by exact `dt/2 + dt/2`, with no recurrent retry over their local horizons.

## Purpose

Continue the three repaired controls through and beyond the physical `12:16 -> 13:16` event.

If all three succeed, combine them with the preserved unmodified coarse-HEAD event to restore four-fixture research authority for the event.

## Frozen fixtures

Use exactly:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d.

For all:

- O05;
- horizon = 280.0 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- unchanged persistent-KLAG control.

## Retry policy

Permit exactly one local recovery at the already attributed first retry-advised interval of each fixture:

`dt -> dt/2 + dt/2 -> dt`.

After that recovery:

- nominal dt must resume;
- no second local repair is permitted;
- any recurrent retry is classified and stops the trajectory.

## Event definition

Require exact accepted transition:

`12:16 -> 13:16`

with contiguous saturated tails defined only by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted threshold, interpolation, extrapolation or event-time forcing.

## Hard gates

Per fixture require:

- known first retry reproduced;
- exact rollback;
- both half steps accepted;
- nominal dt restored;
- no recurrent retry before 280 d;
- complete 280 d trajectory;
- exact accepted `12:16 -> 13:16`;
- finite accepted state;
- no reverse/skipped/noncontiguous geometry;
- physical mass valid.

## Frozen classifications

If all gates pass:

`QUALIFIED_Z14C_REPAIRED_RETREAT_12_TO_13`.

If local recovery succeeds but recurrent retry occurs before the event:

`NLGLOB14Z14C_RECURRENT_RETRY_BEFORE_EVENT`.

If local recovery succeeds, event is reached, then a later retry occurs before 280 d:

`NLGLOB14Z14C_POST_EVENT_RECURRENT_RETRY`.

If event is not reached despite a complete valid 280 d trajectory:

`NLGLOB14Z14C_EVENT_NOT_REACHED`.

Any transaction/mass inconsistency:

`NLGLOB14Z14C_TRANSACTION_INCONSISTENT`.

## Aggregate interpretation

If all three repaired fixtures qualify:

`QUALIFIED_Z14C_THREE_REPAIRED_RETREAT_12_TO_13`.

Together with the preserved unmodified coarse-HEAD event, this restores four-fixture research authority for `12:16 -> 13:16`.

## Consequence

A positive result may authorize a separately preregistered split ownership test through:

`12:16 -> 13:16`

with ownership move:

`face 11/12 -> face 12/13`.

It does not authorize later retreats, disappearance, whole-column TG re-entry or production adaptive stepping.

## Production boundary

Research only. No production source/default change.
