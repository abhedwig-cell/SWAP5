# F-PE-NLGLOB14M closeout — first saturated-block retreat event localization

Date: 2026-09-29

Final status:

`NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Qualification authority:

- run `36569151757`;
- job `109408478863`;
- conclusion: SUCCESS.

## Closure

NLGLOB14M closes the first accepted-state retreat localization attempt negatively on temporal convergence, not on physical validity.

All eight node-3 retreat events are cleanly bracketed and mass-safe.

The two finest event-time estimates still differ more than the preregistered `6.25e-5 d` convergence bound for both route families.

## Scientific conclusion

The retreat event is a real constitutive boundary crossing.

The remaining problem is temporal resolution of the event time.

Do not reinterpret the current linear estimator as qualified and do not widen the gate.

## Direct successor

Open:

`F-PE-NLGLOB14N — refined first-retreat event-time convergence`.

Freeze two additional finer dt levels:

- `1.5625e-5 d`;
- `7.8125e-6 d`.

Reuse the same:

- O05 fixtures;
- HEAD and RUNOFF route families;
- 0.05 d horizon;
- node-3 event definition `h_3=0`;
- accepted-state bracket estimator.

The successor should test convergence using the two new finest estimates without changing the event definition.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14M

BASELINE: `246eca153a7846c07e4981a07c6498528b771ee5`

BRANCH: `research/f-pe-nlglob14m-first-retreat-localization`

STATUS: closed negative localization qualification

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`

NEXT SAFE STEP: preregister NLGLOB14N finer event-time convergence

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
