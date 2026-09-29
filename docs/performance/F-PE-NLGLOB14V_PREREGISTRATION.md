# F-PE-NLGLOB14V preregistration — second-retreat control exposure

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Parent research authority:

- NLGLOB14U closed positive for bounded accepted split-state persistence;
- actual interface motion beyond face 3/4 was not exercised because neither split nor persistent-KLAG control showed a second retreat within 0.05 d;
- NLGLOB14L established only the first 14 -> 13 retreat within 0.05 d.

## Purpose

Establish independently from the persistent-KLAG physical control whether and when a genuine second saturated-block retreat occurs:

`nodes 4:16 -> nodes 5:16`

under unchanged dry forcing.

This workunit does not run or tune the split solver. It exists to expose the physical event before any moving-interface claim is tested.

## Frozen fixtures

Use O05 with:

- HEAD and RUNOFF entry families;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- unchanged NLGLOB14N3 root-controller research policy;
- unchanged dry forcing;
- persistent saturated-KLAG control;
- physical mass as authority.

## Frozen staged horizons

Run the control first to 0.10 d.

If **no** fixture exposes a genuine accepted 13 -> 12 retreat by 0.10 d, run the same bank to 0.20 d.

The second stage is therefore triggered only by absence of the event in the independent control. No split behavior may influence horizon selection.

## Event definition

A second-retreat event exists only when accepted-state saturation geometry changes from:

- contiguous saturated set nodes 4:16, count 13

to:

- contiguous saturated set nodes 5:16, count 12.

The event must be observed in accepted physical states.

Do not use:

- fitted pressure thresholds;
- theta hysteresis;
- predictor-only crossings;
- saturated-count release heuristics detached from the accepted node set.

## Required diagnostics

Per fixture record:

- selected horizon;
- complete/finite/mass-clean status;
- first accepted 13-node state;
- first accepted 12-node state after it;
- last accepted 13-node time;
- first accepted 12-node time;
- accepted saturated sets on both sides;
- whether the transition is exactly 4:16 -> 5:16;
- any noncontiguous set;
- any reverse 12 -> 13 move after the event;
- max and cumulative physical mass ledger.

## Frozen classifications

If all 8 fixtures expose an exact accepted 4:16 -> 5:16 transition within the staged horizon:

`QUALIFIED_SECOND_RETREAT_CONTROL_EXPOSURE`.

If some but not all expose it:

`NLGLOB14V_MIXED_SECOND_RETREAT_EXPOSURE`.

If none expose it by 0.20 d:

`NLGLOB14V_NO_SECOND_RETREAT_WITHIN_0P20D`.

Any noncontiguous/inconsistent geometry:

`NLGLOB14V_SECOND_RETREAT_STATE_INCONSISTENT`.

Any control process or mass failure:

`BLOCKED_NLGLOB14V_CONTROL_EXPOSURE`.

## Consequence boundary

Only a positive second-retreat exposure may authorize a successor that tests whether the accepted split trajectory moves ownership face 3/4 -> 4/5 at the physical event.

No production source change is authorized.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14V

BASELINE: `183e3b645b80c47b7fa3083eaa25d420b2650973`

BRANCH: `research/f-pe-nlglob14v-second-retreat-exposure`

NEXT SAFE STEP: implement the staged persistent-KLAG control exposure and run the 8-fixture bank.

## Production boundary

Research only. `LEGACY_NUMERICS` remains production default.
