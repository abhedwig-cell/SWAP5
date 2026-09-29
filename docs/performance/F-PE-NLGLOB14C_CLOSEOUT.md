# F-PE-NLGLOB14C closeout — saturated-remainder KLAG regime switch

Date: 2026-09-29

Final status:

`NLGLOB14C_MIXED_REGIME_SWITCH_SIGNAL`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@262190047ff97399cb1368cf45d7965dedf6de86`

Qualification authority:

- run `36561512075`;
- job `109383237953`;
- conclusion: SUCCESS.

## Closure

NLGLOB14C closes the one-event TG-to-KLAG remainder experiment as a mixed signal.

All five first saturation-event splits succeed physically:

- event localization succeeds;
- exact remainder duration is positive;
- KLAG remainder converges;
- nominal and cumulative mass remain near roundoff;
- no process failure occurs.

But none of the five trajectories completes the requested horizon.

All fail later with:

`SATURATION_ROOT_BRACKET_INVALID`.

## Scientific conclusion

The first post-saturation KLAG remainder is admissible.

The remaining failure is caused by returning to the TG event machinery at the next nominal interval while the trajectory is still at or extremely near saturation.

Therefore a one-remainder regime switch is too short-lived.

This is not evidence for recursive subdivision or event-time tuning.

## Direct successor

Open:

`F-PE-NLGLOB14D — persistent saturated-mode continuation after first TG saturation event`.

Freeze the bounded candidate before results:

1. use the unchanged NLGLOB14A event localization for the first saturation crossing;
2. integrate the first remainder with KLAG;
3. set an internal research saturated-mode flag;
4. while that flag is active, integrate subsequent nominal intervals using KLAG directly;
5. do not invoke TG saturation-event localization again while saturated mode is active;
6. do not switch back to TG inside NLGLOB14D;
7. retain unchanged dynamic-top provider evaluation every interval;
8. retain S0/R0 endpoint certificates;
9. retain the physical interval/cumulative mass contract;
10. leave no-event trajectories entirely on TG.

A separate future workunit is required for desaturation/release semantics.

## Preserved authority

- TIMEINT16C smooth second-order authority remains positive.
- NLGLOB14A event localization remains positive.
- NLGLOB14B unchanged-TG remainder remains negative.
- NLGLOB12A1/R0 endpoint certificate remains positive at research level.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14C

BASELINE: `31901d9bbb75d87e8723c09f6804dabbcc25c219`

CANONICAL RECONCILED THROUGH: `262190047ff97399cb1368cf45d7965dedf6de86`

BRANCH: `research/f-pe-nlglob14c-saturated-remainder-klag`

STATUS: closed mixed

IMPLEMENTATION STATUS: one-event TG-to-KLAG remainder research mechanism persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB14C_MIXED_REGIME_SWITCH_SIGNAL`

DEPENDENCIES / BLOCKERS: all five targets fail only on subsequent nominal re-entry to TG event logic

NEXT SAFE STEP: preregister NLGLOB14D persistent saturated-mode continuation

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
