# F-PE-NLGLOB14G closeout — forcing-reversal desaturation fixture

Date: 2026-09-29

Final status:

`NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL`

Canonical authority rechecked before closeout through:

`integration/f-ci-canonical@e355dacf50fcc0cceb77e02f73b78eddebcbeced`

Qualification authority:

- run `36564922905`;
- job `109394454586`;
- conclusion: SUCCESS.

## Closure

NLGLOB14G closes the first explicit drying fixture negatively.

Across all eight preregistered O05/TG HEAD/RUNOFF trajectories:

- saturated mode is entered;
- the frozen dry forcing is applied exactly;
- the full 0.012 d horizon completes;
- physical mass remains at roundoff scale;
- no head/moisture saturation-indicator inconsistency occurs;
- no accepted desaturation/release state is observed.

## Scientific conclusion

A physically explicit drying boundary is not sufficient, over this short bounded horizon, to identify the release transition.

The next question is therefore not a release threshold.

It is whether the accepted event-node state under dry forcing is moving toward desaturation or remains effectively pinned to the saturated manifold.

## Direct successor

Open:

`F-PE-NLGLOB14H — dry-phase saturation-manifold drift attribution`.

The successor must remain observational.

For each of the eight NLGLOB14G fixtures, quantify across accepted dry-phase persistent-KLAG intervals:

- event-node pressure head trajectory;
- event-node `theta_s-theta`;
- monotonicity of pressure-head decline;
- whether the state changes at representable precision;
- top flux, bottom flux and ponding evolution;
- cumulative evaporative removal.

If the event node moves monotonically toward negative head while remaining finite and mass-clean, a separately preregistered longer-horizon fixture may be justified.

If the event node is stationary despite nonzero evaporative removal, the physical fixture or saturated-mode formulation needs separate attribution before extending the horizon.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14G

BASELINE: `e46985908b19f83cf2f17f86507aa3495df971a2`

BRANCH: `research/f-pe-nlglob14g-forcing-reversal`

STATUS: closed negative attribution

TEST STATUS: focused eight-fixture run PASS

QUALIFICATION STATUS: `NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL`

NEXT SAFE STEP: preregister NLGLOB14H dry-phase manifold-drift attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
