# F-PE-NLGLOB14L closeout — extended dry-horizon saturated-block evolution

Date: 2026-09-29

Final status:

`NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@67e6abbacf53aada2f2613644446eea826602806`

Qualification authority:

- run `36568451822`;
- job `109406140099`;
- conclusion: SUCCESS.

## Closure

NLGLOB14L closes the fixed 0.05 d extended-dry-horizon experiment.

All eight fixtures show the same lifecycle:

- initial saturated-node count = 1;
- maximum saturated-node count = 14;
- first retreat occurs after the peak;
- final saturated-node count = 13;
- no fixture reaches zero saturated nodes within 0.05 d.

All 8 therefore classify `PARTIAL_RETREAT_AFTER_PEAK`.

Because the preregistered aggregate retreat classification additionally required at least four full-desaturation fixtures, the formal aggregate status remains:

`NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION`.

## Scientific conclusion

The lower saturated block is not permanently pinned.

It expands during early drying, then begins to retreat under continued dry forcing.

The first-retreat timing is stable with timestep refinement:

- HEAD family: approximately 0.0217–0.0221 d;
- RUNOFF family: approximately 0.0261–0.0265 d.

This is the first bounded physical event candidate for release semantics.

Complete disappearance of the saturated set is not observed within the frozen horizon and must not be inferred or extrapolated.

## Direct successor

Open:

`F-PE-NLGLOB14M — first saturated-block retreat event localization`.

The successor must remain observational first.

It should preregister:

1. the event definition as the first accepted state after the saturated-node count leaves its attained maximum;
2. event bracketing between the last peak-count state and first lower-count state;
3. event-time convergence across the four dt levels;
4. route-family consistency for HEAD and RUNOFF;
5. state and mass continuity across the bracket;
6. no pressure-head threshold and no release switch.

Only after event localization is qualified may a test-only temporal-mode release at that event be considered.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14L

BASELINE: `67e6abbacf53aada2f2613644446eea826602806`

BRANCH: `research/f-pe-nlglob14l-extended-dry-horizon`

STATUS: closed mixed classification with universal partial-retreat observation

TEST STATUS: focused 8-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION`

NEXT SAFE STEP: preregister NLGLOB14M first-retreat event localization

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
