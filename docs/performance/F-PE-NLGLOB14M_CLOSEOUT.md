# F-PE-NLGLOB14M closeout — first saturated-block retreat event localization

Date: 2026-09-29

Final status:

`NLGLOB14M_FIRST_RETREAT_EVENT_LOCALIZED`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Qualification authority:

- run `36569300490`;
- job `109408977563`;
- conclusion: SUCCESS.

## Closure

NLGLOB14M closes positively.

All eight extended-dry fixtures provide a valid first-retreat bracket at the same physical retreat node, node 3.

The retreat event is defined by the existing saturation boundary:

`h_3 = 0`.

No empirical release threshold is introduced.

Both HEAD and RUNOFF route families satisfy the frozen timestep-convergence signal for the one-shot bracketed root estimate.

Physical mass remains at roundoff scale.

## Scientific conclusion

The persistent saturated-mode line now has a bounded, physically defined release-event candidate:

the first retreat of the maximum lower saturated block, expressed as the shallow edge node crossing from saturated to unsaturated.

This event is state-based, route-family reproducible and temporally convergent under refinement.

It is therefore suitable for a test-only release experiment.

## Direct successor

Open:

`F-PE-NLGLOB14N — retreat-event test-only saturated-mode release`.

The successor must preregister the release state machine before implementation.

At minimum:

1. release is allowed only at the localized first-retreat event;
2. the accepted state at release is continuous and no storage is modified by the switch itself;
3. the next interval returns to the unsaturated TG research policy;
4. immediate re-entry into saturated mode is detected and treated as chatter unless a new physical saturation event is independently localized;
5. physical interval and cumulative mass remain <= 5e-8 cm;
6. route/state remain finite and consistent;
7. the fixed wet-entry / dry-reversal fixtures complete without unsafe terminal reasons;
8. smooth TIMEINT16C second-order authority is rechecked with the release event inactive.

No production admission is implied by NLGLOB14N.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14M

BASELINE: `246eca153a7846c07e4981a07c6498528b771ee5`

BRANCH: `research/f-pe-nlglob14m-first-retreat-event`

STATUS: closed positive

TEST STATUS: focused 8-fixture event-localization run PASS

QUALIFICATION STATUS: `NLGLOB14M_FIRST_RETREAT_EVENT_LOCALIZED`

NEXT SAFE STEP: preregister NLGLOB14N test-only release-at-retreat-event state machine

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
