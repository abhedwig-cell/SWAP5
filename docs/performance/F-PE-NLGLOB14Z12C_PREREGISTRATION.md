# F-PE-NLGLOB14Z12C preregistration — repaired fine-RUNOFF continuation to 11:16 -> 12:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:

- NLGLOB14Z12A: `QUALIFIED_FINE_RUNOFF_PRE_EVENT_RETRY_ATTRIBUTION`;
- NLGLOB14Z12B: `QUALIFIED_FINE_RUNOFF_LOCAL_RETRY_RECOVERY`;
- fine RUNOFF dt = 6.25e-5 d first requests retry at 71.1821875 d;
- one exact rollback + `dt/2 + dt/2` recovery crosses that interval and completes 75 d without recurrent retry;
- the other three Z12 controls accept exact `11:16 -> 12:16` near 123.585 d.

## Purpose

Continue the repaired fine-RUNOFF trajectory to and beyond the physical `11:16 -> 12:16` event.

## Frozen fixture

Use exactly:

- O05;
- route = RUNOFF;
- nominal dt = 6.25e-5 d;
- horizon = 140.0 d;
- unchanged forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- same one-time Z12B recovery policy.

## Retry policy

Permit exactly one local recovery at the first retry-advised persistent-KLAG interval:

`dt -> dt/2 + dt/2 -> dt`.

After that recovery:

- nominal dt must resume;
- no second local repair is permitted;
- any recurrent retry is classified and stops the trajectory.

## Event definition

Require exact accepted transition:

`11:16 -> 12:16`

with contiguous saturated tails defined only by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No predictor crossing, fitted threshold, interpolation, extrapolation or control event time may define the event.

## Hard gates

Require:

- the known nominal retry is reproduced;
- rollback exact;
- both half steps accepted;
- no recurrent retry before 140 d;
- complete 140 d trajectory;
- exact accepted `11:16 -> 12:16`;
- finite accepted state;
- no reverse/skipped/noncontiguous geometry;
- physical mass valid.

## Frozen classifications

If all gates pass:

`QUALIFIED_REPAIRED_FINE_RUNOFF_RETREAT_11_TO_12`.

If local recovery succeeds but a recurrent retry occurs before the event:

`NLGLOB14Z12C_RECURRENT_RETRY_BEFORE_EVENT`.

If local recovery succeeds and event is reached but a later retry occurs before 140 d:

`NLGLOB14Z12C_POST_EVENT_RECURRENT_RETRY`.

If event is not reached despite complete valid 140 d trajectory:

`NLGLOB14Z12C_EVENT_NOT_REACHED`.

Any transaction/mass inconsistency:

`NLGLOB14Z12C_TRANSACTION_INCONSISTENT`.

## Consequence

A positive result repairs the missing fourth Z12 control event trajectory under the explicitly qualified bounded local-retry research policy.

That result may be combined with the three preserved Z12 accepted event trajectories to authorize a separately preregistered split ownership test through:

`11:16 -> 12:16`

with ownership:

`face 10/11 -> face 11/12`.

## Production boundary

Research only. No production source/default change.
